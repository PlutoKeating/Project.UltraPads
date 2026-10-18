import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// 着色器程序缓存。加载失败（平台不支持 / 资源缺失）时对应程序为 null，
/// 调用方回退到 BoxShadow。
class FxShaders {
  FxShaders._();
  static final FxShaders instance = FxShaders._();

  static const _pkg = 'packages/up_fx/shaders';

  ui.FragmentProgram? bloom;
  ui.FragmentProgram? ripple;
  ui.FragmentProgram? breathe;

  /// pad 主体渐变（带抖动，修复 Impeller 上的同心色带）。
  ui.FragmentProgram? gradient;
  Future<void>? _loading;

  /// 是否已全部可用。
  bool get ready => bloom != null && ripple != null && breathe != null;

  /// 预加载（应用启动时调用一次；可重复调用）。
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    bloom = await _try('$_pkg/neon_bloom.frag');
    ripple = await _try('$_pkg/press_ripple.frag');
    breathe = await _try('$_pkg/loop_breathe.frag');
    gradient = await _try('$_pkg/dither_gradient.frag');
  }

  static Future<ui.FragmentProgram?> _try(String key) async {
    try {
      return await ui.FragmentProgram.fromAsset(key);
    } catch (e) {
      debugPrint('up_fx: shader $key unavailable ($e), falling back');
      return null;
    }
  }
}
