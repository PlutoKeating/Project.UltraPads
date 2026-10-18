import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:up_fx/up_fx.dart';
import 'package:up_tokens/up_tokens.dart';

import 'pad.dart';

/// Pad 回调：bank 0 = A，1 = B；index 0..11 行优先。
typedef PadPointerCallback = void Function(int bank, int index);

/// 3×4 Pad 网格，A/B 两页，带翻页动画。
///
/// 触摸用 [Listener] 读取原始指针（不进手势竞技场，零延迟），多点触控：
/// 触摸到即触发——按下落在 pad 上或手指滑进 pad 都立即回调 [onPadDown]，
/// 滑出 / 抬起 / 取消时对该 pad 回调 [onPadUp]；在缝隙按下后滑进 pad 同样触发。
/// 回调是同步的——调用方应直接调用引擎的同步 `pad_down/pad_up`。
/// 按下态在本组件内**立即**显示，发声状态（[PadData.state]）以引擎为准。
class PadGrid extends StatefulWidget {
  const PadGrid({
    super.key,
    required this.pads,
    required this.bank,
    required this.onPadDown,
    required this.onPadUp,
    this.dimmed = const {},
    this.highlighted = const {},
    this.selected,
    this.showLabels = false,
    this.lottie,
    this.image,
    this.loopIcon,
    this.enabled = true,
    this.externallyPressed = const {},
    this.fills = const {},
  }) : assert(pads.length > 0 && pads.length % (columns * rows) == 0);

  static const int columns = UpPadGridTokens.columns;
  static const int rows = UpPadGridTokens.rows;
  static const int perBank = columns * rows;

  /// 全部音色组的 pad（平铺：bank*12 + index），长度是 12 的倍数。
  final List<PadData> pads;

  /// 音色组（页）数。
  int get bankCount => pads.length ~/ perBank;

  /// 当前页（0 = A，1 = B）。
  final int bank;
  final PadPointerCallback onPadDown;
  final PadPointerCallback onPadUp;

  /// 教程：被暗化 / 高亮的平铺下标。
  final Set<int> dimmed;
  final Set<int> highlighted;

  /// 编辑页选中的平铺下标。
  final int? selected;
  final bool showLabels;
  final PadLottieSkin? lottie;

  /// 位图皮肤（私有素材，可选），见 [PadImageSkin]。
  final PadImageSkin? image;
  final Widget? loopIcon;
  final bool enabled;

  /// 由键盘 / MIDI 按下的 pad（平铺下标），与触摸一样立即显示按下态。
  final Set<int> externallyPressed;

  /// 教程：平铺下标 → 填充进度 0..1。
  final Map<int, double> fills;

  @override
  State<PadGrid> createState() => PadGridState();
}

class PadGridState extends State<PadGrid> with SingleTickerProviderStateMixin {
  late final AnimationController _page = AnimationController(
    vsync: this,
    value: widget.bank.toDouble(),
    // 组数在一个网格的生命周期内不变（应用里始终传入引擎上限数量的 pad）。
    upperBound: (widget.bankCount - 1).toDouble(),
  );

  /// pointer → 正在触摸的平铺下标（[_none] = 在网格内但不在任何 pad 上，例如缝隙）
  final Map<int, int> _pointers = {};
  static const _none = -1;

  /// 平铺下标 → 按下位置（pad 本地坐标）
  final Map<int, Offset> _pressed = {};
  Size _cell = Size.zero;

  /// 当前按下的 pad（测试 / 调试用）。
  Set<int> get pressedPads => _pressed.keys.toSet();

  @override
  void didUpdateWidget(PadGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bank != widget.bank) {
      _page.animateTo(
        widget.bank.toDouble(),
        duration: FxMotion.duration(context, UpPadGridTokens.bankSwitch),
        curve: UpPadGridTokens.bankSwitchCurve,
      );
    }
    if (!widget.enabled) _releaseAll();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _releaseAll() {
    final held = _pointers.values.where((f) => f != _none).toSet();
    _pointers.clear();
    _pressed.clear();
    for (final flat in held) {
      widget.onPadUp(flat ~/ PadGrid.perBank, flat % PadGrid.perBank);
    }
  }

