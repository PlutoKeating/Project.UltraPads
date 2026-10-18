import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../generated/primitives.g.dart';
import 'fonts.dart';
import 'text_role.dart';

/// Resolved [TextStyle]s for every [UpTextRole] of a theme.
@immutable
class UpTypography {
  const UpTypography._(this._styles, this.fontSet);

  /// Builds styles from typography tokens with [color] (usually
  /// `text.primary`). With [UpFontSet.uniSans] each role uses the injected
  /// Uni Sans cut for its weight when loaded, else the bundled Open Sans.
  factory UpTypography.resolve({
    required Color color,
    UpFontSet fontSet = UpFontSet.openSans,
  }) {
    return UpTypography._(<UpTextRole, TextStyle>{
      for (final UpTextRole role in UpTextRole.values)
        role: styleFor(role.spec, color, fontSet: fontSet),
    }, fontSet);
  }

  final Map<UpTextRole, TextStyle> _styles;

  /// Font set these styles were resolved with.
  final UpFontSet fontSet;

  static TextStyle styleFor(
    UpTextRoleSpec spec,
    Color color, {
    UpFontSet fontSet = UpFontSet.openSans,
  }) {
    final String? uni = fontSet == UpFontSet.uniSans
        ? UpFonts.uniSansFamilyFor(spec.weight)
        : null;
    final bool private = uni != null && UpFonts.isLoaded(uni);
    return TextStyle(
      inherit: false,
      color: color,
      fontFamily: private ? uni : spec.family,
      package: private ? null : UpFonts.package,
      // Private Uni Sans cuts are single-weight families: no synthetic bold.
      fontWeight: private ? FontWeight.w400 : spec.weight,
      fontSize: spec.size,
      letterSpacing: spec.letterSpacing,
      height: spec.height,
      textBaseline: TextBaseline.alphabetic,
      leadingDistribution: TextLeadingDistribution.even,
      decoration: TextDecoration.none,
    );
  }

  TextStyle operator [](UpTextRole role) => _styles[role]!;

  /// Applies the role's text case (e.g. upper-case titles). Use this instead
  /// of writing upper-case copy into ARB files.
  String format(UpTextRole role, String text) => role.spec.textCase.apply(text);

  /// Same styles with a different colour.
  UpTypography withColor(Color color) => UpTypography._(<UpTextRole, TextStyle>{
    for (final MapEntry<UpTextRole, TextStyle> e in _styles.entries)
      e.key: e.value.copyWith(color: color),
  }, fontSet);

  static UpTypography lerp(UpTypography a, UpTypography b, double t) {
    if (identical(a, b)) return a;
    return UpTypography._(<UpTextRole, TextStyle>{
      for (final UpTextRole r in UpTextRole.values)
        r: TextStyle.lerp(a[r], b[r], t)!,
    }, t < 0.5 ? a.fontSet : b.fontSet);
  }

  /// Material TextTheme mapping (for stock widgets that read Theme.of).
  TextTheme toTextTheme() => TextTheme(
    displayLarge: this[UpTextRole.hero],
    displayMedium: this[UpTextRole.display],
    headlineMedium: this[UpTextRole.headline],
    titleLarge: this[UpTextRole.title],
    titleMedium: this[UpTextRole.titleSm],
    titleSmall: this[UpTextRole.label],
    bodyLarge: this[UpTextRole.body],
    bodyMedium: this[UpTextRole.bodySm],
    bodySmall: this[UpTextRole.caption],
    labelLarge: this[UpTextRole.button],
    labelMedium: this[UpTextRole.label],
    labelSmall: this[UpTextRole.labelSm],
  );

  @override
  bool operator ==(Object other) =>
      other is UpTypography &&
      other.fontSet == fontSet &&
      mapEquals(other._styles, _styles);

  @override
  int get hashCode => Object.hash(
    fontSet,
    Object.hashAll(UpTextRole.values.map((UpTextRole r) => _styles[r])),
  );
}
