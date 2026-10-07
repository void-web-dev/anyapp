import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppToastVariant { standard, success, destructive }

void showAppToast(
  BuildContext context, {
  required String title,
  String? description,
  AppToastVariant variant = AppToastVariant.standard,
}) {
  final colors = context.colors;
  final icon = switch (variant) {
    AppToastVariant.standard => Icons.info_outline,
    AppToastVariant.success => Icons.check_circle_outline,
    AppToastVariant.destructive => Icons.error_outline,
  };
  final accent = switch (variant) {
    AppToastVariant.destructive => colors.destructive,
    _ => colors.foreground,
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.card,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colors.border),
        ),
        content: Row(
          children: [
            Icon(icon, color: accent, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (description != null)
                    Text(
                      description,
                      style: TextStyle(
                        color: colors.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
}
