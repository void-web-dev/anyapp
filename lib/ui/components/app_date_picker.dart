import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppDatePicker extends StatelessWidget {
  const AppDatePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.placeholder = 'Выберите дату',
    this.helpText,
    this.enabled = true,
    this.clearable = true,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String placeholder;
  final String? helpText;
  final bool enabled;
  final bool clearable;

  Future<void> _open(BuildContext context) async {
    final now = DateUtils.dateOnly(DateTime.now());
    final first = DateUtils.dateOnly(firstDate ?? DateTime(now.year - 100));
    final last = DateUtils.dateOnly(lastDate ?? DateTime(now.year + 100));
    final initial = _clampDate(value ?? now, first, last);

    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: helpText,
      builder: (dialogContext, child) =>
          Theme(data: _pickerTheme(dialogContext), child: child!),
    );
    if (selected != null) onChanged(DateUtils.dateOnly(selected));
  }

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? placeholder
        : MaterialLocalizations.of(context).formatCompactDate(value!);
    return _DatePickerTrigger(
      text: text,
      hasValue: value != null,
      enabled: enabled,
      clearable: clearable && value != null,
      onTap: () => _open(context),
      onClear: () => onChanged(null),
    );
  }
}

class AppDateRangePicker extends StatelessWidget {
  const AppDateRangePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.placeholder = 'Выберите диапазон',
    this.helpText,
    this.saveText,
    this.enabled = true,
    this.clearable = true,
  });

  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String placeholder;
  final String? helpText;
  final String? saveText;
  final bool enabled;
  final bool clearable;

  Future<void> _open(BuildContext context) async {
    final now = DateUtils.dateOnly(DateTime.now());
    final first = DateUtils.dateOnly(firstDate ?? DateTime(now.year - 10));
    final last = DateUtils.dateOnly(lastDate ?? DateTime(now.year + 10));
    final initial = _clampRange(value, first, last);

    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: first,
      lastDate: last,
      helpText: helpText,
      saveText: saveText,
      builder: (dialogContext, child) =>
          Theme(data: _pickerTheme(dialogContext), child: child!),
    );
    if (selected != null) {
      onChanged(
        DateTimeRange(
          start: DateUtils.dateOnly(selected.start),
          end: DateUtils.dateOnly(selected.end),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final text = value == null
        ? placeholder
        : '${localizations.formatCompactDate(value!.start)}'
              ' – ${localizations.formatCompactDate(value!.end)}';
    return _DatePickerTrigger(
      text: text,
      hasValue: value != null,
      enabled: enabled,
      clearable: clearable && value != null,
      range: true,
      onTap: () => _open(context),
      onClear: () => onChanged(null),
    );
  }
}

class _DatePickerTrigger extends StatelessWidget {
  const _DatePickerTrigger({
    required this.text,
    required this.hasValue,
    required this.enabled,
    required this.clearable,
    required this.onTap,
    required this.onClear,
    this.range = false,
  });

  final String text;
  final bool hasValue;
  final bool enabled;
  final bool clearable;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool range;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      enabled: enabled,
      label: text,
      child: Material(
        color: enabled ? colors.background : colors.muted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.input),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 42,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    range
                        ? Icons.date_range_outlined
                        : Icons.calendar_today_outlined,
                    size: 17,
                    color: colors.mutedForeground,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasValue
                            ? colors.foreground
                            : colors.mutedForeground,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (clearable)
                    IconButton(
                      tooltip: 'Очистить',
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      color: colors.mutedForeground,
                      onPressed: onClear,
                      icon: const Icon(Icons.close),
                    )
                  else
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: colors.mutedForeground,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

DateTime _clampDate(DateTime value, DateTime first, DateTime last) {
  final date = DateUtils.dateOnly(value);
  if (date.isBefore(first)) return first;
  if (date.isAfter(last)) return last;
  return date;
}

DateTimeRange? _clampRange(
  DateTimeRange? value,
  DateTime first,
  DateTime last,
) {
  if (value == null) return null;
  final start = _clampDate(value.start, first, last);
  final end = _clampDate(value.end, first, last);
  return DateTimeRange(start: start, end: end.isBefore(start) ? start : end);
}

ThemeData _pickerTheme(BuildContext context) {
  final colors = context.colors;
  return Theme.of(context).copyWith(
    datePickerTheme: DatePickerThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: colors.primary,
      headerForegroundColor: colors.primaryForeground,
      dividerColor: colors.border,
      dayForegroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.mutedForeground.withValues(alpha: 0.45)
            : colors.foreground,
      ),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? colors.primary : null,
      ),
      todayForegroundColor: WidgetStatePropertyAll(colors.foreground),
      todayBorder: BorderSide(color: colors.ring),
      rangePickerBackgroundColor: colors.card,
      rangePickerSurfaceTintColor: Colors.transparent,
      rangePickerHeaderBackgroundColor: colors.card,
      rangePickerHeaderForegroundColor: colors.foreground,
      rangeSelectionBackgroundColor: colors.accent,
    ),
  );
}
