class AppConfig {
  const AppConfig({
    required this.id,
    required this.name,
    required this.apiBaseUrl,
    required this.initialScreen,
    required this.authenticatedScreen,
    required this.screens,
    required this.actions,
    required this.auth,
    this.flowDefinition,
  });

  final String id;
  final String name;
  final String apiBaseUrl;
  final String initialScreen;
  final String? authenticatedScreen;
  final Map<String, ScreenConfig> screens;
  final Map<String, ActionConfig> actions;
  final AuthConfig auth;
  final Map<String, dynamic>? flowDefinition;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    if ((json['format'] == 'any2app.flow' ||
            json['format'] == 'any2app.flow-proposal') &&
        json['version'] != 1) {
      throw const FormatException('Неподдерживаемая версия flow-контракта');
    }
    final screensJson = _map(json['screens'], 'screens');
    final actionsJson = _map(json['actions'], 'actions');
    final config = AppConfig(
      id: _string(json['id'], 'id'),
      name: _string(json['name'], 'name'),
      apiBaseUrl: json['apiBaseUrl'] as String? ?? '',
      initialScreen: _string(
        json['initialScreen'] ?? json['sessionPolicy']?['initialScreen'],
        'initialScreen',
      ),
      authenticatedScreen:
          (json['authenticatedScreen'] ??
                  json['sessionPolicy']?['resumeScreen'])
              as String?,
      flowDefinition:
          json['format'] == 'any2app.flow-proposal' ||
              json['format'] == 'any2app.flow'
          ? json
          : null,
      screens: screensJson.map(
        (key, value) => MapEntry(
          key,
          ScreenConfig.fromJson(key, _map(value, 'screens.$key')),
        ),
      ),
      actions: actionsJson.map(
        (key, value) => MapEntry(
          key,
          ActionConfig.fromJson(key, _map(value, 'actions.$key')),
        ),
      ),
      auth: AuthConfig.fromJson(
        json['auth'] is Map<String, dynamic>
            ? json['auth'] as Map<String, dynamic>
            : const {},
      ),
    );
    if (!config.screens.containsKey(config.initialScreen)) {
      throw const FormatException(
        'initialScreen должен ссылаться на существующий экран',
      );
    }
    return config;
  }

  AppConfig extendWith(RemoteScreenBundle bundle) {
    if (screens.containsKey(bundle.screen.id)) {
      throw FormatException(
        'Асинхронный экран "${bundle.screen.id}" уже существует',
      );
    }
    final actionCollisions = bundle.actions.keys
        .where(actions.containsKey)
        .toList(growable: false);
    if (actionCollisions.isNotEmpty) {
      throw FormatException(
        'Асинхронный экран переопределяет actions: '
        '${actionCollisions.join(', ')}',
      );
    }
    return AppConfig(
      id: id,
      name: name,
      apiBaseUrl: apiBaseUrl,
      initialScreen: initialScreen,
      authenticatedScreen: authenticatedScreen,
      screens: {...screens, bundle.screen.id: bundle.screen},
      actions: {...actions, ...bundle.actions},
      auth: auth,
      flowDefinition: flowDefinition,
    );
  }
}

class RemoteScreenBundle {
  const RemoteScreenBundle({required this.screen, required this.actions});

  final ScreenConfig screen;
  final Map<String, ActionConfig> actions;

  factory RemoteScreenBundle.fromJson(Map<String, dynamic> json) {
    final screenJson = json['screen'] is Map
        ? _map(json['screen'], 'screen')
        : json;
    final id = _string(screenJson['id'], 'screen.id');
    final actionsJson = json['actions'] == null
        ? const <String, dynamic>{}
        : _map(json['actions'], 'actions');
    return RemoteScreenBundle(
      screen: ScreenConfig.fromJson(id, screenJson),
      actions: actionsJson.map(
        (key, value) => MapEntry(
          key,
          ActionConfig.fromJson(key, _map(value, 'actions.$key')),
        ),
      ),
    );
  }
}

