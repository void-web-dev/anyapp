import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppInputGroupAddonAlignment { start, end, top, bottom }

class AppInputGroup extends StatefulWidget {
  const AppInputGroup({
    super.key,
    this.controller,
    this.hint,
    this.addons = const [],
    this.minLines = 1,
    this.maxLines = 1,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? hint;
  final List<AppInputGroupAddon> addons;
  final int minLines;
  final int? maxLines;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppInputGroup> createState() => _AppInputGroupState();
}

class _AppInputGroupState extends State<AppInputGroup> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final top = widget.addons
        .where((item) => item.alignment == AppInputGroupAddonAlignment.top)
        .toList();
    final bottom = widget.addons
        .where((item) => item.alignment == AppInputGroupAddonAlignment.bottom)
        .toList();
    final start = widget.addons
        .where((item) => item.alignment == AppInputGroupAddonAlignment.start)
        .toList();
    final end = widget.addons
        .where((item) => item.alignment == AppInputGroupAddonAlignment.end)
        .toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: widget.enabled ? colors.background : colors.muted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _focusNode.hasFocus ? colors.ring : colors.input,
          width: _focusNode.hasFocus ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (top.isNotEmpty) _blockAddons(top),
          Row(
            crossAxisAlignment: widget.maxLines == 1
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              ...start.map(_inlineAddon),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  minLines: widget.obscureText ? 1 : widget.minLines,
                  maxLines: widget.obscureText ? 1 : widget.maxLines,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: TextStyle(color: colors.foreground, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              ...end.map(_inlineAddon),
            ],
          ),
          if (bottom.isNotEmpty) _blockAddons(bottom),
        ],
      ),
    );
  }

  Widget _inlineAddon(AppInputGroupAddon addon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: addon.child,
    );
  }

  Widget _blockAddons(List<AppInputGroupAddon> addons) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < addons.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: addons[i].child),
          ],
        ],
      ),
    );
  }
}

class AppInputGroupAddon {
  const AppInputGroupAddon({
    required this.child,
    this.alignment = AppInputGroupAddonAlignment.start,
  });

  final Widget child;
  final AppInputGroupAddonAlignment alignment;
}

class AppInputGroupText extends StatelessWidget {
  const AppInputGroupText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: context.colors.mutedForeground, fontSize: 13),
    );
  }
}

class AppInputGroupButton extends StatelessWidget {
  const AppInputGroupButton({super.key, required this.child, this.onPressed});

  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: IconTheme(
            data: IconThemeData(color: context.colors.foreground, size: 16),
            child: DefaultTextStyle(
              style: TextStyle(
                color: context.colors.foreground,
                fontSize: 12,
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
