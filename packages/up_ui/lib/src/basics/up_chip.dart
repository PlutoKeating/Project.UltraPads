import 'package:flutter/widgets.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';

enum UpChipVariant {
  /// 深灰底（TUTORIAL）。
  normal,

  /// 品牌粉（SONGS / MENU）。
  selected,

  /// 教程提示：白底黑字（旧版参考 A/B 反色提示）。
  hint,
}

/// 顶栏胶囊：左侧深色图标格 + 右侧文字（截图「♫ SONGS」「🎓 TUTORIAL」）。
class UpChip extends StatelessWidget {
  const UpChip({
    super.key,
    required this.label,
    this.icon,
    this.iconWidget,
    this.variant = UpChipVariant.normal,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final UpChipVariant variant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final (Color bg, Color fg, Color box) = switch (variant) {
      UpChipVariant.normal => (
        c.chipBackground,
        c.chipForeground,
        c.chipIconBox,
      ),
      UpChipVariant.selected => (
        c.chipSelectedBackground,
        c.chipSelectedForeground,
        c.chipSelectedIconBox,
      ),
      UpChipVariant.hint => (
        c.chipHintBackground,
        c.chipHintForeground,
        c.chipHintBackground,
      ),
    };
    final radius = BorderRadius.circular(UpChipTokens.radius);
    final hasIcon = icon != null || iconWidget != null;
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: UpMotion.duration(context, UpDurations.fast),
        height: UpChipTokens.height,
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasIcon)
              Container(
                width: UpChipTokens.iconBoxWidth,
                color: box,
                alignment: Alignment.center,
                child:
                    iconWidget ??
                    Icon(icon, size: UpChipTokens.iconSize, color: fg),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: UpChipTokens.paddingX,
              ),
              child: UpText(label, role: UpTextRole.label, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
