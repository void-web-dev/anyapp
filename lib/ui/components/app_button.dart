import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, destructive, link }

enum AppButtonSize { small, medium, large, icon }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.child,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.leading,
    this.loading = false,
    this.expanded = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final Widget? leading;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground, border) = switch (variant) {
      AppButtonVariant.primary => (
        colors.primary,
        colors.primaryForeground,
        colors.primary,
      ),
      AppButtonVariant.secondary => (
        colors.secondary,
        colors.secondaryForeground,
        colors.secondary,
      ),
      AppButtonVariant.outline => (
        Colors.transparent,
        colors.foreground,
        colors.border,
      ),
      AppButtonVariant.ghost => (
        Colors.transparent,
        colors.foreground,
        Colors.transparent,
      ),
      AppButtonVariant.destructive => (
        colors.destructive,
        colors.destructiveForeground,
        colors.destructive,
      ),
      AppButtonVariant.link => (
        Colors.transparent,
        colors.foreground,
        Colors.transparent,
      ),
    };
    final (height, horizontal, iconOnly) = switch (size) {
      AppButtonSize.small => (36.0, 12.0, false),
      AppButtonSize.medium => (40.0, 16.0, false),
      AppButtonSize.large => (44.0, 24.0, false),
      AppButtonSize.icon => (40.0, 0.0, true),
    };
    final enabled = onPressed != null && !loading;

    final button = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          hoverColor: foreground.withValues(alpha: 0.08),
          child: SizedBox(
            height: height,
            width: iconOnly ? height : (expanded ? double.infinity : null),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              child: Row(
                mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  else if (leading != null)
                    IconTheme(
                      data: IconThemeData(color: foreground, size: 16),
                      child: leading!,
                    ),
                  if ((loading || leading != null) && !iconOnly)
                    const SizedBox(width: 8),
                  if (!iconOnly)
                    DefaultTextStyle(
                      style: TextStyle(
                        color: foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: variant == AppButtonVariant.link
                            ? TextDecoration.underline
                            : null,
                        decorationColor: foreground,
                      ),
                      child: child,
                    )
                  else if (!loading)
                    DefaultTextStyle(
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      child: IconTheme(
                        data: IconThemeData(color: foreground, size: 18),
                        child: child,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(button: true, enabled: enabled, child: button);
  }
}
