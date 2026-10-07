import 'package:flutter/material.dart';

import 'biometric_service.dart';
import 'security_store.dart';

enum SecurityFlowState { loading, setup, locked, ready }

class AppSecurityController extends ChangeNotifier {
  AppSecurityController(this._store, this._biometricService);

  AppSecurityController.openForTesting()
    : _store = MemorySecurityStore(accessMode: AccessMode.open),
      _biometricService = MemoryBiometricService(),
      state = SecurityFlowState.ready,
      accessMode = AccessMode.open,
      biometricsAvailable = true,
      _initialized = true;

  final SecurityStore _store;
  final BiometricService _biometricService;

  SecurityFlowState state = SecurityFlowState.loading;
  AccessMode? accessMode;
  ThemePreference themePreference = ThemePreference.system;
  bool biometricsAvailable = false;
  bool busy = false;
  String? error;
  bool _initialized = false;

  ThemeMode get themeMode => switch (themePreference) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final values = await Future.wait<Object?>([
        _store.readAccessMode(),
        _store.readThemePreference(),
        _safeBiometricAvailability(),
      ]);
      accessMode = values[0] as AccessMode?;
      themePreference = values[1]! as ThemePreference;
      biometricsAvailable = values[2]! as bool;
      state = switch (accessMode) {
        null => SecurityFlowState.setup,
        AccessMode.open => SecurityFlowState.ready,
        AccessMode.pin || AccessMode.biometric => SecurityFlowState.locked,
      };
      notifyListeners();
      if (accessMode == AccessMode.biometric) {
        await authenticateWithBiometrics();
      }
    } catch (_) {
      error = 'Не удалось загрузить настройки безопасности';
      state = SecurityFlowState.setup;
      notifyListeners();
    }
  }

  Future<void> useOpenMode() async {
    await _run(() async {
      await _store.writeAccessMode(AccessMode.open);
      await _store.clearPin();
      accessMode = AccessMode.open;
      state = SecurityFlowState.ready;
    });
  }

  Future<void> usePin(String pin, {String? currentPin}) async {
    final validationError = validatePin(pin);
    if (validationError != null) {
      error = validationError;
      notifyListeners();
      return;
    }
    await _run(() async {
      if (accessMode == AccessMode.pin &&
          (currentPin == null || !await _store.verifyPin(currentPin))) {
        throw const SecurityException('Текущий короткий код введён неверно');
      }
      await _store.writePin(pin);
      await _store.writeAccessMode(AccessMode.pin);
      accessMode = AccessMode.pin;
      state = SecurityFlowState.ready;
    });
  }

  Future<void> useBiometricMode() async {
    await _run(() async {
      biometricsAvailable = await _safeBiometricAvailability();
      if (!biometricsAvailable) {
        throw const SecurityException(
          'Биометрия недоступна или не настроена на устройстве',
        );
      }
      final authenticated = await _biometricService.authenticate();
      if (!authenticated) {
        throw const SecurityException('Биометрия не подтверждена');
      }
      await _store.writeAccessMode(AccessMode.biometric);
      await _store.clearPin();
      accessMode = AccessMode.biometric;
      state = SecurityFlowState.ready;
    });
  }

  Future<void> unlockWithPin(String pin) async {
    await _run(() async {
      if (!await _store.verifyPin(pin)) {
        throw const SecurityException('Неверный короткий код');
      }
      state = SecurityFlowState.ready;
    });
  }

  Future<void> authenticateWithBiometrics() async {
    if (busy || accessMode != AccessMode.biometric) return;
    await _run(() async {
      if (!await _biometricService.authenticate()) {
        throw const SecurityException('Не удалось подтвердить вход');
      }
      state = SecurityFlowState.ready;
    });
  }

  Future<void> setThemePreference(ThemePreference preference) async {
    themePreference = preference;
    notifyListeners();
    try {
      await _store.writeThemePreference(preference);
    } catch (_) {
      error = 'Не удалось сохранить тему';
      notifyListeners();
    }
  }

  String? validatePin(String pin) {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      return 'Короткий код должен содержать от 4 до 6 цифр';
    }
    return null;
  }

  Future<bool> _safeBiometricAvailability() async {
    try {
      return await _biometricService.isAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } on SecurityException catch (exception) {
      error = exception.message;
    } catch (_) {
      error = 'Операция не выполнена';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

class SecurityException implements Exception {
  const SecurityException(this.message);

  final String message;
}
