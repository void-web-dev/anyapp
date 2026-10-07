import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/app_config.dart';
import '../models/marketplace_catalog.dart';
import '../services/action_engine.dart';
import '../services/app_link_service.dart';
import '../services/config_repository.dart';
import '../services/marketplace_repository.dart';
import '../services/session_store.dart';
import 'app_scope.dart';
import 'value_resolver.dart';

enum AppFlowState {
  splash,
  configuration,
  marketplace,
  builder,
  qrScanner,
  ready,
}

class RuntimeComboboxOption {
  const RuntimeComboboxOption({required this.value, required this.label});

  final String value;
  final String label;
}

class AppController extends ChangeNotifier {
  AppController(
    this._configRepository,
    this._sessionStore,
    this._actionEngine, {
    MarketplaceRepository? marketplaceRepository,
    AppLinkService? appLinkService,
  }) : _marketplaceRepository =
           marketplaceRepository ?? const AssetMarketplaceRepository(),
       _appLinkService = appLinkService ?? const UrlAppLinkService();

  final ConfigRepository _configRepository;
  final SessionStore _sessionStore;
  final ActionEngine _actionEngine;
  final MarketplaceRepository _marketplaceRepository;
  final AppLinkService _appLinkService;
  bool _externalLaunchStarted = false;
  String _storageScope = '';
  int _activation = 0;
  bool _completedAuthentication = false;

  AppFlowState state = AppFlowState.splash;
  AppConfig? config;
  String? currentScreenId;
  String? configurationUrl;
  String? error;
  String? message;
  String? busyAction;
  bool configurationLoading = false;
  MarketplaceCatalog? marketplace;
  Set<String> favoriteAppIds = {};

  Map<String, dynamic> form = {};
  Map<String, dynamic> data = {};
  final Map<String, String> fieldErrors = {};
  final List<String> _history = [];
  String? _lastOnEnterScreen;

  bool get isBusy => busyAction != null;
  String get storageScope => _storageScope;
  ScreenConfig? get currentScreen => config?.screens[currentScreenId];

  Future<void> initialize() async {
    final splashDelay = Future<void>.delayed(const Duration(milliseconds: 700));
    try {
      marketplace = await _marketplaceRepository.load();
      favoriteAppIds = await _sessionStore.readFavoriteAppIds();
    } catch (exception) {
      error = _friendlyError(exception);
    }
    await splashDelay;
    if (_externalLaunchStarted) return;
    final savedUrl = await _sessionStore.readConfigurationUrl();
    if (savedUrl == null || savedUrl.isEmpty) {
      state = AppFlowState.configuration;
      notifyListeners();
      return;
    }
    await connect(savedUrl, persist: false);
  }

  Future<void> openMarketplaceApp(MarketplaceApp app) async {
    configurationLoading = true;
    error = null;
    notifyListeners();
    try {
      await _sessionStore.writeConfigurationUrl(
        app.sourceType == 'url' ? app.source : null,
      );
      configurationUrl = app.sourceType == 'url' ? app.source : null;
      final loaded = app.sourceType == 'url'
          ? await _configRepository.loadUrl(app.source)
          : await _configRepository.loadAsset(app.source);
      await _activate(
        loaded,
        scopeSource: 'marketplace:${app.sourceType}:${app.source}',
      );
    } catch (exception) {
      state = AppFlowState.marketplace;
      error = _friendlyError(exception);
    } finally {
      configurationLoading = false;
      notifyListeners();
    }
  }

  void openMarketplace() {
    state = AppFlowState.marketplace;
    error = null;
    notifyListeners();
  }

  void closeMarketplace() {
    state = AppFlowState.configuration;
    error = null;
    notifyListeners();
  }

  void openBuilder() {
    state = AppFlowState.builder;
    error = null;
    notifyListeners();
  }

  void closeBuilder() {
    state = AppFlowState.configuration;
    error = null;
    notifyListeners();
  }

  void openQrScanner() {
    state = AppFlowState.qrScanner;
    error = null;
    notifyListeners();
  }

  void closeQrScanner() {
    state = AppFlowState.configuration;
    error = null;
    notifyListeners();
  }

  Future<void> handleIncomingUri(Uri uri) async {
    await _openLinkPayload(AppLinkPayload.fromUri(uri));
  }

  Future<void> handleQrPayload(String raw) async {
    await _openLinkPayload(AppLinkPayload.fromRaw(raw));
  }

