import 'package:flutter/material.dart';
import 'package:up_fx/up_fx.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

/// 演奏页功能按钮行（4.7.0 `navButtons` / `navMoreButtons` 的位置）：
/// 默认显示「音色组 A B C… | ⋮」，点 ⋮ 后整行横移切换到
/// 录音 / 皮肤 / 编辑 / 分享 / 返回（设置入口在顶栏右上角）。
class PerformToolbar extends StatelessWidget {
  const PerformToolbar({
    super.key,
    required this.expanded,
    required this.recording,
    required this.recordElapsed,
    required this.hasKit,
    required this.groupCount,
    required this.group,
    required this.onGroup,
    required this.onExpand,
    required this.onRecord,
    required this.onSkins,
    required this.onEdit,
    required this.onShare,
    this.groupsKey,
    this.moreKey,
  });

  final bool expanded;
  final bool recording;
  final double recordElapsed;
  final bool hasKit;

  /// 当前歌曲的音色组数与正在显示的组（0 = A）。
  final int groupCount;
  final int group;
  final ValueChanged<int> onGroup;
  final ValueChanged<bool> onExpand;
  final VoidCallback onRecord;
  final VoidCallback onSkins;
  final VoidCallback onEdit;
  final VoidCallback onShare;

  /// 首次引导用来定位音色组切换条和 ⋮ 的 key（可选）。
  final Key? groupsKey;
  final Key? moreKey;

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
        Flexible(
          child: PadGroupSwitcher(
            key: groupsKey,
            count: groupCount,
            selected: group,
            onSelect: onGroup,
            semanticLabelOf: l10n.performSoundGroup,
          ),
        ),
        Container(
          width: UpBorderWidths.hairline,
          height: UpChipTokens.height,
          color: c.borderDivider,
        ),
        UpIconButton(
          key: moreKey,
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
