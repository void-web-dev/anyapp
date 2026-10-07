import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: value ? colors.primary : Colors.transparent,
                border: Border.all(
                  color: value ? colors.primary : colors.input,
                  width: value ? 0 : 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: value
                  ? Icon(Icons.check, size: 14, color: colors.primaryForeground)
                  : null,
            ),
            if (label != null) ...[
              const SizedBox(width: 9),
              Text(
                label!,
                style: TextStyle(color: colors.foreground, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
