import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSeparator extends StatelessWidget {
  const AppSeparator({super.key, this.vertical = false});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: vertical ? 1 : double.infinity,
      height: vertical ? double.infinity : 1,
      color: context.colors.border,
    );
  }
}
