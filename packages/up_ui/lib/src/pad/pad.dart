import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:up_fx/up_fx.dart';
import 'package:up_tokens/up_tokens.dart';

/// 发声状态（由引擎事件驱动；与 [UpPad.pressed] 的即时按下态无关）。
enum PadVisualState { idle, pending, playing, stopping }

/// 一个 pad 的展示数据（纯数据，不依赖引擎类型）。
@immutable
class PadData {
  const PadData({
    this.role,
    this.loop = false,
    this.state = PadVisualState.idle,
    this.label,
  });

  /// 空 pad。
  static const PadData empty = PadData();

  /// 调色板下标（`pad.palette.N`）；null 表示空 pad。
  final int? role;
  final bool loop;
  final PadVisualState state;

  /// 编号文字（NUMBER 皮肤 / 编辑页）。
  final String? label;

  bool get isEmpty => role == null;

  bool get sounding =>
      state == PadVisualState.playing || state == PadVisualState.stopping;

  @override
  bool operator ==(Object other) =>
      other is PadData &&
      other.role == role &&
      other.loop == loop &&
      other.state == state &&
      other.label == label;

  @override
  int get hashCode => Object.hash(role, loop, state, label);
}

/// Pad 的 Lottie 皮肤（可选，私有素材存在时由应用传入）。
@immutable
class PadLottieSkin {
  const PadLottieSkin({
    required this.assetFor,
    this.package,
    this.playWhole = false,
  });

  /// 按调色板下标返回 Lottie 资源键；返回 null 时使用程序化绘制。
  final String? Function(int role, {required bool loop}) assetFor;
  final String? package;

  /// Launchpad 风格（按下整段播放）。
  final bool playWhole;
}

/// Pad 的位图皮肤（4.7.0 image 类皮肤：Christmas / Pets / Muertos / Halloween
/// 等整张 pad 插画）。只有注入了私有素材时由应用传入；返回 null 的角色仍用
/// token 程序化绘制。
@immutable
class PadImageSkin {
  const PadImageSkin({required this.imageFor});

  /// 调色板下标 → 常态位图（[on] = false）或按下 / 播放中的亮态位图（[on] = true，
  /// 没有时返回 null，改用 `pad.palette.N.pressed` 覆盖层）。
  final ImageProvider? Function(
    int role, {
    required bool loop,
    required bool on,
  })
  imageFor;
}

/// 单个 Pad（纯展示）。触摸由 [PadGrid] 的 Listener 统一处理，
/// 这里只根据 [pressed]（UI 即时态）和 [data.state]（引擎态）绘制。
class UpPad extends StatefulWidget {
  const UpPad({
    super.key,
    required this.data,
    this.pressed = false,
    this.pressOrigin,
    this.dimmed = false,
    this.highlighted = false,
    this.selected = false,
    this.showLabel = false,
    this.lottie,
    this.image,
    this.loopIcon,
    this.fill,
  });

  final PadData data;

  /// 手指按在 pad 上（立即生效，不等引擎）。
  final bool pressed;

  /// 按下位置（本地坐标），用于波纹。
  final Offset? pressOrigin;

  /// 教程中的非目标 pad。
  final bool dimmed;

  /// 教程目标 pad。
  final bool highlighted;

  /// 编辑页选中。
  final bool selected;
  final bool showLabel;
  final PadLottieSkin? lottie;

  /// 位图皮肤（私有素材）；为空或该角色无位图时用 token 绘制。
  final PadImageSkin? image;

  /// 自定义 loop 图标（私有素材）；为空时用 Material 图标。
  final Widget? loopIcon;

  /// 教程「填满」进度 0..1（4.7.0：颜色层从底部向上填，填满时按下判 PERFECT）。
  final double? fill;

  @override
  State<UpPad> createState() => _UpPadState();
}

