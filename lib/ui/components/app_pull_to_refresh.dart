import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppPullToRefresh extends StatelessWidget {
  const AppPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.displacement = 40,
    this.edgeOffset = 0,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  });

  final RefreshCallback onRefresh;
  final Widget child;
  final double displacement;
  final double edgeOffset;
  final ScrollNotificationPredicate notificationPredicate;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      displacement: displacement,
      edgeOffset: edgeOffset,
      notificationPredicate: notificationPredicate,
      color: context.colors.primary,
      backgroundColor: context.colors.card,
      child: child,
    );
  }
}

class AppRefreshListView extends StatelessWidget {
  const AppRefreshListView({
    super.key,
    required this.onRefresh,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.padding,
    this.separatorBuilder,
  });

  final RefreshCallback onRefresh;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final IndexedWidgetBuilder? separatorBuilder;

  @override
  Widget build(BuildContext context) {
    return AppPullToRefresh(
      onRefresh: onRefresh,
      child: separatorBuilder == null
          ? ListView.builder(
              controller: controller,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              itemCount: itemCount,
              itemBuilder: itemBuilder,
            )
          : ListView.separated(
              controller: controller,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              itemCount: itemCount,
              itemBuilder: itemBuilder,
              separatorBuilder: separatorBuilder!,
            ),
    );
  }
}
