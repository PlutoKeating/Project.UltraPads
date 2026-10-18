import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../state/engine_state.dart';

/// 从某个 Kit 里选一个采样（LOAD SOUND →「内置歌曲」/「我的 Kit」）。
Future<SampleInfo?> pickKitSample(
  BuildContext context,
  WidgetRef ref, {
  bool ownKitsOnly = false,
}) async {
  final kits =
      await tryEngine(ref.read(engineProvider).libraryListKits) ??
      const <KitSummary>[];
  if (!context.mounted) return null;
  final list = kits
      .where((k) => !ownKitsOnly || k.source != KitSource.builtin)
      .toList();
  final kit = await showUpSheet<KitSummary>(
    context,
    builder: (ctx) => UpSheet(
      title: ownKitsOnly
          ? ctx.l10n.libraryMyKits
          : ctx.l10n.loadSoundSourceSongs,
      children: [
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(UpSpacing.xxl),
            child: UpText(
              ctx.l10n.libraryEmpty,
              role: UpTextRole.body,
              color: UpTheme.of(ctx).colors.textSecondary,
              maxLines: 3,
            ),
          ),
        for (final k in list)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UpPageTokens.paddingX,
            ),
            child: KitCard(
              title: k.name,
              subtitle: k.song,
              role: k.color.index,
              onTap: () => Navigator.pop(ctx, k),
            ),
          ),
      ],
    ),
  );
  if (kit == null || !context.mounted) return null;
  final samples =
      await tryEngine(
        () => ref.read(engineProvider).libraryKitSamples(kit.id),
      ) ??
      const <SampleInfo>[];
  if (!context.mounted) return null;
  return showUpSheet<SampleInfo>(
    context,
    builder: (ctx) => UpSheet(
      title: ctx.l10n.loadSoundPickSample,
      children: [
        for (final s in samples)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UpPageTokens.paddingX,
            ),
            child: UpListItem(
              icon: Icons.graphic_eq_rounded,
              title: s.name,
              subtitle: ctx.l10n.unitSeconds(s.durationSecs.round()),
              trailing: UpIconButton(
                icon: Icons.play_arrow_rounded,
                semanticLabel: ctx.l10n.kitEditorPreview,
                onPressed: () => tryEngine(
                  () => ref.read(engineProvider).samplePreview(s.id),
                ),
              ),
              onTap: () => Navigator.pop(ctx, s),
            ),
          ),
      ],
    ),
  );
}

/// 从录音作品里选一段（LOAD SOUND →「录音」）。作品以 `track:<id>` 作为采样 id。
Future<SampleInfo?> pickRecordingSample(
  BuildContext context,
  WidgetRef ref,
) async {
  final tracks =
      await tryEngine(ref.read(engineProvider).tracksList) ??
      const <TrackInfo>[];
  if (!context.mounted) return null;
  return showUpSheet<SampleInfo>(
    context,
    builder: (ctx) => UpSheet(
      title: ctx.l10n.loadSoundSourceRecordings,
      children: [
        if (tracks.isEmpty)
          Padding(
            padding: const EdgeInsets.all(UpSpacing.xxl),
            child: UpText(
              ctx.l10n.worksEmpty,
              role: UpTextRole.body,
              color: UpTheme.of(ctx).colors.textSecondary,
              maxLines: 3,
            ),
          ),
        for (final t in tracks)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UpPageTokens.paddingX,
            ),
            child: UpListItem(
              icon: Icons.mic_external_on_rounded,
              title: t.name,
              subtitle: ctx.l10n.unitSeconds(t.durationSecs.round()),
              onTap: () => Navigator.pop(
                ctx,
                SampleInfo(
                  id: 'track:${t.id}',
                  name: t.name,
                  durationSecs: t.durationSecs,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
