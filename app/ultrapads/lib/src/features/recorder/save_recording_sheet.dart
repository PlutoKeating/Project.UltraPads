import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../state/engine_state.dart';
import '../catalog/catalog_state.dart';
import '../catalog/credits.dart';

/// 录音结束后的保存面板（参考设计 `Recorder/Main`：文件名 + `.flac` 后缀 + 时长 + 播放；
/// Save / Save and share / Cancel）。
Future<void> showSaveRecordingSheet(BuildContext context, TrackInfo track) =>
    showUpSheet<void>(
      context,
      builder: (_) => SaveRecordingSheet(track: track),
    );

class SaveRecordingSheet extends ConsumerStatefulWidget {
  const SaveRecordingSheet({super.key, required this.track});
  final TrackInfo track;

  @override
  ConsumerState<SaveRecordingSheet> createState() => _SaveRecordingSheetState();
}

class _SaveRecordingSheetState extends ConsumerState<SaveRecordingSheet> {
  late final _name = TextEditingController(text: widget.track.name);
  bool _playing = false;

  @override
  void dispose() {
    _name.dispose();
    if (_playing) tryEngine(ref.read(engineProvider).trackStop);
    super.dispose();
  }

  EngineClient get _engine => ref.read(engineProvider);

  Future<void> _save({bool share = false}) async {
    final l10n = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty) {
      showUpToast(context, l10n.errorNameEmpty);
      return;
    }
    if (name != widget.track.name) {
      await tryEngine(() => _engine.trackRename(widget.track.id, name));
    }
    if (!mounted) return;
    if (share) await shareTrack(context, ref, widget.track.id, name);
    if (!mounted) return;
    Navigator.of(context).pop();
    showUpToast(context, l10n.recordSaved);
  }

  Future<void> _discard() async {
    final l10n = context.l10n;
    final ok = await showUpConfirm(
      context,
      title: l10n.recordDiscardTitle,
      confirm: l10n.kitEditorDiscard,
      cancel: l10n.commonCancel,
      danger: true,
    );
    if (!ok) return;
    await tryEngine(() => _engine.trackDelete(widget.track.id));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final peaks = widget.track.waveform.isNotEmpty
        ? widget.track.waveform
        : ref
                  .watch(
                    waveformProvider((
                      sample: 'track:${widget.track.id}',
                      buckets: UpWaveformTokens.height.toInt(),
                    )),
                  )
                  .value ??
              const [];
    final credits = creditable(
      ref.watch(catalogAttributionsProvider(widget.track.kitName)),
    );
    final playback = ref.watch(trackPlaybackProvider).value;
    final progress =
        playback != null &&
            playback.trackId == widget.track.id &&
            widget.track.durationSecs > 0
        ? playback.positionSecs / widget.track.durationSecs
        : 0.0;
    return UpSheet(
      title: l10n.recordSaveTitle,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UpPageTokens.paddingX,
          ),
          child: Column(
            spacing: UpSpacing.lg,
            children: [
              Row(
                spacing: UpSpacing.sm,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _name,
                      style: UpTheme.of(context).text[UpTextRole.title],
                      cursorColor: c.inputCursor,
                      decoration: InputDecoration(
                        hintText: l10n.recordNameHint,
                        suffixText: '.flac',
                        suffixStyle: UpTheme.of(context).text[UpTextRole.body]
                            .copyWith(color: c.textSecondary),
                      ),
                    ),
                  ),
                  UpText(
                    _duration(widget.track.durationSecs),
                    role: UpTextRole.numeric,
                    color: c.textSecondary,
                  ),
                ],
              ),
              TrackCard(
                title: _name.text,
                peaks: peaks,
                progress: progress,
                playing: _playing,
                onPlayStop: () async {
                  setState(() => _playing = !_playing);
                  await tryEngine(
                    () => _playing
                        ? _engine.trackPlay(widget.track.id)
                        : _engine.trackStop(),
                  );
                },
              ),
              if (credits.isNotEmpty)
                _CreditsNotice(text: creditsText(l10n, credits)),
              UpButton(label: l10n.commonSave, expand: true, onPressed: _save),
              UpButton(
                label: l10n.recordSaveAndShare,
                variant: UpButtonVariant.outline,
                expand: true,
                onPressed: () => _save(share: true),
              ),
              UpButton(
                label: l10n.commonCancel,
                variant: UpButtonVariant.ghost,
                expand: true,
                onPressed: _discard,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _duration(double secs) {
  final s = secs.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// 导出作品到临时文件并打开系统分享。
Future<void> shareTrack(
  BuildContext context,
  WidgetRef ref,
  String trackId,
  String name,
) async {
  final l10n = context.l10n;
  final kitName =
      ref
          .read(tracksProvider)
          .value
          ?.where((t) => t.id == trackId)
          .map((t) => t.kitName)
          .firstOrNull ??
      '';
  final credits = creditable(ref.read(catalogAttributionsProvider(kitName)));
  final message = credits.isEmpty
      ? l10n.shareRecordingMessage(name)
      : '${l10n.shareRecordingMessage(name)}\n\n'
            '${l10n.shareExportCreditsShareText(creditsText(l10n, credits))}';
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}${Platform.pathSeparator}$name.flac';
  final ok = await tryEngineDo(
    () =>
        ref.read(engineProvider).trackExport(trackId, path, ExportFormat.flac),
  );
  if (!ok && context.mounted) {
    showUpToast(context, l10n.errorEngineUnsupported);
    return;
  }
  if (!File(path).existsSync()) {
    await SharePlus.instance.share(ShareParams(text: message));
    return;
  }
  await SharePlus.instance.share(
    ShareParams(files: [XFile(path)], text: message),
  );
}

/// 录音用了需要署名 / 带限制的目录素材时的提示（保存面板里）。
class _CreditsNotice extends StatelessWidget {
  const _CreditsNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = UpTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: UpSpacing.xs,
      children: [
        Row(
          spacing: UpSpacing.sm,
          children: [
            Icon(
              Icons.info_rounded,
              color: c.statusWarning,
              size: UpSizes.iconMd,
            ),
            Expanded(
              child: UpText(
                context.l10n.shareExportCreditsTitle,
                role: UpTextRole.titleSm,
                color: c.textPrimary,
                maxLines: 2,
              ),
            ),
          ],
        ),
        UpText(
          text,
          role: UpTextRole.bodySm,
          color: c.textSecondary,
          maxLines: 8,
        ),
      ],
    );
  }
}