class ScreenConfig {
  const ScreenConfig({
    required this.id,
    required this.title,
    required this.components,
    this.description,
    this.onEnter,
    this.refreshAction,
    this.showAppBar = true,
    this.canGoBack = false,
    this.requiresCompletedAuthentication = false,
  });

  final String id;
  final String title;
  final String? description;
  final List<ComponentConfig> components;
  final String? onEnter;
  final String? refreshAction;
  final bool showAppBar;
  final bool canGoBack;
  final bool requiresCompletedAuthentication;

  factory ScreenConfig.fromJson(String id, Map<String, dynamic> json) {
    final components =
        json['components'] ??
        (json['resourceKeys'] is List
            ? [
                for (final key in json['resourceKeys'] as List)
                  {
                    'type': 'jsonResource',
                    'title': key.toString(),
                    'dataPath': 'products.$key',
                  },
              ]
            : null);
    if (components is! List) {
      throw FormatException('screens.$id.components должен быть массивом');
    }
    return ScreenConfig(
      id: id,
      title: _string(json['title'], 'screens.$id.title'),
      description: json['description'] as String?,
      components: [
        for (var index = 0; index < components.length; index++)
          ComponentConfig.fromJson(
            _map(components[index], 'screens.$id.components[$index]'),
          ),
      ],
      onEnter: json['onEnter'] as String?,
      refreshAction: json['refreshAction'] as String?,
      showAppBar: json['showAppBar'] as bool? ?? true,
      canGoBack: json['canGoBack'] as bool? ?? false,
      requiresCompletedAuthentication:
          json['requiresCompletedAuthentication'] == true,
    );
  }
}

class ComponentConfig {
  const ComponentConfig({required this.type, required this.properties});

  final String type;
  final Map<String, dynamic> properties;

  factory ComponentConfig.fromJson(Map<String, dynamic> json) {
    return ComponentConfig(
      type: _string(json['type'], 'component.type'),
      properties: json,
    );
  }

  String? get id => properties['id'] as String?;
  String? string(String key) => properties[key] as String?;
  bool boolean(String key, [bool fallback = false]) =>
      properties[key] as bool? ?? fallback;
  num? number(String key) => properties[key] as num?;
}

class ActionConfig {
  const ActionConfig({
    required this.id,
    required this.request,
    required this.success,
    required this.failure,
    this.mock,
    this.definition,
  });

  final String id;
  final Map<String, dynamic> request;
  final Map<String, dynamic> success;
  final Map<String, dynamic> failure;
  final Map<String, dynamic>? mock;
  final Map<String, dynamic>? definition;

  factory ActionConfig.fromJson(String id, Map<String, dynamic> json) {
    return ActionConfig(
      id: id,
      definition: json['type'] is String ? json : null,
      request: _map(json['request'] ?? const {}, 'actions.$id.request'),
      success: _map(json['success'] ?? const {}, 'actions.$id.success'),
      failure: _map(json['failure'] ?? const {}, 'actions.$id.failure'),
      mock: json['mock'] == null
          ? null
          : _map(json['mock'], 'actions.$id.mock'),
    );
  }
}

class AuthConfig {
  const AuthConfig({
    this.refreshAction,
    this.authorizationHeader = 'Authorization',
    this.scheme = 'Bearer',
  });

  final String? refreshAction;
  final String authorizationHeader;
  final String scheme;

  factory AuthConfig.fromJson(Map<String, dynamic> json) {
    return AuthConfig(
      refreshAction: json['refreshAction'] as String?,
      authorizationHeader:
          json['authorizationHeader'] as String? ?? 'Authorization',
      scheme: json['scheme'] as String? ?? 'Bearer',
    );
  }
}

Map<String, dynamic> _map(Object? value, String path) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  throw FormatException('$path должен быть объектом');
}

String _string(Object? value, String path) {
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('$path должен быть непустой строкой');
}
