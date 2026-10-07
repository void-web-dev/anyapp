import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:any2app/server_driven/models/app_config.dart';
import 'package:any2app/server_driven/runtime/app_controller.dart';
import 'package:any2app/server_driven/services/config_repository.dart';
import 'package:any2app/server_driven/services/action_engine.dart';
import 'package:any2app/server_driven/services/flow_engine.dart';
import 'package:any2app/server_driven/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> fixture() =>
    jsonDecode(File('docs/examples/psbank-auth-flow.json').readAsStringSync())
        as Map<String, dynamic>;
http.Response reply(Object body, [int code = 200]) => http.Response(
  jsonEncode(body),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'controller opens SMS, cancels without code, commits and loads dashboard',
    () async {
      final raw = fixture();
      final store = MemorySessionStore();
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/salt')) {
          return reply({
            'passwordSalt': 'YQ==',
            'sessionSalt': 'Yg==',
            'requestId': 'r',
          });
        }
        if (req.url.path.endsWith('/token')) {
          final second =
              Uri.splitQueryString(req.body)['grant_type'] == 'second_step';
          return reply({
            'access_token': second ? 'final' : 'pending',
            'SecondStepRequired': !second,
          });
        }
        return reply({'items': []});
      });
      final controller = AppController(
        HttpConfigRepository(client: MockClient((_) async => reply(raw))),
        store,
        ActionEngine(
          store,
          client: client,
          trustedFlowHeaders: (_, _) async => {'__dp_rsa': 'test'},
        ),
      );
      await controller.connect('https://config.example/psbank.json');
      expect(controller.currentScreenId, 'login');
      controller.setFormValue('login', 'u');
      controller.setFormValue('password', 'p');
      await controller.executeAction('login');
      expect(controller.error, isNull);
      expect(controller.currentScreenId, 'sms');
      await controller.executeAction('cancelLogin');
      expect(controller.currentScreenId, 'login');
      controller.setFormValue('password', 'p');
      await controller.executeAction('login');
      controller.setFormValue('sms', '000001');
      await controller.executeAction('confirmSms');
      expect(controller.error, isNull);
      expect(controller.currentScreenId, 'dashboard');
      expect((controller.data['products'] as Map).length, 6);
      await controller.refreshCurrentScreen();
      expect(controller.error, isNull);
      await controller.changeConfiguration();
      await controller.connect('https://config.example/psbank.json');
      expect(controller.currentScreenId, 'dashboard');
      await controller.executeAction('logout', validate: false);
      expect(controller.currentScreenId, 'login');
      expect(controller.data['products'], isEmpty);
      controller.dispose();
    },
  );

  test(
    'deep link cannot select authenticated screen or inject session state',
    () async {
      final store = MemorySessionStore();
      final controller = AppController(
        HttpConfigRepository(),
        store,
        ActionEngine(store),
      );
      await controller.handleQrPayload(
        jsonEncode({
          'config': fixture(),
          'initial': {
            'screenId': 'dashboard',
            'data': {
              'session': {
                'accessToken': 'fake',
                'authenticationCompleted': true,
              },
            },
          },
        }),
      );
      expect(controller.currentScreenId, 'login');
      expect(
        (await store.readTokens(controller.storageScope)).hasAccessToken,
        false,
      );
      controller.dispose();
    },
  );

  test('challenge disappears after reset and cannot cross scopes', () async {
    final raw = fixture();
    (raw['transport'] as Map).remove('hostProvidedHeaders');
    final config = AppConfig.fromJson(raw);
    var confirms = 0;
    final store = MemorySessionStore();
    final engine = ActionEngine(
      store,
      client: MockClient((req) async {
        if (req.url.path.endsWith('/salt')) {
          return reply({
            'passwordSalt': 'YQ==',
            'sessionSalt': 'Yg==',
            'requestId': 'r',
          });
        }
        if (Uri.splitQueryString(req.body)['grant_type'] == 'second_step') {
          confirms++;
        }
        return reply({'access_token': 'pending', 'SecondStepRequired': true});
      }),
    );
    await engine.execute(
      config: config,
      storageScope: 'a',
      action: config.actions['login']!,
      form: {'login': 'u', 'password': 'p'},
      data: {},
    );
    final other = await engine.execute(
      config: config,
      storageScope: 'b',
      action: config.actions['confirmSms']!,
      form: {'sms': '123'},
      data: {},
    );
    expect(other.isSuccess, false);
    engine.resetFlow('a');
    final restarted = await engine.execute(
      config: config,
      storageScope: 'a',
      action: config.actions['confirmSms']!,
      form: {'sms': '123'},
      data: {},
    );
    expect(restarted.isSuccess, false);
    expect(confirms, 0);
  });

  test('PBKDF2 RFC 6070 and UTF-16LE surrogate pairs', () {
    final bytes =
        flowTransform({
              'op': 'pbkdf2',
              'prf': 'HMAC-SHA-1',
              'iterations': 2,
              'key': utf8.encode('password'),
              'salt': utf8.encode('salt'),
              'lengthBits': 160,
              'outputEncoding': 'bytes',
            })
            as List<int>;
    expect(
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      'ea6c014dc72d6f8ccd1ed92ace1d41f0d8de8957',
    );
    expect(
      flowTransform({
        'op': 'encode',
        'encoding': 'utf-16le',
        'bom': false,
        'normalization': 'none',
        'input': 'A😀',
      }),
      [65, 0, 61, 216, 0, 222],
    );
  });

  for (final smsRequired in [false, true]) {
    test(
      'full login, sms=$smsRequired, correct wire encoding and token isolation',
      () async {
        final config = AppConfig.fromJson(fixture());
        final store = MemorySessionStore();
        final form = <String, dynamic>{
          'login': 'user+test',
          'password': 'пароль😀',
        };
        final data = <String, dynamic>{};
        var firstTokenSeen = false;
        var secondTokenSeen = false;
        final engine = ActionEngine(
          store,
          trustedFlowHeaders: (_, _) async => {'__dp_rsa': 'test-fingerprint'},
          client: MockClient((req) async {
            expect(req.followRedirects, false);
            expect(req.headers['__dp_rsa'], 'test-fingerprint');
            if (req.url.path.endsWith('/salt')) {
              expect(req.headers['Authorization'], isNull);
              final body = jsonDecode(req.body) as Map;
              expect(body['clientIdentifier'], 'user+test');
              expect(
                body['deviceId'],
                await store.readOrCreateDeviceId('app-a'),
              );
              return reply({
                'passwordSalt': base64.encode(utf8.encode('password-salt')),
                'sessionSalt': base64.encode(utf8.encode('session-salt')),
                'requestId': 'r1',
              });
            }
            final body = Uri.splitQueryString(req.body);
            expect(
              req.headers['content-type'],
              contains('application/x-www-form-urlencoded'),
            );
            if (body['grant_type'] == 'password') {
              firstTokenSeen = true;
              expect(
                body['password'],
                'xBBx2sWBoSwt70VEkkCNHRaJ9N5gnuS65cyHF8nuMX0=',
              );
              expect(body['username'], 'user+test');
              expect(body['scope'], 'offline_access retail_client');
              expect(req.body, isNot(contains('пароль')));
              expect(req.headers['Authorization'], isNull);
              return reply({
                'access_token': smsRequired ? 'pending' : 'final',
                'refresh_token': 'refresh',
                'SecondStepRequired': smsRequired,
              });
            }
            secondTokenSeen = true;
            expect(req.headers['Authorization'], 'Bearer pending');
            expect(body, {'grant_type': 'second_step', 'code': '001234'});
            return reply({
              'access_token': 'final',
              'refresh_token': 'final-refresh',
              'SecondStepRequired': false,
            });
          }),
        );
        Future<ActionResult> run(String id) => engine.execute(
          config: config,
          storageScope: 'app-a',
          action: config.actions[id]!,
          form: form,
          data: data,
        );
        final result = await run('login');
        expect(result.flowError, isNull);
        expect(firstTokenSeen, true);
        expect(form.containsKey('password'), false);
        expect(result.navigateTo, smsRequired ? 'sms' : 'dashboard');
        if (smsRequired) {
          expect((await store.readTokens('app-a')).hasAccessToken, false);
          form['sms'] = '001234';
          final confirmation = await run('confirmSms');
          expect(confirmation.flowError, isNull);
          expect(confirmation.navigateTo, 'dashboard');
          expect(form.containsKey('sms'), false);
        }
        expect(secondTokenSeen, smsRequired);
        expect((await store.readTokens('app-a')).accessToken, 'final');
        expect((await store.readTokens('app-a')).authenticationCompleted, true);
        expect((await store.readTokens('app-b')).hasAccessToken, false);
        expect(
          await store.readOrCreateDeviceId('app-a'),
          isNot(await store.readOrCreateDeviceId('app-b')),
        );
      },
    );
  }

  test(
    'missing trusted headers fails closed without network request',
    () async {
      final config = AppConfig.fromJson(fixture());
      final form = <String, dynamic>{'login': 'u', 'password': 'secret'};
      final engine = ActionEngine(
        MemorySessionStore(),
        client: MockClient((_) async => throw StateError('must not send')),
      );
      final result = await engine.execute(
        config: config,
        storageScope: 'a',
        action: config.actions['login']!,
        form: form,
        data: {},
      );
      expect(result.flowError, isNotNull);
      expect(result.navigateTo, 'login');
      expect(form.containsKey('password'), false);
    },
  );

  for (final response in [
    <String, dynamic>{'access_token': 'a'},
    {'access_token': 'a', 'SecondStepRequired': 'false'},
  ]) {
    test('ambiguous auth response never commits: $response', () async {
      final raw = fixture();
      (raw['transport'] as Map).remove('hostProvidedHeaders');
      final config = AppConfig.fromJson(raw);
      final store = MemorySessionStore();
      final engine = ActionEngine(
        store,
        client: MockClient(
          (req) async => req.url.path.endsWith('/salt')
              ? reply({
                  'passwordSalt': 'YQ==',
                  'sessionSalt': 'Yg==',
                  'requestId': 'r',
                })
              : reply(response),
        ),
      );
      final result = await engine.execute(
        config: config,
        storageScope: 'a',
        action: config.actions['login']!,
        form: {'login': 'u', 'password': 'p'},
        data: {},
      );
      expect(result.flowError, isNotNull);
      expect((await store.readTokens('a')).hasAccessToken, false);
    });
  }

  test(
    'parallel products keep partial errors and isolate app stores',
    () async {
      final raw = fixture();
      (raw['transport'] as Map).remove('hostProvidedHeaders');
      final config = AppConfig.fromJson(raw);
      final store = MemorySessionStore();
      await store.writeTokens(
        'a',
        const TokenBundle(accessToken: 'final', authenticationCompleted: true),
      );
      final data = <String, dynamic>{};
      final engine = ActionEngine(
        store,
        client: MockClient((req) async {
          expect(req.headers['Authorization'], 'Bearer final');
          return req.url.path == '/api/loans'
              ? reply({}, 500)
              : reply({'items': []});
        }),
      );
      await engine.execute(
        config: config,
        storageScope: 'a',
        action: config.actions['loadProducts']!,
        form: {},
        data: data,
      );
      expect((data['products'] as Map).length, 6);
      expect(data['products']['loans']['error'], isNotNull);
      expect(data['products']['cards']['raw'], {'items': []});
      expect((await store.readTokens('b')).hasAccessToken, false);
    },
  );

  test('401 clears session and discards late product responses', () async {
    final raw = fixture();
    (raw['transport'] as Map).remove('hostProvidedHeaders');
    final config = AppConfig.fromJson(raw);
    final store = MemorySessionStore();
    await store.writeTokens(
      'a',
      const TokenBundle(accessToken: 'final', authenticationCompleted: true),
    );
    final data = <String, dynamic>{
      'products': {'old': 'secret'},
    };
    final engine = ActionEngine(
      store,
      client: MockClient((req) async {
        if (req.url.path.contains('cards')) return reply({}, 401);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return reply({'secret': 'late'});
      }),
    );
    final result = await engine.execute(
      config: config,
      storageScope: 'a',
      action: config.actions['loadProducts']!,
      form: {},
      data: data,
    );
    expect(result.navigateTo, 'login');
    expect(data['products'], isEmpty);
    expect((await store.readTokens('a')).hasAccessToken, false);
  });

  test(
    'reset cancels pending request and disallows committing old session',
    () async {
      final raw = fixture();
      (raw['transport'] as Map).remove('hostProvidedHeaders');
      final config = AppConfig.fromJson(raw);
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final store = MemorySessionStore();
      final engine = ActionEngine(
        store,
        client: MockClient((_) {
          started.complete();
          return response.future;
        }),
      );
      final form = <String, dynamic>{'login': 'u', 'password': 'p'};
      final running = engine.execute(
        config: config,
        storageScope: 'a',
        action: config.actions['login']!,
        form: form,
        data: {},
      );
      final expectation = expectLater(running, throwsA(isA<ActionFailure>()));
      await started.future;
      engine.resetFlow('a');
      response.complete(
        reply({
          'passwordSalt': 'YQ==',
          'sessionSalt': 'Yg==',
          'requestId': 'r',
        }),
      );
      await expectation;
      expect((await store.readTokens('a')).hasAccessToken, false);
      expect(form.containsKey('password'), false);
    },
  );

  test('foreign origin is rejected before sending', () async {
    final raw = fixture();
    (raw['transport'] as Map).remove('hostProvidedHeaders');
    raw['actions']['login']['steps'][1]['url'] = 'https://other.example/salt';
    final config = AppConfig.fromJson(raw);
    var requests = 0;
    final engine = ActionEngine(
      MemorySessionStore(),
      client: MockClient((_) async {
        requests++;
        return reply({});
      }),
    );
    final result = await engine.execute(
      config: config,
      storageScope: 'a',
      action: config.actions['login']!,
      form: {'login': 'u', 'password': 'p'},
      data: {},
    );
    expect(result.flowError, isNotNull);
    expect(requests, 0);
  });
}
