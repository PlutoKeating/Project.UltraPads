import 'package:flutter/material.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';

class UpSearchField extends StatelessWidget {
  const UpSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

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
          Icon(
            Icons.search_rounded,
            size: UpSizes.iconSm,
            color: c.inputPlaceholder,
          ),
          const SizedBox(width: UpSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              cursorColor: c.inputCursor,
              style: style,
              textInputAction: TextInputAction.search,
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
