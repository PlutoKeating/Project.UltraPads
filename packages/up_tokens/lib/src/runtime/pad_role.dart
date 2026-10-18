import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Colours of one pad palette role (`pad.palette.<index>.*`).
@immutable
class UpPadRole {
  const UpPadRole({
    required this.index,
    required this.core,
    required this.mid,
    required this.edge,
    required this.glow,
    required this.pressed,
  });

  final int index;

  /// Gradient stop 0 (radial centre / top).
  final Color core;

  /// Gradient stop 0.5; also used for loop glyphs and outline strokes.
  final Color mid;

  /// Gradient stop 1 (radial rim / bottom).
  final Color edge;

  /// Glow colour fed into `UpGlowSpec.shadows`.
  final Color glow;

  /// Colour of the press / loop flash layer (white for overlay skins, a pale
  /// tint for tint-swap skins); its peak alpha is `pad.pressed.flashOpacity`.
  final Color pressed;

  List<Color> get colors => <Color>[core, mid, edge];

  static const List<double> stops = <double>[0, 0.5, 1];

  /// Radial gradient radius (fraction of the shortest side).
  static const double radialExtent = 0.75;

  /// `pad.fill.radial` blend → radial (true) or linear geometry.
  static bool isRadial(double radial) => radial >= 0.5;

  /// Pad body gradient. [radial] is the semantic `pad.fill.radial` blend
  /// (1 = radial, 0 = linear); values in between pick the nearer geometry.
  Gradient gradient({double radial = 1, double opacity = 1}) {
    final List<Color> c = opacity >= 1
        ? colors
        : <Color>[
            for (final Color x in colors) x.withValues(alpha: x.a * opacity),
          ];
    return isRadial(radial)
        ? RadialGradient(colors: c, stops: stops, radius: radialExtent)
        : LinearGradient(
            colors: c,
            stops: stops,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );
  }

  @override
  bool operator ==(Object other) =>
      other is UpPadRole &&
      other.index == index &&
      other.core == core &&
      other.mid == mid &&
      other.edge == edge &&
      other.glow == glow &&
      other.pressed == pressed;

  @override
  int get hashCode => Object.hash(index, core, mid, edge, glow, pressed);
}
