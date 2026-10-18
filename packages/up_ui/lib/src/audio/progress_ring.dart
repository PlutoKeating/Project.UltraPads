import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';

/// 进度环（下载 / 加载 Kit）：内半径 64，厚 8。progress 为 null 时不定进度旋转。
class UpProgressRing extends StatefulWidget {
  const UpProgressRing({super.key, this.progress, this.child, this.scale = 1});

  final double? progress;
  final Widget? child;

  /// 缩放（列表内的小号环）。
  final double scale;

  @override
  State<UpProgressRing> createState() => _UpProgressRingState();
}

class _UpProgressRingState extends State<UpProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: UpProgressRingTokens.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(UpProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final spin = widget.progress == null && !UpMotion.reduced(context);
    if (spin && !_spin.isAnimating) _spin.repeat();
    if (!spin && _spin.isAnimating) _spin.stop();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final thickness = UpProgressRingTokens.thickness * widget.scale;
    final d = (UpProgressRingTokens.innerRadius * widget.scale + thickness) * 2;
    return SizedBox.square(
      dimension: d,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.progress ?? 0),
        duration: UpMotion.duration(context, UpDurations.medium),
        curve: UpProgressRingTokens.curve,
        builder: (context, p, child) => AnimatedBuilder(
          animation: _spin,
          builder: (context, _) => CustomPaint(
            painter: _RingPainter(
              progress: widget.progress == null ? null : p,
              spin: _spin.value,
              thickness: thickness,
              track: c.progressRingTrack,
              fill: c.progressRingFill,
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.spin,
    required this.thickness,
    required this.track,
    required this.fill,
  });

  final double? progress;
  final double spin;
  final double thickness;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(thickness / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, base..color = track);
    final p = progress;
    final start = -math.pi / 2 + (p == null ? spin * math.pi * 2 : 0);
    final sweep = p == null ? math.pi / 2 : math.pi * 2 * p.clamp(0.0, 1.0);
    canvas.drawArc(rect, start, sweep, false, base..color = fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.spin != spin || old.fill != fill;
}
