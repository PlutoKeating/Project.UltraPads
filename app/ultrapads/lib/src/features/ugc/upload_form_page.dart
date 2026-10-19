import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../account/account_state.dart';
import '../../state/engine_state.dart';
import '../../ugc/ugc_models.dart';
import '../../ugc/ugc_state.dart';
import '../catalog/catalog_format.dart';
import '../catalog/catalog_models.dart';
import 'ugc_format.dart';
import 'ugc_widgets.dart';

/// 上传表单：标题、署名、许可证、来源声明，确认有权分享后上传。条目默认私有（docs/API.md §7.5）。
class UploadFormPage extends ConsumerStatefulWidget {
  const UploadFormPage({super.key, required this.kitId});
  final String kitId;

  @override
  ConsumerState<UploadFormPage> createState() => _UploadFormPageState();
}

class _UploadFormPageState extends ConsumerState<UploadFormPage> {
  static const _titleMax = 120;
  static const _creditMax = 500;

  final _title = TextEditingController();
  final _credit = TextEditingController();
  final _sourceUrl = TextEditingController();
  final _description = TextEditingController();
  String _license = 'CC-BY-4.0';
  SourceDeclaration _declaration = SourceDeclaration.own;
  bool _confirmed = false;

  /// 点过提交之后才显示字段错误，避免一进页面就满屏红字。
  bool _submitted = false;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    _credit.text = ref.read(accountProvider).profile?.name ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _credit.dispose();
    _sourceUrl.dispose();
    _description.dispose();
    super.dispose();
  }

  UploadDraft _draft() {
    final kit = ref
        .read(kitsProvider)
        .value
        ?.where((k) => k.id == widget.kitId)
        .firstOrNull;
    return UploadDraft(
      title: _title.text,
      credit: _credit.text,
      license: _license,
      declaration: _declaration,
      sourceUrl: _sourceUrl.text,
      description: _description.text,
      bpm: kit?.bpm ?? 0,
      groupCount: kit?.groupCount ?? 0,
      padCount: kit?.padCount ?? 0,
    );
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final errors = validateUpload(_draft(), confirmed: _confirmed);
    if (errors.any) return;
    await ref.read(uploadProvider.notifier).upload(widget.kitId, _draft());
  }

  Future<void> _pickLicense(BuildContext context) async {
    final l10n = context.l10n;
    final v = await showUpSheet<String>(
      context,
      builder: (ctx) => UpSheet(
        title: l10n.libraryUgcFieldLicense,
        children: [
          for (final id in ugcLicenses)
            UgcChoiceRow(
              label: LicenseInfo.of(id).badge,
              subtitle: licenseHints(l10n, LicenseInfo.of(id)).join(' '),
              selected: _license == id,
              onTap: () => Navigator.pop(ctx, id),
            ),
        ],
      ),
    );
    if (v != null) setState(() => _license = v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final upload = ref.watch(uploadProvider);
    final kits = ref.watch(kitsProvider).value;
    final kit = kits?.where((k) => k.id == widget.kitId).firstOrNull;
    if (!_prefilled && kit != null) {
      _prefilled = true;
      if (_title.text.isEmpty) _title.text = kit.name;
    }
    final errors = _submitted
        ? validateUpload(_draft(), confirmed: _confirmed)
        : const UploadFormErrors();
    final running = upload.running;
    final done = upload.phase == UploadPhase.done;

    Widget status() {
      final text = switch (upload.phase) {
        UploadPhase.exporting => l10n.libraryUgcPhaseExporting,
        UploadPhase.creating => l10n.libraryUgcPhaseCreating,
        UploadPhase.uploading => l10n.libraryUgcPhaseUploading(
          (upload.progress * 100).round(),
        ),
        UploadPhase.done => l10n.libraryUgcUploadDone,
        UploadPhase.failed => ugcErrorMessage(l10n, upload.error!),
        UploadPhase.idle => '',
      };
      return UpText(
        text,
        key: const ValueKey('upload-status'),
        role: UpTextRole.body,
        color: upload.phase == UploadPhase.failed
            ? c.statusDanger
            : c.textSecondary,
        align: TextAlign.center,
        maxLines: 3,
      );
    }

    final Widget action;
    if (done) {
      action = UpButton(
        key: const ValueKey('upload-finish'),
        label: l10n.commonDone,
        size: UpButtonSize.lg,
        expand: true,
        onPressed: () => context.pop(),
      );
    } else if (running) {
      action = Row(
        spacing: UpSpacing.lg,
        children: [
          Expanded(
            child: UpButton(
              label: upload.phase == UploadPhase.uploading
                  ? l10n.libraryUgcPhaseUploading(
                      (upload.progress * 100).round(),
                    )
                  : l10n.commonLoading,
              size: UpButtonSize.lg,
              expand: true,
            ),
          ),
          UpButton(
            key: const ValueKey('upload-cancel'),
            label: l10n.commonCancel,
            variant: UpButtonVariant.outline,
            size: UpButtonSize.lg,
            onPressed: ref.read(uploadProvider.notifier).cancel,
          ),
        ],
      );
    } else {
      action = UpButton(
        key: const ValueKey('upload-submit'),
        label: l10n.libraryUgcSubmit,
        icon: Icons.cloud_upload_rounded,
        size: UpButtonSize.lg,
        expand: true,
        onPressed: () => unawaited(_submit()),
      );
    }

    return Scaffold(
      backgroundColor: c.surfacePads,
      body: SafeArea(
        child: Column(
          children: [
            UpTopBar(
              background: c.surfacePads,
              title: l10n.libraryUgcFormTitle,
              leading: UpIconButton(
                icon: Icons.arrow_back_rounded,
                semanticLabel: l10n.commonBack,
                onPressed: running ? null : () => context.pop(),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(UpPageTokens.paddingX),
                children: [
                  UpText(
                    l10n.libraryUgcFormPrivateNote,
                    role: UpTextRole.bodySm,
                    color: c.textSecondary,
                    maxLines: 3,
                  ),
                  const SizedBox(height: UpSpacing.lg),
                  UgcTextField(
                    key: const ValueKey('field-title'),
                    label: l10n.libraryUgcFieldTitle,
                    controller: _title,
                    maxLength: _titleMax,
                    enabled: !running && !done,
                    errorText: errors.title
                        ? l10n.libraryUgcFormErrTitle
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: UpSpacing.md),
                  UgcTextField(
                    key: const ValueKey('field-credit'),
                    label: l10n.libraryUgcFieldCredit,
                    hint: l10n.libraryUgcFieldCreditHint,
                    controller: _credit,
                    maxLength: _creditMax,
                    maxLines: 3,
                    enabled: !running && !done,
                    errorText: errors.credit
                        ? l10n.libraryUgcFormErrCredit
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: UpSpacing.md),
                  UpListItem(
                    key: const ValueKey('field-license'),
                    icon: Icons.verified_rounded,
                    title: l10n.libraryUgcFieldLicense,
                    subtitle: [
                      LicenseInfo.of(_license).badge,
                      ...licenseHints(l10n, LicenseInfo.of(_license)),
                    ].join(' · '),
                    trailing: const Icon(Icons.expand_more_rounded),
                    onTap: running || done
                        ? null
                        : () => unawaited(_pickLicense(context)),
                  ),
                  const SizedBox(height: UpSpacing.md),
                  UpText(
                    l10n.libraryUgcDeclarationTitle,
                    role: UpTextRole.titleSm,
                    color: c.textSecondary,
                  ),
                  UgcChoiceRow(
                    key: const ValueKey('declaration-own'),
                    label: l10n.libraryUgcDeclarationOwn,
                    selected: _declaration == SourceDeclaration.own,
                    onTap: () =>
                        setState(() => _declaration = SourceDeclaration.own),
                  ),
                  UgcChoiceRow(
                    key: const ValueKey('declaration-licensed'),
                    label: l10n.libraryUgcDeclarationLicensed,
                    selected: _declaration == SourceDeclaration.licensed,
                    onTap: () => setState(
                      () => _declaration = SourceDeclaration.licensed,
                    ),
                  ),
                  const SizedBox(height: UpSpacing.md),
                  UgcTextField(
                    key: const ValueKey('field-source'),
                    label: l10n.libraryUgcFieldSourceUrl,
                    controller: _sourceUrl,
                    keyboardType: TextInputType.url,
                    enabled: !running && !done,
                    errorText: errors.sourceUrl
                        ? l10n.libraryUgcFormErrUrl
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: UpSpacing.md),
                  UgcTextField(
                    key: const ValueKey('field-description'),
                    label: l10n.libraryUgcFieldDescription,
                    controller: _description,
                    maxLines: 4,
                    maxLength: _creditMax,
                    enabled: !running && !done,
                  ),
                  const SizedBox(height: UpSpacing.md),
                  UpSwitchRow(
                    key: const ValueKey('field-confirm'),
                    title: l10n.libraryUgcConfirmRights,
                    value: _confirmed,
                    onChanged: running || done
                        ? (_) {}
                        : (v) => setState(() => _confirmed = v),
                  ),
                  if (errors.confirmed)
                    Padding(
                      padding: const EdgeInsets.only(top: UpSpacing.xs),
                      child: UpText(
                        l10n.libraryUgcFormErrConfirm,
                        role: UpTextRole.caption,
                        color: c.statusDanger,
                      ),
                    ),
                  const SizedBox(height: UpSpacing.lg),
                  if (upload.phase != UploadPhase.idle) status(),
                  if (running && upload.phase != UploadPhase.uploading)
                    const Padding(
                      padding: EdgeInsets.only(top: UpSpacing.md),
                      child: Center(child: UpProgressRing()),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(UpPageTokens.paddingX),
              child: action,
            ),
          ],
        ),
      ),
    );
  }
}
