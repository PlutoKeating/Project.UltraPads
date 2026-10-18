import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'shaders.dart';
import 'tier.dart';

/// 带抖动的 3 色标渐变（pad 主体）。
///
/// Impeller 在 Android（Vulkan / SwiftShader）上不对渐变做抖动，大面积低对比的
/// 径向渐变会出现同心色带（「淡环」）。[FxTier.full] 且着色器可用时用
/// `dither_gradient.frag` 绘制（±1/255 三角噪声）；否则回退到普通
/// [RadialGradient] / [LinearGradient]（Skia 默认抖动，golden 测试也走这条路）。
class DitheredGradient extends StatelessWidget {
  const DitheredGradient({
    super.key,
    required this.colors,
    required this.stops,
    required this.radial,
    required this.extent,
    required this.cornerRadius,
  });

  /// 色标颜色（可带透明度；着色器路径要求正好 3 个）。
  final List<Color> colors;
  final List<double> stops;

  /// true = 以中心为圆心的径向渐变；false = 自上而下的线性渐变。
  final bool radial;

  /// 径向半径（占短边比例，与 [RadialGradient.radius] 相同）。
  final double extent;
  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    // 着色器只支持 3 个色标；其它情况走普通渐变。
    final program =
        FxScope.tierOf(context) == FxTier.full &&
            colors.length == 3 &&
            stops.length == 3
        ? FxShaders.instance.gradient
        : null;
    return CustomPaint(
      size: Size.infinite,
      painter: _GradientPainter(
        program,
        colors,
        stops,
        radial,
        extent,
        cornerRadius,
      ),
    );
  }
}

class _GradientPainter extends CustomPainter {
  _GradientPainter(
    this.program,
    this.colors,
    this.stops,
    this.radial,
    this.extent,
    this.corner,
  );

  final ui.FragmentProgram? program;
  final List<Color> colors;
  final List<double> stops;
  final bool radial;
  final double extent;
  final double corner;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final p = program;
    if (p == null) {
      final Gradient g = radial
          ? RadialGradient(colors: colors, stops: stops, radius: extent)
          : LinearGradient(
              colors: colors,
              stops: stops,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(corner)),
        Paint()..shader = g.createShader(rect),
      );
      return;
    }
    final s = p.fragmentShader();
    var i = 0;
    void f(double v) => s.setFloat(i++, v);
    f(size.width);
    f(size.height);
    f(corner);
    f(radial ? 1 : 0);
    f(extent);
    for (final c in colors) {
      f(c.r);
      f(c.g);
      f(c.b);
      f(c.a);
    }
    for (final v in stops) {
      f(v);
    }
    canvas.drawRect(rect, Paint()..shader = s);
  }

  @override
  bool shouldRepaint(_GradientPainter old) =>
      old.program != program ||
      old.radial != radial ||
      old.extent != extent ||
      old.corner != corner ||
      !_listEq(old.colors, colors) ||
      !_listEq(old.stops, stops);

  static bool _listEq<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
