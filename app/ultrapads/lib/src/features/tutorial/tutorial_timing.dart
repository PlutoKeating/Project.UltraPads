import 'dart:math' as math;

import 'package:up_tokens/up_tokens.dart';

/// 教程时间轴参数（4.7.0 `ScreenPads` Transition / FirstGuide）。
///
/// 填充时长、反馈动效来自 `UpTutorialTokens`；判定窗口在 4.7.0 中没有查到
/// 毫秒值（分析文档 §7.2【未知】），暂时在这里定义。
/// TODO(tokens): 请 token 代理补 `tutorial.perfectWindow` / `tutorial.missWindow`。
abstract final class TutorialTiming {
  /// pad「填满」时长（1.0 s Linear）。
  static const Duration fill = UpTutorialTokens.fill;

  /// |按下时刻 − 目标时刻| ≤ 该值判 PERFECT（取 1/8 填充时长）。
  static final Duration perfectWindow = UpTutorialTokens.fill ~/ 8;

  /// 目标时刻之后超过该值仍未按下判 MISS（取 1/2 填充时长）。
  static final Duration missWindow = UpTutorialTokens.fill ~/ 2;

  /// 判定反馈总时长：PERFECT 上浮 0.3 s + 绿色圆 0.4 s。
  static final Duration feedback =
      UpTutorialTokens.perfectDuration + UpTutorialTokens.perfectCircle;

  /// TOO FAST / TOO SLOW 的倾斜角（弧度，token 为度）。
  static double get missTilt => UpTutorialTokens.missTilt * math.pi / 180;

  /// 速度三档：1.0 normal / 0.7 slow / 0.5 very slow（4.7.0 modalVelocities）。
  static const List<double> speeds = [1.0, 0.7, 0.5];
}
