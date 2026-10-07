import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../ui/ui.dart';

class AppSplashScreen extends StatelessWidget {
  const AppSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SvgPicture.asset(
                'assets/icon/anyapp-logo.svg',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'any2app',
              style: TextStyle(
                color: context.colors.foreground,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Загрузка конфигурации',
              style: TextStyle(
                color: context.colors.mutedForeground,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),
            const AppSpinner(size: 22),
          ],
        ),
      ),
    );
  }
}
