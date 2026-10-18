import 'package:flutter/material.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';

/// 单行输入框（搜索框样式）。[icon] / [keyboardType] / [textInputAction]
/// 可改为其它用途（例如 Hub 手动输入地址）。
class UpSearchField extends StatelessWidget {
  const UpSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.icon = Icons.search_rounded,
    this.keyboardType,
    this.textInputAction = TextInputAction.search,
  });

  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final style = context
        .textRole(UpTextRole.body)
        .copyWith(color: c.inputForeground);
    return Container(
      height: UpSearchFieldTokens.height,
      padding: const EdgeInsets.symmetric(
        horizontal: UpSearchFieldTokens.paddingX,
      ),
      decoration: BoxDecoration(
        color: c.inputBackground,
        borderRadius: BorderRadius.circular(UpSearchFieldTokens.radius),
      ),
      child: Row(
        children: [
          Icon(icon, size: UpSizes.iconSm, color: c.inputPlaceholder),
          const SizedBox(width: UpSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              cursorColor: c.inputCursor,
              style: style,
              textInputAction: textInputAction,
              keyboardType: keyboardType,
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: style.copyWith(color: c.inputPlaceholder),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
