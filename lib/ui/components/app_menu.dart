import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppMenuItem<T> {
  const AppMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.shortcut,
    this.enabled = true,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? shortcut;
  final bool enabled;
  final bool destructive;
}

class AppDropdownMenu<T> extends StatelessWidget {
  const AppDropdownMenu({
    super.key,
    required this.items,
    required this.onSelected,
    required this.child,
    this.tooltip,
  });

  final List<AppMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final Widget child;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip ?? '',
      color: context.colors.card,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: context.colors.border),
      ),
      onSelected: onSelected,
      itemBuilder: (menuContext) => [
        for (final item in items)
          PopupMenuItem<T>(
            value: item.value,
            enabled: item.enabled,
            height: 40,
            child: Row(
              children: [
                if (item.icon != null) ...[
                  Icon(
                    item.icon,
                    size: 16,
                    color: item.destructive
                        ? menuContext.colors.destructive
                        : menuContext.colors.foreground,
                  ),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: item.destructive
                          ? menuContext.colors.destructive
                          : menuContext.colors.foreground,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (item.shortcut != null)
                  Text(
                    item.shortcut!,
                    style: TextStyle(
                      color: menuContext.colors.mutedForeground,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
      ],
      child: child,
    );
  }
}
