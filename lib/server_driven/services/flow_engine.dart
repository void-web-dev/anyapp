import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_config.dart';
import '../runtime/value_resolver.dart';
import 'action_engine.dart';
import 'session_store.dart';

/// Only native integration code may supply antifraud headers. Never use form,
/// initial-link JSON or the remote configuration itself as this provider.
typedef TrustedFlowHeaders =
    Future<Map<String, String>> Function(String scope, Uri origin);

class FlowEngine {
  FlowEngine(this.store, this.client, {this.trustedHeaders});
  final SessionStore store;
  final http.Client client;
  final TrustedFlowHeaders? trustedHeaders;
  final Map<String, _FlowState> _states = {};

  void reset(String scope) {
    final state = _states.remove(scope);
    state?.cancel();
  }

  Future<ActionResult> execute({
    required AppConfig config,
    required String scope,
    required ActionConfig action,
    required Map<String, dynamic> form,
    required Map<String, dynamic> data,
  }) async {
    final state = _states.putIfAbsent(scope, _FlowState.new);
    if (state.busy) throw const ActionFailure('Действие уже выполняется');
    state.busy = true;
    state.form = form;
    try {
      final tokens = await store.readTokens(scope);
      final device = await store.readOrCreateDeviceId(scope);
      state.check();
      final run = _FlowRun(this, config, scope, state, {
        'form': form,
        'data': data,
        'products': data['products'] ?? <String, dynamic>{},
        'scratch': <String, dynamic>{},
        'challenge': state.challenge,
        'session': tokens.toRuntimeMap(),
        'host': {'applicationScopedStableDeviceId': device},
      });
      try {
        await run.step(action.definition!);
      } on _FlowCancelled {
        rethrow;
      } catch (failure) {
        if (failure is ActionFailure && failure.statusCode == 401) {
          await run.clear(['session', 'products', 'challenge', 'data', 'form']);
          run.navigation = config.initialScreen;
        }
        // Do not reflect transport exceptions or server messages containing secrets.
        return ActionResult(
          statusCode: 400,
          body: const {},
          navigateTo: run.navigation,
          replaceHistory: true,
          flowError: run.error ?? 'Не удалось выполнить сценарий',
        );
      }
      state.check();
      data['products'] = run.roots['products'];
      return ActionResult(
        statusCode: 200,
        body: const {},
        navigateTo: run.navigation,
        replaceHistory: run.replaceHistory,
      );
    } on _FlowCancelled {
      throw const ActionFailure('Сценарий отменён');
    } finally {
      state.busy = false;
      state.form = null;
    }
  }
}

class _FlowCancelled implements Exception {}

class _FlowState {
  Map<String, dynamic>? form;
  final challenge = <String, dynamic>{};
  final requests = <Completer<void>>{};
  bool busy = false;
  bool cancelled = false;
  void check() {
    if (cancelled) throw _FlowCancelled();
  }

  void abortRequests() {
    for (final request in requests) {
      if (!request.isCompleted) request.complete();
    }
  }

  void cancel() {
    cancelled = true;
    challenge.clear();
    form?.remove('password');
    form?.remove('sms');
    abortRequests();
  }
}

class _FlowRun {
  _FlowRun(this.engine, this.config, this.scope, this.state, this.roots);
  final FlowEngine engine;
  final AppConfig config;
  final String scope;
  final _FlowState state;
  final Map<String, dynamic> roots;
  String? navigation;
  String? error;
  bool replaceHistory = false;
  int steps = 0;

  dynamic resolve(dynamic value) => resolveTemplate(
    value,
    RuntimeValues(
      form: roots['form'] as Map<String, dynamic>,
      data: roots['data'] as Map<String, dynamic>,
      auth: const {},
      extra: roots,
    ),
  );

  void set(String path, dynamic value) {
    final parts = path.split('.');
    if (!{
      'scratch',
      'challenge',
      'form',
      'products',
      'data',
    }.contains(parts.first)) {
      throw const FormatException('Недопустимая область записи');
    }
    Map current = roots;
    for (final part in parts.take(parts.length - 1)) {
      current = current.putIfAbsent(part, () => <String, dynamic>{}) as Map;
    }
    current[parts.last] = value;
  }

