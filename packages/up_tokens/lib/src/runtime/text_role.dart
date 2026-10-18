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
    required this.size,
    required this.weight,
    required this.letterSpacing,
    required this.height,
    required this.textCase,
  });

  /// Bundled family name (`Open Sans`, shipped in up_tokens).
  final String family;
  final double size;
  final FontWeight weight;
  final double letterSpacing;

  /// Line height multiplier.
  final double height;
  final UpTextCase textCase;
}
