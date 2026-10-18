import 'package:flutter/material.dart';
import 'package:up_tokens/up_tokens.dart';

import '../audio/waveform.dart';
import '../util.dart';

/// 传输栏：停止全部 + 进度/波形（截图 2：■ ▮▮▮▮|||||）。
class TransportBar extends StatelessWidget {
  const TransportBar({
    super.key,
    required this.progress,
    required this.onStop,
    this.peaks,
    this.active = false,
    this.trailing,
    this.stopLabel,
  });

  /// 当前小节/作品进度 0..1。
  final double progress;
  final VoidCallback? onStop;

  /// 波形峰值；为空时画进度条。
  final List<double>? peaks;

  /// 是否有声音在播（停止按钮高亮）。
  final bool active;
  final Widget? trailing;
  final String? stopLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    return SizedBox(
      height: UpTransportTokens.height,
      child: Row(
        spacing: UpTransportTokens.gap,
        children: [
          Semantics(
            label: stopLabel,
            button: true,
            child: PressScale(
              onTap: onStop,
              child: AnimatedContainer(
                duration: UpMotion.duration(context, UpDurations.fast),
                width: UpTransportTokens.stopSize,
                height: UpTransportTokens.stopSize,
                decoration: BoxDecoration(
                  color: c.transportStopBackground,
                  borderRadius: BorderRadius.circular(UpRadii.md),
                ),
                child: Icon(
                  Icons.stop_rounded,
                  color: active ? c.transportStopIcon : c.iconSecondary,
                  size: UpSizes.iconMd,
                ),
              ),
            ),
          ),
          Expanded(
            child: peaks != null
                ? WaveformView(
                    peaks: peaks!,
                    progress: progress,
                    playedColor: c.transportWaveformPlayed,
                    unplayedColor: c.transportWaveformUnplayed,
                  )
                : _ProgressLine(progress: progress),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final x = w * progress.clamp(0.0, 1.0);
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: UpSliderTokens.trackHeight,
              color: c.transportProgressTrack,
            ),
            Container(
              height: UpSliderTokens.trackHeight,
              width: x,
              color: c.transportProgressFill,
            ),
            Positioned(
              left: x - UpSliderTokens.thumbSize / 2,
              child: Container(
                width: UpSliderTokens.thumbSize,
                height: UpSliderTokens.thumbSize,
                decoration: BoxDecoration(
                  color: c.transportThumb,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 教程进度条（36dp，可拖动跳步）。
class TutorialBar extends StatelessWidget {
  const TutorialBar({
    super.key,
    required this.step,
    required this.total,
    required this.onSeek,
    this.label,
  });

  final int step;
  final int total;
  final ValueChanged<int> onSeek;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final max = total <= 1 ? 1 : total - 1;
    return Container(
      height: UpTutorialTokens.barHeight,
      color: c.surfaceToolbar,
      padding: const EdgeInsets.symmetric(horizontal: UpSpacing.xxl),
      child: Row(
        spacing: UpSpacing.md,
        children: [
          if (label != null)
            UpText(label!, role: UpTextRole.labelSm, color: c.textSecondary),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                int at(double dx) =>
                    ((dx / box.maxWidth) * max).round().clamp(0, max);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => onSeek(at(d.localPosition.dx)),
                  onHorizontalDragUpdate: (d) => onSeek(at(d.localPosition.dx)),
                  child: _ProgressLine(progress: step / max),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