  (int, Offset)? _hit(Offset local) {
    if (_cell.isEmpty) return null;
    final gap = UpPadTokens.gap;
    final col = (local.dx / (_cell.width + gap)).floor();
    final row = (local.dy / (_cell.height + gap)).floor();
    if (col < 0 || col >= PadGrid.columns || row < 0 || row >= PadGrid.rows) {
      return null;
    }
    final origin = Offset(
      local.dx - col * (_cell.width + gap),
      local.dy - row * (_cell.height + gap),
    );
    final flat = widget.bank * PadGrid.perBank + row * PadGrid.columns + col;
    return (flat, origin);
  }

  /// 触摸到即触发：按下落在 pad 上、或手指滑进 pad，都立刻发声（每次触碰都重触发）。
  void _down(PointerDownEvent e) {
    if (!widget.enabled || !isPadPointer(e)) return;
    _pointers[e.pointer] = _none;
    _touch(e.pointer, e.localPosition);
  }

  void _move(PointerMoveEvent e) {
    if (!widget.enabled || !_pointers.containsKey(e.pointer)) return;
    if (!isPadPointer(e)) return;
    _touch(e.pointer, e.localPosition);
  }

  void _up(PointerEvent e) {
    final flat = _pointers.remove(e.pointer);
    if (flat == null) return;
    _leave(flat);
  }

  /// 指针在 `local` 处：离开上一个 pad（松开）并进入新的 pad（立即触发）。
  void _touch(int pointer, Offset local) {
    final hit = _hit(local);
    final flat = hit == null || widget.pads[hit.$1].isEmpty ? _none : hit.$1;
    final previous = _pointers[pointer] ?? _none;
    if (flat == previous) return;
    _pointers[pointer] = flat;
    // 先回调（同步进引擎队列），再刷新视觉
    if (previous != _none) {
      widget.onPadUp(previous ~/ PadGrid.perBank, previous % PadGrid.perBank);
    }
    if (flat != _none) {
      widget.onPadDown(flat ~/ PadGrid.perBank, flat % PadGrid.perBank);
    }
    setState(() {
      if (previous != _none && !_pointers.containsValue(previous)) {
        _pressed.remove(previous);
      }
      if (flat != _none) _pressed[flat] = hit!.$2;
    });
  }

  void _leave(int flat) {
    if (flat == _none) return;
    widget.onPadUp(flat ~/ PadGrid.perBank, flat % PadGrid.perBank);
    if (!_pointers.containsValue(flat)) {
      setState(() => _pressed.remove(flat));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gap = UpPadTokens.gap;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        _cell = Size(
          (w - gap * (PadGrid.columns - 1)) / PadGrid.columns,
          (h - gap * (PadGrid.rows - 1)) / PadGrid.rows,
        );
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _page,
              builder: (context, _) => Stack(
                children: [
                  for (var b = 0; b < widget.bankCount; b++)
                    if ((b - _page.value).abs() < 1)
                      Positioned(
                        left: (b - _page.value) * (w + gap),
                        top: 0,
                        width: w,
                        height: h,
                        child: _bankPage(b),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bankPage(int bank) {
    final gap = UpPadTokens.gap;
    return Column(
      children: [
        for (var r = 0; r < PadGrid.rows; r++) ...[
          if (r > 0) SizedBox(height: gap),
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < PadGrid.columns; col++) ...[
                  if (col > 0) SizedBox(width: gap),
                  Expanded(
                    child: _cellAt(
                      bank * PadGrid.perBank + r * PadGrid.columns + col,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _cellAt(int flat) => RepaintBoundary(
    child: UpPad(
      key: ValueKey('pad-$flat'),
      data: widget.pads[flat],
      pressed:
          _pressed.containsKey(flat) || widget.externallyPressed.contains(flat),
      pressOrigin: _pressed[flat],
      dimmed: widget.dimmed.contains(flat),
      highlighted: widget.highlighted.contains(flat),
      selected: widget.selected == flat,
      showLabel: widget.showLabels,
      lottie: widget.lottie,
      image: widget.image,
      loopIcon: widget.loopIcon,
      fill: widget.fills[flat],
    ),
  );
}

/// 鼠标只有主键触发 pad；触摸 / 手写笔全部触发。
bool isPadPointer(PointerEvent e) =>
    e.kind != PointerDeviceKind.mouse || e.buttons == kPrimaryMouseButton;
