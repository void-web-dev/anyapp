import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_button.dart';

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.description,
    this.actions = const [],
  });

  final String title;
  final String? description;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: context.colors.foreground,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AppButton(
                    size: AppButtonSize.icon,
                    variant: AppButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close),
                  ),
                ],
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description!,
                  style: TextStyle(
                    color: context.colors.mutedForeground,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              content,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var index = 0; index < actions.length; index++) ...[
                      if (index > 0) const SizedBox(width: 8),
                      actions[index],
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  String? description,
  required Widget content,
  List<Widget> actions = const [],
}) {
  return showDialog<T>(
    context: context,
    builder: (_) => AppDialog(
      title: title,
      description: description,
      content: content,
      actions: actions,
    ),
  );
}

Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  String? description,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      padding: EdgeInsets.fromLTRB(
        24,
        10,
        24,
        24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      decoration: BoxDecoration(
        color: sheetContext.colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: sheetContext.colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetContext.colors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                color: sheetContext.colors.foreground,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: sheetContext.colors.mutedForeground,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    ),
  );
}

class AppTooltip extends StatelessWidget {
  const AppTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      decoration: BoxDecoration(
        color: context.colors.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: TextStyle(
        color: context.colors.primaryForeground,
        fontSize: 12,
      ),
      child: child,
    );
  }
}
