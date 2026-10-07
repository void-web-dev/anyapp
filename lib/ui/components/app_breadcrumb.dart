import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppBreadcrumbItem {
  const AppBreadcrumbItem(this.label, {this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
}

class AppBreadcrumb extends StatelessWidget {
  const AppBreadcrumb({super.key, required this.items});

  final List<AppBreadcrumbItem> items;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: context.colors.mutedForeground,
                ),
              ),
            InkWell(
              onTap: items[index].onTap,
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  if (items[index].icon != null) ...[
                    Icon(
                      items[index].icon,
                      size: 15,
                      color: context.colors.mutedForeground,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    items[index].label,
                    style: TextStyle(
                      color: index == items.length - 1
                          ? context.colors.foreground
                          : context.colors.mutedForeground,
                      fontSize: 13,
                      fontWeight: index == items.length - 1
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