class _UpPadState extends State<UpPad> with TickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(vsync: this);
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: UpPadTokens.loopRevolution,
  );

  /// Loop 播放中的白色闪烁（yoyo，一个来回 = loopFlashCycle）。
  late final AnimationController _loopFlash = AnimationController(
    vsync: this,
    duration: UpPadTokens.loopFlashHalf,
  );
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: UpPadTokens.pendingBlink,
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: UpTutorialTokens.pulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoops();
  }

  @override
  void didUpdateWidget(UpPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pressed != widget.pressed) _onPressChanged();
    _syncLoops();
  }

  void _onPressChanged() {
    final reduce = FxMotion.reduce(context);
    if (widget.pressed) {
      // 按下即全亮：pressAttack（≈1 帧）用动画实现时，控制器要到下一帧才开始走，
      // 按下后的第一帧几乎看不出变化；直接置 1 让按下当帧就渲染出亮态。
      _flash
        ..stop()
        ..value = 1;
    } else {
      _flash.animateTo(
        0,
        duration: reduce ? Duration.zero : UpPadTokens.pressRelease,
        curve: UpPadTokens.pressCurve,
      );
    }
  }

  void _syncLoops() {
    final reduce = FxMotion.reduce(context);
    final d = widget.data;
    _run(_loop, d.loop && d.sounding && !reduce);
    _run(_loopFlash, d.loop && d.sounding && !reduce, reverse: true);
    _run(_blink, d.state == PadVisualState.pending && !reduce, reverse: true);
    _run(_pulse, widget.highlighted && !reduce, reverse: true);
  }

  static void _run(AnimationController c, bool on, {bool reverse = false}) {
    if (on && !c.isAnimating) {
      c.repeat(reverse: reverse);
    } else if (!on && c.isAnimating) {
      c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    _loop.dispose();
    _loopFlash.dispose();
    _blink.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = UpTheme.of(context);
    final c = theme.colors;
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final radius = size.shortestSide * c.padShapeRadiusRatio;
        Widget pad = AnimatedBuilder(
          animation: Listenable.merge([_flash, _loopFlash, _blink, _pulse]),
          builder: (context, _) => _paint(context, theme, size, radius),
        );
        pad = SpringScale(
          scale: widget.pressed && !widget.data.isEmpty ? c.padPressedScale : 1,
          spring: SpringSpec(
            stiffness: UpPadTokens.scaleSpring.stiffness,
            damping: UpPadTokens.scaleSpring.damping,
            mass: UpPadTokens.scaleSpring.mass,
          ),
          child: pad,
        );
        return AnimatedOpacity(
          opacity: widget.dimmed ? c.padTutorialDimOpacity : UpOpacities.full,
          duration: FxMotion.duration(context, UpDurations.fast),
          child: pad,
        );
      },
    );
  }

  Widget _paint(BuildContext context, UpTheme theme, Size size, double radius) {
    final c = theme.colors;
    final d = widget.data;
    final shape = BorderRadius.circular(radius);

    if (d.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          gradient: c.padEmptyFill.linear(),
          border: Border.all(
            color: c.padEmptyBorder,
            width: UpBorderWidths.hairline,
          ),
        ),
        child: _overlays(context, theme, size, radius, null),
      );
    }

    final role = theme.padRole(d.role!);
    final flash = _flash.value;
    final sounding = d.sounding;

    // 填充不透明度：idle → pressed/playing
    final baseFill = sounding ? c.padPlayingFillOpacity : c.padIdleFillOpacity;
    final fillOpacity = _lerp(baseFill, c.padPressedFillOpacity, flash);

    // 光晕强度
    final baseGlow = sounding ? c.padPlayingGlow : c.padIdleGlow;
    final glow = math.max(baseGlow, c.padPressedGlow * flash);
    final glowRecipe = flash > 0
        ? UpPadTokens.glowPressed
        : UpPadTokens.glowPlaying;

    // Loop 待机：紫色底 + 角色色描边（截图 2）
    final loopIdle = d.loop && !sounding && flash == 0;
    Widget content;
    if (loopIdle) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          color: c.padLoopIdleFill.withValues(
            alpha: c.padLoopIdleFill.a * c.padLoopIdleFillOpacity,
          ),
          border: Border.all(color: role.mid, width: c.padLoopBorderWidth),
          boxShadow: _bevel(c.padIdleBevel, role.edge),
        ),
        child: _overlays(context, theme, size, radius, role),
      );
    } else {
      // 主体渐变走 DitheredGradient：Impeller（Android）上普通渐变不抖动，
      // 大面积径向渐变会出现同心色带（visual-review #14）。
      final stroke = _lerp(c.padIdleBorderWidth, 0, fillOpacity);
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: _bevel(c.padIdleBevel, role.edge),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DitheredGradient(
              colors: [
                for (final x in role.colors)
                  x.withValues(alpha: x.a * fillOpacity),
              ],
              stops: UpPadRole.stops,
              radial: UpPadRole.isRadial(c.padFillRadial),
              extent: UpPadRole.radialExtent,
              cornerRadius: radius,
            ),
            if (stroke > 0)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: shape,
                  border: Border.all(color: role.mid, width: stroke),
                ),
              ),
            _overlays(context, theme, size, radius, role),
          ],
        ),
      );
    }

    // 位图皮肤：整张 pad 插画替换程序化主体；亮态位图按按下 / loop 闪烁淡入。
    final base = widget.image?.imageFor(d.role!, loop: d.loop, on: false);
    if (base != null) {
      final on = widget.image!.imageFor(d.role!, loop: d.loop, on: true);
      final loopFlash = d.loop && d.sounding
          ? UpPadTokens.loopFlashCurve.transform(_loopFlash.value)
          : 0.0;
      final lit = math.max(flash, loopFlash);
      content = Stack(
        fit: StackFit.expand,
        children: [
          Image(image: base, fit: BoxFit.fill, gaplessPlayback: true),
          if (on != null && lit > 0)
            Opacity(
              opacity: lit,
              child: Image(image: on, fit: BoxFit.fill, gaplessPlayback: true),
            ),
          _overlays(context, theme, size, radius, role, flashLayer: on == null),
        ],
      );
    }

    final lottie = widget.lottie;
    final asset = lottie?.assetFor(d.role!, loop: d.loop);
    if (lottie != null && asset != null) {
      final procedural = content;
      content = SegmentedLottie(
        asset: asset,
        package: lottie.package,
        split:
            UpDurations.padPressHalf.inMicroseconds /
            UpDurations.padPress.inMicroseconds,
        pressed: widget.pressed,
        looping: d.loop && sounding,
        playWhole: lottie.playWhole,
        fallback: (_) => procedural,
      );
    }

    if (d.state == PadVisualState.pending) {
      final t = _blink.value;
      content = Opacity(
        opacity: _lerp(c.padPendingOpacityMin, UpOpacities.full, t),
        child: content,
      );
    }

    return NeonGlow(
      spec: GlowSpec(
        color: role.glow,
        spread: _maxBlur(glowRecipe),
        radius: radius,
        intensity: glow,
        fallbackShadows: glowRecipe.shadows(role.glow, intensity: glow),
      ),
      child: content,
    );
  }

  Widget _overlays(
    BuildContext context,
    UpTheme theme,
    Size size,
    double radius,
    UpPadRole? role, {
    bool flashLayer = true,
  }) {
    final c = theme.colors;
    final d = widget.data;
    final flash = _flash.value;
    final shape = BorderRadius.circular(radius);
    final flashPeak = d.sounding
        ? c.padPlayingFlashOpacity
        : c.padPressedFlashOpacity;
    final loopFlash = d.loop && d.sounding
        ? UpPadTokens.loopFlashCurve.transform(_loopFlash.value)
        : 0.0;
    final overlay = math.max(flash, loopFlash);
    final fill = widget.fill;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (role != null && fill != null)
          ClipRRect(
            borderRadius: shape,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: fill.clamp(0.0, 1.0),
                widthFactor: 1,
                child: ColoredBox(color: role.core),
              ),
            ),
          ),
        if (role != null && overlay > 0 && flashLayer)
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              // 覆盖层颜色 = 角色的 pressed 色（overlay 类皮肤为白色闪光，
              // tint 类皮肤为浅色替换，见 UpSkinPreset.technique）。
              color: role.pressed.withValues(
                alpha: role.pressed.a * flashPeak * overlay,
              ),
            ),
          ),
        if (role != null && widget.pressOrigin != null)
          PressRipple(
            progress: widget.pressed ? flash : 0,
            center: widget.pressOrigin!,
            color: c.padFlash,
            radius: radius,
            peakOpacity: flashPeak,
          ),
        if (role != null && d.loop)
          Center(child: _loopGlyph(theme, size, role)),
        if (role != null && d.loop && d.sounding)
          LoopBreathe(
            active: true,
            color: role.core,
            radius: radius,
            strokeWidth: c.padLoopBorderWidth,
            period: UpPadTokens.loopFlashCycle,
            minOpacity: c.padPendingOpacityMin,
          ),
        if ((widget.showLabel || c.padShowNumber >= UpOpacities.muted) &&
            d.label != null)
          Positioned(
            right: size.width * UpPadTokens.numberInsetEndRatio,
            bottom: size.height * UpPadTokens.numberInsetBottomRatio,
            child: Text(
              d.label!,
              style: theme.text[UpTextRole.padNumber].copyWith(
                color: c.padLabel,
                fontSize: size.width * UpPadTokens.numberSizeRatio,
              ),
            ),
          ),
        if (widget.selected)
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              border: Border.all(
                color: c.padSelectedBorder,
                width: c.padSelectedBorderWidth,
              ),
            ),
          ),
        if (widget.highlighted)
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              border: Border.all(
                color: c.padTutorialHighlight.withValues(
                  alpha: _lerp(
                    c.padPendingOpacityMin,
                    UpOpacities.full,
                    _pulse.value,
                  ),
                ),
                width: UpTutorialTokens.ringWidth,
              ),
            ),
          ),
      ],
    );
  }

  Widget _loopGlyph(UpTheme theme, Size size, UpPadRole role) {
    final c = theme.colors;
    final d = widget.data;
    final color = d.sounding ? c.padLoopIcon : role.mid;
    final iconSize = size.shortestSide * UpPadTokens.loopIconRatio;
    final glyph =
        widget.loopIcon ??
        Icon(Icons.refresh_rounded, size: iconSize, color: color);
    return RotationTransition(
      turns: _loop,
      child: IconTheme.merge(
        data: IconThemeData(size: iconSize, color: color),
        child: glyph,
      ),
    );
  }

  static List<BoxShadow> _bevel(double strength, Color edge) {
    if (strength <= 0) return const [];
    return [
      for (final s in UpPadTokens.bevel)
        BoxShadow(
          color: Color.lerp(
            s.color,
            edge,
            UpOpacities.muted,
          )!.withValues(alpha: s.color.a * strength),
          offset: s.offset,
          blurRadius: s.blurRadius,
          spreadRadius: s.spreadRadius,
        ),
    ];
  }

  static double _maxBlur(UpGlowSpec spec) =>
      spec.layers.fold(0, (m, l) => math.max(m, l.blur + l.spread));

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
