import 'package:flutter/widgets.dart';

/// `prefers-reduced-motion` 适配：读取 `MediaQuery.disableAnimations`
/// （以及 [FxScope] 中用户的「动画 pad」开关）。
abstract final class FxMotion {
  /// 是否应减少动效。
  static bool reduce(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// 减少动效时返回 [Duration.zero]。
  static Duration duration(BuildContext context, Duration d) =>
      reduce(context) ? Duration.zero : d;

  /// 减少动效时返回 [Curves.linear]，避免回弹。
  static Curve curve(BuildContext context, Curve c) =>
      reduce(context) ? Curves.linear : c;
}
