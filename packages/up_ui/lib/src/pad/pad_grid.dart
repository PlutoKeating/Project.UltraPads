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
/// 每个指针在按下时命中一个 pad，抬起/取消时释放同一个 pad。
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
  }) : assert(pads.length == columns * rows * banks);

  static const int columns = UpPadGridTokens.columns;
  static const int rows = UpPadGridTokens.rows;
  static const int banks = UpPadGridTokens.banks;
  static const int perBank = columns * rows;

  /// 24 个 pad（平铺：bank*12 + index）。
  final List<PadData> pads;

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
    upperBound: (PadGrid.banks - 1).toDouble(),
  );

  /// pointer → 平铺下标
  final Map<int, int> _pointers = {};

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
    final held = _pointers.values.toSet();
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

  void _down(PointerDownEvent e) {
    if (!widget.enabled || !isPadPointer(e)) return;
    final hit = _hit(e.localPosition);
    if (hit == null) return;
    final (flat, origin) = hit;
    if (widget.pads[flat].isEmpty) return;
    _pointers[e.pointer] = flat;
    // 先回调（同步进引擎队列），再刷新视觉
    widget.onPadDown(flat ~/ PadGrid.perBank, flat % PadGrid.perBank);
    setState(() => _pressed[flat] = origin);
  }

  void _up(PointerEvent e) {
    final flat = _pointers.remove(e.pointer);
    if (flat == null) return;
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
          onPointerUp: _up,
          onPointerCancel: _up,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _page,
              builder: (context, _) => Stack(
                children: [
                  for (var b = 0; b < PadGrid.banks; b++)
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
