import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppInputOtp extends StatefulWidget {
  const AppInputOtp({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
  });

  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  @override
  State<AppInputOtp> createState() => _AppInputOtpState();
}

class _AppInputOtpState extends State<AppInputOtp> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _changed(String value) {
    final normalized = value.replaceAll(RegExp(r'\D'), '');
    if (normalized != value) {
      _controller.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
    widget.onChanged?.call(normalized);
    if (normalized.length == widget.length) {
      widget.onCompleted?.call(normalized);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text;
    return GestureDetector(
      onTap: _focusNode.requestFocus,
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: SizedBox(
              width: 1,
              height: 1,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                maxLength: widget.length,
                onChanged: _changed,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < widget.length; index++) ...[
                Container(
                  width: 40,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.background,
                    border: Border.all(
                      color: index == value.length && _focusNode.hasFocus
                          ? context.colors.ring
                          : context.colors.input,
                      width: index == value.length && _focusNode.hasFocus
                          ? 2
                          : 1,
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    index < value.length ? value[index] : '',
                    style: TextStyle(
                      color: context.colors.foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (index < widget.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
