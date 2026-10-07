import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_button.dart';

class AppPagination extends StatelessWidget {
  const AppPagination({
    super.key,
    required this.page,
    required this.totalPages,
    required this.onChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeTotal = math.max(totalPages, 1);
    final safePage = page.clamp(1, safeTotal);
    final start = math.max(1, math.min(safePage - 1, safeTotal - 2));
    final end = math.min(safeTotal, start + 2);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          size: AppButtonSize.icon,
          variant: AppButtonVariant.outline,
          onPressed: safePage > 1 ? () => onChanged(safePage - 1) : null,
          child: const Icon(Icons.chevron_left),
        ),
        const SizedBox(width: 6),
        for (var current = start; current <= end; current++) ...[
          AppButton(
            size: AppButtonSize.icon,
            variant: current == safePage
                ? AppButtonVariant.primary
                : AppButtonVariant.ghost,
            onPressed: () => onChanged(current),
            child: Text('$current'),
          ),
          if (current < end) const SizedBox(width: 2),
        ],
        const SizedBox(width: 6),
        AppButton(
          size: AppButtonSize.icon,
          variant: AppButtonVariant.outline,
          onPressed: safePage < safeTotal
              ? () => onChanged(safePage + 1)
              : null,
          child: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class AppButtonGroup extends StatelessWidget {
  const AppButtonGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
