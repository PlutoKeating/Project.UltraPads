import 'package:flutter/material.dart';

import '../generated/primitives.g.dart';
import '../generated/semantic.g.dart';
import '../generated/themes.g.dart';
import 'fonts.dart';
import 'pad_role.dart';
import 'skin.dart';
import 'typography.dart';

/// The UltraPads theme, injected as a [ThemeExtension].
///
/// Widgets read every theme-dependent value through [UpTheme.of]:
/// `colors` (semantic tokens) and `text` (typography roles). Theme-independent
/// geometry/motion comes from the generated `Up*Tokens` / `Up*` constant
/// classes. Never hard-code colours or shapes in UI code.
@immutable
class UpTheme extends ThemeExtension<UpTheme> {
  const UpTheme({
    required this.id,
    required this.baseId,
    required this.brightness,
    required this.colors,
    required this.text,
    this.overrides = const UpSemanticOverrides.empty(),
  });

  /// Builds a theme from semantic values; text colour = `text.primary`.
  factory UpTheme.fromSemantic({
    required String id,
    required Brightness brightness,
    required UpSemantic colors,
    String? baseId,
    UpSemanticOverrides overrides = const UpSemanticOverrides.empty(),
  }) => UpTheme(
    id: id,
    baseId: baseId ?? id,
    brightness: brightness,
    colors: colors,
    text: UpTypography.resolve(color: colors.textPrimary),
    overrides: overrides,
  );

  /// A user skin: [base] with semantic [overrides] applied.
  factory UpTheme.custom(
    UpTheme base,
    UpSemanticOverrides overrides, {
    String id = 'custom',
  }) => UpTheme.fromSemantic(
    id: id,
    baseId: base.baseId,
    brightness: base.brightness,
    colors: overrides.applyTo(
      UpSemanticThemes.byId[base.baseId] ?? base.colors,
    ),
    overrides: overrides,
  );

  /// Resolves a persisted [UpSkin].
  factory UpTheme.fromSkin(UpSkin skin) =>
      UpTheme.custom(UpThemes.byId(skin.baseId), skin.overrides, id: skin.id);

  /// Theme id (`neon`, `outline`, `light`, or a custom skin id).
  final String id;

  /// Built-in theme this one derives from (== [id] for built-ins).
  final String baseId;
  final Brightness brightness;

  /// Semantic tokens (colours, gradients, pad state numbers).
  final UpSemantic colors;

  /// Typography roles resolved with this theme's text colour.
  final UpTypography text;

  /// Overrides applied on top of [baseId] (empty for built-ins).
  final UpSemanticOverrides overrides;

  bool get isCustom => overrides.values.isNotEmpty || id != baseId;

  /// Pad colour role for a Kit colour index (wraps).
  UpPadRole padRole(int index) => colors.padRole(index);

  /// Converts back into a persistable skin.
  UpSkin toSkin({required String name, String? id}) => UpSkin(
    id: id ?? this.id,
    name: name,
    baseId: baseId,
    overrides: overrides,
  );

  /// Theme from the nearest [Theme]; falls back to the default built-in theme
  /// (asserting in debug builds) when no [UpTheme] extension is installed.
  static UpTheme of(BuildContext context) {
    final UpTheme? t = maybeOf(context);
    assert(
      t != null,
      'No UpTheme in ThemeData.extensions; use UpTheme.toThemeData()',
    );
    return t ?? UpThemes.byId(UpSemanticThemes.defaultId);
  }

  static UpTheme? maybeOf(BuildContext context) =>
      Theme.of(context).extension<UpTheme>();

  /// Material [ThemeData] carrying this extension, with stock widgets mapped
  /// onto semantic tokens.
  ThemeData toThemeData() {
    final UpSemantic c = colors;
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: c.accentPrimary,
      onPrimary: c.textOnAccent,
      secondary: c.accentSecondary,
      onSecondary: c.textOnAccent,
      error: c.statusDanger,
      onError: c.textOnAccent,
      surface: c.surfacePage,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.surfaceRaisedHigh,
      outline: c.borderDefault,
      outlineVariant: c.borderSubtle,
      scrim: c.surfaceScrim,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.surfaceApp,
      canvasColor: c.surfaceApp,
      dividerColor: c.borderDivider,
      textTheme: text.toTextTheme(),
      splashFactory: NoSplash.splashFactory,
      extensions: <ThemeExtension<dynamic>>[this],
    );
  }

  @override
  UpTheme copyWith({
    String? id,
    String? baseId,
    Brightness? brightness,
    UpSemantic? colors,
    UpTypography? text,
    UpSemanticOverrides? overrides,
  }) => UpTheme(
    id: id ?? this.id,
    baseId: baseId ?? this.baseId,
    brightness: brightness ?? this.brightness,
    colors: colors ?? this.colors,
    text: text ?? this.text,
    overrides: overrides ?? this.overrides,
  );

  /// Interpolates every semantic token and text style, enabling animated skin
  /// switches through [AnimatedTheme] / [ThemeData.lerp].
  @override
  UpTheme lerp(covariant ThemeExtension<UpTheme>? other, double t) {
    if (other is! UpTheme) return this;
    if (t <= 0) return this;
    if (t >= 1) return other;
    final bool second = t >= 0.5;
    return UpTheme(
      id: second ? other.id : id,
      baseId: second ? other.baseId : baseId,
      brightness: second ? other.brightness : brightness,
      colors: UpSemantic.lerp(colors, other.colors, t),
      text: UpTypography.lerp(text, other.text, t),
      overrides: second ? other.overrides : overrides,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UpTheme &&
      other.id == id &&
      other.baseId == baseId &&
      other.brightness == brightness &&
      other.colors == colors &&
      other.text == text &&
      other.overrides == overrides;

  @override
  int get hashCode =>
      Object.hash(id, baseId, brightness, colors, text, overrides);
}

/// Built-in themes (generated from design/tokens/themes.config.json).
/// Re-resolved when private fonts finish loading ([UpFonts.revision]).
abstract final class UpThemes {
  static final Map<String, UpTheme> _cache = <String, UpTheme>{};
  static int _cacheRevision = -1;

  static UpTheme get neon => byId('neon');
  static UpTheme get outline => byId('outline');
  static UpTheme get light => byId('light');

  /// All built-in ids in display order.
  static List<String> get ids => UpSemanticThemes.ids;

  static List<UpTheme> get all => <UpTheme>[
    for (final String id in ids) byId(id),
  ];

  /// Built-in theme by id; unknown ids fall back to the default theme.
  static UpTheme byId(String id) {
    if (_cacheRevision != UpFonts.revision.value) {
      _cache.clear();
      _cacheRevision = UpFonts.revision.value;
    }
    final String key = UpSemanticThemes.byId.containsKey(id)
        ? id
        : UpSemanticThemes.defaultId;
    return _cache.putIfAbsent(
      key,
      () => UpTheme.fromSemantic(
        id: key,
        brightness: UpSemanticThemes.brightness[key]!,
        colors: UpSemanticThemes.byId[key]!,
      ),
    );
  }

  /// Text role lookup without a BuildContext (e.g. golden tests).
  @visibleForTesting
  static UpTextRole role(String name) => UpTextRole.values.byName(name);
}
