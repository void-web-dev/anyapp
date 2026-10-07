import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppAccordionItem {
  const AppAccordionItem({
    required this.title,
    required this.content,
    this.leading,
  });

  final Widget title;
  final Widget content;
  final Widget? leading;
}

class AppAccordion extends StatefulWidget {
  const AppAccordion({
    super.key,
    required this.items,
    this.initiallyOpen = const {0},
    this.multiple = false,
  });

  final List<AppAccordionItem> items;
  final Set<int> initiallyOpen;
  final bool multiple;

  @override
  State<AppAccordion> createState() => _AppAccordionState();
}

class _AppAccordionState extends State<AppAccordion> {
  late final Set<int> _open = {...widget.initiallyOpen};

  void _toggle(int index) {
    setState(() {
      if (_open.contains(index)) {
        _open.remove(index);
      } else {
        if (!widget.multiple) _open.clear();
        _open.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < widget.items.length; index++)
          _buildItem(context, widget.items[index], index),
      ],
    );
  }

  Widget _buildItem(BuildContext context, AppAccordionItem item, int index) {
    final expanded = _open.contains(index);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggle(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  if (item.leading != null) ...[
                    item.leading!,
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: DefaultTextStyle(
                      style: TextStyle(
                        color: context.colors.foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      child: item.title,
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: context.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: context.colors.mutedForeground,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  child: item.content,
                ),
              ),
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}
