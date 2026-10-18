import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// One layer of a glow recipe (token `glow.*`). The colour comes from the pad
/// role at runtime; [opacity] is the layer alpha at intensity 1.
@immutable
class UpGlowLayer {
  const UpGlowLayer({
    required this.opacity,
    required this.blur,
    required this.spread,
    this.dx = 0,
    this.dy = 0,
  });

  final double opacity;
  final double blur;
  final double spread;
  final double dx;
  final double dy;

  static UpGlowLayer lerp(UpGlowLayer a, UpGlowLayer b, double t) =>
      UpGlowLayer(
        opacity: lerpDouble(a.opacity, b.opacity, t)!,
        blur: lerpDouble(a.blur, b.blur, t)!,
        spread: lerpDouble(a.spread, b.spread, t)!,
        dx: lerpDouble(a.dx, b.dx, t)!,
        dy: lerpDouble(a.dy, b.dy, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is UpGlowLayer &&
      other.opacity == opacity &&
      other.blur == blur &&
      other.spread == spread &&
      other.dx == dx &&
      other.dy == dy;

  @override
  int get hashCode => Object.hash(opacity, blur, spread, dx, dy);
}

/// A colourless glow recipe; call [shadows] with a pad role colour.
@immutable
class UpGlowSpec {
  const UpGlowSpec(this.layers);

  static const UpGlowSpec none = UpGlowSpec(<UpGlowLayer>[]);

  final List<UpGlowLayer> layers;

  /// Builds the BoxShadow list for [color]. [intensity] (0..1, usually a
  /// semantic `pad.*.glow` value times an animation value) scales the alpha;
  /// returns an empty list when intensity is 0 so no shadow pass is paid.
  List<BoxShadow> shadows(Color color, {double intensity = 1}) {
    if (intensity <= 0 || layers.isEmpty) return const <BoxShadow>[];
    final double k = intensity.clamp(0.0, 1.0);
    return <BoxShadow>[
      for (final UpGlowLayer l in layers)
        BoxShadow(
          color: color.withValues(alpha: color.a * l.opacity * k),
          offset: Offset(l.dx, l.dy),
          blurRadius: l.blur,
          spreadRadius: l.spread,
        ),
    ];
  }

  static UpGlowSpec lerp(UpGlowSpec a, UpGlowSpec b, double t) {
    if (identical(a, b)) return a;
    final int n = a.layers.length > b.layers.length
        ? a.layers.length
        : b.layers.length;
    const UpGlowLayer zero = UpGlowLayer(opacity: 0, blur: 0, spread: 0);
    return UpGlowSpec(<UpGlowLayer>[
      for (int i = 0; i < n; i++)
        UpGlowLayer.lerp(
          i < a.layers.length ? a.layers[i] : zero,
          i < b.layers.length ? b.layers[i] : zero,
          t,
        ),
    ]);
  }

  @override
  bool operator ==(Object other) =>
      other is UpGlowSpec && listEquals(other.layers, layers);

  @override
  int get hashCode => Object.hashAll(layers);
}
