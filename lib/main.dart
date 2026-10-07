import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'security/access_screens.dart';
import 'security/biometric_service.dart';
import 'security/security_controller.dart';
import 'security/security_store.dart';
import 'server_driven/runtime/app_controller.dart';
import 'server_driven/services/action_engine.dart';
import 'server_driven/services/config_repository.dart';
import 'server_driven/services/session_store.dart';
import 'server_driven/ui/configuration_screen.dart';
import 'server_driven/ui/marketplace_screen.dart';
import 'server_driven/ui/qr_scanner_screen.dart';
import 'server_driven/ui/screen_builder_screen.dart';
import 'server_driven/ui/server_driven_screen.dart';
import 'server_driven/ui/splash_screen.dart';
import 'ui/ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Any2App());
}

class Any2App extends StatefulWidget {
  const Any2App({super.key, this.controller, this.securityController});

  final AppController? controller;
  final AppSecurityController? securityController;

  @override
  State<Any2App> createState() => _Any2AppState();
}

class _Any2AppState extends State<Any2App> {
  late final bool _ownsController = widget.controller == null;
  late final bool _ownsSecurityController = widget.securityController == null;
  late final AppController _controller =
      widget.controller ?? _createController();
  late final AppSecurityController _securityController =
      widget.securityController ??
      (widget.controller == null
          ? AppSecurityController(
              DeviceSecurityStore(),
              DeviceBiometricService(),
            )
          : AppSecurityController.openForTesting());
  StreamSubscription<Uri>? _linkSubscription;

  AppController _createController() {
    final sessionStore = DeviceSessionStore();
    return AppController(
      HttpConfigRepository(),
      sessionStore,
      ActionEngine(sessionStore),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller.initialize();
    _securityController.initialize();
    if (_ownsController) _listenForLinks();
  }

  Future<void> _listenForLinks() async {
    try {
      final appLinks = AppLinks();
      final initial = await appLinks.getInitialLink();
      if (initial != null) await _controller.handleIncomingUri(initial);
      _linkSubscription = appLinks.uriLinkStream.listen(
        _controller.handleIncomingUri,
        onError: (Object error) => debugPrint('Deep link error: $error'),
      );
    } catch (error) {
      debugPrint('Deep link initialization error: $error');
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    if (_ownsController) _controller.dispose();
    if (_ownsSecurityController) _securityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _securityController]),
      builder: (context, _) {
        return MaterialApp(
          title: 'any2app',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _securityController.themeMode,
          home: switch (_securityController.state) {
            SecurityFlowState.loading => const AppSplashScreen(),
            SecurityFlowState.setup => AccessSetupScreen(
              controller: _securityController,
            ),
            SecurityFlowState.locked => AccessUnlockScreen(
              controller: _securityController,
            ),
            SecurityFlowState.ready => switch (_controller.state) {
              AppFlowState.splash => const AppSplashScreen(),
              AppFlowState.configuration => ConfigurationScreen(
                controller: _controller,
                securityController: _securityController,
              ),
              AppFlowState.marketplace => MarketplaceScreen(
                controller: _controller,
              ),
              AppFlowState.builder => ScreenBuilderScreen(
                controller: _controller,
              ),
              AppFlowState.qrScanner => QrScannerScreen(
                controller: _controller,
              ),
              AppFlowState.ready when _controller.currentScreen != null =>
                ServerDrivenScreen(
                  key: ValueKey(_controller.currentScreenId),
                  controller: _controller,
                ),
              AppFlowState.ready => const Scaffold(
                body: Center(child: Text('Экран не найден')),
              ),
            },
          },
        );
      },
    );
  }
}
