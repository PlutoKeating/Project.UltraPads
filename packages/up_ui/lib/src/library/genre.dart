import 'package:flutter/material.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';

/// 曲风圆形图标 + 标签（截图 4 底部：HIP-HOP / FUNK BR / K-POP / ROCK / DISCO）。
class GenreIcon extends StatelessWidget {
  const GenreIcon({
    super.key,
    required this.label,
    required this.role,
    this.icon,
    this.iconWidget,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final int role;
  final IconData? icon;
  final Widget? iconWidget;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = UpTheme.of(context);
    final r = t.padRole(role);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: PressScale(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: UpGenreIconTokens.labelGap,
          children: [
            AnimatedContainer(
              duration: UpMotion.duration(context, UpDurations.fast),
              width: UpGenreIconTokens.size,
              height: UpGenreIconTokens.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: r.gradient(radial: t.colors.padFillRadial),
                border: Border.all(
                  color: selected ? t.colors.genreRing : r.edge,
                  width: UpGenreIconTokens.ringWidth,
                ),
                boxShadow: selected
                    ? UpPadTokens.glowPlaying.shadows(r.glow)
                    : null,
              ),
              alignment: Alignment.center,
              child:
                  iconWidget ??
                  Icon(
                    icon ?? Icons.music_note_rounded,
                    size: UpGenreIconTokens.iconSize,
                    color: t.colors.iconOnAccent,
                  ),
            ),
            UpText(label, role: UpTextRole.labelSm, color: t.colors.genreLabel),
          ],
        ),
      ),
    );
  }
}

/// 一排可横向滚动的曲风图标。
class GenreRow extends StatelessWidget {
  const GenreRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: UpPageTokens.paddingX),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: UpGenreIconTokens.gap,
      children: children,
    ),
  );
}
