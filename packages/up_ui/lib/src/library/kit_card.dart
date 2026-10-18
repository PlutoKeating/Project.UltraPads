import 'package:flutter/material.dart';
import 'package:up_tokens/up_tokens.dart';

import '../audio/progress_ring.dart';
import '../util.dart';

/// Kit 下载 / 导入状态。
enum KitStatus { ready, notDownloaded, downloading, importing, error }

/// Kit 封面：角色色渐变 + 上下色带 + 「KIT」+ 标题（截图 4）。
/// 私有封面图存在时用 [image] 覆盖。
class KitCover extends StatelessWidget {
  const KitCover({
    super.key,
    required this.title,
    required this.role,
    this.overline,
    this.image,
    this.size = UpKitCardTokens.coverSize,
  });

  final String title;
  final String? overline;
  final int role;
  final ImageProvider? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = UpTheme.of(context);
    final r = t.padRole(role);
    final band = size * UpRatios.padNumberSize;
    final ink = t.colors.textInverse;
    return ClipRRect(
      borderRadius: BorderRadius.circular(UpKitCardTokens.coverRadius),
      child: SizedBox.square(
        dimension: size,
        child: image != null
            ? Image(image: image!, fit: BoxFit.cover)
            : DecoratedBox(
                decoration: BoxDecoration(
                  gradient: r.gradient(radial: t.colors.padFillRadial),
                ),
                child: Column(
                  children: [
                    Container(height: band, color: r.edge),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(UpSpacing.xs),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (overline != null)
                                UpText(
                                  overline!,
                                  role: UpTextRole.overline,
                                  color: ink.withValues(
                                    alpha: UpOpacities.muted,
                                  ),
                                ),
                              UpText(
                                title,
                                role: UpTextRole.title,
                                color: ink,
                                maxLines: 2,
                                align: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(height: band, color: r.edge),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Kit 列表卡（深色卡 + 封面 + KIT / 标题 / 副标题）。
class KitCard extends StatelessWidget {
  const KitCard({
    super.key,
    required this.title,
    required this.role,
    this.overline,
    this.subtitle,
    this.image,
    this.selected = false,
    this.focused = false,
    this.large = false,
    this.status = KitStatus.ready,
    this.progress,
    this.badge,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String? overline;
  final String? subtitle;
  final int role;
  final ImageProvider? image;

  /// 当前加载中的 Kit（左侧选中指示条）。
  final bool selected;

  /// 视觉焦点（截图中放大突出的那张）。
  final bool focused;
  final bool large;
  final KitStatus status;
  final double? progress;
  final Widget? badge;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final height = large ? UpKitCardTokens.heightLarge : UpKitCardTokens.height;
    final cover =
        (large ? UpKitCardTokens.coverSizeLarge : UpKitCardTokens.coverSize)
            .clamp(0.0, height - UpSpacing.xs * 2);
    return PressScale(
      onTap: onTap,
      child: AnimatedScale(
        scale: focused ? UpKitCardTokens.focusScale : UpOpacities.full,
        duration: UpMotion.duration(context, UpDurations.medium),
        curve: UpEasings.emphasized,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: selected ? c.cardBackgroundSelected : c.cardBackground,
            borderRadius: BorderRadius.circular(UpKitCardTokens.radius),
            boxShadow: focused ? UpKitCardTokens.shadow : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              AnimatedContainer(
                duration: UpMotion.duration(context, UpDurations.fast),
                width: selected ? UpKitCardTokens.indicatorWidth : 0,
                color: c.cardSelectedIndicator,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UpKitCardTokens.padding,
                  vertical: UpSpacing.xs,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    KitCover(
                      title: title,
                      overline: overline,
                      role: role,
                      image: image,
                      size: cover,
                    ),
                    if (status != KitStatus.ready)
                      _StatusOverlay(
                        status: status,
                        progress: progress,
                        size: cover,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (overline != null)
                      UpText(
                        overline!,
                        role: UpTextRole.overline,
                        color: c.cardOverline,
                      ),
                    UpText(
                      title,
                      role: large ? UpTextRole.headline : UpTextRole.title,
                      color: c.cardTitle,
                    ),
                    if (subtitle != null)
                      UpText(
                        subtitle!,
                        role: UpTextRole.body,
                        color: c.cardSubtitle,
                      ),
                  ],
                ),
              ),
              if (badge != null)
                Padding(
                  padding: const EdgeInsets.all(UpSpacing.md),
                  child: badge,
                ),
              ?trailing,
              const SizedBox(width: UpKitCardTokens.gap),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusOverlay extends StatelessWidget {
  const _StatusOverlay({
    required this.status,
    required this.progress,
    required this.size,
  });
  final KitStatus status;
  final double? progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final scale =
        size /
        ((UpProgressRingTokens.innerRadius + UpProgressRingTokens.thickness) *
            2) *
        UpOpacities.muted;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.surfaceOverlayDownload,
        borderRadius: BorderRadius.circular(UpKitCardTokens.coverRadius),
      ),
      alignment: Alignment.center,
      child: switch (status) {
        KitStatus.notDownloaded => Icon(
          Icons.download_rounded,
          color: c.iconPrimary,
          size: UpSizes.iconLg,
        ),
        KitStatus.downloading ||
        KitStatus.importing => UpProgressRing(progress: progress, scale: scale),
        KitStatus.error => Icon(
          Icons.error_outline_rounded,
          color: c.statusDanger,
          size: UpSizes.iconLg,
        ),
        KitStatus.ready => const SizedBox.shrink(),
      },
    );
  }
}
