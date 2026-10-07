import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/ui.dart';
import 'security_controller.dart';
import 'security_store.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppSecurityController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        key: const Key('settings-screen'),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Настройки',
                    style: TextStyle(
                      color: context.colors.foreground,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Оформление и локальная защита any2app.',
                    style: TextStyle(
                      color: context.colors.mutedForeground,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppCard(
                    child: AppSwitch(
                      key: const Key('light-theme-setting'),
                      value:
                          controller.themePreference == ThemePreference.light,
                      onChanged: controller.busy
                          ? null
                          : (enabled) => controller.setThemePreference(
                              enabled
                                  ? ThemePreference.light
                                  : ThemePreference.system,
                            ),
                      label: 'Светлая тема',
                      description: 'Если выключено, используется тема системы.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        AppItem(
                          title: 'Короткий код',
                          description: controller.accessMode == AccessMode.pin
                              ? 'Используется для входа. Нажмите, чтобы изменить.'
                              : 'Установить код из 4–6 цифр.',
                          leading: const Icon(Icons.pin_outlined),
                          trailing: controller.accessMode == AccessMode.pin
                              ? const Icon(Icons.check_circle)
                              : const Icon(Icons.chevron_right),
                          onTap: controller.busy
                              ? null
                              : () => _showPinDialog(context),
                        ),
                        const AppSeparator(),
                        AppItem(
                          title: 'Биометрия',
                          description: controller.biometricsAvailable
                              ? 'Face ID, Touch ID или отпечаток пальца.'
                              : 'Недоступна или не настроена на устройстве.',
                          leading: const Icon(Icons.fingerprint),
                          trailing:
                              controller.accessMode == AccessMode.biometric
                              ? const Icon(Icons.check_circle)
                              : const Icon(Icons.chevron_right),
                          onTap:
                              controller.busy || !controller.biometricsAvailable
                              ? null
                              : controller.useBiometricMode,
                        ),
                        const AppSeparator(),
                        AppItem(
                          title: 'Открытый режим',
                          description: 'Вход без кода и биометрии.',
                          leading: const Icon(Icons.lock_open_outlined),
                          trailing: controller.accessMode == AccessMode.open
                              ? const Icon(Icons.check_circle)
                              : const Icon(Icons.chevron_right),
                          onTap: controller.busy
                              ? null
                              : () => _confirmOpenMode(context),
                        ),
                      ],
                    ),
                  ),
                  if (controller.error != null) ...[
                    const SizedBox(height: 16),
                    AppAlert(
                      title: 'Настройка не изменена',
                      description: controller.error!,
                      icon: Icons.error_outline,
                      variant: AppAlertVariant.destructive,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmOpenMode(BuildContext context) async {
    if (controller.accessMode == AccessMode.open) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Включить открытый режим?'),
        content: const Text(
          'any2app больше не будет запрашивать короткий код или биометрию.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const Key('confirm-open-mode'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Включить'),
          ),
        ],
      ),
    );
    if (accepted == true) await controller.useOpenMode();
  }

  Future<void> _showPinDialog(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _PinDialog(controller: controller),
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Короткий код изменён')));
    }
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.controller});

  final AppSecurityController controller;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _currentController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmationController = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _currentController.dispose();
    _pinController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_pinController.text != _confirmationController.text) {
      setState(() => _localError = 'Новые коды не совпадают');
      return;
    }
    final validationError = widget.controller.validatePin(_pinController.text);
    if (validationError != null) {
      setState(() => _localError = validationError);
      return;
    }
    await widget.controller.usePin(
      _pinController.text,
      currentPin: widget.controller.accessMode == AccessMode.pin
          ? _currentController.text
          : null,
    );
    if (!mounted) return;
    if (widget.controller.error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() => _localError = widget.controller.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.controller.accessMode == AccessMode.pin
            ? 'Изменить короткий код'
            : 'Установить короткий код',
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.controller.accessMode == AccessMode.pin) ...[
              _DialogPinField(
                key: const Key('current-pin'),
                controller: _currentController,
                label: 'Текущий код',
              ),
              const SizedBox(height: 12),
            ],
            _DialogPinField(
              key: const Key('new-pin'),
              controller: _pinController,
              label: 'Новый код',
            ),
            const SizedBox(height: 12),
            _DialogPinField(
              key: const Key('confirm-new-pin'),
              controller: _confirmationController,
              label: 'Повторите новый код',
            ),
            if (_localError != null) ...[
              const SizedBox(height: 12),
              Text(
                _localError!,
                style: TextStyle(
                  color: context.colors.destructive,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const Key('save-pin-setting'),
          onPressed: widget.controller.busy ? null : _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _DialogPinField extends StatelessWidget {
  const _DialogPinField({
    super.key,
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 6,
      decoration: InputDecoration(labelText: label, counterText: ''),
    );
  }
}
