import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import 'harness.dart';

final _peaks = [
  for (var i = 0; i < 48; i++) (0.3 + ((i * 37) % 17) / 24).clamp(0.0, 1.0),
];

void main() {
  testWidgets('top bar + menu bar + chips', (t) async {
    await golden(
      t,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const UpTopBar(
            leading: UpChip(
              label: 'Songs',
              icon: Icons.music_note_rounded,
              variant: UpChipVariant.selected,
            ),
            title: 'AMEM',
            trailing: [SpeedPill(label: '1.0')],
          ),
          PerformMenuBar(
            trailing: const BankButton(label: 'A'),
            children: [
              const UpChip(label: 'Tutorial', icon: Icons.school_rounded),
              UpIconButton(icon: Icons.more_vert_rounded, onPressed: () {}),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              UpChip(label: 'Hint', variant: UpChipVariant.hint),
              BankButton(label: 'B', hint: true),
            ],
          ),
        ],
      ),
      'top_bar',
      surface: const Size(400, 220),
      size: const Size(380, 200),
    );
  });

  testWidgets('transport + tutorial bar', (t) async {
    await golden(
      t,
      Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          TransportBar(
            progress: 0.35,
            peaks: _peaks,
            onStop: () {},
            active: true,
          ),
          TransportBar(progress: 0.6, onStop: () {}),
          TutorialBar(step: 3, total: 10, onSeek: (_) {}),
        ],
      ),
      'transport_bar',
      surface: const Size(400, 200),
      size: const Size(380, 180),
    );
  });

  testWidgets('buttons, badge, swatches, slider, search', (t) async {
    await golden(
      t,
      Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              UpButton(label: 'Primary', onPressed: () {}),
              UpButton(
                label: 'Secondary',
                variant: UpButtonVariant.secondary,
                onPressed: () {},
              ),
              UpButton(
                label: 'Outline',
                variant: UpButtonVariant.outline,
                onPressed: () {},
              ),
              UpButton(
                label: 'Danger',
                icon: Icons.delete_rounded,
                variant: UpButtonVariant.danger,
                onPressed: () {},
              ),
              const UpButton(label: 'Disabled'),
              const UpBadge(label: 'New', kind: UpBadgeKind.isNew),
              const UpBadge(label: 'Top', kind: UpBadgeKind.top),
            ],
          ),
          UpSwatchRow(
            colors: [for (var i = 0; i < 8; i++) UpThemes.neon.padRole(i).mid],
            selected: 2,
            onSelected: (_) {},
          ),
          UpSlider(value: 0.4, onChanged: (_) {}),
          const UpSearchField(hint: 'Search'),
        ],
      ),
      'basics',
      surface: const Size(420, 300),
      size: const Size(400, 280),
    );
  });

  testWidgets('kit cards, banner, genres', (t) async {
    await golden(
      t,
      Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          BannerCarousel(
            itemCount: 3,
            autoplay: false,
            itemBuilder: (c, i, f) =>
                KitCover(title: 'KIT $i', role: i, size: 200),
          ),
          const KitCard(
            title: 'Loud Rock',
            overline: 'Kit',
            subtitle: 'Rock Music',
            role: 2,
          ),
          const KitCard(
            title: 'Best Hip Hop',
            overline: 'Kit',
            subtitle: 'Hip-Hop Music',
            role: 1,
            focused: true,
            selected: true,
          ),
          const KitCard(
            title: 'Party Dance',
            overline: 'Kit',
            subtitle: 'Pop Music',
            role: 0,
            status: KitStatus.notDownloaded,
          ),
          const KitCard(
            title: 'Crazy House',
            overline: 'Kit',
            role: 4,
            status: KitStatus.downloading,
            progress: 0.4,
          ),
          const GenreRow(
            children: [
              GenreIcon(
                label: 'Hip-Hop',
                role: 0,
                icon: Icons.headphones_rounded,
              ),
              GenreIcon(label: 'Funk BR', role: 2, icon: Icons.flag_rounded),
              GenreIcon(
                label: 'K-Pop',
                role: 1,
                icon: Icons.favorite_rounded,
                selected: true,
              ),
              GenreIcon(label: 'Rock', role: 3, icon: Icons.bolt_rounded),
              GenreIcon(label: 'Disco', role: 4, icon: Icons.album_rounded),
            ],
          ),
        ],
      ),
      'library',
      surface: const Size(400, 760),
      size: const Size(380, 740),
    );
  });

  testWidgets('sheet with list items', (t) async {
    await golden(
      t,
      const UpSheet(
        title: 'Load sound',
        children: [
          UpListItem(
            overline: 'Import from',
            title: 'Demo song',
            icon: Icons.grid_view_rounded,
          ),
          UpListItem(
            overline: 'Recording from',
            title: 'Microphone',
            icon: Icons.mic_rounded,
          ),
          UpListItem(
            overline: 'Import from',
            title: 'Files',
            icon: Icons.audio_file_rounded,
          ),
          UpListItem(
            overline: 'Import from',
            title: 'Kits',
            icon: Icons.person_rounded,
          ),
          UpListItem(
            overline: 'Import from',
            title: 'Recordings',
            icon: Icons.mic_external_on_rounded,
            enabled: false,
          ),
        ],
      ),
      'sheet',
      surface: const Size(400, 460),
      size: const Size(380, 440),
    );
  });

  testWidgets('audio: waveform trim, meter, ring, track card, record', (
    t,
  ) async {
    await golden(
      t,
      Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          WaveformView(
            peaks: _peaks,
            selection: (0.2, 0.7),
            onSelectionChanged: (_) {},
          ),
          TrackCard(
            title: 'TRACK 1',
            subtitle: '00:12',
            peaks: _peaks,
            progress: 0.3,
            playing: true,
            looping: true,
            onPlayStop: () {},
            onShare: () {},
          ),
          const Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              SizedBox(height: 60, child: UpMeter(level: 0.3)),
              SizedBox(height: 60, child: UpMeter(level: 0.7, peak: 0.8)),
              SizedBox(height: 60, child: UpMeter(level: 0.95, peak: 0.98)),
              UpProgressRing(progress: 0.66, scale: 0.4),
              RecordButton(recording: false, onPressed: null),
            ],
          ),
        ],
      ),
      'audio',
      surface: const Size(400, 520),
      size: const Size(380, 500),
    );
  });

  testWidgets('dialog, pairing, skin tiles', (t) async {
    await golden(
      t,
      Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          const UpDialog(
            title: 'Delete track?',
            message: 'This cannot be undone.',
            actions: [
              UpButton(label: 'Cancel', variant: UpButtonVariant.ghost),
              UpButton(label: 'Delete', variant: UpButtonVariant.danger),
            ],
          ),
          const PairingCodeDisplay(code: '482913'),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              for (final id in UpThemes.ids)
                SkinTile(
                  theme: UpThemes.byId(id),
                  name: id,
                  selected: id == 'neon',
                ),
            ],
          ),
        ],
      ),
      'dialog_hub_skins',
      surface: const Size(420, 520),
      size: const Size(400, 500),
    );
  });

  testWidgets('tab bar + segment tabs', (t) async {
    await golden(
      t,
      Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          UpSegmentTabs(
            labels: const ['Downloaded', 'Favorites', 'My kits'],
            index: 1,
            onChanged: (_) {},
          ),
          UpTabBar(
            items: const [
              UpTabItem(icon: Icons.library_music_rounded, label: 'Kits'),
              UpTabItem(icon: Icons.whatshot_rounded, label: 'Feed'),
              UpTabItem(icon: Icons.person_rounded, label: 'Profile'),
            ],
            index: 0,
            onChanged: (_) {},
          ),
        ],
      ),
      'tabs',
      surface: const Size(400, 160),
      size: const Size(380, 140),
    );
  });

  testWidgets('pairing input completes after 6 digits', (t) async {
    String? done;
    await t.pumpWidget(harness(PairingCodeInput(onCompleted: (v) => done = v)));
    await t.enterText(find.byType(TextField), '123456');
    expect(done, '123456');
  });
}
