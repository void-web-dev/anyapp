import 'dart:convert';
import 'dart:io';

import 'package:any2app/server_driven/runtime/app_controller.dart';
import 'package:any2app/server_driven/services/action_engine.dart';
import 'package:any2app/server_driven/services/config_repository.dart';
import 'package:any2app/server_driven/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = File('assets/config/dummyjson_demo.json').readAsStringSync();
  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  test(
    'Dummy Shop login, search escaping, product, profile, resume and logout',
    () async {
      final store = MemorySessionStore();
      var query = '';
      var expired = false;
      final client = MockClient((req) async {
        expect(req.url.origin, 'https://dummyjson.com');
        switch (req.url.path) {
          case '/auth/login':
            expect(jsonDecode(req.body), {
              'username': 'emilys',
              'password': 'emilyspass',
              'expiresInMins': 30,
            });
            return json({'accessToken': 'access', 'refreshToken': 'refresh'});
          case '/products/search':
            expect(req.headers['Authorization'], isNull);
            expect(req.url.queryParameters, {'q': query, 'limit': '24'});
            return json({
              'products': [
                {
                  'id': 1,
                  'title': 'Phone',
                  'category': 'smartphones',
                  'price': 100,
                },
              ],
              'total': 1,
            });
          case '/products/1':
            return json({
              'id': 1,
              'title': 'Phone',
              'price': 100,
              'description': 'A test phone',
            });
          case '/auth/me':
            expect(req.headers['Authorization'], 'Bearer access');
            return expired
                ? json({'message': 'Expired'}, 401)
                : json({
                    'username': 'emilys',
                    'firstName': 'Emily',
                    'email': 'example@dummyjson.com',
                  });
          default:
            throw StateError('Unexpected endpoint');
        }
      });
      final controller = AppController(
        HttpConfigRepository(
          client: MockClient(
            (_) async => http.Response(
              source,
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        ),
        store,
        ActionEngine(store, client: client),
      );
      await controller.connect('https://config.example/dummy.json');
      expect(controller.currentScreenId, 'login');
      await controller.executeAction('demoLogin');
      expect(controller.error, isNull);
      expect(controller.currentScreenId, 'catalog');
      expect(controller.form.containsKey('password'), false);
      query = 'phone & q=other / чай';
      controller.setFormValue('query', query);
      await controller.executeAction('loadCatalog');
      expect(controller.error, isNull);
      controller.setFormValue(
        'selectedProduct',
        controller.data['catalog']['products'][0],
      );
      await controller.executeAction('openProduct');
      expect(controller.currentScreenId, 'product');
      expect(controller.data['product']['title'], 'Phone');
      await controller.executeAction('openProfile');
      expect(controller.currentScreenId, 'profile');
      expect(controller.data['profile']['username'], 'emilys');
      await controller.changeConfiguration();
      query = '';
      await controller.connect('https://config.example/dummy.json');
      expect(controller.currentScreenId, 'catalog');
      expect(controller.error, isNull);
      expired = true;
      await controller.executeAction('openProfile');
      expect(controller.currentScreenId, 'login');
      expect(controller.data, isEmpty);
      expect(
        (await store.readTokens(controller.storageScope)).hasAccessToken,
        false,
      );
      expired = false;
      await controller.executeAction('demoLogin');
      await controller.executeAction('logout');
      expect(controller.currentScreenId, 'login');
      expect(controller.form, isEmpty);
      expect(controller.data.keys.toSet().difference({'products'}), isEmpty);
      expect(
        (await store.readTokens(controller.storageScope)).hasAccessToken,
        false,
      );
      controller.dispose();
    },
  );

  test('failed login clears password and never creates session', () async {
    final store = MemorySessionStore();
    final controller = AppController(
      HttpConfigRepository(
        client: MockClient(
          (_) async => http.Response(
            source,
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
      store,
      ActionEngine(
        store,
        client: MockClient(
          (_) async => json({'message': 'Invalid credentials'}, 400),
        ),
      ),
    );
    await controller.connect('https://config.example/dummy.json');
    await controller.executeAction('demoLogin');
    expect(controller.currentScreenId, 'login');
    expect(controller.error, isNotNull);
    expect(controller.form.containsKey('password'), false);
    expect(
      (await store.readTokens(controller.storageScope)).hasAccessToken,
      false,
    );
    controller.dispose();
  });
}
