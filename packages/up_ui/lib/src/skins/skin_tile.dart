import 'package:flutter/material.dart';
import 'package:up_tokens/up_tokens.dart';

import '../pad/pad.dart';
import '../util.dart';

/// 皮肤面板中的一项：用该皮肤的主题绘制 2×2 迷你 pad 预览 + 名称。
class SkinTile extends StatelessWidget {
  const SkinTile({
    super.key,
    required this.theme,
    required this.name,
    this.selected = false,
    this.onTap,
    this.thumbnail,
  });

  /// 该皮肤的主题（用于预览）。
  final UpTheme theme;
  final String name;
  final bool selected;
  final VoidCallback? onTap;

  /// 私有缩略图（存在时替代程序化预览）。
  final ImageProvider? thumbnail;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final preview = thumbnail != null
        ? Image(image: thumbnail!, fit: BoxFit.cover)
        : Theme(
            data: theme.toThemeData(),
            child: Container(
              color: theme.colors.surfacePads,
              padding: const EdgeInsets.all(UpSpacing.sm),
              child: Column(
                spacing: UpPadTokens.gap,
                children: [
                  for (final row in const [
                    [0, 1],
                    [2, 3],
                  ])
                    Expanded(
                      child: Row(
                        spacing: UpPadTokens.gap,
                        children: [
                          for (final r in row)
                            Expanded(
                              child: UpPad(
                                data: PadData(role: r, loop: r == 3),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
    return Semantics(
      selected: selected,
      button: true,
      label: name,
      child: PressScale(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: UpSpacing.xs,
          children: [
            AnimatedContainer(
              duration: UpMotion.duration(context, UpDurations.fast),
              width: UpSkinItemTokens.thumbSize,
              height: UpSkinItemTokens.thumbSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(UpSkinItemTokens.radius),
                border: Border.all(
                  color: selected ? c.accentSelected : c.borderSubtle,
                  width: selected
                      ? UpBorderWidths.thick
                      : UpBorderWidths.hairline,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: preview,
            ),
            UpText(
              name,
              role: UpTextRole.labelSm,
              color: selected ? c.accentSelected : c.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
