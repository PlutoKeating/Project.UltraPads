import 'package:flutter/widgets.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';

/// 电平表（竖直或水平）。颜色按阈值：低 / 中 / 高，外加峰值线。
class UpMeter extends StatelessWidget {
  const UpMeter({
    super.key,
    required this.level,
    this.peak,
    this.axis = Axis.vertical,
  });

  final double level;
  final double? peak;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final v = level.clamp(0.0, 1.0);
    final color = v >= UpMeterTokens.highThreshold
        ? c.meterHigh
        : v >= UpMeterTokens.midThreshold
        ? c.meterMid
        : c.meterLow;
    final vertical = axis == Axis.vertical;
    return ClipRRect(
      borderRadius: BorderRadius.circular(UpMeterTokens.radius),
      child: SizedBox(
        width: vertical ? UpMeterTokens.width : null,
        height: vertical ? null : UpMeterTokens.width,
        child: CustomPaint(
          painter: _MeterPainter(
            v,
            peak,
            color,
            c.meterTrack,
            c.meterPeak,
            vertical,
          ),
        ),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  _MeterPainter(
    this.level,
    this.peak,
    this.color,
    this.track,
    this.peakColor,
    this.vertical,
  );
  final double level;
  final double? peak;
  final Color color;
  final Color track;
  final Color peakColor;
  final bool vertical;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = track);
    final fill = vertical
        ? Rect.fromLTRB(0, size.height * (1 - level), size.width, size.height)
        : Rect.fromLTRB(0, 0, size.width * level, size.height);
    canvas.drawRect(fill, Paint()..color = color);
    final p = peak;
    if (p != null) {
      final paint = Paint()
        ..color = peakColor
        ..strokeWidth = UpMeterTokens.segmentGap;
      if (vertical) {
        final y = size.height * (1 - p.clamp(0.0, 1.0));
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      } else {
        final x = size.width * p.clamp(0.0, 1.0);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MeterPainter old) =>
      old.level != level || old.peak != peak || old.color != color;
}
