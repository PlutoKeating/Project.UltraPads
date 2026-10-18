import 'package:flutter/material.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';

/// 演奏页 / 子页顶栏（toolbar 56）。
class UpTopBar extends StatelessWidget {
  const UpTopBar({
    super.key,
    this.leading,
    this.title,
    this.titleWidget,
    this.trailing = const [],
    this.centerTitle = false,
    this.background,
  });

  final Widget? leading;
  final String? title;
  final Widget? titleWidget;
  final List<Widget> trailing;
  final bool centerTitle;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final titleChild =
        titleWidget ??
        (title == null
            ? const SizedBox.shrink()
            : UpText(title!, role: UpTextRole.title, color: c.textPrimary));
    return Container(
      height: UpTopBarTokens.height,
      color: background ?? c.surfaceToolbar,
      padding: const EdgeInsets.symmetric(horizontal: UpTopBarTokens.paddingX),
      child: NavigationToolbar(
        leading: leading,
        middle: titleChild,
        centerMiddle: centerTitle,
        middleSpacing: UpTopBarTokens.gap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: UpTopBarTokens.gap,
          children: trailing,
        ),
      ),
    );
  }
}

/// 演奏页第二栏（menu bar 36）：TUTORIAL、⋮ …… 右侧 A/B。
class PerformMenuBar extends StatelessWidget {
  const PerformMenuBar({super.key, required this.children, this.trailing});

  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    return SizedBox(
      height: UpTopBarTokens.bankButtonSize,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.symmetric(vertical: UpSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: UpTopBarTokens.paddingX,
              ),
              color: c.surfaceSunken,
              child: Row(spacing: UpTopBarTokens.gap, children: children),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A/B 翻页按钮（56×56 方块，#191E20；教程提示时反色）。
class BankButton extends StatelessWidget {
  const BankButton({
    super.key,
    required this.label,
    this.onPressed,
    this.hint = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool hint;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final bg = hint ? c.chipHintBackground : c.surfaceBankButton;
    final fg = hint ? c.chipHintForeground : c.textPrimary;
    return Semantics(
      label: semanticLabel,
      button: true,
      child: PressScale(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: UpMotion.duration(context, UpDurations.fast),
          width: UpTopBarTokens.bankButtonSize,
          height: UpTopBarTokens.bankButtonSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(UpRadii.md),
            ),
          ),
          child: AnimatedSwitcher(
            duration: UpMotion.duration(context, UpPadGridTokens.bankSwitch),
            child: UpText(
              label,
              key: ValueKey(label),
              role: UpTextRole.padBank,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

/// 速度药丸「1.0x」。
class SpeedPill extends StatelessWidget {
  const SpeedPill({super.key, required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    return PressScale(
      onTap: onTap,
      child: Container(
        height: UpTransportTokens.speedHeight,
        padding: const EdgeInsets.symmetric(horizontal: UpSpacing.sm),
        decoration: BoxDecoration(
          color: c.transportSpeedBackground,
          borderRadius: BorderRadius.circular(UpRadii.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: UpSpacing.xs,
          children: [
            UpText(
              label,
              role: UpTextRole.numeric,
              color: c.transportSpeedText,
            ),
            Icon(
              Icons.speed_rounded,
              size: UpSizes.iconXs,
              color: c.transportSpeedText,
            ),
          ],
        ),
      ),
    );
  }
}
