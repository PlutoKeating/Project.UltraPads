import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'shaders.dart';
import 'tier.dart';

/// 光晕参数（全部来自 token）。
@immutable
class GlowSpec {
  const GlowSpec({
    required this.color,
    required this.spread,
    required this.radius,
    required this.intensity,
    this.fallbackShadows,
  });

  final Color color;

  /// 低端回退时使用的 BoxShadow（通常是 token 的 glow 配方 × 颜色）；
  /// 为空时按 [spread] 生成两层默认光晕。
  final List<BoxShadow>? fallbackShadows;

  /// 光晕外扩（逻辑像素）。
  final double spread;

  /// 被包裹元素的圆角。
  final double radius;

  /// 0..1。
  final double intensity;

  GlowSpec copyWith({Color? color, double? intensity}) => GlowSpec(
    color: color ?? this.color,
    spread: spread,
    radius: radius,
    intensity: intensity ?? this.intensity,
    fallbackShadows: fallbackShadows,
  );
}

/// 霓虹 bloom：在 [child] 背后画一圈柔光。
///
/// - [FxTier.full] 且着色器可用 → `neon_bloom.frag`
/// - 否则 → `BoxShadow` 回退
/// - [FxTier.minimal] 或 intensity=0 → 不画
class NeonGlow extends StatelessWidget {
  const NeonGlow({super.key, required this.spec, required this.child});

  final GlowSpec spec;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tier = FxScope.tierOf(context);
    if (tier == FxTier.minimal || spec.intensity <= 0) return child;
    final program = FxShaders.instance.bloom;
    if (tier == FxTier.full && program != null) {
      return CustomPaint(painter: _BloomPainter(program, spec), child: child);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(spec.radius),
        boxShadow: spec.fallbackShadows ?? glowShadows(spec),
      ),
      child: child,
    );
  }

  /// BoxShadow 回退：两层（近处实、远处虚）。
  static List<BoxShadow> glowShadows(GlowSpec spec) {
    final c = spec.color.withValues(alpha: spec.color.a * spec.intensity);
    return [
      BoxShadow(
        color: c,
        blurRadius: spec.spread,
        spreadRadius: spec.spread / 8,
      ),
      BoxShadow(
        color: c.withValues(alpha: c.a / 2),
        blurRadius: spec.spread * 2,
      ),
    ];
  }
}

class _BloomPainter extends CustomPainter {
  _BloomPainter(this.program, this.spec);

  final ui.FragmentProgram program;
  final GlowSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final s = spec.spread;
    final canvasSize = Size(size.width + s * 2, size.height + s * 2);
    final shader = program.fragmentShader();
    var i = 0;
    shader
      ..setFloat(i++, canvasSize.width)
      ..setFloat(i++, canvasSize.height)
      ..setFloat(i++, size.width)
      ..setFloat(i++, size.height)
      ..setFloat(i++, spec.radius)
      ..setFloat(i++, s)
      ..setFloat(i++, spec.color.r)
      ..setFloat(i++, spec.color.g)
      ..setFloat(i++, spec.color.b)
      ..setFloat(i++, spec.color.a)
      ..setFloat(i++, spec.intensity);
    canvas
      ..save()
      ..translate(-s, -s)
      ..drawRect(Offset.zero & canvasSize, Paint()..shader = shader)
      ..restore();
    shader.dispose();
  }

  @override
  bool shouldRepaint(_BloomPainter old) =>
      old.spec.color != spec.color ||
      old.spec.intensity != spec.intensity ||
      old.spec.spread != spec.spread ||
      old.spec.radius != spec.radius;
}
