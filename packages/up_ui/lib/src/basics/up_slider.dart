import 'package:flutter/widgets.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';

/// 轻量滑块（音量、速度、教程进度）。拖动/点击均可。
class UpSlider extends StatefulWidget {
  const UpSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeEnd,
    this.semanticLabel,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String? semanticLabel;

  @override
  State<UpSlider> createState() => _UpSliderState();
}

class _UpSliderState extends State<UpSlider> {
  bool _active = false;

  double _valueAt(double dx, double width) {
    final inset = UpSliderTokens.insetX;
    var t = ((dx - inset) / (width - inset * 2)).clamp(0.0, 1.0);
    final d = widget.divisions;
    if (d != null && d > 0) t = (t * d).round() / d;
    return widget.min + (widget.max - widget.min) * t;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final span = widget.max - widget.min;
    final t = span == 0
        ? 0.0
        : ((widget.value - widget.min) / span).clamp(0.0, 1.0);
    final enabled = widget.onChanged != null;
    return Semantics(
      label: widget.semanticLabel,
      slider: true,
      value: widget.value.toStringAsFixed(2),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          void update(Offset p) => widget.onChanged?.call(_valueAt(p.dx, w));
          final thumb = _active
              ? UpSliderTokens.thumbSizeActive
              : UpSliderTokens.thumbSize;
          final inset = UpSliderTokens.insetX;
          final x = inset + (w - inset * 2) * t;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (d) => update(d.localPosition) : null,
            onTapUp: enabled
                ? (d) =>
                      widget.onChangeEnd?.call(_valueAt(d.localPosition.dx, w))
                : null,
            onHorizontalDragStart: enabled
                ? (d) => setState(() => _active = true)
                : null,
            onHorizontalDragUpdate: enabled
                ? (d) => update(d.localPosition)
                : null,
            onHorizontalDragEnd: enabled
                ? (d) {
                    setState(() => _active = false);
                    widget.onChangeEnd?.call(widget.value);
                  }
                : null,
            child: SizedBox(
              height: UpSliderTokens.thumbSizeActive,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned(
                    left: inset,
                    right: inset,
                    child: Container(
                      height: UpSliderTokens.trackHeight,
                      decoration: BoxDecoration(
                        color: c.sliderTrack,
                        borderRadius: BorderRadius.circular(UpRadii.pill),
                      ),
                    ),
                  ),
                  Positioned(
                    left: inset,
                    width: x - inset,
                    child: Container(
                      height: UpSliderTokens.trackHeight,
                      decoration: BoxDecoration(
                        color: c.sliderFill,
                        borderRadius: BorderRadius.circular(UpRadii.pill),
                      ),
                    ),
                  ),
                  Positioned(
                    left: x - thumb / 2,
                    child: AnimatedContainer(
                      duration: UpMotion.duration(context, UpDurations.fast),
                      width: thumb,
                      height: thumb,
                      decoration: BoxDecoration(
                        color: c.sliderThumb,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
