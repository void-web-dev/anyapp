import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_config.dart';
import '../runtime/value_resolver.dart';
import 'session_store.dart';
import 'flow_engine.dart';

class ActionEngine {
  ActionEngine(
    this._sessionStore, {
    http.Client? client,
    TrustedFlowHeaders? trustedFlowHeaders,
  }) : _client = client ?? http.Client() {
    _flows = FlowEngine(
      _sessionStore,
      _client,
      trustedHeaders: trustedFlowHeaders,
    );
  }

  final SessionStore _sessionStore;
  final http.Client _client;
  late final FlowEngine _flows;
  void resetFlow(String scope) => _flows.reset(scope);

  Future<ActionResult> execute({
    required AppConfig config,
    required String storageScope,
    required ActionConfig action,
    required Map<String, dynamic> form,
    required Map<String, dynamic> data,
    bool allowRefresh = true,
  }) async {
    if (action.definition != null) {
      return _flows.execute(
        config: config,
        scope: storageScope,
        action: action,
        form: form,
        data: data,
      );
    }
    var tokens = await _sessionStore.readTokens(storageScope);
    final values = RuntimeValues(
      form: form,
      data: data,
      auth: tokens.toRuntimeMap(),
    );

    ActionResult result;
    if (action.mock != null) {
      result = await _executeMock(action.mock!, values);
    } else if (_method(action) == 'BOOKMARK') {
      final request = resolveTemplate(action.request, values) as Map;
      final items = await _sessionStore.readBookmarks(storageScope);
      final operation = request['operation'] ?? 'list';
      if (operation == 'save') {
        final item = Map<String, dynamic>.from(request['item'] as Map);
        if (item['id'] == null || item['id'].toString().isEmpty) {
          throw const ActionFailure('Для закладки необходим id');
        }
        items.removeWhere((entry) => entry['id'] == item['id']);
        items.add(item);
        await _sessionStore.writeBookmarks(storageScope, items);
      } else if (operation == 'remove') {
        items.removeWhere((entry) => entry['id'] == request['id']);
        await _sessionStore.writeBookmarks(storageScope, items);
      } else if (operation != 'list') {
        throw const ActionFailure('Неизвестная операция с закладками');
      }
      result = ActionResult(statusCode: 200, body: {'bookmarks': items});
    } else if (_method(action) == 'LOCAL' || _method(action) == 'LINK') {
      result = const ActionResult(statusCode: 200, body: {});
    } else {
      result = await _executeHttp(config, action, values, tokens);
      if (result.statusCode == 401 &&
          allowRefresh &&
          config.auth.refreshAction != null &&
          action.id != config.auth.refreshAction) {
        final refreshed = await _refresh(config, storageScope, form, data);
        if (refreshed) {
          tokens = await _sessionStore.readTokens(storageScope);
          result = await _executeHttp(
            config,
            action,
            RuntimeValues(form: form, data: data, auth: tokens.toRuntimeMap()),
            tokens,
          );
        }
      }
    }

    if (result.isSuccess) {
      await _applyTokenResult(storageScope, action.success, result.body);
      if (action.success['clearTokens'] == true) {
        await _sessionStore.clearTokens(storageScope);
      }
      return result;
    }

    final messagePath = action.failure['messagePath'] as String?;
    final serverMessage = readJsonPath(result.body, messagePath);
    throw ActionFailure(
      serverMessage?.toString() ??
          action.failure['message'] as String? ??
          'Операция завершилась с ошибкой ${result.statusCode}',
      statusCode: result.statusCode,
    );
  }

  Future<bool> _refresh(
    AppConfig config,
    String storageScope,
    Map<String, dynamic> form,
    Map<String, dynamic> data,
  ) async {
    final refreshId = config.auth.refreshAction;
    final action = refreshId == null ? null : config.actions[refreshId];
    if (action == null) return false;
    try {
      final result = await execute(
        config: config,
        storageScope: storageScope,
        action: action,
        form: form,
        data: data,
        allowRefresh: false,
      );
      return result.isSuccess;
    } on ActionFailure {
      await _sessionStore.clearTokens(storageScope);
      return false;
    }
  }

  Future<ActionResult> _executeMock(
    Map<String, dynamic> mock,
    RuntimeValues values,
  ) async {
    final delay = (mock['delayMs'] as num?)?.toInt() ?? 350;
    await Future<void>.delayed(Duration(milliseconds: delay));
    return ActionResult(
      statusCode: (mock['status'] as num?)?.toInt() ?? 200,
      body: resolveTemplate(mock['body'] ?? const {}, values),
    );
  }

  Future<ActionResult> _executeHttp(
    AppConfig config,
    ActionConfig action,
    RuntimeValues values,
    TokenBundle tokens,
  ) async {
    final requestConfig = action.request;
    final rawUrl = resolveTemplate(
      requestConfig['url'] ?? '',
      values,
    ).toString();
    final uri = _resolveUri(config.apiBaseUrl, rawUrl);
    final headers = <String, String>{
      'Accept': 'application/json',
      for (final entry
          in (resolveTemplate(requestConfig['headers'] ?? const {}, values)
                  as Map)
              .entries)
        entry.key.toString(): entry.value.toString(),
    };
    if (tokens.hasAccessToken &&
        !headers.containsKey(config.auth.authorizationHeader)) {
      headers[config.auth.authorizationHeader] =
          '${config.auth.scheme} ${tokens.accessToken}';
    }

    final request = http.Request(_method(action), uri)..headers.addAll(headers);
    if (requestConfig.containsKey('body')) {
      request.headers.putIfAbsent(
        'Content-Type',
        () => 'application/json; charset=utf-8',
      );
      request.body = jsonEncode(resolveTemplate(requestConfig['body'], values));
    }
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    dynamic body;
    if (response.body.isEmpty) {
      body = <String, dynamic>{};
    } else {
      try {
        body = jsonDecode(response.body);
      } on FormatException {
        body = {'message': response.body};
      }
    }
    return ActionResult(statusCode: response.statusCode, body: body);
  }

  Future<void> _applyTokenResult(
    String storageScope,
    Map<String, dynamic> success,
    dynamic body,
  ) async {
    final tokenConfig = success['tokens'];
    if (tokenConfig is! Map) return;
    final current = await _sessionStore.readTokens(storageScope);
    final access = readJsonPath(
      body,
      tokenConfig['accessTokenPath'] as String?,
    );
    final refresh = readJsonPath(
      body,
      tokenConfig['refreshTokenPath'] as String?,
    );
    await _sessionStore.writeTokens(
      storageScope,
      TokenBundle(
        accessToken: access?.toString() ?? current.accessToken,
        refreshToken: refresh?.toString() ?? current.refreshToken,
      ),
    );
  }

  String _method(ActionConfig action) =>
      (action.request['method'] as String? ?? 'GET').toUpperCase();

  Uri _resolveUri(String baseUrl, String value) {
    final uri = Uri.parse(value);
    if (uri.hasScheme) return uri;
    if (baseUrl.isEmpty) {
      throw const ActionFailure('В конфигурации отсутствует apiBaseUrl');
    }
    return Uri.parse(baseUrl).resolve(value);
  }
}

class ActionResult {
  const ActionResult({
    required this.statusCode,
    required this.body,
    this.navigateTo,
    this.replaceHistory = false,
    this.flowError,
  });

  final int statusCode;
  final dynamic body;
  final String? navigateTo;
  final bool replaceHistory;
  final String? flowError;
  bool get isSuccess =>
      flowError == null && statusCode >= 200 && statusCode < 300;
}

class ActionFailure implements Exception {
  const ActionFailure(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
