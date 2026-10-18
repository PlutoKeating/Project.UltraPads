import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'color_codec.dart';

/// A colour-stop list (DTCG `gradient`). Geometry (linear/radial, direction)
/// is chosen by the component; the token only carries colours and stops.
@immutable
class UpGradient {
  /// [colors] and [stops] must have the same length (checked by the token
  /// build and by [fromJson]).
  const UpGradient({required this.colors, required this.stops});

  final List<Color> colors;
  final List<double> stops;

  LinearGradient linear({
    AlignmentGeometry begin = Alignment.topCenter,
    AlignmentGeometry end = Alignment.bottomCenter,
  }) => LinearGradient(colors: colors, stops: stops, begin: begin, end: end);

  RadialGradient radial({
    AlignmentGeometry center = Alignment.center,
    double radius = 0.75,
  }) => RadialGradient(
    colors: colors,
    stops: stops,
    center: center,
    radius: radius,
  );

  /// Lerps stop-by-stop. Gradients with different stop counts are resampled
  /// onto the longer stop list.
  static UpGradient lerp(UpGradient a, UpGradient b, double t) {
    if (identical(a, b)) return a;
    if (a.colors.length == b.colors.length) {
      return UpGradient(
        colors: List<Color>.generate(
          a.colors.length,
          (int i) => Color.lerp(a.colors[i], b.colors[i], t)!,
        ),
        stops: List<double>.generate(
          a.stops.length,
          (int i) => lerpDouble(a.stops[i], b.stops[i], t)!,
        ),
      );
    }
    final List<double> stops = a.stops.length >= b.stops.length
        ? a.stops
        : b.stops;
    return UpGradient(
      colors: <Color>[
        for (final double s in stops)
          Color.lerp(a.colorAt(s), b.colorAt(s), t)!,
      ],
      stops: stops,
    );
  }

  /// Colour at position [s] (0..1) by linear interpolation between stops.
  Color colorAt(double s) {
    if (s <= stops.first) return colors.first;
    for (int i = 1; i < stops.length; i++) {
      if (s <= stops[i]) {
        final double span = stops[i] - stops[i - 1];
        final double f = span == 0 ? 1 : (s - stops[i - 1]) / span;
        return Color.lerp(colors[i - 1], colors[i], f)!;
      }
    }
    return colors.last;
  }

  Object toJson() => <Object>[
    for (int i = 0; i < colors.length; i++)
      <String, Object>{
        'color': UpColorCodec.encode(colors[i]),
        'position': stops[i],
      },
  ];

  static UpGradient fromJson(Object? json) {
    if (json is! List || json.length < 2) {
      throw const FormatException('gradient must be a list of >= 2 stops');
    }
    final List<Color> colors = <Color>[];
    final List<double> stops = <double>[];
    for (final Object? stop in json) {
      if (stop is! Map) {
        throw const FormatException('gradient stop must be an object');
      }
      colors.add(UpColorCodec.decode(stop['color']));
      final Object? p = stop['position'];
      if (p is! num) {
        throw const FormatException('gradient stop position must be a number');
      }
      stops.add(p.toDouble());
    }
    return UpGradient(colors: colors, stops: stops);
  }

  @override
  bool operator ==(Object other) =>
      other is UpGradient &&
      listEquals(other.colors, colors) &&
      listEquals(other.stops, stops);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(colors), Object.hashAll(stops));

  @override
  String toString() => 'UpGradient(${toJson()})';
}
