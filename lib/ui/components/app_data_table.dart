import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppTableColumn<T> {
  const AppTableColumn({
    required this.label,
    required this.cellBuilder,
    this.numeric = false,
  });

  final String label;
  final Widget Function(T row) cellBuilder;
  final bool numeric;
}

class AppDataTable<T> extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
  });

  final List<AppTableColumn<T>> columns;
  final List<T> rows;
  final ValueChanged<T>? onRowTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: colors.border,
          dataTableTheme: DataTableThemeData(
            headingTextStyle: TextStyle(
              color: colors.mutedForeground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            dataTextStyle: TextStyle(color: colors.foreground, fontSize: 13),
            headingRowColor: WidgetStatePropertyAll(colors.muted),
            dataRowColor: WidgetStatePropertyAll(colors.card),
            decoration: BoxDecoration(
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        child: DataTable(
          headingRowHeight: 42,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 52,
          columnSpacing: 32,
          columns: [
            for (final column in columns)
              DataColumn(numeric: column.numeric, label: Text(column.label)),
          ],
          rows: [
            for (final row in rows)
              DataRow(
                onSelectChanged: onRowTap == null
                    ? null
                    : (_) => onRowTap!(row),
                cells: [
                  for (final column in columns)
                    DataCell(column.cellBuilder(row)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
