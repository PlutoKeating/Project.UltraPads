import 'package:flutter/material.dart';
import 'package:up_tokens/up_tokens.dart';

import '../basics/up_chip.dart';
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

/// 顶栏右侧的「图标 + 文字」方块按钮（设置入口、视频教程等）。
class TopBarTileButton extends StatelessWidget {
  const TopBarTileButton({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticLabel,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: PressScale(
        onTap: onTap,
        child: Container(
          width: UpTopBarTokens.youtubeWidth,
          height: UpTopBarTokens.youtubeHeight,
          decoration: BoxDecoration(
            color: c.surfaceSunken,
            borderRadius: BorderRadius.circular(UpRadii.md),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: UpSizes.iconSm, color: c.accentPrimary),
              UpText(label, role: UpTextRole.caption, color: c.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 参考设计 `btnYoutube`：视频教程入口（[TopBarTileButton] 的一种）。
class VideoTutorialButton extends StatelessWidget {
  const VideoTutorialButton({
    super.key,
    required this.label,
    required this.semanticLabel,
    this.onTap,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => TopBarTileButton(
    icon: Icons.smart_display_rounded,
    label: label,
    semanticLabel: semanticLabel,
    onTap: onTap,
  );
}

/// 音色组切换条：一首歌有 [count] 组（每组 12 个 pad），组名 A、B、C…；
/// 点击即切换，正在播放的声音不受影响（由调用方决定）。[hint] 中的组反色提示。
class PadGroupSwitcher extends StatelessWidget {
  const PadGroupSwitcher({
    super.key,
    required this.count,
    required this.selected,
    required this.onSelect,
    this.hint = const {},
    this.semanticLabelOf,
  });

  final int count;
  final int selected;
  final ValueChanged<int> onSelect;
  final Set<int> hint;

  /// 读屏文案（例如「音色组 B」）。
  final String Function(String name)? semanticLabelOf;

  /// 组名：0 → A，1 → B …（超过 26 组时 AA、AB…）。
  static String nameOf(int group) {
    final letter = String.fromCharCode(0x41 + group % 26);
    return group < 26 ? letter : '${nameOf(group ~/ 26 - 1)}$letter';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: UpTopBarTokens.gap,
        children: [
          for (var g = 0; g < count; g++)
            Semantics(
              selected: g == selected,
              label: semanticLabelOf?.call(nameOf(g)),
              child: UpChip(
                key: ValueKey('group-$g'),
                label: nameOf(g),
                variant: g == selected
                    ? UpChipVariant.selected
                    : hint.contains(g)
                    ? UpChipVariant.hint
                    : UpChipVariant.normal,
                onTap: () => onSelect(g),
              ),
            ),
        ],
      ),
    );
  }
}
