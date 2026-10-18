import 'package:flutter/services.dart';

/// 桌面键盘映射（F1.7）：4 行 × 3 列对应当前页的 12 个 pad。
///
/// ```
/// 1 2 3      pad 1  2  3
/// Q W E      pad 4  5  6
/// A S D      pad 7  8  9
/// Z X C      pad A  B  C
/// Tab = 切换 A/B，Space = 停止全部，R = 录音
/// ```
abstract final class PadKeyboardMap {
  static final Map<PhysicalKeyboardKey, int> pads = {
    PhysicalKeyboardKey.digit1: 0,
    PhysicalKeyboardKey.digit2: 1,
    PhysicalKeyboardKey.digit3: 2,
    PhysicalKeyboardKey.keyQ: 3,
    PhysicalKeyboardKey.keyW: 4,
    PhysicalKeyboardKey.keyE: 5,
    PhysicalKeyboardKey.keyA: 6,
    PhysicalKeyboardKey.keyS: 7,
    PhysicalKeyboardKey.keyD: 8,
    PhysicalKeyboardKey.keyZ: 9,
    PhysicalKeyboardKey.keyX: 10,
    PhysicalKeyboardKey.keyC: 11,
  };

  static const PhysicalKeyboardKey switchBank = PhysicalKeyboardKey.tab;
  static const PhysicalKeyboardKey stopAll = PhysicalKeyboardKey.space;
  static const PhysicalKeyboardKey record = PhysicalKeyboardKey.keyR;
}
