import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Case transform declared by a typography token (`$extensions.up.textCase`).
/// Translations stay in natural case; the role decides presentation.
enum UpTextCase {
  none,
  upper;

  String apply(String text) => switch (this) {
    UpTextCase.none => text,
    UpTextCase.upper => text.toUpperCase(),
  };
}

/// Raw values of a typography role token.
@immutable
class UpTextRoleSpec {
  const UpTextRoleSpec({
    required this.family,
    required this.fallbackFamily,
    required this.size,
    required this.weight,
    required this.letterSpacing,
    required this.height,
    required this.textCase,
  });

  /// Private family name (e.g. `Uni Sans Heavy`, single-weight family).
  final String family;

  /// Open fallback family bundled in up_tokens (e.g. `Montserrat`).
  final String? fallbackFamily;
  final double size;

  /// Weight applied when rendering with the fallback family.
  final FontWeight weight;
  final double letterSpacing;

  /// Line height multiplier.
  final double height;
  final UpTextCase textCase;
}
