import 'package:flutter/widgets.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';

/// 竖条波形（CustomPainter）。可选：播放进度、裁剪选区（可拖动首尾标记）。
class WaveformView extends StatelessWidget {
  const WaveformView({
    super.key,
    required this.peaks,
    this.progress = 0,
    this.playedColor,
    this.unplayedColor,
    this.selection,
    this.onSelectionChanged,
    this.height = UpWaveformTokens.height,
  });

  /// 峰值 0..1。
  final List<double> peaks;

  /// 0..1；之前的条用 [playedColor]。
  final double progress;
  final Color? playedColor;
  final Color? unplayedColor;

  /// 裁剪选区（0..1 的起止）。
  final (double, double)? selection;
  final ValueChanged<(double, double)>? onSelectionChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final painter = WaveformPainter(
      peaks: peaks,
      progress: progress,
      played: playedColor ?? c.waveformActive,
      unplayed: unplayedColor ?? c.waveformInactive,
      selection: selection,
      selectionColor: c.waveformSelection,
      markerColor: c.waveformMarker,
    );
    final paint = CustomPaint(
      size: Size(double.infinity, height),
      painter: painter,
    );
    Widget child = paint;
    final onSel = onSelectionChanged;
    final sel = selection;
    if (onSel != null && sel != null) {
      child = LayoutBuilder(
        builder: (context, box) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) {
            final t = (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0);
            final (s, e) = sel;
            // 拖动离得近的那个标记
            if ((t - s).abs() <= (t - e).abs()) {
              onSel((t.clamp(0.0, e), e));
            } else {
              onSel((s, t.clamp(s, 1.0)));
            }
          },
          child: paint,
        ),
      );
    }
    return SizedBox(height: height, child: child);
  }
}

class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.peaks,
    required this.progress,
    required this.played,
    required this.unplayed,
    this.selection,
    required this.selectionColor,
    required this.markerColor,
  });

  final List<double> peaks;
  final double progress;
  final Color played;
  final Color unplayed;
  final (double, double)? selection;
  final Color selectionColor;
  final Color markerColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty || size.isEmpty) return;
    const bar = UpWaveformTokens.barWidth;
    const gap = UpWaveformTokens.barGap;
    final count = ((size.width + gap) / (bar + gap)).floor().clamp(1, 1 << 16);
    final step = (size.width - bar) / (count > 1 ? count - 1 : 1);
    final mid = size.height / 2;
    final playedPaint = Paint()..color = played;
    final unplayedPaint = Paint()..color = unplayed;

    final sel = selection;
    if (sel != null) {
      final (s, e) = sel;
      canvas.drawRect(
        Rect.fromLTRB(s * size.width, 0, e * size.width, size.height),
        Paint()..color = selectionColor,
      );
    }

    for (var i = 0; i < count; i++) {
      final t = count == 1 ? 0.0 : i / (count - 1);
      final peak = peaks[(t * (peaks.length - 1)).round()].clamp(0.0, 1.0);
      final h = (peak * size.height).clamp(
        UpWaveformTokens.minBarHeight,
        size.height,
      );
      final x = i * step;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, mid - h / 2, bar, h),
          const Radius.circular(UpWaveformTokens.barRadius),
        ),
        t <= progress ? playedPaint : unplayedPaint,
      );
    }

    if (sel != null) {
      final m = Paint()..color = markerColor;
      for (final v in [sel.$1, sel.$2]) {
        canvas.drawRect(
          Rect.fromLTWH(
            v * size.width - UpWaveformTokens.markerWidth / 2,
            0,
            UpWaveformTokens.markerWidth,
            size.height,
          ),
          m,
        );
      }
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.peaks != peaks ||
      old.progress != progress ||
      old.selection != selection ||
      old.played != played ||
      old.unplayed != unplayed;
}
