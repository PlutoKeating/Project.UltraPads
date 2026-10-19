import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../account/account_state.dart';
import '../../ugc/ugc_models.dart';
import '../../ugc/ugc_state.dart';
import '../catalog/catalog_models.dart';
import 'ugc_format.dart';
import 'ugc_widgets.dart';

/// 举报一条公开的用户上传：选原因、补充说明、提交（docs/API.md §7.5）。
/// 未登录、或这是自己的上传时只给出提示，不弹面板。
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref,
  CatalogItem item,
) async {
  final l10n = context.l10n;
  if (!ref.read(accountProvider).signedIn) {
    showUpToast(context, l10n.libraryUgcReportSignIn);
    return;
  }
  if (ref.read(myUploadsProvider).owns(item.id)) {
    showUpToast(context, l10n.libraryUgcReportOwn);
    return;
  }
  final sent = await showUpSheet<bool>(
    context,
    builder: (_) => _ReportSheet(item: item),
  );
  if (sent == true && context.mounted) {
    showUpToast(context, l10n.libraryUgcReportSent);
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.item});
  final CatalogItem item;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  static const _noteMax = 500;

  final _note = TextEditingController();
  ReportReason _reason = ReportReason.copyright;
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    setState(() => _sending = true);
    try {
      await ref.read(reportUploadProvider)(widget.item.id, _reason, _note.text);
      if (mounted) nav.pop(true);
    } on CatalogException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showUpToast(
        context,
        e.status == 404 || e.status == 410
            ? l10n.libraryUgcReportGone
            : e.status == 400
            ? l10n.libraryUgcReportOwn
            : ugcErrorMessage(l10n, e),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: UpMotion.duration(context, UpSheetTokens.enter),
      padding: EdgeInsets.only(bottom: bottom),
      child: UpSheet(
        title: l10n.libraryUgcReportTitle,
        children: [
          for (final r in ReportReason.values)
            UgcChoiceRow(
              label: reportReasonLabel(l10n, r),
              selected: _reason == r,
              onTap: () => setState(() => _reason = r),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UpPageTokens.paddingX,
            ),
            child: UgcTextField(
              label: l10n.libraryUgcReportNoteHint,
              controller: _note,
              maxLength: _noteMax,
              maxLines: 3,
              enabled: !_sending,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(UpPageTokens.paddingX),
            child: UpButton(
              label: l10n.libraryUgcReportSubmit,
              expand: true,
              onPressed: _sending ? null : () => unawaited(_submit()),
            ),
          ),
        ],
      ),
    );
  }
}
