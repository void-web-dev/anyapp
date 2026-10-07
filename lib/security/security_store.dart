import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AccessMode { pin, biometric, open }

enum ThemePreference { system, light, dark }

abstract interface class SecurityStore {
  Future<AccessMode?> readAccessMode();
  Future<void> writeAccessMode(AccessMode mode);
  Future<ThemePreference> readThemePreference();
  Future<void> writeThemePreference(ThemePreference preference);
  Future<void> writePin(String pin);
  Future<bool> verifyPin(String pin);
  Future<void> clearPin();
}

class DeviceSecurityStore implements SecurityStore {
  DeviceSecurityStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _accessModeKey = 'security.access_mode';
  static const _themeKey = 'settings.theme';
  static const _pinSaltKey = 'security.pin_salt';
  static const _pinHashKey = 'security.pin_hash';

  final FlutterSecureStorage _secureStorage;

  @override
  Future<AccessMode?> readAccessMode() async {
    final stored = await _secureStorage.read(key: _accessModeKey);
    return AccessMode.values.where((mode) => mode.name == stored).firstOrNull;
  }

  @override
  Future<void> writeAccessMode(AccessMode mode) async {
    await _secureStorage.write(key: _accessModeKey, value: mode.name);
  }

  @override
  Future<ThemePreference> readThemePreference() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_themeKey);
    return ThemePreference.values
            .where((preference) => preference.name == stored)
            .firstOrNull ??
        ThemePreference.system;
  }

  @override
  Future<void> writeThemePreference(ThemePreference preference) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeKey, preference.name);
  }

  @override
  Future<void> writePin(String pin) async {
    final salt = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    final digest = sha256.convert([...salt, ...utf8.encode(pin)]).bytes;
    await Future.wait([
      _secureStorage.write(key: _pinSaltKey, value: base64UrlEncode(salt)),
      _secureStorage.write(key: _pinHashKey, value: base64UrlEncode(digest)),
    ]);
  }

  @override
  Future<bool> verifyPin(String pin) async {
    final values = await Future.wait([
      _secureStorage.read(key: _pinSaltKey),
      _secureStorage.read(key: _pinHashKey),
    ]);
    final encodedSalt = values[0];
    final encodedExpected = values[1];
    if (encodedSalt == null || encodedExpected == null) return false;
    try {
      final salt = base64Url.decode(encodedSalt);
      final expected = base64Url.decode(encodedExpected);
      final actual = sha256.convert([...salt, ...utf8.encode(pin)]).bytes;
      return _constantTimeEquals(expected, actual);
    } on FormatException {
      return false;
    }
  }

  @override
  Future<void> clearPin() async {
    await Future.wait([
      _secureStorage.delete(key: _pinSaltKey),
      _secureStorage.delete(key: _pinHashKey),
    ]);
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}

class MemorySecurityStore implements SecurityStore {
  MemorySecurityStore({
    this.accessMode,
    this.themePreference = ThemePreference.system,
  });

  AccessMode? accessMode;
  ThemePreference themePreference;
  String? _pin;

  @override
  Future<void> clearPin() async => _pin = null;

  @override
  Future<AccessMode?> readAccessMode() async => accessMode;

  @override
  Future<ThemePreference> readThemePreference() async => themePreference;

  @override
  Future<bool> verifyPin(String pin) async => _pin == pin;

  @override
  Future<void> writeAccessMode(AccessMode mode) async {
    accessMode = mode;
  }

  @override
  Future<void> writePin(String pin) async => _pin = pin;

  @override
  Future<void> writeThemePreference(ThemePreference preference) async {
    themePreference = preference;
  }
}
