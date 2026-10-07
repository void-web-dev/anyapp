import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../security/security_controller.dart';
import '../../security/settings_screen.dart';
import '../../ui/ui.dart';
import '../runtime/app_controller.dart';

class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({
    super.key,
    required this.controller,
    required this.securityController,
  });

  final AppController controller;
  final AppSecurityController securityController;

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  var _selectedTab = 0;
  late final TextEditingController _urlController = TextEditingController(
    text: widget.controller.configurationUrl,
  );

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _connect() {
    FocusScope.of(context).unfocus();
    widget.controller.connect(_urlController.text);
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.controller.configurationLoading;
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: [
          SafeArea(
            child: AppPullToRefresh(
              onRefresh: widget.controller.refreshMarketplace,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SvgPicture.asset(
                            'assets/icon/anyapp-logo.svg',
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          'Подключить приложение',
                          style: TextStyle(
                            color: context.colors.foreground,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Введите URL JSON-конфигурации. Она определяет экраны, '
                          'поля, переходы и API-действия приложения.',
                          style: TextStyle(
                            color: context.colors.mutedForeground,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 30),
                        AppField(
                          label: 'URL конфигурации',
                          required: true,
                          description:
                              'Используйте HTTPS. HTTP предназначен только для '
                              'локальной разработки.',
                          child: AppInputGroup(
                            key: const Key('configuration-url'),
                            controller: _urlController,
                            hint: 'https://example.com/app-config.json',
                            keyboardType: TextInputType.url,
                            enabled: !loading,
                            onSubmitted: (_) => _connect(),
                            addons: const [
                              AppInputGroupAddon(
                                child: Icon(Icons.link, size: 17),
                              ),
                            ],
                          ),
                        ),
                        if (widget.controller.error != null) ...[
                          const SizedBox(height: 18),
                          AppAlert(
                            title: 'Не удалось загрузить конфигурацию',
                            description: widget.controller.error!,
                            icon: Icons.error_outline,
                            variant: AppAlertVariant.destructive,
                          ),
                        ],
                        const SizedBox(height: 24),
                        AppButton(
                          key: const Key('connect-configuration'),
                          expanded: true,
                          loading: loading,
                          leading: const Icon(Icons.arrow_forward),
                          onPressed: loading ? null : _connect,
                          child: const Text('Продолжить'),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          key: const Key('open-marketplace'),
                          expanded: true,
                          variant: AppButtonVariant.outline,
                          leading: const Icon(Icons.apps_outlined),
                          onPressed: loading
                              ? null
                              : widget.controller.openMarketplace,
                          child: const Text('Маркетплейс any2app'),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          key: const Key('open-builder'),
                          expanded: true,
                          variant: AppButtonVariant.outline,
                          leading: const Icon(
                            Icons.dashboard_customize_outlined,
                          ),
                          onPressed: loading
                              ? null
                              : widget.controller.openBuilder,
                          child: const Text('Конструктор экранов'),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          key: const Key('open-qr-scanner'),
                          expanded: true,
                          variant: AppButtonVariant.outline,
                          leading: const Icon(Icons.qr_code_scanner),
                          onPressed: loading
                              ? null
                              : widget.controller.openQrScanner,
                          child: const Text('Получить приложение из QR'),
                        ),
                        const SizedBox(height: 30),
                        const AppSeparator(),
                        const SizedBox(height: 20),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Попробуйте Dummy Shop',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Пример приложения: каталог, поиск и тестовый вход. Откройте здесь или отсканируйте QR с другого устройства.',
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: Image.asset(
                                  'assets/testing/dummy-app-qr.png',
                                  width: 180,
                                  height: 180,
                                  semanticLabel:
                                      'QR: https://static.w3bsrv.app/dummy-app.json',
                                  filterQuality: FilterQuality.none,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const SelectableText(
                                'https://static.w3bsrv.app/dummy-app.json',
                              ),
                              const SizedBox(height: 16),
                              AppButton(
                                key: const Key('open-remote-example'),
                                expanded: true,
                                onPressed: loading
                                    ? null
                                    : () => widget.controller.connect(
                                        'https://static.w3bsrv.app/dummy-app.json',
                                      ),
                                child: const Text('Открыть пример'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SettingsScreen(controller: widget.securityController),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          setState(() => _selectedTab = index);
        },
        destinations: const [
          NavigationDestination(
            key: Key('home-tab'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Главная',
          ),
          NavigationDestination(
            key: Key('settings-tab'),
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}
