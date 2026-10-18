import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

import 'motion.dart';
import 'tier.dart';

/// Pad 按下的分段 Lottie 播放器（与 APK `Pad.java` 一致）：
///
/// - 按下（[pressed] false→true）：从 0 播到 [split]；
/// - 松手（true→false）：从 [split] 播到 1，结束后回到 0；
/// - [playWhole]（Launchpad 皮肤 h=1）：按下直接整段 0→1；
/// - [looping]：整段循环（loop pad 播放期间），停下时回到 0；
/// - 资源缺失 / 加载失败 / 关闭「动画 Pad」/ 减少动效 → [fallback]。
class SegmentedLottie extends StatefulWidget {
  const SegmentedLottie({
    super.key,
    required this.asset,
    required this.split,
    required this.fallback,
    this.package,
    this.pressed = false,
    this.looping = false,
    this.playWhole = false,
    this.delegates,
    this.fit = BoxFit.fill,
  });

  final String asset;
  final String? package;

  /// 分段点（APK：0.5）。来自 token。
  final double split;
  final bool pressed;
  final bool looping;
  final bool playWhole;
  final LottieDelegates? delegates;
  final BoxFit fit;
  final WidgetBuilder fallback;

  @override
  State<SegmentedLottie> createState() => _SegmentedLottieState();
}

class _SegmentedLottieState extends State<SegmentedLottie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Duration? _length;

  @override
  void didUpdateWidget(SegmentedLottie oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_length == null) return;
    if (oldWidget.looping != widget.looping) _applyLoop();
    if (oldWidget.pressed != widget.pressed && !widget.looping) {
      widget.pressed ? _press() : _release();
    }
  }

  bool get _animate => FxScope.animatePadsOf(context);

  void _applyLoop() {
    if (widget.looping && _animate) {
      _c.repeat(period: _length);
    } else {
      _c
        ..stop()
        ..value = 0;
    }
  }

  void _press() {
    if (!_animate) return;
    final len = _length!;
    _c.value = 0;
    if (widget.playWhole) {
      _c.animateTo(1, duration: len).whenComplete(_resetIfIdle);
    } else {
      _c.animateTo(widget.split, duration: len * widget.split);
    }
  }

  void _release() {
    if (!_animate || widget.playWhole) return;
    final len = _length!;
    final remaining = (1 - _c.value).clamp(0.0, 1.0);
    _c.animateTo(1, duration: len * remaining).whenComplete(_resetIfIdle);
  }

  void _resetIfIdle() {
    if (mounted && !widget.pressed && !widget.looping && !_c.isAnimating) {
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (FxScope.tierOf(context) == FxTier.minimal || FxMotion.reduce(context)) {
      return widget.fallback(context);
    }
    return Lottie.asset(
      widget.asset,
      package: widget.package,
      controller: _c,
      fit: widget.fit,
      delegates: widget.delegates,
      frameRate: FrameRate.max,
      onLoaded: (composition) {
        _length = composition.duration;
        _c.duration = composition.duration;
        if (widget.looping) _applyLoop();
      },
      errorBuilder: (context, error, stack) => widget.fallback(context),
    );
  }
}
