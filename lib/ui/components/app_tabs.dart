import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppTabItem {
  const AppTabItem({required this.label, required this.child, this.icon});

  final String label;
  final Widget child;
  final IconData? icon;
}

class AppTabs extends StatefulWidget {
  const AppTabs({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.onChanged,
  });

  final List<AppTabItem> items;
  final int initialIndex;
  final ValueChanged<int>? onChanged;

  @override
  State<AppTabs> createState() => _AppTabsState();
}

class _AppTabsState extends State<AppTabs> {
  late int _selected = widget.initialIndex.clamp(0, widget.items.length - 1);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.colors.muted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              for (var index = 0; index < widget.items.length; index++)
                Expanded(
                  child: _TabTrigger(
                    item: widget.items[index],
                    selected: _selected == index,
                    onTap: () {
                      setState(() => _selected = index);
                      widget.onChanged?.call(index);
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey(_selected),
            child: widget.items[_selected].child,
          ),
        ),
      ],
    );
  }
}

class _TabTrigger extends StatelessWidget {
  const _TabTrigger({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.colors.background : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 15, color: context.colors.foreground),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? context.colors.foreground
                        : context.colors.mutedForeground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
