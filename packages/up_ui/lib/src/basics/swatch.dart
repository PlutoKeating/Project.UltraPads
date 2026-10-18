import 'package:flutter/widgets.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';

/// 编辑器色板圆点（32dp；未选中白描边 2，选中 4）。
class UpSwatch extends StatelessWidget {
  const UpSwatch({
    super.key,
    required this.color,
    this.selected = false,
    this.onTap,
    this.semanticLabel,
  });

  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    return Semantics(
      label: semanticLabel,
      selected: selected,
      child: PressScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: UpMotion.duration(context, UpDurations.fast),
          width: UpSwatchTokens.size,
          height: UpSwatchTokens.size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: c.swatchRing,
              width: selected
                  ? UpSwatchTokens.ringWidthSelected
                  : UpSwatchTokens.ringWidth,
            ),
          ),
        ),
      ),
    );
  }
}

/// 一排色板，选中下标 [selected]。
class UpSwatchRow extends StatelessWidget {
  const UpSwatchRow({
    super.key,
    required this.colors,
    required this.selected,
    required this.onSelected,
    this.labels,
  });

  final List<Color> colors;
  final int? selected;
  final ValueChanged<int> onSelected;
  final List<String>? labels;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: UpSpacing.md,
    runSpacing: UpSpacing.md,
    children: [
      for (var i = 0; i < colors.length; i++)
        UpSwatch(
          color: colors[i],
          selected: selected == i,
          onTap: () => onSelected(i),
          semanticLabel: labels?[i],
        ),
    ],
  );
}
