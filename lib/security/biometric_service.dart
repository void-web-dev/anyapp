import 'package:local_auth/local_auth.dart';

abstract interface class BiometricService {
  Future<bool> isAvailable();
  Future<bool> authenticate();
}

class DeviceBiometricService implements BiometricService {
  DeviceBiometricService({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> isAvailable() async {
    final supported = await _authentication.isDeviceSupported();
    if (!supported || !await _authentication.canCheckBiometrics) return false;
    return (await _authentication.getAvailableBiometrics()).isNotEmpty;
  }

  @override
  Future<bool> authenticate() {
    return _authentication.authenticate(
      localizedReason: 'Подтвердите вход в any2app',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }
}

class MemoryBiometricService implements BiometricService {
  MemoryBiometricService({this.available = true, this.result = true});

  bool available;
  bool result;
  int authenticationCount = 0;

  @override
  Future<bool> authenticate() async {
    authenticationCount += 1;
    return result;
  }

  @override
  Future<bool> isAvailable() async => available;
}