  Future<void> clear(dynamic targets) async {
    for (final target in targets as List? ?? []) {
      final path = target as String;
      if (path == 'session') {
        await engine.store.clearTokens(scope);
        roots['session'] = <String, dynamic>{};
        continue;
      }
      final parts = path.split('.');
      if (!{
        'scratch',
        'challenge',
        'form',
        'products',
        'data',
      }.contains(parts.first)) {
        throw const FormatException('Недопустимая область очистки');
      }
      if (parts.length == 1) {
        (roots[path] as Map?)?.clear();
      } else {
        final parent = readJsonPath(
          roots,
          parts.take(parts.length - 1).join('.'),
        );
        if (parent is Map) parent.remove(parts.last);
      }
    }
  }

  void validate(dynamic value, dynamic schema) {
    if (schema == null) return;
    for (final entry in (schema as Map).entries) {
      final v = readJsonPath(value, entry.key as String);
      final valid = switch (entry.value) {
        'boolean' => v is bool,
        'strictly-false' => v == false,
        'non-empty-string' => v is String && v.isNotEmpty,
        'base64-string' => v is String && v.isNotEmpty && _validBase64(v),
        _ => false,
      };
      if (!valid) {
        throw const FormatException('Ответ API не соответствует контракту');
      }
    }
  }

  Future<void> step(Map definition, [int depth = 0]) async {
    state.check();
    if (++steps > 256 || depth > 24) {
      throw const FormatException('Превышен лимит шагов');
    }
    if (definition['type'] != 'sequence') validateStep(definition);
    switch (definition['type']) {
      case 'sequence':
        try {
          validateStep(definition);
          for (final child in definition['steps'] as List) {
            await step(child as Map, depth + 1);
          }
        } on _FlowCancelled {
          rethrow;
        } catch (_) {
          final handler = definition['onError'];
          if (handler is Map) {
            await clear(handler['clear']);
            navigation = handler['navigate'] as String?;
            replaceHistory = true;
            error ??= handler['message'] as String?;
          }
          rethrow;
        } finally {
          await clear((definition['finally'] as Map?)?['clear']);
        }
      case 'clear':
        await clear(definition['targets']);
      case 'set':
        set(definition['target'] as String, resolve(definition['value']));
      case 'navigate':
        navigation = definition['screen'] as String;
        replaceHistory = definition['replaceHistory'] == true;
      case 'clearAndNavigate':
        await clear(definition['clear']);
        navigation = definition['screen'] as String;
        replaceHistory = true;
      case 'call':
        final previous = roots['input'];
        roots['input'] = resolve(definition['input']);
        try {
          final action = config.actions[definition['action']];
          if (action?.definition == null) {
            throw const FormatException('Неизвестное действие');
          }
          await step(action!.definition!, depth + 1);
        } finally {
          roots['input'] = previous;
        }
      case 'branch':
        final value = resolve(definition['value']);
        final cases = (definition['cases'] as List).where(
          (c) => c['equals'] == value,
        );
        if (cases.isEmpty) {
          await step(definition['otherwise'] as Map, depth + 1);
        } else {
          for (final child in cases.first['steps'] as List) {
            await step(child as Map, depth + 1);
          }
        }
      case 'fail':
        throw const FormatException('Сценарий отклонён');
      case 'transform':
        for (final operation in definition['operations'] as List) {
          final result = await compute(
            flowTransform,
            Map<String, dynamic>.from(resolve(operation) as Map),
          );
          state.check();
          set(operation['output'] as String, result);
        }
      case 'http':
        final response = await request(definition);
        validate(response, definition['requireResponse']);
        if (definition['saveResponse'] != null) {
          set(definition['saveResponse'] as String, response);
        }
      case 'secureSessionCommit':
        final values = resolve(definition['values']) as Map;
        if (values['authenticationCompleted'] != true ||
            values['accessToken'] is! String ||
            (values['accessToken'] as String).isEmpty) {
          throw const FormatException('Незавершённая сессия');
        }
        final tokens = TokenBundle(
          accessToken: values['accessToken'] as String,
          refreshToken: values['refreshToken'] as String?,
          authenticationCompleted: true,
          expiryRaw: values['expiryRaw'],
        );
        state.check();
        await engine.store.writeTokens(scope, tokens);
        if (state.cancelled) {
          await engine.store.clearTokens(scope);
          state.check();
        }
        roots['session'] = tokens.toRuntimeMap();
      case 'parallelHttp':
        requireSession();
        var unauthorized = false;
        await Future.wait(
          (definition['resources'] as List).map((resource) async {
            final key = resource['key'] as String;
            try {
              final response = await request({...definition, ...resource});
              if (!unauthorized) set('products.$key', {'raw': response});
            } on ActionFailure catch (failure) {
              if (failure.statusCode == 401) {
                unauthorized = true;
                state.abortRequests();
              } else if (!unauthorized) {
                set('products.$key', {'error': 'Не удалось загрузить ресурс'});
              }
            } on _FlowCancelled {
              rethrow;
            } catch (_) {
              if (!unauthorized) {
                set('products.$key', {'error': 'Не удалось загрузить ресурс'});
              }
            }
          }),
        );
        if (unauthorized) {
          final handler = definition['onUnauthorized'] as Map;
          await step({'type': 'call', 'action': handler['action']}, depth + 1);
        }
      default:
        throw const FormatException('Неизвестный тип действия');
    }
  }

