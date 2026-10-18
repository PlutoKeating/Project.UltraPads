import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'shaders.dart';
import 'tier.dart';

/// 按下波纹：[progress] 0..1 由调用方的动画驱动，[center] 为触点。
/// 着色器不可用时画一个淡出的圆。
class PressRipple extends StatelessWidget {
  const PressRipple({
    super.key,
    required this.progress,
    required this.center,
    required this.color,
    required this.radius,
    required this.peakOpacity,
  });

  final double progress;
  final Offset center;
  final Color color;
  final double radius;
  final double peakOpacity;

  @override
  Widget build(BuildContext context) {
    final tier = FxScope.tierOf(context);
    if (tier == FxTier.minimal || progress <= 0 || progress >= 1) {
      return const SizedBox.expand();
    }
    final program = tier == FxTier.full ? FxShaders.instance.ripple : null;
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _RipplePainter(
          program,
          progress,
          center,
          color,
          radius,
          peakOpacity,
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(
    this.program,
    this.progress,
    this.center,
    this.color,
    this.radius,
    this.peak,
  );

  final ui.FragmentProgram? program;
  final double progress;
  final Offset center;
  final Color color;
  final double radius;
  final double peak;

  @override
  void paint(Canvas canvas, Size size) {
    final p = program;
    final rect = Offset.zero & size;
    if (p == null) {
      final r = size.longestSide * progress;
      canvas
        ..save()
        ..clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)))
        ..drawCircle(
          center,
          r,
          Paint()
            ..color = color.withValues(alpha: color.a * peak * (1 - progress)),
        )
        ..restore();
      return;
    }
    final shader = p.fragmentShader();
    var i = 0;
    shader
      ..setFloat(i++, size.width)
      ..setFloat(i++, size.height)
      ..setFloat(i++, center.dx)
      ..setFloat(i++, center.dy)
      ..setFloat(i++, progress)
      ..setFloat(i++, radius)
      ..setFloat(i++, color.r)
      ..setFloat(i++, color.g)
      ..setFloat(i++, color.b)
      ..setFloat(i++, color.a)
      ..setFloat(i++, peak);
    canvas.drawRect(rect, Paint()..shader = shader);
    shader.dispose();
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.progress != progress || old.center != center || old.color != color;
}
