import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppAlertVariant { standard, destructive }

class AppAlert extends StatelessWidget {
  const AppAlert({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.info_outline,
    this.variant = AppAlertVariant.standard,
  });

  final String title;
  final String description;
  final IconData icon;
  final AppAlertVariant variant;

  @override
  Widget build(BuildContext context) {
    final foreground = variant == AppAlertVariant.destructive
        ? context.colors.destructive
        : context.colors.foreground;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: variant == AppAlertVariant.destructive
              ? context.colors.destructive.withValues(alpha: 0.5)
              : context.colors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: variant == AppAlertVariant.destructive
                        ? foreground
                        : context.colors.mutedForeground,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
