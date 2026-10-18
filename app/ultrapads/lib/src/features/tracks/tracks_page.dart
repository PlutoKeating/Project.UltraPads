import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../state/engine_state.dart';
import '../recorder/save_recording_sheet.dart';

/// 我的录音：TRACK 卡列表（播放 / 循环 / 分享导出 / 重命名 / 删除）。
class TracksPage extends ConsumerStatefulWidget {
  const TracksPage({super.key});

  @override
  ConsumerState<TracksPage> createState() => _TracksPageState();
}

class _TracksPageState extends ConsumerState<TracksPage> {
  final Set<String> _looping = {};

  EngineClient get _engine => ref.read(engineProvider);

  Future<void> _more(TrackInfo t) async {
    final l10n = context.l10n;
    final action = await showUpSheet<int>(
      context,
      builder: (ctx) => UpSheet(
        title: t.name,
        children: [
          for (final (i, icon, label) in [
            (0, Icons.edit_rounded, l10n.commonRename),
            (1, Icons.ios_share_rounded, l10n.worksExportWav),
            (2, Icons.delete_rounded, l10n.commonDelete),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: UpPageTokens.paddingX,
              ),
              child: UpListItem(
                icon: icon,
                title: label,
                onTap: () => Navigator.pop(ctx, i),
              ),
            ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 0:
        final name = await _rename(t);
        if (name != null) {
          await tryEngine(() => _engine.trackRename(t.id, name));
        }
      case 1:
        await shareTrack(context, ref, t.id, t.name);
      case 2:
        final ok = await showUpConfirm(
          context,
          title: l10n.worksDeleteTitle,
          message: l10n.worksDeleteBody(t.name),
          confirm: l10n.commonDelete,
          cancel: l10n.commonCancel,
          danger: true,
        );
        if (ok) await tryEngine(() => _engine.trackDelete(t.id));
    }
  }

  Future<String?> _rename(TrackInfo t) {
    final l10n = context.l10n;
    final ctrl = TextEditingController(text: t.name);
    return showUpDialog<String>(
      context,
      builder: (ctx) => UpDialog(
        title: l10n.worksRenameTitle,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.recordNameHint),
        ),
        actions: [
          UpButton(
            label: l10n.commonCancel,
            variant: UpButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx),
          ),
          UpButton(
            label: l10n.commonSave,
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final tracks = ref.watch(tracksProvider);
    final playback = ref.watch(trackPlaybackProvider).value;
    return Scaffold(
      backgroundColor: c.surfacePage,
      body: SafeArea(
        child: Column(
          children: [
            UpTopBar(
              leading: UpIconButton(
                icon: Icons.arrow_back_rounded,
                semanticLabel: l10n.commonBack,
                onPressed: () => context.pop(),
              ),
              title: l10n.worksTitle,
              centerTitle: true,
            ),
            Expanded(
              child: tracks.when(
                loading: () => const Center(child: UpProgressRing()),
                error: (e, _) => Center(
                  child: UpText(
                    e is EngineNotImplemented
                        ? l10n.errorEngineUnsupported
                        : l10n.errorGeneric,
                    role: UpTextRole.body,
                    color: c.textSecondary,
                  ),
                ),
                data: (list) => list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(UpSpacing.xxxl),
                          child: UpText(
                            l10n.worksEmpty,
                            role: UpTextRole.body,
                            color: c.textSecondary,
                            align: TextAlign.center,
                            maxLines: 3,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(UpPageTokens.paddingX),
                        itemCount: list.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: UpSpacing.lg),
                        itemBuilder: (_, i) {
                          final t = list[i];
                          final playing =
                              playback != null &&
                              playback.playing &&
                              playback.trackId == t.id;
                          final peaks = t.waveform.isNotEmpty
                              ? t.waveform
                              : ref
                                        .watch(
                                          waveformProvider((
                                            sample: 'track:${t.id}',
                                            buckets: UpWaveformTokens.height
                                                .toInt(),
                                          )),
                                        )
                                        .value ??
                                    const [];
                          return TrackCard(
                            title: t.name,
                            subtitle: l10n.worksRecordedOn(t.createdAt),
                            peaks: peaks,
                            playing: playing,
                            looping: _looping.contains(t.id),
                            progress: playing && t.durationSecs > 0
                                ? playback.positionSecs / t.durationSecs
                                : 0,
                            labels: TrackCardLabels(
                              play: l10n.commonPlay,
                              stop: l10n.commonStop,
                              loop: l10n.worksLoop,
                              share: l10n.commonShare,
                              more: l10n.performMoreOptions,
                            ),
                            onPlayStop: () => tryEngine(
                              () => playing
                                  ? _engine.trackStop()
                                  : _engine.trackPlay(
                                      t.id,
                                      loop: _looping.contains(t.id),
                                    ),
                            ),
                            onLoop: () => setState(
                              () => _looping.contains(t.id)
                                  ? _looping.remove(t.id)
                                  : _looping.add(t.id),
                            ),
                            onShare: () =>
                                shareTrack(context, ref, t.id, t.name),
                            onMore: () => _more(t),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