  void validateStep(Map definition) {
    if (definition['requiresCompletedAuthentication'] == true) requireSession();
    validate(roots['input'], definition['requireInput']);
    for (final path in definition['require'] as List? ?? []) {
      final value = readJsonPath(roots, path as String);
      if (value == null || value == '') {
        throw const FormatException('Отсутствует обязательное значение');
      }
    }
  }

  void requireSession() {
    final session = roots['session'] as Map;
    if (session['authenticationCompleted'] != true ||
        session['accessToken'] == null) {
      throw const ActionFailure('Требуется завершить вход', statusCode: 401);
    }
  }

  Future<dynamic> request(Map definition) async {
    final transport = config.flowDefinition?['transport'] as Map? ?? {};
    var uri = Uri.parse(
      config.apiBaseUrl,
    ).resolve(resolve(definition['url']) as String);
    final query = resolve(definition['query']);
    if (query is Map) {
      uri = uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          for (final entry in query.entries)
            if (entry.value != null)
              entry.key.toString(): entry.value.toString(),
        },
      );
    }
    final allowed =
        transport['allowedOrigins'] as List? ??
        [Uri.parse(config.apiBaseUrl).origin];
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        !allowed.contains(uri.origin)) {
      throw const FormatException('HTTP origin не разрешён');
    }
    final headers = <String, String>{'Accept': 'application/json'};
    final hostHeaders = transport['hostProvidedHeaders'] as Map? ?? {};
    if (hostHeaders.isNotEmpty) {
      if (engine.trustedHeaders == null) {
        error = 'Не настроен доверенный провайдер антифрод-заголовков API';
        throw const FormatException('Нужна интеграция host headers');
      }
      final supplied = await engine.trustedHeaders!(
        scope,
        Uri.parse(uri.origin),
      );
      for (final key in hostHeaders.keys.cast<String>()) {
        final value = supplied[key];
        if (value == null || value.isEmpty) {
          throw const FormatException('Нет обязательного host header');
        }
        headers[key] = value;
      }
    }
    final authorization = resolve(definition['authorization']);
    if (authorization is Map) {
      final token = authorization['token'];
      if (token is! String || token.isEmpty) {
        throw const ActionFailure('Нет токена', statusCode: 401);
      }
      headers['Authorization'] = '${authorization['scheme']} $token';
    }
    state.check();
    final abort = Completer<void>();
    state.requests.add(abort);
    final timeout = ((transport['timeoutSeconds'] as num?)?.toInt() ?? 30)
        .clamp(1, 60);
    final timer = Timer(Duration(seconds: timeout), () {
      if (!abort.isCompleted) abort.complete();
    });
    try {
      final req =
          http.AbortableRequest(
              definition['method'] as String? ?? 'GET',
              uri,
              abortTrigger: abort.future,
            )
            ..followRedirects = false
            ..headers.addAll(headers);
      if (definition.containsKey('body')) {
        final body = resolve(definition['body']);
        if (definition['encoding'] == 'application/x-www-form-urlencoded') {
          req.bodyFields = (body as Map).map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
        } else if (definition['encoding'] == 'json') {
          req.headers['Content-Type'] = 'application/json; charset=utf-8';
          req.body = jsonEncode(body);
        } else {
          throw const FormatException('Неизвестная кодировка HTTP body');
        }
      }
      final response = await (() async => http.Response.fromStream(
        await engine.client.send(req),
      ))().timeout(Duration(seconds: timeout));
      state.check();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ActionFailure('Ошибка HTTP', statusCode: response.statusCode);
      }
      return jsonDecode(response.body);
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
      state.requests.remove(abort);
    }
  }
}

