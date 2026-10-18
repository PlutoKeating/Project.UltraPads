import 'package:flutter/material.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';
import 'waveform.dart';

/// 作品卡（截图 5：TRACK 1、⤮ 循环、□ 分享 / 导出、■ 播放停止、波形）。
class TrackCard extends StatelessWidget {
  const TrackCard({
    super.key,
    required this.title,
    required this.peaks,
    this.subtitle,
    this.progress = 0,
    this.playing = false,
    this.looping = false,
    this.onPlayStop,
    this.onLoop,
    this.onShare,
    this.onMore,
    this.labels = const TrackCardLabels(),
  });

  final String title;
  final String? subtitle;
  final List<double> peaks;
  final double progress;
  final bool playing;
  final bool looping;
  final VoidCallback? onPlayStop;
  final VoidCallback? onLoop;
  final VoidCallback? onShare;
  final VoidCallback? onMore;
  final TrackCardLabels labels;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    return Container(
      padding: const EdgeInsets.all(UpTrackCardTokens.padding),
      decoration: BoxDecoration(
        color: c.recordTrackCard,
        borderRadius: BorderRadius.circular(UpTrackCardTokens.radius),
        boxShadow: UpTrackCardTokens.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: UpTrackCardTokens.gap,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UpText(
                      title,
                      role: UpTextRole.headline,
                      color: c.textPrimary,
                    ),
                    if (subtitle != null)
                      UpText(
                        subtitle!,
                        role: UpTextRole.caption,
                        color: c.textSecondary,
                      ),
                  ],
                ),
              ),
              _Icon(
                icon: Icons.repeat_rounded,
                active: looping,
                onTap: onLoop,
                label: labels.loop,
              ),
              _Icon(
                icon: Icons.ios_share_rounded,
                onTap: onShare,
                label: labels.share,
              ),
              if (onMore != null)
                _Icon(
                  icon: Icons.more_vert_rounded,
                  onTap: onMore,
                  label: labels.more,
                ),
            ],
          ),
          const Divider(
            height: UpBorderWidths.hairline,
            thickness: UpBorderWidths.hairline,
          ),
          Row(
            spacing: UpTransportTokens.gap,
            children: [
              Semantics(
                button: true,
                label: playing ? labels.stop : labels.play,
                child: GestureDetector(
                  onTap: onPlayStop,
                  child: Container(
                    width: UpTransportTokens.stopSize,
                    height: UpTransportTokens.stopSize,
                    decoration: BoxDecoration(
                      color: c.transportStopBackground,
                      borderRadius: BorderRadius.circular(UpRadii.md),
                    ),
                    child: Icon(
                      playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: c.transportStopIcon,
                      size: UpSizes.iconMd,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: WaveformView(
                  peaks: peaks,
                  progress: progress,
                  playedColor: c.transportWaveformPlayed,
                  unplayedColor: c.transportWaveformUnplayed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// TrackCard 的无障碍标签（由应用从 i18n 传入）。
@immutable
class TrackCardLabels {
  const TrackCardLabels({
    this.play,
    this.stop,
    this.loop,
    this.share,
    this.more,
  });
  final String? play;
  final String? stop;
  final String? loop;
  final String? share;
  final String? more;
}

class _Icon extends StatelessWidget {
  const _Icon({
    required this.icon,
    this.onTap,
    this.active = false,
    this.label,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    return Semantics(
      label: label,
      button: true,
      toggled: active,
      child: PressScale(
        onTap: onTap,
        child: SizedBox.square(
          dimension: UpIconButtonTokens.size,
          child: Icon(
            icon,
            size: UpIconButtonTokens.iconSize,
            color: active ? c.accentPrimary : c.iconSecondary,
          ),
        ),
      ),
    );
  }
}
