import 'package:flutter/material.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

/// 单行 / 多行文本输入（上传表单、举报说明共用）。
class UgcTextField extends StatelessWidget {
  const UgcTextField({
    super.key,
    required this.label,
    required this.controller,
    this.errorText,
    this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;
  final String? hint;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = UpTheme.of(context).colors;
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: 1,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: UpTheme.of(context).text[UpTextRole.body],
      cursorColor: c.inputCursor,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        counterText: '',
      ),
    );
  }
}

/// 选择面板里的一行（左文字、右勾）。
class UgcChoiceRow extends StatelessWidget {
  const UgcChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = UpTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: UpPageTokens.paddingX),
      child: UpListItem(
        title: label,
        subtitle: subtitle,
        trailing: selected
            ? Icon(Icons.check_rounded, color: c.accentPrimary)
            : null,
        onTap: onTap,
      ),
    );
  }
}
