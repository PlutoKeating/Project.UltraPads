import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'motion.dart';
import 'shaders.dart';
import 'tier.dart';

/// Loop 描边呼吸：[active] 时以 [period] 为一圈循环。
/// 着色器不可用时退化为透明度呼吸的描边。
class LoopBreathe extends StatefulWidget {
  const LoopBreathe({
    super.key,
    required this.active,
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.period,
    required this.minOpacity,
  });

  final bool active;
  final Color color;
  final double radius;
  final double strokeWidth;
  final Duration period;
  final double minOpacity;

  @override
  State<LoopBreathe> createState() => _LoopBreatheState();
}

class _LoopBreatheState extends State<LoopBreathe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LoopBreathe oldWidget) {
    super.didUpdateWidget(oldWidget);
    _c.duration = widget.period;
    _sync();
  }

  void _sync() {
    final run = widget.active && !FxMotion.reduce(context);
    if (run && !_c.isAnimating) {
      _c.repeat();
    } else if (!run && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.expand();
    final tier = FxScope.tierOf(context);
    final program = tier == FxTier.full ? FxShaders.instance.breathe : null;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _BreathePainter(
            program,
            _c.value,
            widget.color,
            widget.radius,
            widget.strokeWidth,
            widget.minOpacity,
          ),
        ),
      ),
    );
  }
}

class _BreathePainter extends CustomPainter {
  _BreathePainter(
    this.program,
    this.phase,
    this.color,
    this.radius,
    this.width,
    this.min,
  );

  final ui.FragmentProgram? program;
  final double phase;
  final Color color;
  final double radius;
  final double width;
  final double min;

  @override
  void paint(Canvas canvas, Size size) {
    final p = program;
    final rect = Offset.zero & size;
    if (p == null) {
      final t = (1 + math.cos(phase * math.pi * 2)) / 2;
      final a = min + (1 - min) * t;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(width / 2),
          Radius.circular(radius),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color.withValues(alpha: color.a * a),
      );
      return;
    }
    final shader = p.fragmentShader();
    var i = 0;
    shader
      ..setFloat(i++, size.width)
      ..setFloat(i++, size.height)
      ..setFloat(i++, radius)
      ..setFloat(i++, width)
      ..setFloat(i++, phase)
      ..setFloat(i++, color.r)
      ..setFloat(i++, color.g)
      ..setFloat(i++, color.b)
      ..setFloat(i++, color.a)
      ..setFloat(i++, min);
    canvas.drawRect(rect, Paint()..shader = shader);
    shader.dispose();
  }

  @override
  bool shouldRepaint(_BreathePainter old) =>
      old.phase != phase || old.color != color || old.radius != radius;
}
