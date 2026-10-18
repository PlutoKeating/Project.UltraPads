import 'package:flutter/painting.dart';

/// `#RRGGBB` / `#RRGGBBAA` <-> [Color] (DTCG hex order: alpha last).
abstract final class UpColorCodec {
  static String encode(Color c) {
    String h(double v) => (v * 255)
        .round()
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0')
        .toUpperCase();
    final String rgb = '#${h(c.r)}${h(c.g)}${h(c.b)}';
    return c.a >= 1 ? rgb : '$rgb${h(c.a)}';
  }

  static Color decode(Object? value) {
    if (value is! String) {
      throw FormatException('colour must be a hex string', value);
    }
    final RegExp re = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');
    if (!re.hasMatch(value)) throw FormatException('invalid colour', value);
    final String hex = value.substring(1);
    final int rgb = int.parse(hex.substring(0, 6), radix: 16);
    final int a = hex.length == 8
        ? int.parse(hex.substring(6, 8), radix: 16)
        : 0xFF;
    return Color((a << 24) | rgb);
  }
}