bool _validBase64(String value) {
  try {
    return base64.decode(value).isNotEmpty;
  } on FormatException {
    return false;
  }
}

/// Executed in an isolate so PBKDF2 does not block the UI thread.
dynamic flowTransform(Map<String, dynamic> operation) {
  List<int> bytes(dynamic value) {
    if (value is! List || value.any((v) => v is! int || v < 0 || v > 255)) {
      throw const FormatException('Ожидались байты');
    }
    return value.cast<int>();
  }

  switch (operation['op']) {
    case 'base64Decode':
      return base64.decode(operation['input'] as String);
    case 'base64Encode':
      if (operation['alphabet'] != 'standard' || operation['padding'] != true) {
        throw const FormatException('Неподдерживаемый base64');
      }
      return base64.encode(bytes(operation['input']));
    case 'encode':
      if (operation['encoding'] != 'utf-16le' ||
          operation['bom'] != false ||
          operation['normalization'] != 'none') {
        throw const FormatException('Неподдерживаемая кодировка');
      }
      return [
        for (final unit in (operation['input'] as String).codeUnits) ...[
          unit & 255,
          unit >> 8,
        ],
      ];
    case 'concatBytes':
      return [for (final part in operation['inputs'] as List) ...bytes(part)];
    case 'digest':
      if (operation['algorithm'] != 'SHA-256' ||
          operation['outputEncoding'] != 'bytes') {
        throw const FormatException('Неподдерживаемый digest');
      }
      return sha256.convert(bytes(operation['input'])).bytes;
    case 'pbkdf2':
      final iterations = operation['iterations'] as int;
      final length = operation['lengthBits'] as int;
      if (operation['prf'] != 'HMAC-SHA-1' ||
          operation['outputEncoding'] != 'bytes' ||
          iterations < 1 ||
          iterations > 100000 ||
          length < 8 ||
          length > 512 ||
          length % 8 != 0) {
        throw const FormatException('Недопустимые параметры PBKDF2');
      }
      final hmac = Hmac(sha1, bytes(operation['key']));
      final salt = bytes(operation['salt']);
      final output = <int>[];
      for (var block = 1; output.length < length ~/ 8; block++) {
        var u = hmac.convert([
          ...salt,
          (block >> 24) & 255,
          (block >> 16) & 255,
          (block >> 8) & 255,
          block & 255,
        ]).bytes;
        final result = [...u];
        for (var i = 1; i < iterations; i++) {
          u = hmac.convert(u).bytes;
          for (var j = 0; j < result.length; j++) {
            result[j] ^= u[j];
          }
        }
        output.addAll(result);
      }
      return output.sublist(0, length ~/ 8);
    default:
      throw const FormatException('Неизвестное преобразование');
  }
}
