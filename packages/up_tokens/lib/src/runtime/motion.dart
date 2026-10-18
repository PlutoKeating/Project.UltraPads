import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Motion helpers on top of the generated `UpDurations` / `UpEasings` /
/// `UpSprings` tokens. Honour the platform "reduce motion" setting.
abstract final class UpMotion {
  /// True when the platform asks to disable animations.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [token] or [Duration.zero] when motion is reduced.
  static Duration duration(BuildContext context, Duration token) =>
      reduced(context) ? Duration.zero : token;

  /// Spring simulation from a spring token.
  static SpringSimulation spring(
    SpringDescription token, {
    required double from,
    required double to,
    double velocity = 0,
  }) => SpringSimulation(token, from, to, velocity);
}
