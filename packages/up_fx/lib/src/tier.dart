import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'motion.dart';

/// 设备能力分级。
enum FxTier {
  /// Fragment Shader 光效 + Lottie。
  full,

  /// BoxShadow 光晕回退 + Lottie（低端机 / Web / 着色器加载失败）。
  lite,

  /// 只有静态色块（减少动效）。
  minimal,
}

/// 光效 / 动效配置作用域。
class FxScope extends InheritedWidget {
  const FxScope({
    super.key,
    this.tier,
    this.animatePads = true,
    required super.child,
  });

  /// 强制分级；null 表示自动检测（[detectTier]）。
  final FxTier? tier;

  /// 设置页「动画 Pad」开关（APK `preferences_animate`）。
  final bool animatePads;

  static FxScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FxScope>();

  /// 当前生效的分级：减少动效 → minimal；否则 [tier] 或自动检测。
  static FxTier tierOf(BuildContext context) {
    if (FxMotion.reduce(context)) return FxTier.minimal;
    return maybeOf(context)?.tier ?? detectTier();
  }

  static bool animatePadsOf(BuildContext context) =>
      (maybeOf(context)?.animatePads ?? true) && !FxMotion.reduce(context);

  /// 自动检测：Web 用 lite（CanvasKit/skwasm 上大面积着色器开销高）；
  /// 测试环境用 lite（golden 稳定）；其它平台 full。
  static FxTier detectTier() {
    if (kIsWeb) return FxTier.lite;
    if (_isTest) return FxTier.lite;
    return FxTier.full;
  }

  static bool get _isTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  bool updateShouldNotify(FxScope oldWidget) =>
      tier != oldWidget.tier || animatePads != oldWidget.animatePads;
}
