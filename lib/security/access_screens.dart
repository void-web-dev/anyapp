import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../ui/ui.dart';
import 'security_controller.dart';
import 'security_store.dart';

class AccessSetupScreen extends StatefulWidget {
  const AccessSetupScreen({super.key, required this.controller});

  final AppSecurityController controller;

  @override
  State<AccessSetupScreen> createState() => _AccessSetupScreenState();
}

class _AccessSetupScreenState extends State<AccessSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmationController = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    FocusScope.of(context).unfocus();
    if (_pinController.text != _confirmationController.text) {
      setState(() => _localError = 'Коды не совпадают');
      return;
    }
    setState(() => _localError = null);
    await widget.controller.usePin(_pinController.text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SvgPicture.asset(
                    'assets/icon/anyapp-logo.svg',
                    width: 58,
                    height: 58,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Защитите any2app',
                    style: TextStyle(
                      color: context.colors.foreground,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'При первом запуске выберите способ входа. Позже его можно '
                    'изменить во вкладке «Настройки».',
                    style: TextStyle(
                      color: context.colors.mutedForeground,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppCardHeader(
                          title: Text('Короткий код'),
                          description: Text('От 4 до 6 цифр'),
                        ),
                        const SizedBox(height: 20),
                        _PinInput(
                          key: const Key('setup-pin'),
                          controller: _pinController,
                          label: 'Новый код',
                          action: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        _PinInput(
                          key: const Key('setup-pin-confirmation'),
                          controller: _confirmationController,
                          label: 'Повторите код',
                          action: TextInputAction.done,
                          onSubmitted: (_) => _savePin(),
                        ),
                        if (_localError != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _localError!,
                            style: TextStyle(
                              color: context.colors.destructive,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        AppButton(
                          key: const Key('setup-use-pin'),
                          expanded: true,
                          loading: controller.busy,
                          onPressed: controller.busy ? null : _savePin,
                          leading: const Icon(Icons.pin_outlined),
                          child: const Text('Использовать короткий код'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppButton(
                    key: const Key('setup-use-biometrics'),
                    expanded: true,
                    variant: AppButtonVariant.outline,
                    loading: controller.busy,
                    onPressed:
                        controller.busy || !controller.biometricsAvailable
                        ? null
                        : controller.useBiometricMode,
                    leading: const Icon(Icons.fingerprint),
                    child: Text(
                      controller.biometricsAvailable
                          ? 'Использовать биометрию'
                          : 'Биометрия недоступна',
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    key: const Key('setup-use-open'),
                    expanded: true,
                    variant: AppButtonVariant.ghost,
                    onPressed: controller.busy ? null : controller.useOpenMode,
                    leading: const Icon(Icons.lock_open_outlined),
                    child: const Text('Открытый режим'),
                  ),
                  if (controller.error != null) ...[
                    const SizedBox(height: 18),
                    AppAlert(
                      title: 'Не удалось сохранить настройку',
                      description: controller.error!,
                      icon: Icons.error_outline,
                      variant: AppAlertVariant.destructive,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccessUnlockScreen extends StatefulWidget {
  const AccessUnlockScreen({super.key, required this.controller});

  final AppSecurityController controller;

  @override
  State<AccessUnlockScreen> createState() => _AccessUnlockScreenState();
}

class _AccessUnlockScreenState extends State<AccessUnlockScreen> {
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _unlockPin() async {
    FocusScope.of(context).unfocus();
    await widget.controller.unlockWithPin(_pinController.text);
    if (widget.controller.state != SecurityFlowState.ready) {
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final usesBiometrics = controller.accessMode == AccessMode.biometric;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AppCard(
                child: Column(
                  children: [
                    SvgPicture.asset(
                      'assets/icon/anyapp-logo.svg',
                      width: 64,
                      height: 64,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Вход в any2app',
                      style: TextStyle(
                        color: context.colors.foreground,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      usesBiometrics
                          ? 'Подтвердите вход с помощью биометрии'
                          : 'Введите короткий код',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.colors.mutedForeground,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (usesBiometrics)
                      AppButton(
                        key: const Key('unlock-biometrics'),
                        expanded: true,
                        loading: controller.busy,
                        onPressed: controller.busy
                            ? null
                            : controller.authenticateWithBiometrics,
                        leading: const Icon(Icons.fingerprint),
                        child: const Text('Повторить проверку'),
                      )
                    else ...[
                      _PinInput(
                        key: const Key('unlock-pin'),
                        controller: _pinController,
                        label: 'Короткий код',
                        action: TextInputAction.done,
                        onSubmitted: (_) => _unlockPin(),
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        key: const Key('unlock-with-pin'),
                        expanded: true,
                        loading: controller.busy,
                        onPressed: controller.busy ? null : _unlockPin,
                        leading: const Icon(Icons.lock_open_outlined),
                        child: const Text('Войти'),
                      ),
                    ],
                    if (controller.error != null) ...[
                      const SizedBox(height: 16),
                      AppAlert(
                        title: 'Вход не выполнен',
                        description: controller.error!,
                        icon: Icons.error_outline,
                        variant: AppAlertVariant.destructive,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinInput extends StatelessWidget {
  const _PinInput({
    super.key,
    required this.controller,
    required this.label,
    required this.action,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final TextInputAction action;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return AppInput(
      controller: controller,
      label: label,
      hint: '••••',
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 6,
      textInputAction: action,
      onSubmitted: onSubmitted,
    );
  }
}
