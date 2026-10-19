import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../split/model_store.dart';
import '../../split/split_controller.dart';
import '../../state/engine_state.dart';
import '../../state/library_state.dart';

/// 导入歌曲并拆成 Kit 的面板：一个音色组 = 歌曲的一个完整段落，组内一个 pad = 一个乐器。
/// 全程在本机处理，云端不参与。
Future<void> showSplitSongSheet(BuildContext context, String path) =>
    showUpSheet<void>(context, builder: (_) => SplitSongSheet(path: path));

class SplitSongSheet extends ConsumerStatefulWidget {
  const SplitSongSheet({super.key, required this.path});
  final String path;

  @override
  ConsumerState<SplitSongSheet> createState() => _SplitSongSheetState();
}

class _SplitSongSheetState extends ConsumerState<SplitSongSheet> {
  bool _separate = true;
  late final SplitController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ref.read(splitProvider.notifier);
  }

  String get _name {
    final base = widget.path.split(Platform.pathSeparator).last;
    final dot = base.lastIndexOf('.');
    return dot > 0 ? base.substring(0, dot) : base;
  }

  @override
  void dispose() {
    // 面板关闭时不再保留已结束的状态
    Future.microtask(_ctrl.reset);
    super.dispose();
  }

  String _failureText(String f) {
    final l10n = context.l10n;
    final tag = RegExp(r'^\[([a-z_]+)\]').firstMatch(f)?.group(1);
    return switch (tag) {
      'cancelled' => l10n.librarySplitCancelled,
      'too_short' => l10n.librarySplitErrorTooShort,
      'no_grid' => l10n.librarySplitErrorNoGrid,
      'insufficient_memory' => l10n.librarySplitErrorMemory,
      'decode' => l10n.librarySplitErrorDecode,
      'model' => l10n.librarySplitErrorModel,
      _ when f == 'model_checksum' => l10n.librarySplitErrorModelChecksum,
      _ when f.startsWith('model_') => l10n.librarySplitErrorModelDownload,
      _ => l10n.librarySplitErrorGeneric,
    };
  }

  String _stageText(SplitUiState s) {
    final l10n = context.l10n;
    final pct = ((s.fraction ?? 0) * 100).round();
    if (s.phase == SplitPhase.downloadingModel) {
      return l10n.librarySplitStageDownloadingModel(pct);
    }
    return switch (s.stage) {
      null || SplitStage.decoding => l10n.librarySplitStageDecoding,
      SplitStage.loadingModel => l10n.librarySplitStageLoadingModel,
      SplitStage.analyzing => l10n.librarySplitStageAnalyzing,
      SplitStage.separating => l10n.librarySplitStageSeparating(pct),
      SplitStage.building => l10n.librarySplitStageBuilding,
      SplitStage.importing => l10n.librarySplitStageImporting,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final s = ref.watch(splitProvider);
    final caps = ref.watch(engineProvider).splitCapabilities();
    final installed = ref.watch(modelInstalledProvider).value ?? false;
    final modelMb = (demucsModel.bytes / (1024 * 1024)).round();
    final needGb = (caps.separationMemoryMb / 1024).toStringAsFixed(1);
    final canSeparate = caps.separationAvailable;
    final separate = _separate && canSeparate;

    Widget body;
    if (s.busy) {
      body = Column(
        spacing: UpSpacing.lg,
        children: [
          const UpProgressRing(),
          UpText(_stageText(s), role: UpTextRole.body, color: c.textSecondary),
          UpButton(
            label: l10n.commonCancel,
            variant: UpButtonVariant.ghost,
            expand: true,
            onPressed: ref.read(splitProvider.notifier).cancel,
          ),
        ],
      );
    } else if (s.phase == SplitPhase.done) {
      final d = s.done!;
      body = Column(
        spacing: UpSpacing.lg,
        children: [
          UpText(
            l10n.librarySplitDone(d.kit.name, d.sections, d.bpm.round()),
            role: UpTextRole.body,
          ),
          if (!d.reliable)
            UpText(
              l10n.librarySplitUnreliable,
              role: UpTextRole.labelSm,
              color: c.textSecondary,
            ),
          UpButton(
            label: l10n.librarySplitLoadKit,
            expand: true,
            onPressed: () async {
              final nav = Navigator.of(context);
              await ref.read(kitLoadProvider.notifier).load(d.kit.id);
              nav.pop();
            },
          ),
          UpButton(
            label: l10n.commonDone,
            variant: UpButtonVariant.outline,
            expand: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    } else {
      body = Column(
        spacing: UpSpacing.lg,
        children: [
          UpText(_name, role: UpTextRole.title),
          UpText(
            l10n.librarySplitIntro,
            role: UpTextRole.labelSm,
            color: c.textSecondary,
          ),
          UpListItem(
            icon: separate
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            title: l10n.librarySplitModeSeparate,
            subtitle: canSeparate
                ? (installed
                      ? l10n.librarySplitModeSeparateReady(needGb)
                      : l10n.librarySplitModeSeparateDownload(modelMb, needGb))
                : l10n.librarySplitModeSeparateNoMemory(needGb),
            enabled: canSeparate,
            onTap: () => setState(() => _separate = true),
          ),
          UpListItem(
            icon: !separate
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            title: l10n.librarySplitModeQuick,
            subtitle: l10n.librarySplitModeQuickHint,
            onTap: () => setState(() => _separate = false),
          ),
          if (s.phase == SplitPhase.failed)
            UpText(
              _failureText(s.failure ?? ''),
              role: UpTextRole.labelSm,
              color: c.textSecondary,
            ),
          UpButton(
            label: l10n.librarySplitStart,
            expand: true,
            onPressed: () => ref
                .read(splitProvider.notifier)
                .start(path: widget.path, separate: separate, title: _name),
          ),
        ],
      );
    }
    return UpSheet(
      title: l10n.librarySplitTitle,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UpPageTokens.paddingX,
          ),
          child: body,
        ),
      ],
    );
  }
}
