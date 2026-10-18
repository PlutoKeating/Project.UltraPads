import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';

/// 配对码显示（桌面 Hub）：6 个大号数字格。
class PairingCodeDisplay extends StatelessWidget {
  const PairingCodeDisplay({super.key, required this.code, this.semanticLabel});
  final String code;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    return Semantics(
      label: semanticLabel,
      value: code,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: UpSpacing.sm,
        children: [
          for (final ch in code.split(''))
            Container(
              width: UpSizes.controlLg,
              height: UpSizes.controlXl,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surfaceRaised,
                borderRadius: BorderRadius.circular(UpRadii.lg),
                border: Border.all(
                  color: c.hubPairing,
                  width: UpBorderWidths.regular,
                ),
              ),
              child: UpText(ch, role: UpTextRole.display, color: c.textPrimary),
            ),
        ],
      ),
    );
  }
}

/// 配对码输入（手机）：6 个格子，输满回调 [onCompleted]。
class PairingCodeInput extends StatefulWidget {
  const PairingCodeInput({
    super.key,
    required this.onCompleted,
    this.length = 6,
    this.onChanged,
    this.semanticLabel,
    this.autofocus = true,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final String? semanticLabel;
  final bool autofocus;

  @override
  State<PairingCodeInput> createState() => _PairingCodeInputState();
}

class _PairingCodeInputState extends State<PairingCodeInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final text = _controller.text;
    return GestureDetector(
      onTap: _focus.requestFocus,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: UpSpacing.sm,
            children: [
              for (var i = 0; i < widget.length; i++)
                AnimatedContainer(
                  duration: UpMotion.duration(context, UpDurations.xfast),
                  width: UpSizes.controlLg,
                  height: UpSizes.controlXl,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.inputBackground,
                    borderRadius: BorderRadius.circular(UpRadii.lg),
                    border: Border.all(
                      color: i == text.length && _focus.hasFocus
                          ? c.focusRing
                          : c.borderDefault,
                      width: c.focusRingWidth,
                    ),
                  ),
                  child: UpText(
                    i < text.length ? text[i] : '',
                    role: UpTextRole.display,
                    color: c.inputForeground,
                  ),
                ),
            ],
          ),
          Positioned.fill(
            child: Opacity(
              opacity: UpOpacities.none,
              child: Semantics(
                label: widget.semanticLabel,
                textField: true,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  maxLength: widget.length,
                  showCursor: false,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    setState(() {});
                    widget.onChanged?.call(v);
                    if (v.length == widget.length) widget.onCompleted(v);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
