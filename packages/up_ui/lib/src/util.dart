import 'package:flutter/widgets.dart';
import 'package:up_tokens/up_tokens.dart';

extension UpContext on BuildContext {
  UpTheme get up => UpTheme.of(this);
  UpSemantic get upColors => UpTheme.of(this).colors;

  /// 某个排版角色的样式。
  TextStyle textRole(UpTextRole role) => UpTheme.of(this).text[role];
}

/// 按角色的大小写规则格式化文字后显示。
class UpText extends StatelessWidget {
  const UpText(
    this.text, {
    super.key,
    required this.role,
    this.color,
    this.maxLines,
    this.align,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final UpTextRole role;
  final Color? color;
  final int? maxLines;
  final TextAlign? align;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final t = UpTheme.of(context).text;
    final style = t[role];
    return Text(
      t.format(role, text),
      style: color == null ? style : style.copyWith(color: color),
      maxLines: maxLines,
      textAlign: align,
      overflow: overflow,
    );
  }
}

/// 按压缩放反馈（button.pressScale / button.press）。
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    return Semantics(
      button: true,
      enabled: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: active ? (_) => _set(true) : null,
        onTapUp: active ? (_) => _set(false) : null,
        onTapCancel: active ? () => _set(false) : null,
        onTap: active ? widget.onTap : null,
        child: AnimatedScale(
          scale: _down ? UpButtonTokens.pressScale : UpOpacities.full,
          duration: UpMotion.duration(context, UpButtonTokens.press),
          curve: UpEasings.standard,
          child: widget.child,
        ),
      ),
    );
  }
}
