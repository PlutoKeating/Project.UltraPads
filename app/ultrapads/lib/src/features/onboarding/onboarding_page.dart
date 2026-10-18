import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_fx/up_fx.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../state/settings_state.dart';
import '../library/genres.dart';
import '../perform/pad_mapping.dart';

/// 首次启动引导（4.7.0：Walkthrough + 音乐风格选择 CategoryPreference；
/// 付费试用页不做）。品牌渐变背景，每页一个由真实组件拼成的插图。
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with SingleTickerProviderStateMixin {
  final _pages = PageController();
  int _page = 0;
  final Set<String> _genres = {};

  /// 未选择风格时 NEXT 按钮左右抖动（4.7.0：±20 px，每段 0.1 s）。
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: UpDurations.fast * 4,
  );

  static const _walkthrough = 4;
  int get _count => _walkthrough + 1;

  @override
  void dispose() {
    _pages.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _count - 1) {
      _pages.nextPage(
        duration: FxMotion.duration(context, UpPageTokens.push),
        curve: UpPageTokens.pushCurve,
      );
      return;
    }
    if (_genres.isEmpty) {
      if (!FxMotion.reduce(context)) _shake.forward(from: 0);
      return;
    }
    _finish();
  }

  void _finish() {
    ref.read(prefsProvider).setStringList('preferredGenres', _genres.toList());
    ref.read(settingsProvider.notifier).setOnboarded();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final titles = [
      l10n.onboardingMakeMusicTitle,
      l10n.onboardingRhythmsTitle,
      l10n.onboardingLoopsTitle,
      l10n.onboardingShareTitle,
      l10n.onboardingStyleTitle,
    ];
    final last = _page == _count - 1;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: c.brandBackground.linear(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: UpButton(
                  label: l10n.onboardingSkip,
                  variant: UpButtonVariant.ghost,
                  size: UpButtonSize.sm,
                  onPressed: _finish,
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _count,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UpSpacing.xxl,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: UpSpacing.xxl),
                        UpText(
                          titles[i],
                          role: UpTextRole.hero,
                          color: c.textOnAccent,
                          align: TextAlign.center,
                          maxLines: 3,
                        ),
                        const SizedBox(height: UpSpacing.xxl),
                        Expanded(
                          child: i < _walkthrough
                              ? _Illustration(index: i)
                              : _StylePicker(
                                  selected: _genres,
                                  onToggle: (g) => setState(
                                    () => _genres.contains(g)
                                        ? _genres.remove(g)
                                        : _genres.add(g),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: UpBannerTokens.indicatorGap,
                children: [
                  for (var i = 0; i < _count; i++)
                    AnimatedContainer(
                      duration: UpMotion.duration(context, UpDurations.fast),
                      width: UpBannerTokens.indicatorSize,
                      height: UpBannerTokens.indicatorSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? c.bannerIndicatorActive
                            : c.bannerIndicator,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(UpSpacing.xxl),
                child: AnimatedBuilder(
                  animation: _shake,
                  builder: (context, child) {
                    final t = _shake.value;
                    // 4 段往返：0 → +x → −x → +x → 0
                    final dx = t == 0
                        ? 0.0
                        : UpSpacing.xl *
                              (1 - t) *
                              ((t * 4).floor().isEven ? 1 : -1);
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: child,
                    );
                  },
                  child: UpButton(
                    label: last ? l10n.onboardingStart : l10n.onboardingNext,
                    variant: UpButtonVariant.secondary,
                    size: UpButtonSize.lg,
                    wide: true,
                    onPressed: _next,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 引导插图：用真实组件拼出截图中的场景。
class _Illustration extends StatelessWidget {
  const _Illustration({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = UpTheme.of(context).colors;
    final pads = [
      for (var i = 0; i < PadId.total; i++)
        PadData(
          role: const [6, 2, 4, 3, 0, 1][i % 6],
          loop: index == 1 && i % 4 == 0,
          state: index == 1 && i == 4
              ? PadVisualState.playing
              : PadVisualState.idle,
          label: padNumberLabel(i % PadId.padsPerBank),
        ),
    ];
    final grid = AspectRatio(
      aspectRatio: PadId.columns / PadId.rows,
      child: Container(
        padding: const EdgeInsets.all(UpSpacing.md),
        decoration: BoxDecoration(
          color: c.surfacePads,
          borderRadius: BorderRadius.circular(UpRadii.xxl),
        ),
        child: IgnorePointer(
          child: PadGrid(
            pads: pads,
            bank: 0,
            onPadDown: (_, _) {},
            onPadUp: (_, _) {},
          ),
        ),
      ),
    );
    final peaks = DemoLibrary.waveform(
      'onboarding',
      UpWaveformTokens.height.toInt(),
    );
    return Center(
      child: switch (index) {
        1 => Column(
          spacing: UpSpacing.lg,
          children: [
            TransportBar(
              progress: UpOpacities.muted,
              peaks: peaks,
              onStop: null,
              active: true,
            ),
            Expanded(child: grid),
          ],
        ),
        3 => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TrackCard(
              title: context.l10n.recordDefaultName(1),
              peaks: peaks,
              progress: UpOpacities.muted,
              playing: true,
            ),
          ],
        ),
        2 => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: UpSpacing.md,
          children: [
            for (final g in genreSpecs.take(3))
              KitCard(
                title: g.label(context.l10n),
                overline: context.l10n.libraryKitBadge,
                role: g.role.index,
              ),
          ],
        ),
        _ => grid,
      },
    );
  }
}

/// 音乐风格选择（CategoryPreference：列表 + 粉色勾选）。
class _StylePicker extends StatelessWidget {
  const _StylePicker({required this.selected, required this.onToggle});
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    return Column(
      children: [
        UpText(
          l10n.onboardingChooseStyleBody,
          role: UpTextRole.body,
          color: c.textOnAccent,
          align: TextAlign.center,
          maxLines: 3,
        ),
        const SizedBox(height: UpSpacing.lg),
        Expanded(
          child: ListView(
            children: [
              for (final g in genreSpecs)
                Padding(
                  padding: const EdgeInsets.only(bottom: UpSheetTokens.itemGap),
                  child: UpListItem(
                    iconWidget: Icon(
                      g.icon,
                      color: UpTheme.of(context).padRole(g.role.index).mid,
                    ),
                    title: g.label(l10n),
                    trailing: Icon(
                      selected.contains(g.key)
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected.contains(g.key)
                          ? c.accentPrimary
                          : c.iconSecondary,
                    ),
                    onTap: () => onToggle(g.key),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
