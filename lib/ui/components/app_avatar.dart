import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, this.image, this.fallback = '?', this.size = 40});

  final ImageProvider? image;
  final String fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: context.colors.muted,
      backgroundImage: image,
      child: image == null
          ? Text(
              fallback,
              style: TextStyle(
                color: context.colors.mutedForeground,
                fontWeight: FontWeight.w600,
                fontSize: size * 0.35,
              ),
            )
          : null,
    );
  }
}
