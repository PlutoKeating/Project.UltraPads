import 'package:flutter/material.dart';
import 'package:up_fx/up_fx.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

/// 首次引导的一步：高亮 [target] 对应的控件（[hole] 可把目标矩形再细化，
/// 例如只取 pad 网格左上角的第一个 pad），并显示 [text]。
class FirstGuideStep {
  const FirstGuideStep({required this.target, required this.text, this.hole});

  final GlobalKey target;
  final String text;
  final Rect Function(Rect target)? hole;
}

/// 演奏页首次引导浮层（4.7.0 FirstGuide）：
/// - `componentHighlight`：70% 黑遮罩（`surface.scrim`）挖出目标的洞；
/// - `componentHandFirstOpen`：手指 1.0 s QuadIn 上移（`tutorial.hand*`），循环；
/// - `modalTextBoxFirstOpen`：白色气泡（`feedback.bubble`，`tutorial.bubbleWidth`）；
/// - `componentStep`：STEP x/4，从右侧滑入（`tutorial.stepSlide` / `textIn`）；
/// - `btnSkipTutorial`：右上角 SKIP，0.25 s 从右侧滑入（`tutorial.skipSlide`）。
///
/// 点洞内或「下一步」前进；最后一步 / 跳过时调用 [onDone]（由调用方持久化）。
class FirstGuideOverlay extends StatefulWidget {
  const FirstGuideOverlay({
    super.key,
    required this.steps,
    required this.onDone,
  });

  final List<FirstGuideStep> steps;
  final VoidCallback onDone;

  @override
  State<FirstGuideOverlay> createState() => _FirstGuideOverlayState();
}

