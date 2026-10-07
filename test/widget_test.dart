import 'dart:convert';
import 'dart:io';

import 'package:any2app/main.dart';
import 'package:any2app/security/biometric_service.dart';
import 'package:any2app/security/security_controller.dart';
import 'package:any2app/security/security_store.dart';
import 'package:any2app/server_driven/models/app_config.dart';
import 'package:any2app/server_driven/models/marketplace_catalog.dart';
import 'package:any2app/server_driven/runtime/app_controller.dart';
import 'package:any2app/server_driven/runtime/value_resolver.dart';
import 'package:any2app/server_driven/services/action_engine.dart';
import 'package:any2app/server_driven/services/app_link_service.dart';
import 'package:any2app/server_driven/services/config_repository.dart';
import 'package:any2app/server_driven/services/marketplace_repository.dart';
import 'package:any2app/server_driven/services/session_store.dart';
import 'package:any2app/ui/ui.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first launch configures and verifies a short code', () async {
    final store = MemorySecurityStore();
    final controller = AppSecurityController(
      store,
      MemoryBiometricService(available: false),
    );

    await controller.initialize();
    expect(controller.state, SecurityFlowState.setup);

    await controller.usePin('1234');
    expect(controller.state, SecurityFlowState.ready);
    expect(controller.accessMode, AccessMode.pin);

    final restarted = AppSecurityController(
      store,
      MemoryBiometricService(available: false),
    );
    await restarted.initialize();
    expect(restarted.state, SecurityFlowState.locked);

    await restarted.unlockWithPin('0000');
    expect(restarted.state, SecurityFlowState.locked);
    expect(restarted.error, 'Неверный короткий код');

    await restarted.unlockWithPin('1234');
    expect(restarted.state, SecurityFlowState.ready);
  });

  test('biometric mode authenticates on the next launch', () async {
    final store = MemorySecurityStore();
    final firstBiometrics = MemoryBiometricService();
    final controller = AppSecurityController(store, firstBiometrics);

    await controller.initialize();
    await controller.useBiometricMode();
    expect(controller.accessMode, AccessMode.biometric);
    expect(firstBiometrics.authenticationCount, 1);

    final nextBiometrics = MemoryBiometricService();
    final restarted = AppSecurityController(store, nextBiometrics);
    await restarted.initialize();
    expect(restarted.state, SecurityFlowState.ready);
    expect(nextBiometrics.authenticationCount, 1);
  });

  testWidgets('first launch shows access mode selection', (tester) async {
    final sessionStore = MemorySessionStore();
    final appController = AppController(
      AssetConfigRepository(),
      sessionStore,
      ActionEngine(sessionStore),
      marketplaceRepository: TestMarketplaceRepository(),
    );
    final securityController = AppSecurityController(
      MemorySecurityStore(),
      MemoryBiometricService(available: false),
    );

    await tester.pumpWidget(
      Any2App(
        controller: appController,
        securityController: securityController,
      ),
    );
    await tester.pump();

    expect(find.text('Защитите any2app'), findsOneWidget);
    expect(find.byKey(const Key('setup-use-pin')), findsOneWidget);
    expect(find.byKey(const Key('setup-use-biometrics')), findsOneWidget);
    expect(find.byKey(const Key('setup-use-open')), findsOneWidget);

    final pinField = find.descendant(
      of: find.byKey(const Key('setup-pin')),
      matching: find.byType(TextField),
    );
    final confirmationField = find.descendant(
      of: find.byKey(const Key('setup-pin-confirmation')),
      matching: find.byType(TextField),
    );
    await tester.enterText(pinField, '2468');
    await tester.enterText(confirmationField, '2468');
    await tester.ensureVisible(find.byKey(const Key('setup-use-pin')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('setup-use-pin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));

    expect(securityController.accessMode, AccessMode.pin);
    expect(find.text('Подключить приложение'), findsOneWidget);
  });

  testWidgets('shows splash then configuration URL screen', (tester) async {
    final store = MemorySessionStore();
    final controller = AppController(
      AssetConfigRepository(),
      store,
      ActionEngine(store),
      marketplaceRepository: TestMarketplaceRepository(),
    );

    await tester.pumpWidget(Any2App(controller: controller));
    expect(find.text('Загрузка конфигурации'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Подключить приложение'), findsOneWidget);
    expect(find.byKey(const Key('configuration-url')), findsOneWidget);
    expect(find.text('По пути'), findsNothing);
    expect(find.byType(AppPullToRefresh), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-marketplace')));
    await tester.pump();
    expect(find.text('Маркетплейс any2app'), findsOneWidget);
    expect(find.text('По пути'), findsOneWidget);
    expect(find.byKey(const Key('configuration-url')), findsNothing);
    expect(find.byType(AppPullToRefresh), findsOneWidget);
  });

  testWidgets('settings changes light theme and short code', (tester) async {
    final sessionStore = MemorySessionStore();
    final appController = AppController(
      AssetConfigRepository(),
      sessionStore,
      ActionEngine(sessionStore),
      marketplaceRepository: TestMarketplaceRepository(),
    );
    final securityStore = MemorySecurityStore(accessMode: AccessMode.open);
    final securityController = AppSecurityController(
      securityStore,
      MemoryBiometricService(),
    );

    await tester.pumpWidget(
      Any2App(
        controller: appController,
        securityController: securityController,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.tap(find.byKey(const Key('settings-tab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-screen')), findsOneWidget);
    expect(find.text('Светлая тема'), findsOneWidget);
    await tester.tap(find.byKey(const Key('light-theme-setting')));
    await tester.pumpAndSettle();
    expect(securityController.themePreference, ThemePreference.light);
    expect(securityStore.themePreference, ThemePreference.light);

    await tester.tap(find.text('Короткий код'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('new-pin')),
        matching: find.byType(TextField),
      ),
      '1357',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('confirm-new-pin')),
        matching: find.byType(TextField),
      ),
      '1357',
    );
    await tester.tap(find.byKey(const Key('save-pin-setting')));
    await tester.pumpAndSettle();

    expect(securityController.accessMode, AccessMode.pin);
    expect(await securityStore.verifyPin('1357'), isTrue);
  });

  testWidgets('screen builder adds components and generates JSON', (
    tester,
  ) async {
    final store = MemorySessionStore();
    final controller = AppController(
      AssetConfigRepository(),
      store,
      ActionEngine(store),
      marketplaceRepository: TestMarketplaceRepository(),
    );

    await tester.pumpWidget(Any2App(controller: controller));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.ensureVisible(find.byKey(const Key('open-builder')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-builder')));
    await tester.pump();

    expect(find.byKey(const Key('screen-builder')), findsOneWidget);
    expect(find.text('Конструктор экранов'), findsOneWidget);
    expect(find.byType(AppPullToRefresh), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('add-builder-component')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-builder-component')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-component-combobox')));
    await tester.pumpAndSettle();
    expect(find.text('combobox'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('screen-builder')),
      const Offset(0, 900),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('JSON'));
    await tester.pump();
    await tester.tap(find.text('JSON'));
    await tester.pump();
    expect(find.byKey(const Key('copy-builder-json')), findsOneWidget);
    expect(find.textContaining('"initialScreen": "home"'), findsOneWidget);
    expect(find.textContaining('"method": "POST"'), findsOneWidget);
    expect(find.textContaining('"email": "{{form.email}}"'), findsOneWidget);
    expect(
      find.textContaining('"searchAction": "search_options"'),
      findsOneWidget,
    );
    expect(find.textContaining('"method": "GET"'), findsOneWidget);
  });

  testWidgets('renders extended form and list components', (tester) async {
    final store = MemorySessionStore();
    final extendedConfig = AppConfig.fromJson({
      'id': 'component-demo',
      'name': 'Components',
      'apiBaseUrl': '',
      'initialScreen': 'home',
      'auth': <String, dynamic>{},
      'screens': {
        'home': {
          'title': 'Extended components',
          'components': [
            {
              'type': 'inputGroup',
              'id': 'amount',
              'label': 'Сумма',
              'prefix': '₽',
            },
            {
              'type': 'select',
              'id': 'currency',
              'label': 'Валюта',
              'options': [
                {'value': 'RUB', 'label': 'Рубли'},
                {'value': 'USD', 'label': 'Доллары'},
              ],
            },
            {
              'type': 'combobox',
              'id': 'country',
              'label': 'Страна',
              'options': <dynamic>[],
              'searchAction': 'searchCountries',
              'searchQueryField': 'searchQuery',
              'optionsPath': r'$.items',
              'optionValuePath': r'$.code',
              'optionLabelPath': r'$.name',
              'minSearchLength': 2,
              'searchDebounceMs': 300,
            },
            {
              'type': 'list',
              'id': 'product',
              'items': [
                {'value': 'card', 'title': 'Карта', 'description': 'Дебетовая'},
              ],
            },
            {
              'type': 'image',
              'source': 'assets/icon/anyapp-icon-1024.png',
              'alt': 'any2app',
              'height': 80,
              'fit': 'contain',
            },
          ],
        },
      },
      'actions': {
        'searchCountries': {
          'request': {
            'method': 'GET',
            'url': 'countries?q={{form.searchQuery}}',
          },
          'mock': {
            'delayMs': 10,
            'status': 200,
            'body': {
              'items': [
                {'code': 'ru', 'name': 'Россия'},
                {'code': 'kz', 'name': 'Казахстан'},
              ],
            },
          },
          'success': <String, dynamic>{},
          'failure': {'message': 'Ошибка поиска'},
        },
      },
    });
    final controller = AppController(
      AssetConfigRepository(extendedConfig),
      store,
      ActionEngine(store),
      marketplaceRepository: TestMarketplaceRepository(),
    );

    await tester.pumpWidget(Any2App(controller: controller));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
    await controller.useDemo();
    await tester.pump();

    expect(find.byType(AppInputGroup), findsOneWidget);
    expect(find.byType(AppSelect<String>), findsOneWidget);
    expect(find.byType(AppCombobox<String>), findsOneWidget);
    expect(find.text('Карта'), findsOneWidget);
    expect(find.text('Дебетовая'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.byType(AppSelect<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Рубли').last);
    await tester.pumpAndSettle();
    expect(controller.form['currency'], 'RUB');

    await tester.tap(find.byType(AppCombobox<String>));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'ро');
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tap(find.text('Россия'));
    await tester.pumpAndSettle();
    expect(controller.form['country'], 'ru');

    await tester.tap(find.byKey(const Key('return-to-any2app')));
    await tester.pump();
    expect(find.text('Подключить приложение'), findsOneWidget);
  });

  test('deep link and QR payload preserve initial form and data', () async {
    final config = {
      'id': 'linked-app',
      'name': 'Linked App',
      'apiBaseUrl': '',
      'initialScreen': 'home',
      'auth': <String, dynamic>{},
      'screens': {
        'home': {'title': 'Linked', 'components': <dynamic>[]},
      },
      'actions': <String, dynamic>{},
    };
    final payload = AppLinkPayload(
      config: config,
      initial: {
        'form': {'email': 'qr@example.com'},
        'data': {'referrer': 'qr'},
      },
    );
    final uri = payload.toUri(Uri.parse('any2app://open'));
    final decoded = AppLinkPayload.fromUri(uri);
    expect(decoded.config?['id'], 'linked-app');
    expect(decoded.initial['form'], {'email': 'qr@example.com'});

    final store = MemorySessionStore();
    final controller = AppController(
      AssetConfigRepository(),
      store,
      ActionEngine(store),
      marketplaceRepository: TestMarketplaceRepository(),
    );
    await controller.handleQrPayload(
      jsonEncode({'config': config, 'initial': payload.initial}),
    );

    expect(controller.state, AppFlowState.ready);
    expect(controller.form['email'], 'qr@example.com');
    expect(controller.data['referrer'], 'qr');
  });

  test('LINK action delegates opening to link service', () async {
    final config = AppConfig.fromJson({
      'id': 'link-action-app',
      'name': 'Link action',
      'apiBaseUrl': '',
      'initialScreen': 'home',
      'auth': <String, dynamic>{},
      'screens': {
        'home': {'title': 'Home', 'components': <dynamic>[]},
      },
      'actions': {
        'share': {
          'request': {
            'method': 'LINK',
            'url': 'any2app://open',
            'initial': {
              'form': {'ref': '{{form.ref}}'},
            },
          },
          'success': {'message': 'Ссылка открыта'},
          'failure': <String, dynamic>{},
        },
      },
    });
    final store = MemorySessionStore();
    final links = MemoryAppLinkService();
    final controller = AppController(
      AssetConfigRepository(config),
      store,
      ActionEngine(store),
      marketplaceRepository: TestMarketplaceRepository(),
      appLinkService: links,
    );
    await controller.useDemo();
    controller.setFormValue('ref', 'campaign');
    await controller.executeAction('share', validate: false);

    expect(links.calls, 1);
    expect(links.lastValues?.form['ref'], 'campaign');
    expect(controller.message, 'Ссылка открыта');
  });

  testWidgets('marketplace app can be added to favorites', (tester) async {
    final store = MemorySessionStore();
    final controller = AppController(
      AssetConfigRepository(),
      store,
      ActionEngine(store),
      marketplaceRepository: TestMarketplaceRepository(),
    );

    await tester.pumpWidget(Any2App(controller: controller));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.byKey(const Key('open-marketplace')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('favorite-app-suburban-train-demo')));
    await tester.pump();

    expect(controller.favoriteAppIds, contains('suburban-train-demo'));
    expect(store.favoriteAppIds, contains('suburban-train-demo'));
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  test(
    'Tutu demo loads HTTP schedules and persists isolated route bookmarks',
    () async {
      final store = MemorySessionStore();
      final client = MockClient((request) async {
        expect(request.url.host, 'suggest.travelpayouts.com');
        expect(request.url.queryParameters['service'], 'tutu_trains');
        expect(request.url.queryParameters['term'], '2000000');
        return http.Response(
          jsonEncode({
            'trips': [
              {
                'trainNumber': '102М',
                'departureTime': '14:20:00',
                'arrivalTime': '13:17:00',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      AppController controller() => AppController(
        AssetConfigRepository(
          AppConfig.fromJson(
            jsonDecode(
                  File('test/fixtures/route_bookmarks.json').readAsStringSync(),
                )
                as Map<String, dynamic>,
          ),
        ),
        store,
        ActionEngine(store, client: client),
      );
      final first = controller();
      await first.useDemo();
      expect(first.config!.actions.containsKey('bookTrip'), isFalse);
      first.setFormValue('from', '2000000');
      first.setFormValue('to', '2064130');
      await first.executeAction('searchTrips');
      expect(first.error, isNull);
      expect(first.currentScreenId, 'results');
      expect(first.data['searchResult']['trips'].length, 1);
      await first.executeAction('saveRoute');
      await first.executeAction('saveRoute');
      expect((await store.readBookmarks(first.storageScope)).length, 1);
      expect(await store.readBookmarks('another-app'), isEmpty);
      final reopened = controller();
      await reopened.useDemo();
      final bookmarks = reopened.data['saved']['bookmarks'] as List;
      expect(bookmarks.length, 1);
      reopened.setFormValue('bookmark', bookmarks.single);
      await reopened.executeAction('openBookmark', validate: false);
      expect(reopened.form['from'], '2000000');
      await reopened.executeAction('searchTrips');
      expect(reopened.currentScreenId, 'results');
      await reopened.executeAction('removeRoute', validate: false);
      expect(await store.readBookmarks(reopened.storageScope), isEmpty);
    },
  );

  test('templates support concat and nested SHA-256', () {
    const values = RuntimeValues(
      form: {'login': 'alice', 'password': 'secret'},
      data: {
        'profile': {'id': 42},
      },
      auth: {},
    );
    final concatenated = resolveTemplate(
      r'{{concat(form.login, ":", form.password)}}',
      values,
    );
    expect(concatenated, 'alice:secret');

    final expectedHash = sha256.convert(utf8.encode('alice:secret')).toString();
    expect(
      resolveTemplate(
        r'{{sha256(concat(form.login, ":", form.password))}}',
        values,
      ),
      expectedHash,
    );
    expect(
      resolveTemplate(
        r'user={{form.login}}&signature={{hash(concat(form.login, ":", data.profile.id))}}',
        values,
      ),
      'user=alice&signature='
      '${sha256.convert(utf8.encode('alice:42'))}',
    );
  });

  test('action asynchronously loads and opens the next screen', () async {
    final config = AppConfig.fromJson({
      'id': 'remote-screen-app',
      'name': 'Remote screen',
      'apiBaseUrl': 'https://api.example.com/',
      'initialScreen': 'home',
      'screens': {
        'home': {'title': 'Home', 'components': <dynamic>[]},
      },
      'actions': {
        'continue': {
          'request': {'method': 'POST', 'url': 'continue'},
          'mock': {
            'status': 200,
            'body': {
              'navigation': {'url': 'screens/details.json'},
            },
          },
          'success': {
            'screenUrlPath': r'$.navigation.url',
            'setData': {
              'screenSource': 'remote:{{result.navigation.url}}',
              'screenHash': '{{sha256(result.navigation.url)}}',
            },
          },
          'failure': <String, dynamic>{},
        },
      },
      'auth': <String, dynamic>{},
    });
    final remoteScreen = RemoteScreenBundle.fromJson({
      'screen': {
        'id': 'details',
        'title': 'Loaded details',
        'components': [
          {'type': 'text', 'text': 'Асинхронный экран'},
        ],
      },
      'actions': {
        'remoteAction': {
          'request': {'method': 'LOCAL'},
          'success': {'message': 'remote'},
          'failure': <String, dynamic>{},
        },
      },
    });
    final repository = AssetConfigRepository(config, remoteScreen);
    final store = MemorySessionStore();
    final controller = AppController(
      repository,
      store,
      ActionEngine(store),
      marketplaceRepository: TestMarketplaceRepository(),
    );

    await controller.connect('https://apps.example.com/config/app.json');
    await controller.executeAction('continue', validate: false);

    expect(
      repository.lastScreenUrl,
      'https://apps.example.com/config/screens/details.json',
    );
    expect(controller.currentScreenId, 'details');
    expect(controller.currentScreen?.title, 'Loaded details');
    expect(controller.config?.actions, contains('remoteAction'));
    expect(controller.data['screenSource'], 'remote:screens/details.json');
    expect(
      controller.data['screenHash'],
      sha256.convert(utf8.encode('screens/details.json')).toString(),
    );
  });

  test('apps with the same declared id cannot share tokens or data', () async {
    final config = AppConfig.fromJson({
      'id': 'spoofable-id',
      'name': 'Scoped app',
      'apiBaseUrl': '',
      'initialScreen': 'login',
      'authenticatedScreen': 'dashboard',
      'screens': {
        'login': {'title': 'Login', 'components': <dynamic>[]},
        'dashboard': {'title': 'Dashboard', 'components': <dynamic>[]},
      },
      'actions': {
        'login': {
          'request': {'method': 'LOCAL'},
          'mock': {
            'status': 200,
            'body': {'accessToken': 'app-a-token'},
          },
          'success': {
            'tokens': {'accessTokenPath': r'$.accessToken'},
          },
          'failure': <String, dynamic>{},
        },
      },
      'auth': <String, dynamic>{},
    });
    final store = MemorySessionStore();
    final first = AppController(
      AssetConfigRepository(config),
      store,
      ActionEngine(store),
      marketplaceRepository: TestMarketplaceRepository(),
    );
    await first.connect('https://apps.example.com/a/config.json');
    first.data['private'] = 'app-a-data';
    await first.executeAction('login', validate: false);
    final firstScope = first.storageScope;
    expect((await store.readTokens(firstScope)).accessToken, 'app-a-token');

    final second = AppController(
      AssetConfigRepository(config),
      store,
      ActionEngine(store),
      marketplaceRepository: TestMarketplaceRepository(),
    );
    await second.connect('https://apps.example.com/b/config.json');

    expect(second.storageScope, isNot(firstScope));
    expect((await store.readTokens(second.storageScope)).accessToken, isNull);
    expect(second.currentScreenId, 'login');
    expect(second.data, isEmpty);

    await first.connect('https://apps.example.com/b/config.json');
    expect(first.data, isEmpty);
  });

  test('401 refreshes token and retries original request once', () async {
    var protectedCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        return http.Response(
          jsonEncode({
            'accessToken': 'new-access',
            'refreshToken': 'new-refresh',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      protectedCalls++;
      if (protectedCalls == 1) {
        return http.Response('{"message":"expired"}', 401);
      }
      expect(request.headers['Authorization'], 'Bearer new-access');
      return http.Response('{"ok":true}', 200);
    });
    final store = MemorySessionStore();
    const storageScope = 'test-scope';
    await store.writeTokens(
      storageScope,
      const TokenBundle(
        accessToken: 'expired-access',
        refreshToken: 'refresh-token',
      ),
    );
    final config = AppConfig.fromJson({
      'id': 'test-app',
      'name': 'Test',
      'apiBaseUrl': 'https://api.example.com/',
      'initialScreen': 'home',
      'auth': {'refreshAction': 'refresh'},
      'screens': {
        'home': {'title': 'Home', 'components': <dynamic>[]},
      },
      'actions': {
        'protected': {
          'request': {'method': 'GET', 'url': 'protected'},
          'success': <String, dynamic>{},
          'failure': {'messagePath': r'$.message'},
        },
        'refresh': {
          'request': {
            'method': 'POST',
            'url': 'auth/refresh',
            'body': {'refreshToken': '{{auth.refreshToken}}'},
          },
          'success': {
            'tokens': {
              'accessTokenPath': r'$.accessToken',
              'refreshTokenPath': r'$.refreshToken',
            },
          },
          'failure': {'message': 'refresh failed'},
        },
      },
    });
    final result = await ActionEngine(store, client: client).execute(
      config: config,
      storageScope: storageScope,
      action: config.actions['protected']!,
      form: const {},
      data: const {},
    );

    expect(result.statusCode, 200);
    expect(protectedCalls, 2);
    final tokens = await store.readTokens(storageScope);
    expect(tokens.accessToken, 'new-access');
    expect(tokens.refreshToken, 'new-refresh');
  });
}

class AssetConfigRepository implements ConfigRepository {
  AssetConfigRepository([this.config, this.remoteScreen]);

  final AppConfig? config;
  final RemoteScreenBundle? remoteScreen;
  String? lastScreenUrl;

  @override
  Future<AppConfig> loadAsset(String assetPath) => loadDemo();

  @override
  Future<AppConfig> loadInline(String source) {
    return Future.value(
      AppConfig.fromJson(jsonDecode(source) as Map<String, dynamic>),
    );
  }

  @override
  Future<RemoteScreenBundle> loadScreenUrl(String url) async {
    lastScreenUrl = url;
    final screen = remoteScreen;
    if (screen == null) {
      throw const ConfigLoadException('Remote screen not configured');
    }
    return screen;
  }

  @override
  Future<AppConfig> loadDemo() async {
    if (config != null) return config!;
    final source = File('assets/config/dummyjson_demo.json').readAsStringSync();
    return AppConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);
  }

  @override
  Future<AppConfig> loadUrl(String url) => loadDemo();
}

class TestMarketplaceRepository implements MarketplaceRepository {
  @override
  Future<MarketplaceCatalog> load() async {
    return const MarketplaceCatalog(
      title: 'Маркетплейс any2app',
      description: 'Выберите приложение.',
      apps: [
        MarketplaceApp(
          id: 'suburban-train-demo',
          name: 'По пути',
          description: 'Билеты на электрички.',
          category: 'Путешествия',
          icon: 'train',
          sourceType: 'asset',
          source: 'assets/config/train_demo.json',
        ),
      ],
    );
  }
}

class MemoryAppLinkService implements AppLinkService {
  var calls = 0;
  RuntimeValues? lastValues;

  @override
  Future<void> launchAction(ActionConfig action, RuntimeValues values) async {
    calls++;
    lastValues = values;
  }
}
