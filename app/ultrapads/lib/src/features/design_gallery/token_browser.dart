import 'package:flutter/material.dart';
import 'package:up_fx/up_fx.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

/// 设计画廊 ① token 浏览：颜色（primitive / 当前主题 semantic）、圆角、间距、
/// 字体角色、光晕、动效时长和曲线。
///
/// 标识符（`brandPink`、`pad.palette.0.core`）是 token 名，不是 UI 文案，
/// 所以直接显示；色值由 Color 计算得到。
/// TODO(tokens): primitive 目前没有生成「全部列表」，这里手工引用主要分组；
/// 请 token 代理生成 `UpPrimitiveColors.all` 等枚举后改为遍历。
class TokenBrowser extends StatelessWidget {
  const TokenBrowser({super.key});

  static final List<(String, Color)> primitives = [
    ('brandPink', UpPrimitiveColors.brandPink),
    ('brandRose', UpPrimitiveColors.brandRose),
    ('brandCreate', UpPrimitiveColors.brandCreate),
    ('brandAlert', UpPrimitiveColors.brandAlert),
    ('uiBgPads', UpPrimitiveColors.uiBgPads),
    ('uiBgMenu', UpPrimitiveColors.uiBgMenu),
    ('uiCell', UpPrimitiveColors.uiCell),
    ('uiCellPressed', UpPrimitiveColors.uiCellPressed),
    ('uiTextSection', UpPrimitiveColors.uiTextSection),
    ('uiRecRed', UpPrimitiveColors.uiRecRed),
    ('uiTutorialFill', UpPrimitiveColors.uiTutorialFill),
    ('uiPerfect', UpPrimitiveColors.uiPerfect),
    ('padBlueBase', UpPrimitiveColors.padBlueBase),
    ('padOrangeBase', UpPrimitiveColors.padOrangeBase),
    ('padGreenBase', UpPrimitiveColors.padGreenBase),
    ('padPinkBase', UpPrimitiveColors.padPinkBase),
    ('neonPink500', UpPrimitiveColors.neonPink500),
    ('neonYellow500', UpPrimitiveColors.neonYellow500),
    ('neonGreen500', UpPrimitiveColors.neonGreen500),
    ('neonBlue500', UpPrimitiveColors.neonBlue500),
    ('neonMagenta500', UpPrimitiveColors.neonMagenta500),
    ('neonCyan500', UpPrimitiveColors.neonCyan500),
    ('neonOrange500', UpPrimitiveColors.neonOrange500),
    ('neonViolet500', UpPrimitiveColors.neonViolet500),
    ('grey900', UpPrimitiveColors.grey900),
    ('grey500', UpPrimitiveColors.grey500),
    ('alphaWhite10', UpPrimitiveColors.alphaWhite10),
    ('alphaBlack70', UpPrimitiveColors.alphaBlack70),
  ];

  static const List<(String, double)> radii = [
    ('xs', UpRadii.xs),
    ('sm', UpRadii.sm),
    ('md', UpRadii.md),
    ('lg', UpRadii.lg),
    ('xl', UpRadii.xl),
    ('xxl', UpRadii.xxl),
    ('xxxl', UpRadii.xxxl),
  ];

  static const List<(String, double)> spacing = [
    ('hair', UpSpacing.hair),
    ('xxs', UpSpacing.xxs),
    ('xs', UpSpacing.xs),
    ('sm', UpSpacing.sm),
    ('md', UpSpacing.md),
    ('lg', UpSpacing.lg),
    ('xl', UpSpacing.xl),
    ('xxl', UpSpacing.xxl),
    ('xxxl', UpSpacing.xxxl),
    ('huge', UpSpacing.huge),
  ];

  static const List<(String, Duration)> durations = [
    ('frame', UpDurations.frame),
    ('fast', UpDurations.fast),
    ('quick', UpDurations.quick),
    ('short', UpDurations.short),
    ('medium', UpDurations.medium),
    ('slow', UpDurations.slow),
    ('modalIn', UpDurations.modalIn),
    ('loopHalf', UpDurations.loopHalf),
    ('breathe', UpDurations.breathe),
    ('slower', UpDurations.slower),
    ('loopCycle', UpDurations.loopCycle),
  ];

