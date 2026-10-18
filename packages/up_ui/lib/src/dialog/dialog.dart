import 'package:flutter/material.dart';
import 'package:up_tokens/up_tokens.dart';

import '../basics/up_button.dart';
import '../util.dart';

class UpDialog extends StatelessWidget {
  const UpDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.actions = const [],
  });

  final String title;
  final String? message;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.upColors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: UpDialogTokens.maxWidth),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            margin: const EdgeInsets.all(UpSpacing.xxl),
            padding: const EdgeInsets.all(UpDialogTokens.padding),
            decoration: BoxDecoration(
              color: c.dialogBackground,
              borderRadius: BorderRadius.circular(UpDialogTokens.radius),
              boxShadow: UpDialogTokens.shadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: UpDialogTokens.gap,
              children: [
                UpText(
                  title,
                  role: UpTextRole.title,
                  color: c.textPrimary,
                  align: TextAlign.center,
                  maxLines: 2,
                ),
                if (message != null)
                  UpText(
                    message!,
                    role: UpTextRole.body,
                    color: c.textSecondary,
                    align: TextAlign.center,
                    maxLines: 6,
                  ),
                ?content,
                if (actions.isNotEmpty)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: UpSpacing.md,
                    runSpacing: UpSpacing.md,
                    children: actions,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 弹出对话框（dialog.enter / curve，缩放 + 淡入）。
Future<T?> showUpDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  final c = UpTheme.of(context).colors;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: c.dialogScrim,
    transitionDuration: UpMotion.duration(context, UpDialogTokens.enter),
    pageBuilder: (context, a, b) => builder(context),
    transitionBuilder: (context, a, b, child) {
      final curved = CurvedAnimation(parent: a, curve: UpDialogTokens.curve);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(
            begin: UpKitCardTokens.focusScale,
            end: UpOpacities.full,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// 确认对话框的快捷方法。
Future<bool> showUpConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirm,
  required String cancel,
  bool danger = false,
}) async {
  final r = await showUpDialog<bool>(
    context,
    builder: (ctx) => UpDialog(
      title: title,
      message: message,
      actions: [
        UpButton(
          label: cancel,
          variant: UpButtonVariant.ghost,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        UpButton(
          label: confirm,
          variant: danger ? UpButtonVariant.danger : UpButtonVariant.primary,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// 轻提示（「Kit 已加载！」）。
void showUpToast(BuildContext context, String message) {
  final c = UpTheme.of(context).colors;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: UpToastTokens.visible,
        backgroundColor: c.toastBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UpToastTokens.radius),
        ),
        content: UpText(
          message,
          role: UpTextRole.bodySm,
          color: c.toastForeground,
          maxLines: 3,
        ),
      ),
    );
}
