import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSelectItem<T> {
  const AppSelectItem({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool enabled;
}

class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.placeholder = 'Выберите значение',
    this.enabled = true,
  });

  final T? value;
  final List<AppSelectItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String placeholder;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: enabled ? context.colors.background : context.colors.muted,
        border: Border.all(color: context.colors.input),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(
            placeholder,
            style: TextStyle(
              color: context.colors.mutedForeground,
              fontSize: 14,
            ),
          ),
          icon: Icon(
            Icons.unfold_more,
            size: 17,
            color: context.colors.mutedForeground,
          ),
          dropdownColor: context.colors.card,
          borderRadius: BorderRadius.circular(8),
          onChanged: enabled ? onChanged : null,
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item.value,
                enabled: item.enabled,
                child: Row(
                  children: [
                    if (item.icon != null) ...[
                      Icon(
                        item.icon,
                        size: 16,
                        color: context.colors.foreground,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      item.label,
                      style: TextStyle(
                        color: context.colors.foreground,
                        fontSize: 14,
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
}
