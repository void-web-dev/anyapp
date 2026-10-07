import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppToggle extends StatelessWidget {
  const AppToggle({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.child,
  });

  final bool selected;
  final ValueChanged<bool>? onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.colors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!selected),
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: IconTheme(
            data: IconThemeData(color: context.colors.foreground, size: 17),
            child: DefaultTextStyle(
              style: TextStyle(
                color: context.colors.foreground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class AppToggleGroup<T> extends StatelessWidget {
  const AppToggleGroup({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final Map<T, Widget> items;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in items.entries)
            AppToggle(
              selected: value == entry.key,
              onChanged: onChanged == null
                  ? null
                  : (_) => onChanged!(entry.key),
              child: entry.value,
            ),
        ],
      ),
    );
  }
}

class AppSlider extends StatelessWidget {
  const AppSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: context.colors.primary,
        inactiveTrackColor: context.colors.secondary,
        thumbColor: context.colors.background,
        overlayColor: context.colors.primary.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 8,
          elevation: 1,
        ),
      ),
      child: Slider(
        value: value,
        onChanged: onChanged,
        min: min,
        max: max,
        divisions: divisions,
      ),
    );
  }
}
