// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: design/tokens/src (W3C DTCG) -> Style Dictionary -> design/tokens/scripts/build.mjs
// Regenerate with `just tokens` (cd design/tokens && pnpm run build).
// ignore_for_file: type=lint, unused_import

import 'dart:ui' show Brightness;

import 'semantic.g.dart';
import 'semantic_neon.g.dart';
import 'semantic_outline.g.dart';
import 'semantic_light.g.dart';

/// Built-in skins generated from design/tokens/themes.config.json.
abstract final class UpSemanticThemes {
  /// Id of the default skin.
  static const String defaultId = 'neon';

  /// Built-in skin ids in display order.
  static const List<String> ids = <String>['neon', 'outline', 'light'];

  static const Map<String, UpSemantic> byId = <String, UpSemantic>{
    'neon': upSemanticNeon,
    'outline': upSemanticOutline,
    'light': upSemanticLight,
  };

  static const Map<String, Brightness> brightness = <String, Brightness>{
    'neon': Brightness.dark,
    'outline': Brightness.dark,
    'light': Brightness.light,
  };

  static const Map<String, String> descriptions = <String, String>{
    'neon':
        'Neon gradient glow: solid radial-gradient pads with coloured glow (current store look).',
    'outline':
        'Dark surface with colour-stroked pads; pressed pads fill solid (classic palette).',
    'light': 'Light surfaces with saturated pads and soft glow.',
  };
}