class _FirstGuideOverlayState extends State<FirstGuideOverlay>
    with TickerProviderStateMixin {
  int _step = 0;
  Rect? _hole;

  late final AnimationController _hand = AnimationController(
    vsync: this,
    duration: UpTutorialTokens.hand,
  );
  late final AnimationController _skip = AnimationController(
    vsync: this,
    duration: UpTutorialTokens.skipSlide,
  );

  @override
  void initState() {
    super.initState();
    _skip.forward();
    _measure();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (FxMotion.reduce(context)) {
      _hand.stop();
    } else if (!_hand.isAnimating) {
      _hand.repeat();
    }
  }

  @override
  void dispose() {
    _hand.dispose();
    _skip.dispose();
    super.dispose();
  }

  /// 目标位置要等布局完成才能读到：下一帧测量（窗口尺寸变化时也重测）。
  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hole = _rectOf(widget.steps[_step]);
      if (hole != _hole) setState(() => _hole = hole);
    });
  }

  Rect? _rectOf(FirstGuideStep s) {
    final box = s.target.currentContext?.findRenderObject() as RenderBox?;
    final self = context.findRenderObject() as RenderBox?;
    if (box == null || self == null || !box.hasSize || !self.hasSize) {
      return null;
    }
    final r = box.localToGlobal(Offset.zero, ancestor: self) & box.size;
    return (s.hole?.call(r) ?? r).inflate(UpSpacing.xs);
  }

  void _next() {
    if (_step + 1 >= widget.steps.length) {
      widget.onDone();
      return;
    }
    setState(() {
      _step++;
      _hole = null;
    });
    _measure();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final last = _step + 1 >= widget.steps.length;
    return LayoutBuilder(
      builder: (context, box) {
        _measure();
        final size = box.biggest;
        final hole = _hole;
        return Stack(
          children: [
            // 遮罩：挡住其它触摸，洞内点击 = 下一步。
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  if (hole != null && hole.contains(d.localPosition)) _next();
                },
                child: CustomPaint(
                  painter: _MaskPainter(
                    hole: hole,
                    color: c.surfaceScrim,
                    radius: UpRadii.md,
                  ),
                ),
              ),
            ),
            if (hole != null) ..._pointer(hole),
            if (hole != null) _bubble(context, size, hole, last),
            // 避开状态栏 / 刘海（浮层铺满整个页面，不在 SafeArea 内）。
            Positioned(
              top: MediaQuery.paddingOf(context).top + UpSpacing.lg,
              right: MediaQuery.paddingOf(context).right + UpSpacing.lg,
              child: SlideTransition(
                position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                    .animate(
                      CurvedAnimation(parent: _skip, curve: UpEasings.quadOut),
                    ),
                child: UpButton(
                  key: const ValueKey('first-guide-skip'),
                  label: l10n.commonSkip,
                  variant: UpButtonVariant.secondary,
                  size: UpButtonSize.sm,
                  onPressed: widget.onDone,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 手指：从洞下方向上移 `tutorial.handTravel`（1.0 s QuadIn，循环）。
  List<Widget> _pointer(Rect hole) {
    final c = UpTheme.of(context).colors;
    return [
      AnimatedBuilder(
        animation: _hand,
        builder: (context, child) {
          final t = UpTutorialTokens.handCurve.transform(_hand.value);
          return Positioned(
            left: hole.center.dx - UpSizes.iconXxl / 2,
            top:
                hole.center.dy +
                UpTutorialTokens.handTravel * (1 - t) -
                UpSizes.iconXxl / 2,
            child: IgnorePointer(child: child!),
          );
        },
        child: Icon(
          Icons.touch_app_rounded,
          size: UpSizes.iconXxl,
          color: c.feedbackBubble,
        ),
      ),
    ];
  }

  Widget _bubble(BuildContext context, Size size, Rect hole, bool last) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final width = UpTutorialTokens.bubbleWidth;
    final left = (hole.center.dx - width / 2).clamp(
      UpSpacing.lg,
      size.width - width - UpSpacing.lg,
    );
    // 目标在上半屏 → 气泡放在手指下面；否则放在目标上方。
    final below = hole.center.dy < size.height / 2;
    final gap = UpTutorialTokens.handTravel + UpSizes.iconXxl;
    return Positioned(
      left: left,
      width: width,
      top: below ? hole.bottom + gap : null,
      bottom: below ? null : size.height - hole.top + UpSpacing.lg,
      child: Container(
        key: const ValueKey('first-guide-bubble'),
        constraints: const BoxConstraints(
          minHeight: UpTutorialTokens.bubbleHeight,
        ),
        padding: const EdgeInsets.all(UpSpacing.lg),
        decoration: BoxDecoration(
          color: c.feedbackBubble,
          borderRadius: BorderRadius.circular(UpRadii.xxl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: UpSpacing.md,
          children: [
            UpText(
              widget.steps[_step].text,
              role: UpTextRole.titleSm,
              color: c.feedbackBubbleText,
              maxLines: 4,
            ),
            Row(
              children: [
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_step),
                    tween: Tween(begin: 1, end: 0),
                    duration: FxMotion.duration(
                      context,
                      UpTutorialTokens.textIn,
                    ),
                    curve: UpEasings.quadOut,
                    builder: (context, v, child) => Transform.translate(
                      offset: Offset(UpTutorialTokens.stepSlide * v, 0),
                      child: Opacity(opacity: 1 - v, child: child),
                    ),
                    child: UpText(
                      l10n.tutorialFirstGuideStep(
                        _step + 1,
                        widget.steps.length,
                      ),
                      role: UpTextRole.label,
                      color: c.feedbackBubbleText,
                    ),
                  ),
                ),
                UpButton(
                  key: const ValueKey('first-guide-next'),
                  label: last ? l10n.tutorialFirstGuideDone : l10n.commonNext,
                  size: UpButtonSize.sm,
                  onPressed: _next,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MaskPainter extends CustomPainter {
  _MaskPainter({required this.hole, required this.color, required this.radius});

  final Rect? hole;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final h = hole;
    final path = h == null
        ? full
        : Path.combine(
            PathOperation.difference,
            full,
            Path()
              ..addRRect(RRect.fromRectAndRadius(h, Radius.circular(radius))),
          );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MaskPainter old) =>
      old.hole != hole || old.color != color || old.radius != radius;
}
