import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.child,
    this.label,
    this.description,
    this.error,
    this.required = false,
  });

  final Widget child;
  final String? label;
  final String? description;
  final String? error;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            children: [
              Text(
                label!,
                style: TextStyle(
                  color: context.colors.foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (required)
                Text(' *', style: TextStyle(color: context.colors.destructive)),
            ],
          ),
          const SizedBox(height: 7),
        ],
        child,
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: TextStyle(color: context.colors.destructive, fontSize: 12),
          ),
        ] else if (description != null) ...[
          const SizedBox(height: 6),
          Text(
            description!,
            style: TextStyle(
              color: context.colors.mutedForeground,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class AppTextarea extends StatelessWidget {
  const AppTextarea({
    super.key,
    this.controller,
    this.hint,
    this.minLines = 3,
    this.maxLines = 6,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController? controller;
  final String? hint;
  final int minLines;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      enabled: enabled,
      onChanged: onChanged,
      style: TextStyle(color: context.colors.foreground, fontSize: 14),
      decoration: InputDecoration(hintText: hint),
    );
  }
}
