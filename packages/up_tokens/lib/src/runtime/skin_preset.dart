import 'package:flutter/foundation.dart';

import 'fonts.dart';
import 'skin.dart';
import 'up_theme.dart';

/// How the original skin draws pads (informs the UI, e.g. which art layers
/// a full-fidelity implementation would need).
enum UpSkinTechnique {
  /// Coloured body + white overlay flash.
  overlay,

  /// Single white shape tinted per role; press swaps to a pale tint.
  tint,

  /// Per-colour bitmaps with an "on" image (decorations not reproducible
  /// from tokens alone).
  image,

  /// Geometry change on press (Circle / Square).
  scale,
}

/// Whether tokens reproduce the skin fully or only its colours / shape.
enum UpSkinFidelity { full, partial }

/// A built-in skin preset generated from design/tokens/src/skins/*.skin.json.
@immutable
class UpSkinPreset {
  const UpSkinPreset({
    required this.id,
    required this.order,
    required this.nameKey,
    required this.baseId,
    required this.technique,
    required this.fidelity,
    required this.description,
    required this.overrides,
  });

  final String id;

  /// Display order in the skin panel (original controller order).
  final int order;

  /// up_i18n message key of the display name (e.g. `skinPresetDefault`).
  final String nameKey;
  final String baseId;
  final UpSkinTechnique technique;
  final UpSkinFidelity fidelity;
  final String description;

  /// Semantic overrides in skin-JSON form (hex strings / numbers).
  final Map<String, Object> overrides;

  /// Persistable skin (e.g. as a starting point in the skin editor).
  UpSkin toSkin({
    String? name,
    String? id,
    UpFontSet fontSet = UpFontSet.openSans,
  }) => UpSkin(
    id: id ?? 'preset-${this.id}',
    name: name ?? this.id,
    baseId: baseId,
    fontSet: fontSet,
    overrides: UpSemanticOverrides.fromJson(overrides),
  );

  /// Resolved theme for this preset.
  UpTheme toTheme({UpFontSet fontSet = UpFontSet.openSans}) =>
      UpTheme.fromSkin(toSkin(fontSet: fontSet));
}
