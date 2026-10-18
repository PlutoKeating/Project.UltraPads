import 'package:flutter/material.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';

@immutable
class UpTabItem {
  const UpTabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// 底部 TabBar（4.7.0 `BaseTabBar`：顶部 10% 白线，选中图标底下一个粉色圆）。
class UpTabBar extends StatelessWidget {
  const UpTabBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<UpTabItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    return Container(
      height: UpTabBarTokens.height,
      decoration: BoxDecoration(
        color: c.surfacePage,
        border: Border(
          top: BorderSide(
            color: c.borderDivider,
            width: UpBorderWidths.hairline,
          ),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                selected: i == index,
                button: true,
                label: items[i].label,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: Center(
                    child: AnimatedContainer(
                      duration: UpMotion.duration(context, UpDurations.fast),
                      width:
                          UpTabBarTokens.iconSize +
                          UpTabBarTokens.indicatorHeight * 2,
                      height:
                          UpTabBarTokens.iconSize +
                          UpTabBarTokens.indicatorHeight * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == index
                            ? c.accentPrimary
                            : UpPrimitiveColors.baseTransparent,
                      ),
                      child: Icon(
                        items[i].icon,
                        size: UpTabBarTokens.iconSize,
                        color: i == index ? c.iconOnAccent : c.iconSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 子 Tab（DOWNLOADED / FAVORITES / MY KITS：选中 3 px 粉色下划线）。
class UpSegmentTabs extends StatelessWidget {
  const UpSegmentTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: UpSpacing.md),
                child: Column(
                  spacing: UpSpacing.xs,
                  children: [
                    UpText(
                      labels[i],
                      role: UpTextRole.label,
                      color: i == index ? c.textPrimary : c.textMuted,
                    ),
                    AnimatedContainer(
                      duration: UpMotion.duration(context, UpDurations.fast),
                      height: UpBorderWidths.thick,
                      width: i == index ? UpButtonTokens.minWidth : 0,
                      color: c.accentPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
