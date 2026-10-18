import 'package:flutter/material.dart';
import 'package:up_fx/up_fx.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../state/perform_state.dart';
import '../tutorial/tutorial_timing.dart';

/// 演奏页功能按钮行（4.7.0 `navButtons` / `navMoreButtons`）：
/// 默认显示「LEARN TO PLAY | ⋮」，点 ⋮ 后整行横移切换到
/// 录音 / 皮肤 / 编辑 / 分享 / 设置 / 返回。
class PerformToolbar extends StatelessWidget {
  const PerformToolbar({
    super.key,
    required this.expanded,
    required this.recording,
    required this.recordElapsed,
    required this.hasKit,
    required this.hasTutorial,
    required this.onExpand,
    required this.onTutorial,
    required this.onRecord,
    required this.onSkins,
    required this.onEdit,
    required this.onShare,
    required this.onSettings,
  });

  final bool expanded;
  final bool recording;
  final double recordElapsed;
  final bool hasKit;
  final bool hasTutorial;
  final ValueChanged<bool> onExpand;
  final VoidCallback onTutorial;
  final VoidCallback onRecord;
  final VoidCallback onSkins;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    // 录音中保持展开（录音按钮在展开行里）。
    final open = expanded || recording;
    final duration = FxMotion.duration(context, UpTopBarTokens.collapse);

    final main = Row(
      spacing: UpTopBarTokens.gap,
      children: [
        UpChip(
          label: l10n.performLearnToPlay,
          icon: Icons.school_rounded,
          variant: UpChipVariant.selected,
          onTap: hasTutorial ? onTutorial : null,
        ),
        Container(
          width: UpBorderWidths.hairline,
          height: UpChipTokens.height,
          color: c.borderDivider,
        ),
        UpIconButton(
          icon: Icons.more_vert_rounded,
          semanticLabel: l10n.performMoreOptions,
          onPressed: () => onExpand(true),
        ),
      ],
    );

    Widget tool(IconData icon, String label, VoidCallback? onTap) => Tooltip(
      message: label,
      child: UpIconButton(icon: icon, semanticLabel: label, onPressed: onTap),
    );

    final more = Row(
      spacing: UpTopBarTokens.gap,
      children: [
        RecordButton(
          recording: recording,
          onPressed: hasKit ? onRecord : null,
          elapsedLabel: l10n.loadSoundElapsed(recordElapsed.floor()),
          semanticLabel: recording
              ? l10n.performStopRecording
              : l10n.performRecord,
        ),
        tool(Icons.palette_rounded, l10n.performSkins, onSkins),
        tool(Icons.edit_rounded, l10n.performEditKit, hasKit ? onEdit : null),
        tool(
          Icons.ios_share_rounded,
          l10n.performShareKit,
          hasKit ? onShare : null,
        ),
        tool(Icons.settings_rounded, l10n.navSettings, onSettings),
        tool(
          Icons.chevron_left_rounded,
          l10n.performBackToTools,
          recording ? null : () => onExpand(false),
        ),
      ],
    );

    return Container(
      color: c.surfaceSunken,
      padding: const EdgeInsets.symmetric(horizontal: UpTopBarTokens.paddingX),
      child: ClipRect(
        // 4.7.0：整行横移切换（收起 0.3 s CircIn，展开 0.3 s CircOut）。
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSlide(
                offset: open ? const Offset(-1, 0) : Offset.zero,
                duration: duration,
                curve: open
                    ? UpTopBarTokens.collapseCurve
                    : UpTopBarTokens.expandCurve,
                child: IgnorePointer(
                  ignoring: open,
                  child: Align(alignment: Alignment.centerLeft, child: main),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedSlide(
                offset: open ? Offset.zero : const Offset(1, 0),
                duration: duration,
                curve: open
                    ? UpTopBarTokens.expandCurve
                    : UpTopBarTokens.collapseCurve,
                child: IgnorePointer(
                  ignoring: !open,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: more,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 教程模式的功能行：▶/■（时间轴播放 / 暂停）+ 可拖动进度条 + 退出。
class TutorialToolbar extends StatelessWidget {
  const TutorialToolbar({
    super.key,
    required this.session,
    required this.onPlayPause,
    required this.onSeek,
    required this.onExit,
  });

  final TutorialSession session;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final playing = session.playing && !session.completed;
    return Container(
      color: c.surfaceSunken,
      padding: const EdgeInsets.symmetric(horizontal: UpTopBarTokens.paddingX),
      child: Row(
        spacing: UpSpacing.md,
        children: [
          UpIconButton(
            icon: playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
            semanticLabel: playing ? l10n.commonStop : l10n.tutorialPlayDemo,
            onPressed: onPlayPause,
          ),
          Expanded(
            child: UpSlider(
              value: session.progress,
              onChanged: onSeek,
              semanticLabel: session.timed
                  ? l10n.tutorialProgress((session.progress * 100).round())
                  : l10n.tutorialStep(session.step + 1, session.total),
            ),
          ),
          UpIconButton(
            icon: Icons.close_rounded,
            semanticLabel: l10n.tutorialExit,
            onPressed: onExit,
          ),
        ],
      ),
    );
  }
}

/// 速度选择框（4.7.0 `modalVelocities`：1.0 normal / 0.7 slow / 0.5 very slow）。
Future<double?> showSpeedModal(
  BuildContext context, {
  required double current,
}) {
  final l10n = context.l10n;
  final labels = [
    l10n.performSpeedNormal,
    l10n.performSpeedSlow,
    l10n.performSpeedVerySlow,
  ];
  return showUpDialog<double>(
    context,
    builder: (ctx) => UpDialog(
      title: l10n.performSpeed(current),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: UpSheetTokens.itemGap,
        children: [
          for (var i = 0; i < TutorialTiming.speeds.length; i++)
            UpListItem(
              title:
                  '${l10n.performSpeedValue(TutorialTiming.speeds[i])}  ${labels[i]}',
              trailing: TutorialTiming.speeds[i] == current
                  ? Icon(
                      Icons.check_rounded,
                      color: UpTheme.of(ctx).colors.accentPrimary,
                    )
                  : null,
              onTap: () => Navigator.pop(ctx, TutorialTiming.speeds[i]),
            ),
        ],
      ),
    ),
  );
}
