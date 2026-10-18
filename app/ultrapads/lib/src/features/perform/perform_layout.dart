import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:up_tokens/up_tokens.dart';

/// 演奏页的宽屏 / 平板布局（4.7.0 `fixed_height` 适配）。
///
/// 4.7.0 的设计画布是 414×736 pt，以高度为准等比缩放：pad 区（x 9..819、
/// y 286..1321 px）的宽高比固定，屏幕更宽时（iPad、桌面横屏）pad 网格按高度算出
/// 宽度、水平居中，而不是被拉宽成扁 pad；手机（比画布更窄或相同）时网格占满宽度，
/// 与原来一致。顶栏和功能行与网格同宽（整列居中），A/B 按钮始终在网格右上角。
abstract final class PerformLayout {
  /// pad 网格的宽高比：3 个 cell + 2 个间距 : 4 个 cell + 3 个间距
  /// （cell 133.5×128 pt，间距 2 pt；约 0.78）。
  static const double gridAspect =
      (UpPadGridTokens.columns * UpPadTokens.cellWidth +
          (UpPadGridTokens.columns - 1) * UpPadTokens.gap) /
      (UpPadGridTokens.rows * UpPadTokens.cellHeight +
          (UpPadGridTokens.rows - 1) * UpPadTokens.gap);

  /// 网格上方的固定高度：顶栏 + 功能行 + 网格上边距。
  static const double chromeTop =
      UpTopBarTokens.height +
      UpTopBarTokens.bankButtonSize +
      UpPadGridTokens.marginTop;

  /// 网格下边距。
  static const double chromeBottom = UpPadGridTokens.marginBottom;

  /// 给网格留出的区域 [area]（已扣除左右 pageInset 与上下边距）里网格的实际尺寸：
  /// 高度占满，宽度 = min(可用宽度, 高度 × [gridAspect])。
  static Size gridSize(Size area) =>
      Size(math.min(area.width, area.height * gridAspect), area.height);

  /// 整列（顶栏、功能行、网格）的宽度。[body] 是 SafeArea 内的可用尺寸，
  /// [extraTop] 是额外占用的高度（例如控制器状态条）。
  static double columnWidth(Size body, {double extraTop = 0}) {
    final gridHeight = math.max(
      0.0,
      body.height - chromeTop - chromeBottom - extraTop,
    );
    final grid = gridSize(
      Size(body.width - 2 * UpPadGridTokens.pageInset, gridHeight),
    );
    return math.min(body.width, grid.width + 2 * UpPadGridTokens.pageInset);
  }

  /// 是否处于宽屏（网格被高度限制、两侧留白）。
  static bool isWide(Size body) => columnWidth(body) < body.width;
}
