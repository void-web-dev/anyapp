import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppBadgeVariant { primary, secondary, outline, destructive }

class AppBadge extends StatelessWidget {
  const AppBadge(
    this.label, {
    super.key,
    this.variant = AppBadgeVariant.primary,
    this.icon,
  });

  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground, border) = switch (variant) {
      AppBadgeVariant.primary => (
        colors.primary,
        colors.primaryForeground,
        colors.primary,
      ),
      AppBadgeVariant.secondary => (
        colors.secondary,
        colors.secondaryForeground,
        colors.secondary,
      ),
      AppBadgeVariant.outline => (
        Colors.transparent,
        colors.foreground,
        colors.border,
      ),
      AppBadgeVariant.destructive => (
        colors.destructive,
        colors.destructiveForeground,
        colors.destructive,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
