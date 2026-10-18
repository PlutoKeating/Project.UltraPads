import 'package:flutter/material.dart';
import 'package:up_tokens/up_tokens.dart';

import '../util.dart';

/// 底部面板（LOAD SOUND、皮肤面板、⋮ 菜单）：标题 + 粉色下划线 + 内容。
class UpSheet extends StatelessWidget {
  const UpSheet({
    super.key,
    this.title,
    required this.children,
    this.footer,
    this.scrollable = true,
  });

  final String? title;
  final List<Widget> children;
  final Widget? footer;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      spacing: UpSheetTokens.itemGap,
      children: children,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: UpSizes.contentTabletMaxWidth,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: BoxDecoration(
              color: c.sheetBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(UpSheetTokens.radius),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: UpSpacing.sm),
                      width: UpSheetTokens.handleWidth,
                      height: UpSheetTokens.handleHeight,
                      decoration: BoxDecoration(
                        color: c.sheetHandle,
                        borderRadius: BorderRadius.circular(UpRadii.pill),
                      ),
                    ),
                  ),
                  if (title != null)
                    Container(
                      height: UpSheetTokens.headerHeight,
                      alignment: Alignment.center,
                      color: c.sheetHeader,
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: UpSpacing.xs,
                          children: [
                            UpText(
                              title!,
                              role: UpTextRole.label,
                              color: c.textPrimary,
                              align: TextAlign.center,
                            ),
                            Container(
                              height: UpBorderWidths.regular,
                              color: c.sheetUnderline,
                            ),
                          ],
                        ),
                      ),
                    ),
                  Flexible(
                    child: scrollable
                        ? SingleChildScrollView(child: body)
                        : body,
                  ),
                  if (footer != null)
                    SizedBox(height: UpSheetTokens.footerHeight, child: footer),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 以 sheet 动效（sheet.enter / exit / curve）弹出底部面板。
Future<T?> showUpSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final c = UpTheme.of(context).colors;
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: c.surfaceDim,
      transitionDuration: UpMotion.duration(context, UpSheetTokens.enter),
      reverseTransitionDuration: UpMotion.duration(context, UpSheetTokens.exit),
      pageBuilder: (context, a, b) =>
          Align(alignment: Alignment.bottomCenter, child: builder(context)),
      transitionsBuilder: (context, a, b, child) => SlideTransition(
        position: Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a, curve: UpSheetTokens.curve)),
        child: child,
      ),
    ),
  );
}

/// LOAD SOUND 的来源项：图标格 + 小字「IMPORT FROM」+ 标题。
class UpListItem extends StatefulWidget {
  const UpListItem({
    super.key,
    required this.title,
    this.overline,
    this.subtitle,
    this.icon,
    this.iconWidget,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final String title;
  final String? overline;
  final String? subtitle;
  final IconData? icon;
  final Widget? iconWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<UpListItem> createState() => _UpListItemState();
}

class _UpListItemState extends State<UpListItem> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    final active = widget.enabled && widget.onTap != null;
    final fg = widget.enabled ? c.textPrimary : c.textDisabled;
    return Semantics(
      button: true,
      enabled: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: active ? (_) => setState(() => _down = true) : null,
        onTapCancel: active ? () => setState(() => _down = false) : null,
        onTapUp: active ? (_) => setState(() => _down = false) : null,
        onTap: active ? widget.onTap : null,
        child: AnimatedContainer(
          duration: UpMotion.duration(context, UpDurations.xfast),
          constraints: const BoxConstraints(minHeight: UpListItemTokens.height),
          padding: const EdgeInsets.symmetric(
            horizontal: UpListItemTokens.paddingX,
          ),
          decoration: BoxDecoration(
            color: _down ? c.listItemPressed : c.listItem,
            borderRadius: BorderRadius.circular(UpListItemTokens.radius),
          ),
          child: Row(
            spacing: UpListItemTokens.gap,
            children: [
              if (widget.icon != null || widget.iconWidget != null)
                Container(
                  width: UpListItemTokens.iconBoxSize,
                  height: UpListItemTokens.iconBoxSize,
                  decoration: BoxDecoration(
                    color: c.sheetItemIconBox,
                    borderRadius: BorderRadius.circular(UpRadii.sm),
                    border: Border.all(
                      color: c.borderDefault,
                      width: UpBorderWidths.hairline,
                    ),
                  ),
                  alignment: Alignment.center,
                  child:
                      widget.iconWidget ??
                      Icon(
                        widget.icon,
                        size: UpListItemTokens.iconSize,
                        color: fg,
                      ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: UpSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.overline != null)
                        UpText(
                          widget.overline!,
                          role: UpTextRole.overline,
                          color: c.textMuted,
                        ),
                      UpText(widget.title, role: UpTextRole.titleSm, color: fg),
                      if (widget.subtitle != null)
                        UpText(
                          widget.subtitle!,
                          role: UpTextRole.caption,
                          color: c.textSecondary,
                          maxLines: 2,
                        ),
                    ],
                  ),
                ),
              ),
              ?widget.trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// 设置页开关行。
class UpSwitchRow extends StatelessWidget {
  const UpSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    return UpListItem(
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: c.accentPrimary,
      ),
    );
  }
}