  Future<void> _openLinkPayload(AppLinkPayload payload) async {
    _externalLaunchStarted = true;
    configurationLoading = true;
    error = null;
    notifyListeners();
    try {
      if (!payload.hasConfiguration) {
        throw const FormatException(
          'Ссылка или QR не содержит configUrl либо config',
        );
      }
      final loaded = payload.configUrl != null
          ? await _configRepository.loadUrl(payload.configUrl!)
          : await _configRepository.loadInline(jsonEncode(payload.config));
      await _sessionStore.writeConfigurationUrl(payload.configUrl);
      configurationUrl = payload.configUrl;
      final inlineSource = jsonEncode(payload.config);
      await _activate(
        loaded,
        initial: payload.initial,
        scopeSource: payload.configUrl != null
            ? 'url:${payload.configUrl!.trim()}'
            : 'inline:$inlineSource',
      );
    } catch (exception) {
      state = AppFlowState.configuration;
      error = _friendlyError(exception);
    } finally {
      configurationLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String appId) async {
    final updated = {...favoriteAppIds};
    if (!updated.add(appId)) {
      updated.remove(appId);
    }
    favoriteAppIds = updated;
    notifyListeners();
    await _sessionStore.writeFavoriteAppIds(updated);
  }

  Future<void> refreshMarketplace() async {
    error = null;
    try {
      marketplace = await _marketplaceRepository.load();
      favoriteAppIds = await _sessionStore.readFavoriteAppIds();
    } catch (exception) {
      error = _friendlyError(exception);
    }
    notifyListeners();
  }

  Future<void> refreshCurrentScreen() async {
    final action = currentScreen?.refreshAction ?? currentScreen?.onEnter;
    if (action != null) {
      await executeAction(action, validate: false);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<List<RuntimeComboboxOption>> searchComboboxOptions(
    ComponentConfig component,
    String query,
  ) async {
    final activeConfig = config;
    final actionId = component.string('searchAction');
    final action = actionId == null ? null : activeConfig?.actions[actionId];
    if (activeConfig == null || action == null) {
      throw FormatException(
        'Search action "${actionId ?? ''}" не найден в конфигурации',
      );
    }
    final queryField = component.string('searchQueryField') ?? 'searchQuery';
    final result = await _actionEngine.execute(
      config: activeConfig,
      storageScope: _storageScope,
      action: action,
      form: {...form, queryField: query},
      data: data,
    );
    final rawItems = readJsonPath(
      result.body,
      component.string('optionsPath') ?? r'$.items',
    );
    if (rawItems is! List) {
      throw const FormatException(
        'Ответ online combobox должен содержать список options',
      );
    }
    final valuePath = component.string('optionValuePath') ?? r'$.value';
    final labelPath = component.string('optionLabelPath') ?? r'$.label';
    return [
      for (final item in rawItems)
        if (readJsonPath(item, valuePath) != null &&
            readJsonPath(item, labelPath) != null)
          RuntimeComboboxOption(
            value: readJsonPath(item, valuePath).toString(),
            label: readJsonPath(item, labelPath).toString(),
          ),
    ];
  }

  Future<void> connect(String url, {bool persist = true}) async {
    configurationLoading = true;
    error = null;
    configurationUrl = url.trim();
    notifyListeners();
    try {
      final loaded = await _configRepository.loadUrl(url);
      if (persist) {
        await _sessionStore.writeConfigurationUrl(url.trim());
      }
      await _activate(loaded, scopeSource: 'url:${url.trim()}');
    } catch (exception) {
      state = AppFlowState.configuration;
      error = _friendlyError(exception);
    } finally {
      configurationLoading = false;
      notifyListeners();
    }
  }

  Future<void> useDemo() async {
    configurationLoading = true;
    error = null;
    notifyListeners();
    try {
      await _sessionStore.writeConfigurationUrl(null);
      configurationUrl = null;
      await _activate(
        await _configRepository.loadDemo(),
        scopeSource: 'asset:assets/config/dummyjson_demo.json',
      );
    } catch (exception) {
      state = AppFlowState.configuration;
      error = _friendlyError(exception);
    } finally {
      configurationLoading = false;
      notifyListeners();
    }
  }

  Future<void> _activate(
    AppConfig loaded, {
    Map<String, dynamic> initial = const {},
    required String scopeSource,
  }) async {
    _actionEngine.resetFlow(_storageScope);
    _activation++;
    busyAction = null;
    _storageScope = createAppScope(scopeSource);
    config = loaded;
    form = {};
    data = {};
    fieldErrors.clear();
    _history.clear();
    _lastOnEnterScreen = null;
    final initialForm = initial['form'];
    final initialData = initial['data'];
    if (initialForm is Map) {
      form.addAll(Map<String, dynamic>.from(initialForm));
    }
    if (initialData is Map) {
      data.addAll(Map<String, dynamic>.from(initialData));
    } else {
      data.addAll({
        for (final entry in initial.entries)
          if (entry.key != 'form' && entry.key != 'screenId')
            entry.key: entry.value,
      });
    }
    final tokens = await _sessionStore.readTokens(_storageScope);
    _completedAuthentication =
        tokens.hasAccessToken && tokens.authenticationCompleted;
    final defaultScreen =
        tokens.hasAccessToken &&
            (loaded.flowDefinition == null || _completedAuthentication) &&
            loaded.authenticatedScreen != null
        ? loaded.authenticatedScreen
        : loaded.initialScreen;
    final requestedScreen = initial['screenId'] as String?;
    currentScreenId =
        requestedScreen != null &&
            loaded.screens.containsKey(requestedScreen) &&
            (!loaded
                    .screens[requestedScreen]!
                    .requiresCompletedAuthentication ||
                _completedAuthentication)
        ? requestedScreen
        : defaultScreen;
    state = AppFlowState.ready;
    notifyListeners();
    await _runOnEnter();
  }

  void setFormValue(String id, dynamic value) {
    form[id] = value;
    for (final component
        in currentScreen?.components ?? const <ComponentConfig>[]) {
      if (component.id != id) continue;
      final options = component.properties['options'];
      if (options is List) {
        for (final option in options.whereType<Map>()) {
          if (option['value'] == value) form['${id}Label'] = option['label'];
        }
      }
    }
    fieldErrors.remove(id);
  }

  dynamic resolve(String expression) {
    return resolveValue(
      expression,
      RuntimeValues(form: form, data: data, auth: const {}),
    );
  }

  Future<void> executeAction(String actionId, {bool validate = true}) async {
    final activeConfig = config;
    if (activeConfig == null || isBusy) return;
    final action = activeConfig.actions[actionId];
    if (action == null) {
      error = 'Действие "$actionId" не найдено в конфигурации';
      notifyListeners();
      return;
    }
    if (validate &&
        action.definition?['type'] != 'clearAndNavigate' &&
        !_validateCurrentScreen()) {
      notifyListeners();
      return;
    }

    busyAction = actionId;
    final activation = _activation;
    final actionScope = _storageScope;
    error = null;
    message = null;
    notifyListeners();
    try {
      if ((action.request['method'] as String?)?.toUpperCase() == 'LINK') {
        await _appLinkService.launchAction(
          action,
          RuntimeValues(form: form, data: data, auth: const {}),
        );
      }
      final result = await _actionEngine.execute(
        config: activeConfig,
        storageScope: _storageScope,
        action: action,
        form: form,
        data: data,
      );
      if (activation != _activation) return;
      if (action.definition != null) {
        final tokens = await _sessionStore.readTokens(actionScope);
        if (activation != _activation) return;
        _completedAuthentication =
            tokens.hasAccessToken && tokens.authenticationCompleted;
        error = result.flowError;
        if (result.replaceHistory) _history.clear();
        if (result.navigateTo != null) {
          _setScreen(result.navigateTo!, addToHistory: !result.replaceHistory);
        }
      }
      final success = action.success;
      final storeAs = success['storeResponseAs'] as String?;
      if (storeAs != null) {
        data[storeAs] = readJsonPath(
          result.body,
          success['storeResponsePath'] as String?,
        );
      }
      final successValues = RuntimeValues(
        form: form,
        data: data,
        auth: const {},
        result: result.body,
      );
      final setData = success['setData'];
      if (setData is Map) {
        final resolved = resolveTemplate(setData, successValues);
        if (resolved is! Map) {
          throw const FormatException('success.setData должен быть объектом');
        }
        data.addAll(Map<String, dynamic>.from(resolved));
      }
      final setForm = success['setForm'];
      if (setForm is Map) {
        form.addAll(
          Map<String, dynamic>.from(
            resolveTemplate(setForm, successValues) as Map,
          ),
        );
      }
      final messageTemplate = success['message'];
      message = messageTemplate == null
          ? null
          : resolveTemplate(messageTemplate, successValues).toString();
      if (success['clearForm'] == true) form.clear();
      final loadedScreenId = await _loadNextScreen(
        activeConfig,
        success,
        result.body,
      );
      final navigateTemplate = success['navigate'];
      final navigateTo =
          (navigateTemplate == null
              ? null
              : resolveTemplate(navigateTemplate, successValues).toString()) ??
          (success['navigateLoadedScreen'] == false ? null : loadedScreenId);
      if (navigateTo != null) {
        _setScreen(navigateTo);
      }
    } on ActionFailure catch (failure) {
      if (activation != _activation) return;
      error = failure.message;
      if (failure.statusCode == 401) {
        await _sessionStore.clearTokens(_storageScope);
        _setScreen(activeConfig.initialScreen, addToHistory: false);
      }
    } catch (exception) {
      if (activation != _activation) return;
      error = _friendlyError(exception);
    } finally {
      if (activation == _activation) {
        busyAction = null;
        notifyListeners();
      }
    }
    await _runOnEnter();
  }

  Future<String?> _loadNextScreen(
    AppConfig activeConfig,
    Map<String, dynamic> success,
    dynamic resultBody,
  ) async {
    if (success['loadNextScreen'] == false) return null;
    final configuredPath = success['screenUrlPath'] as String?;
    final value = readJsonPath(
      resultBody,
      configuredPath ?? r'$.nextScreenUrl',
    );
    if (value == null || value.toString().trim().isEmpty) return null;
    final screenUri = _resolveScreenUri(
      value.toString(),
      activeConfig.apiBaseUrl,
    );
    final bundle = await _configRepository.loadScreenUrl(screenUri.toString());
    config = (config ?? activeConfig).extendWith(bundle);
    return bundle.screen.id;
  }

  Uri _resolveScreenUri(String value, String apiBaseUrl) {
    final parsed = Uri.tryParse(value.trim());
    if (parsed == null) {
      throw const FormatException('Ответ содержит некорректный URL экрана');
    }
    if (parsed.hasScheme) {
      if (parsed.scheme != 'http' && parsed.scheme != 'https') {
        throw const FormatException(
          'Экран можно загрузить только по HTTP или HTTPS',
        );
      }
      return parsed;
    }
    final base = configurationUrl?.trim().isNotEmpty == true
        ? configurationUrl!
        : apiBaseUrl;
    final baseUri = Uri.tryParse(base);
    if (baseUri == null || !baseUri.hasScheme) {
      throw const FormatException(
        'Для относительного URL экрана отсутствует базовый URL',
      );
    }
    return baseUri.resolveUri(parsed);
  }

  bool _validateCurrentScreen() {
    fieldErrors.clear();
    for (final component in currentScreen?.components ?? const []) {
      const fieldTypes = {'input', 'inputGroup', 'select', 'combobox'};
      if (!fieldTypes.contains(component.type) ||
          !component.boolean('required')) {
        continue;
      }
      final id = component.id;
      if (id == null) continue;
      final value = form[id];
      if (value == null || value.toString().trim().isEmpty) {
        fieldErrors[id] =
            component.string('requiredMessage') ?? 'Обязательное поле';
      }
    }
    return fieldErrors.isEmpty;
  }

  Future<void> _runOnEnter() async {
    if (_lastOnEnterScreen == currentScreenId) return;
    _lastOnEnterScreen = currentScreenId;
    final action = currentScreen?.onEnter;
    if (action != null && action != busyAction) {
      await executeAction(action, validate: false);
    }
  }

  void _setScreen(String id, {bool addToHistory = true}) {
    if (config?.screens.containsKey(id) != true) {
      throw FormatException('Экран "$id" не найден в конфигурации');
    }
    if (config!.screens[id]!.requiresCompletedAuthentication &&
        !_completedAuthentication) {
      id = config!.initialScreen;
    }
    if (addToHistory && currentScreenId != null && currentScreenId != id) {
      _history.add(currentScreenId!);
    }
    currentScreenId = id;
    fieldErrors.clear();
  }

  void goBack() {
    if (_history.isEmpty) return;
    _setScreen(_history.removeLast(), addToHistory: false);
    error = null;
    notifyListeners();
  }

  Future<void> changeConfiguration() async {
    _activation++;
    _actionEngine.resetFlow(_storageScope);
    busyAction = null;
    _completedAuthentication = false;
    await _sessionStore.writeConfigurationUrl(null);
    config = null;
    currentScreenId = null;
    _storageScope = '';
    form = {};
    data = {};
    fieldErrors.clear();
    _history.clear();
    _lastOnEnterScreen = null;
    state = AppFlowState.configuration;
    error = null;
    notifyListeners();
  }

  String _friendlyError(Object exception) {
    if (exception is ConfigLoadException) return exception.message;
    if (exception is FormatException) return exception.message;
    return 'Не удалось выполнить операцию: $exception';
  }

  @override
  void dispose() {
    _activation++;
    _actionEngine.resetFlow(_storageScope);
    form.clear();
    data.clear();
    super.dispose();
  }
}
