import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../generated/primitives.g.dart';
import 'fonts.dart';
import 'text_role.dart';

/// Resolved [TextStyle]s for every [UpTextRole] of a theme.
@immutable
class UpTypography {
  const UpTypography._(this._styles);

  /// Builds styles from typography tokens with [color] (usually
  /// `text.primary`). Uses the private Uni Sans cut when it is loaded
  /// (single-weight family -> normal weight), else the bundled fallback with
  /// the token weight.
  factory UpTypography.resolve({required Color color}) {
    return UpTypography._(<UpTextRole, TextStyle>{
      for (final UpTextRole role in UpTextRole.values)
        role: styleFor(role.spec, color),
    });
  }

  final Map<UpTextRole, TextStyle> _styles;

  static TextStyle styleFor(UpTextRoleSpec spec, Color color) {
    final bool private = UpFonts.isLoaded(spec.family);
    return TextStyle(
      inherit: false,
      color: color,
      fontFamily: private ? spec.family : spec.fallbackFamily,
      package: private || spec.fallbackFamily == null ? null : UpFonts.package,
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
  });

  static UpTypography lerp(UpTypography a, UpTypography b, double t) {
    if (identical(a, b)) return a;
    return UpTypography._(<UpTextRole, TextStyle>{
      for (final UpTextRole r in UpTextRole.values)
        r: TextStyle.lerp(a[r], b[r], t)!,
    });
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
      other is UpTypography && mapEquals(other._styles, _styles);

  @override
  int get hashCode =>
      Object.hashAll(UpTextRole.values.map((UpTextRole r) => _styles[r]));
}
