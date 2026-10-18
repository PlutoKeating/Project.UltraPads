import 'dart:async';

import 'package:flutter/material.dart';
import 'package:up_engine/up_engine.dart' show DemoLibrary;
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../perform/pad_mapping.dart';
import 'token_browser.dart';

/// 设计画廊 ② 组件：每个 up_ui 组件的状态变体，可交互。
class ComponentGallery extends StatefulWidget {
  const ComponentGallery({super.key});

  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

class _ComponentGalleryState extends State<ComponentGallery> {
  double _slider = 0.4;
  bool _switch = true;
  bool _recording = false;
  bool _playing = true;
  int _tab = 0;
  int _swatch = 0;
  (double, double) _sel = (0.2, 0.7);
  final List<double> _peaks = DemoLibrary.waveform(
    'gallery',
    UpWaveformTokens.height.toInt(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = UpTheme.of(context);
    final c = theme.colors;

    Widget pad(String label, Widget child) => SizedBox(
      width: UpPadTokens.cellWidth / 2,
      child: Column(
        spacing: UpSpacing.xs,
        children: [
          AspectRatio(aspectRatio: 1, child: child),
          UpText(
            label,
            role: UpTextRole.caption,
            color: c.textMuted,
            maxLines: 2,
            align: TextAlign.center,
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(UpPageTokens.paddingX),
      children: [
        GallerySection(title: '${l10n.settingsGalleryStates} · UpPad'),
        Wrap(
          spacing: UpSpacing.md,
          runSpacing: UpSpacing.md,
          children: [
            pad(l10n.performPadStateIdle, const UpPad(data: PadData(role: 1))),
            pad(
              l10n.settingsGalleryPressed,
              const UpPad(data: PadData(role: 1), pressed: true),
            ),
            pad(
              l10n.performPadStatePlaying,
              const UpPad(
                data: PadData(role: 2, state: PadVisualState.playing),
              ),
            ),
            pad(
              l10n.performPadModeLoop,
              const UpPad(data: PadData(role: 3, loop: true)),
            ),
            pad(
              '${l10n.performPadModeLoop} · ${l10n.performPadStatePlaying}',
              const UpPad(
                data: PadData(
                  role: 3,
                  loop: true,
                  state: PadVisualState.playing,
                ),
              ),
            ),
            pad(
              l10n.performPadStatePending,
              const UpPad(
                data: PadData(
                  role: 3,
                  loop: true,
                  state: PadVisualState.pending,
                ),
              ),
            ),
            pad(
              l10n.settingsGalleryDisabled,
              const UpPad(data: PadData(role: 0), dimmed: true),
            ),
            pad(l10n.performPadEmpty, const UpPad(data: PadData.empty)),
            pad(
              l10n.tutorialTitle,
              const UpPad(data: PadData(role: 0), fill: 0.6),
            ),
            pad(
              l10n.commonSelect,
              const UpPad(
                data: PadData(role: 6, label: '7'),
                selected: true,
                showLabel: true,
              ),
            ),
          ],
        ),
        GallerySection(title: 'PadGrid'),
        const SizedBox(
          height: UpPadTokens.cellHeight * 2,
          child: InteractivePadGrid(),
        ),
        GallerySection(title: 'UpChip · BankButton · SpeedPill'),
        Wrap(
          spacing: UpSpacing.md,
          runSpacing: UpSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            UpChip(
              label: l10n.navSongs,
              icon: Icons.music_note_rounded,
              variant: UpChipVariant.selected,
              onTap: () {},
            ),
            UpChip(
              label: l10n.performTutorial,
              icon: Icons.school_rounded,
              onTap: () {},
            ),
            UpChip(
              label: l10n.tutorialSwitchBank(l10n.performBankB),
              variant: UpChipVariant.hint,
            ),
            BankButton(label: l10n.performBankA, onPressed: () {}),
            BankButton(label: l10n.performBankB, hint: true, onPressed: () {}),
            SpeedPill(label: l10n.performSpeedValue(1), onTap: () {}),
          ],
        ),
        GallerySection(title: 'UpButton · UpBadge'),
        Wrap(
          spacing: UpSpacing.md,
          runSpacing: UpSpacing.md,
          children: [
            for (final v in UpButtonVariant.values)
              UpButton(label: v.name, variant: v, onPressed: () {}),
            UpButton(label: l10n.settingsGalleryDisabled),
            UpBadge(label: l10n.commonNew, kind: UpBadgeKind.isNew),
            UpBadge(label: l10n.commonTop, kind: UpBadgeKind.top),
            UpBadge(label: l10n.libraryKitBadge),
          ],
        ),
        GallerySection(
          title: 'UpSlider · UpSwitchRow · UpSwatchRow · UpSearchField',
        ),
        UpSlider(value: _slider, onChanged: (v) => setState(() => _slider = v)),
        UpSwitchRow(
          title: l10n.settingsAnimatePads,
          value: _switch,
          onChanged: (v) => setState(() => _switch = v),
        ),
        const SizedBox(height: UpSpacing.md),
        UpSwatchRow(
          colors: [for (var i = 0; i < 8; i++) theme.padRole(i).mid],
          selected: _swatch,
          onSelected: (i) => setState(() => _swatch = i),
        ),
        const SizedBox(height: UpSpacing.md),
        UpSearchField(hint: l10n.librarySearchHint),
        GallerySection(
          title:
              'TransportBar · TutorialBar · WaveformView · UpMeter · UpProgressRing',
        ),
        TransportBar(
          progress: _slider,
          peaks: _peaks,
          active: true,
          onStop: () {},
        ),
        const SizedBox(height: UpSpacing.md),
        TutorialBar(step: 3, total: 10, onSeek: (_) {}),
        const SizedBox(height: UpSpacing.md),
        WaveformView(
          peaks: _peaks,
          selection: _sel,
          onSelectionChanged: (s) => setState(() => _sel = s),
        ),
        const SizedBox(height: UpSpacing.md),
        Row(
          spacing: UpSpacing.lg,
          children: [
            SizedBox(
              height: UpSizes.controlXl,
              child: UpMeter(level: _slider * UpMeterTokens.midThreshold),
            ),
            SizedBox(
              height: UpSizes.controlXl,
              child: UpMeter(level: _slider, peak: _slider),
            ),
            SizedBox(
              height: UpSizes.controlXl,
              child: UpMeter(level: UpMeterTokens.highThreshold),
            ),
            UpProgressRing(progress: _slider, scale: UpOpacities.muted),
            const UpProgressRing(scale: UpOpacities.muted),
            RecordButton(
              recording: _recording,
              onPressed: () => setState(() => _recording = !_recording),
              elapsedLabel: l10n.loadSoundElapsed(3),
            ),
          ],
        ),
        GallerySection(title: 'TrackCard'),
        TrackCard(
          title: l10n.recordDefaultName(1),
          subtitle: l10n.unitSeconds(12),
          peaks: _peaks,
          progress: _slider,
          playing: _playing,
          onPlayStop: () => setState(() => _playing = !_playing),
          onShare: () {},
        ),
        GallerySection(title: 'KitCard · KitCover · BannerCarousel · GenreRow'),
        BannerCarousel(
          itemCount: 3,
          autoplay: false,
          itemBuilder: (context, i, f) => KitCover(
            title: l10n.libraryFeatured,
            overline: l10n.libraryKitBadge,
            role: i,
            size: UpBannerTokens.width,
          ),
        ),
        for (final s in KitStatus.values)
          Padding(
            padding: const EdgeInsets.only(top: UpSpacing.xs),
            child: KitCard(
              title: s.name,
              overline: l10n.performInspiredBy,
              subtitle: l10n.libraryGenrePop,
              role: s.index,
              status: s,
              progress: _slider,
              selected: s == KitStatus.ready,
            ),
          ),
        const SizedBox(height: UpSpacing.md),
        GenreRow(
          children: [
            GenreIcon(
              label: l10n.libraryGenreHipHop,
              role: 0,
              icon: Icons.headphones_rounded,
              selected: true,
            ),
            GenreIcon(
              label: l10n.libraryGenreRock,
              role: 3,
              icon: Icons.bolt_rounded,
            ),
            GenreIcon(
              label: l10n.libraryGenreDisco,
              role: 4,
              icon: Icons.album_rounded,
            ),
          ],
        ),
        GallerySection(title: 'UpTabBar · UpSegmentTabs'),
        UpSegmentTabs(
          labels: [
            l10n.libraryDownloaded,
            l10n.libraryFavorites,
            l10n.libraryMyKits,
          ],
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        UpTabBar(
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
          items: [
            UpTabItem(icon: Icons.library_music_rounded, label: l10n.navKits),
            UpTabItem(icon: Icons.whatshot_rounded, label: l10n.navFeed),
            UpTabItem(icon: Icons.person_rounded, label: l10n.navProfile),
          ],
        ),
        GallerySection(title: 'UpSheet · UpListItem'),
        UpSheet(
          title: l10n.loadSoundTitle,
          scrollable: false,
          children: [
            UpListItem(
              icon: Icons.grid_view_rounded,
              overline: l10n.loadSoundImportFrom,
              title: l10n.loadSoundSourceSongs,
              onTap: () {},
            ),
            UpListItem(
              icon: Icons.mic_rounded,
              overline: l10n.loadSoundRecordingFrom,
              title: l10n.loadSoundSourceMicrophone,
              enabled: false,
            ),
          ],
        ),
        GallerySection(title: 'UpDialog · Toast · Pairing'),
        Wrap(
          spacing: UpSpacing.md,
          runSpacing: UpSpacing.md,
          children: [
            UpButton(
              label: l10n.worksDeleteTitle,
              variant: UpButtonVariant.secondary,
              onPressed: () => showUpConfirm(
                context,
                title: l10n.worksDeleteTitle,
                message: l10n.worksDeleteBody(l10n.recordDefaultName(1)),
                confirm: l10n.commonDelete,
                cancel: l10n.commonCancel,
                danger: true,
              ),
            ),
            UpButton(
              label: l10n.performKitLoaded,
              variant: UpButtonVariant.secondary,
              onPressed: () => showUpToast(context, l10n.performKitLoaded),
            ),
          ],
        ),
        const SizedBox(height: UpSpacing.lg),
        const Center(child: PairingCodeDisplay(code: '482913')),
        const SizedBox(height: UpSpacing.lg),
        Center(child: PairingCodeInput(autofocus: false, onCompleted: (_) {})),
        const SizedBox(height: UpSpacing.giant),
      ],
    );
  }
}

/// 可交互的 PadGrid（本地模拟发声状态：loop 点一下开/关，one-shot 短暂播放）。
class InteractivePadGrid extends StatefulWidget {
  const InteractivePadGrid({super.key, this.bank = 0});
  final int bank;

  @override
  State<InteractivePadGrid> createState() => _InteractivePadGridState();
}

class _InteractivePadGridState extends State<InteractivePadGrid> {
  final Set<int> _playing = {};

  static bool _isLoop(int i) => i % 3 == 1;

  @override
  Widget build(BuildContext context) {
    final pads = [
      for (var i = 0; i < 24; i++)
        i % 12 == 11
            ? PadData.empty
            : PadData(
                role: const [1, 3, 0, 2, 3, 1, 0, 3, 2, 1, 3][i % 12],
                loop: _isLoop(i),
                state: _playing.contains(i)
                    ? PadVisualState.playing
                    : PadVisualState.idle,
                label: padNumberLabel(i % 12),
              ),
    ];
    return PadGrid(
      pads: pads,
      bank: widget.bank,
      onPadDown: (b, i) {
        final f = b * 12 + i;
        setState(
          () => _isLoop(f) && _playing.contains(f)
              ? _playing.remove(f)
              : _playing.add(f),
        );
        if (!_isLoop(f)) {
          Timer(UpDurations.slower, () {
            if (mounted) setState(() => _playing.remove(f));
          });
        }
      },
      onPadUp: (_, _) {},
    );
  }
}
