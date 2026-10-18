import 'package:flutter/widgets.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';

enum UpButtonVariant { primary, secondary, outline, ghost, danger }

enum UpButtonSize { sm, md, lg }

class UpButton extends StatelessWidget {
  const UpButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = UpButtonVariant.primary,
    this.size = UpButtonSize.md,
    this.wide = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final UpButtonVariant variant;
  final UpButtonSize size;

  /// 固定宽度（sub_button，335）。
  final bool wide;

  /// 撑满父宽度。
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final enabled = onPressed != null;
    final (Color bg, Color fg, Color? border) = switch (variant) {
      _ when !enabled => (
        c.buttonDisabledBackground,
        c.buttonDisabledForeground,
        null,
      ),
      UpButtonVariant.primary => (
        c.buttonPrimaryBackground,
        c.buttonPrimaryForeground,
        null,
      ),
      UpButtonVariant.secondary => (
        c.buttonSecondaryBackground,
        c.buttonSecondaryForeground,
        null,
      ),
      UpButtonVariant.outline => (
        UpPrimitiveColors.baseTransparent,
        c.buttonGhostForeground,
        c.buttonOutlineBorder,
      ),
      UpButtonVariant.ghost => (
        UpPrimitiveColors.baseTransparent,
        c.buttonGhostForeground,
        null,
      ),
      UpButtonVariant.danger => (
        c.buttonDangerBackground,
        c.buttonPrimaryForeground,
        null,
      ),
    };
    final height = switch (size) {
      UpButtonSize.sm => UpButtonTokens.heightSm,
      UpButtonSize.md => UpButtonTokens.height,
      UpButtonSize.lg => UpButtonTokens.heightLg,
    };
    Widget child = Container(
      height: height,
      width: wide ? UpButtonTokens.wideWidth : null,
      constraints: const BoxConstraints(minWidth: UpButtonTokens.minWidth),
      padding: const EdgeInsets.symmetric(horizontal: UpButtonTokens.paddingX),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(UpButtonTokens.radius),
        border: border == null
            ? null
            : Border.all(color: border, width: UpButtonTokens.borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: UpButtonTokens.iconSize, color: fg),
            const SizedBox(width: UpButtonTokens.gap),
          ],
          Flexible(
            child: UpText(label, role: UpTextRole.button, color: fg),
          ),
        ],
      ),
    );
    if (expand) child = SizedBox(width: double.infinity, child: child);
    return PressScale(onTap: onPressed, child: child);
  }
}

/// 只有图标的按钮（顶栏 ✕、⋮、🔍 等）。
class UpIconButton extends StatelessWidget {
  const UpIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size = UpIconButtonTokens.size,
    this.iconSize = UpIconButtonTokens.iconSize,
    this.semanticLabel,
    this.child,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final double iconSize;
  final String? semanticLabel;

  /// 自定义图标（例如私有位图），优先于 [icon]。
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    return Semantics(
      label: semanticLabel,
      child: PressScale(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child:
                child ??
                Icon(
                  icon,
                  size: iconSize,
                  color: onPressed == null
                      ? c.iconDisabled
                      : (color ?? c.iconPrimary),
                ),
          ),
        ),
      ),
    );
  }
}
