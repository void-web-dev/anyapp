import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenBundle {
  const TokenBundle({
    this.accessToken,
    this.refreshToken,
    this.authenticationCompleted = false,
    this.expiryRaw,
  });

  final String? accessToken;
  final String? refreshToken;
  final bool authenticationCompleted;
  final dynamic expiryRaw;

  bool get hasAccessToken => accessToken != null && accessToken!.isNotEmpty;

  Map<String, dynamic> toRuntimeMap() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'authenticationCompleted': authenticationCompleted,
    'expiryRaw': expiryRaw,
  };
}

abstract interface class SessionStore {
  Future<String> readOrCreateDeviceId(String scope);
  Future<List<Map<String, dynamic>>> readBookmarks(String scope);
  Future<void> writeBookmarks(String scope, List<Map<String, dynamic>> items);
  Future<TokenBundle> readTokens(String appId);
  Future<void> writeTokens(String appId, TokenBundle tokens);
  Future<void> clearTokens(String appId);
  Future<String?> readConfigurationUrl();
  Future<void> writeConfigurationUrl(String? url);
  Future<Set<String>> readFavoriteAppIds();
  Future<void> writeFavoriteAppIds(Set<String> appIds);
}

class DeviceSessionStore implements SessionStore {
  @override
  Future<String> readOrCreateDeviceId(String scope) async {
    final key = 'server_driven.$scope.device_id';
    final existing = await _secureStorage.read(key: key);
    if (existing != null) return existing;
    final id = _newDeviceId();
    await _secureStorage.write(key: key, value: id);
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> readBookmarks(String scope) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('server_driven.$scope.bookmarks');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  @override
  Future<void> writeBookmarks(
    String scope,
    List<Map<String, dynamic>> items,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'server_driven.$scope.bookmarks',
      jsonEncode(items),
    );
  }

  DeviceSessionStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _configUrlKey = 'server_driven.configuration_url';
  static const _favoritesKey = 'server_driven.marketplace_favorites';
  final FlutterSecureStorage _secureStorage;

  String _accessKey(String appId) => 'server_driven.$appId.access_token';
  String _refreshKey(String appId) => 'server_driven.$appId.refresh_token';

  @override
  Future<TokenBundle> readTokens(String appId) async {
    final raw = await _secureStorage.read(key: 'server_driven.$appId.session');
    if (raw != null) {
      final value = jsonDecode(raw) as Map;
      return TokenBundle(
        accessToken: value['accessToken'] as String?,
        refreshToken: value['refreshToken'] as String?,
        authenticationCompleted: value['authenticationCompleted'] == true,
        expiryRaw: value['expiryRaw'],
      );
    }
    return TokenBundle(
      accessToken: await _secureStorage.read(key: _accessKey(appId)),
      refreshToken: await _secureStorage.read(key: _refreshKey(appId)),
    );
  }

  @override
  Future<void> writeTokens(String appId, TokenBundle tokens) async {
    await _secureStorage.write(
      key: 'server_driven.$appId.session',
      value: jsonEncode(tokens.toRuntimeMap()),
    );
    await _secureStorage.delete(key: _accessKey(appId));
    await _secureStorage.delete(key: _refreshKey(appId));
  }

  @override
  Future<void> clearTokens(String appId) async {
    await Future.wait([
      _secureStorage.delete(key: 'server_driven.$appId.session'),
      _secureStorage.delete(key: _accessKey(appId)),
      _secureStorage.delete(key: _refreshKey(appId)),
    ]);
  }

  @override
  Future<String?> readConfigurationUrl() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_configUrlKey);
  }

  @override
  Future<void> writeConfigurationUrl(String? url) async {
    final preferences = await SharedPreferences.getInstance();
    if (url == null) {
      await preferences.remove(_configUrlKey);
    } else {
      await preferences.setString(_configUrlKey, url);
    }
  }

  @override
  Future<Set<String>> readFavoriteAppIds() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_favoritesKey)?.toSet() ?? {};
  }

  @override
  Future<void> writeFavoriteAppIds(Set<String> appIds) async {
    final preferences = await SharedPreferences.getInstance();
    final sorted = appIds.toList()..sort();
    await preferences.setStringList(_favoritesKey, sorted);
  }
}

class MemorySessionStore implements SessionStore {
  final Map<String, String> _deviceIds = {};
  @override
  Future<String> readOrCreateDeviceId(String scope) async =>
      _deviceIds.putIfAbsent(scope, _newDeviceId);
  final Map<String, String> _bookmarks = {};

  @override
  Future<List<Map<String, dynamic>>> readBookmarks(String scope) async =>
      (jsonDecode(_bookmarks[scope] ?? '[]') as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  @override
  Future<void> writeBookmarks(
    String scope,
    List<Map<String, dynamic>> items,
  ) async {
    _bookmarks[scope] = jsonEncode(items);
  }

  final Map<String, TokenBundle> _tokens = {};
  String? configurationUrl;
  final Set<String> favoriteAppIds = {};

  @override
  Future<void> clearTokens(String appId) async => _tokens.remove(appId);

  @override
  Future<String?> readConfigurationUrl() async => configurationUrl;

  @override
  Future<TokenBundle> readTokens(String appId) async {
    return _tokens[appId] ?? const TokenBundle();
  }

  @override
  Future<Set<String>> readFavoriteAppIds() async => {...favoriteAppIds};

  @override
  Future<void> writeConfigurationUrl(String? url) async {
    configurationUrl = url;
  }

  @override
  Future<void> writeFavoriteAppIds(Set<String> appIds) async {
    favoriteAppIds
      ..clear()
      ..addAll(appIds);
  }

  @override
  Future<void> writeTokens(String appId, TokenBundle tokens) async {
    _tokens[appId] = tokens;
  }
}

String _newDeviceId() {
  final random = Random.secure();
  return List.generate(
    32,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