  static const List<(String, Cubic)> curves = [
    ('linear', UpEasings.linear),
    ('quadOut', UpEasings.quadOut),
    ('quadIn', UpEasings.quadIn),
    ('circOut', UpEasings.circOut),
    ('circIn', UpEasings.circIn),
    ('standard', UpEasings.standard),
    ('decelerate', UpEasings.decelerate),
    ('emphasized', UpEasings.emphasized),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = UpTheme.of(context);
    final c = theme.colors;
    final semantic = UpSemantic.tokens
        .where((t) => t.type == UpSemanticType.color)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(UpPageTokens.paddingX),
      children: [
        GallerySection(title: l10n.settingsGalleryPrimitive),
        Wrap(
          spacing: UpSpacing.md,
          runSpacing: UpSpacing.md,
          children: [
            for (final (n, col) in primitives) ColorChip(name: n, color: col),
          ],
        ),
        GallerySection(title: l10n.settingsGallerySemantic),
        Wrap(
          spacing: UpSpacing.md,
          runSpacing: UpSpacing.md,
          children: [
            for (final t in semantic)
              ColorChip(name: t.key, color: c.valueOf(t.key) as Color),
          ],
        ),
        GallerySection(title: l10n.settingsGalleryRadii),
        Wrap(
          spacing: UpSpacing.lg,
          runSpacing: UpSpacing.lg,
          children: [
            for (final (n, r) in radii)
              _Labeled(
                label: '$n · ${r.toStringAsFixed(1)}',
                child: Container(
                  width: UpSizes.controlLg,
                  height: UpSizes.controlLg,
                  decoration: BoxDecoration(
                    color: c.accentPrimary,
                    borderRadius: BorderRadius.circular(r),
                  ),
                ),
              ),
          ],
        ),
        GallerySection(title: l10n.settingsGallerySpacing),
        for (final (n, v) in spacing)
          Padding(
            padding: const EdgeInsets.only(bottom: UpSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: UpButtonTokens.minWidth,
                  child: UpText(
                    '$n · ${v.toStringAsFixed(1)}',
                    role: UpTextRole.caption,
                    color: c.textSecondary,
                  ),
                ),
                Container(
                  width: v,
                  height: UpSpacing.md,
                  color: c.accentSecondary,
                ),
              ],
            ),
          ),
        GallerySection(title: l10n.settingsGalleryTypography),
        for (final role in UpTextRole.values)
          Padding(
            padding: const EdgeInsets.only(bottom: UpSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                SizedBox(
                  width: UpButtonTokens.minWidth,
                  child: UpText(
                    role.name,
                    role: UpTextRole.caption,
                    color: c.textMuted,
                  ),
                ),
                Expanded(
                  child: UpText(
                    l10n.onboardingMakeMusicTitle,
                    role: role,
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        GallerySection(title: l10n.settingsGalleryGlow),
        Wrap(
          spacing: UpSpacing.xxl,
          runSpacing: UpSpacing.xxl,
          children: [
            for (final (n, spec) in [
              ('glow.sm', UpGlows.sm),
              ('glow.md', UpGlows.md),
              ('glow.lg', UpGlows.lg),
              ('pad.glowPressed', UpPadTokens.glowPressed),
              ('pad.glowPlaying', UpPadTokens.glowPlaying),
            ])
              _Labeled(
                label: n,
                child: Container(
                  width: UpSizes.controlLg,
                  height: UpSizes.controlLg,
                  decoration: BoxDecoration(
                    color: theme.padRole(3).mid,
                    borderRadius: BorderRadius.circular(UpRadii.lg),
                    boxShadow: spec.shadows(theme.padRole(3).glow),
                  ),
                ),
              ),
          ],
        ),
        GallerySection(title: l10n.settingsGalleryDurations),
        for (final (n, d) in durations)
          CurveDemo(
            label: '$n · ${d.inMilliseconds} ms',
            duration: d,
            curve: UpEasings.linear,
          ),
        for (final (n, cv) in curves)
          CurveDemo(label: n, duration: UpDurations.slower, curve: cv),
      ],
    );
  }
}

class GallerySection extends StatelessWidget {
  const GallerySection({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: UpSpacing.xxl, bottom: UpSpacing.md),
    child: UpText(
      title,
      role: UpTextRole.titleSm,
      color: UpTheme.of(context).colors.textSecondary,
    ),
  );
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: UpSpacing.xs,
    children: [
      child,
      UpText(
        label,
        role: UpTextRole.caption,
        color: UpTheme.of(context).colors.textMuted,
      ),
    ],
  );
}

/// 色块 + token 名 + 计算出的色值。
class ColorChip extends StatelessWidget {
  const ColorChip({super.key, required this.name, required this.color});
  final String name;
  final Color color;

  static String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final c = UpTheme.of(context).colors;
    return SizedBox(
      width: UpButtonTokens.minWidth + UpSpacing.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: UpSpacing.xxs,
        children: [
          Container(
            height: UpSizes.controlMd,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(UpRadii.md),
              border: Border.all(
                color: c.borderSubtle,
                width: UpBorderWidths.hairline,
              ),
            ),
          ),
          UpText(
            name,
            role: UpTextRole.caption,
            color: c.textPrimary,
            maxLines: 2,
          ),
          UpText(hex(color), role: UpTextRole.caption, color: c.textMuted),
        ],
      ),
    );
  }
}

/// 曲线 / 时长演示：一个点按 [curve] 在 [duration] 内走完轨道，点击重播。
class CurveDemo extends StatefulWidget {
  const CurveDemo({
    super.key,
    required this.label,
    required this.duration,
    required this.curve,
  });
  final String label;
  final Duration duration;
  final Curve curve;

  @override
  State<CurveDemo> createState() => _CurveDemoState();
}

class _CurveDemoState extends State<CurveDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = UpTheme.of(context).colors;
    return GestureDetector(
      onTap: () => _c.forward(from: 0),
      child: Padding(
        padding: const EdgeInsets.only(bottom: UpSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: UpButtonTokens.width / 2,
              child: UpText(
                widget.label,
                role: UpTextRole.caption,
                color: c.textSecondary,
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final t = FxMotion.reduce(context)
                        ? _c.value
                        : widget.curve.transform(_c.value);
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: UpSliderTokens.trackHeight,
                          color: c.sliderTrack,
                        ),
                        Positioned(
                          left: (box.maxWidth - UpSpacing.lg) * t,
                          child: Container(
                            width: UpSpacing.lg,
                            height: UpSpacing.lg,
                            decoration: BoxDecoration(
                              color: c.accentPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Icon(
              Icons.replay_rounded,
              size: UpSizes.iconSm,
              color: c.iconSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
