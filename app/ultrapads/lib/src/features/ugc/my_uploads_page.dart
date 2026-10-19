import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../account/account_state.dart';
import '../../account/auth_flow.dart';
import '../../routing/routes.dart';
import '../../state/engine_state.dart';
import '../../ugc/ugc_models.dart';
import '../../ugc/ugc_state.dart';
import '../catalog/catalog_format.dart';
import '../catalog/catalog_models.dart';
import 'ugc_format.dart';
import 'ugc_widgets.dart';

/// 我的上传：列出自己上传的 Kit，改公开 / 私有、删除、取回到本机，以及上传新的 Kit（docs/API.md §7.5）。
class MyUploadsPage extends ConsumerStatefulWidget {
  const MyUploadsPage({super.key});

  @override
  ConsumerState<MyUploadsPage> createState() => _MyUploadsPageState();
}

class _MyUploadsPageState extends ConsumerState<MyUploadsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(Future.microtask(_load));
  }

  Future<void> _load() async {
    if (!mounted || !ref.read(accountProvider).signedIn) return;
    await ref.read(myUploadsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final account = ref.watch(accountProvider);
    final uploads = ref.watch(myUploadsProvider);
    ref.listen<AccountState>(accountProvider, (prev, next) {
      if (next.signedIn && !(prev?.signedIn ?? false)) unawaited(_load());
    });

    final Widget body;
    if (account.status == AccountStatus.loading) {
      body = const Center(child: UpProgressRing());
    } else if (!account.signedIn) {
      body = _Message(
        text: l10n.libraryUgcSignInPrompt,
        action: UpButton(
          key: const ValueKey('uploads-sign-in'),
          label: l10n.settingsAccountSignIn,
          onPressed: () => unawaited(
            ref
                .read(accountProvider.notifier)
                .signIn(
                  page: LoopbackPage(
                    title: l10n.settingsAccountLoopbackTitle,
                    body: l10n.settingsAccountLoopbackBody,
                  ),
                ),
          ),
        ),
      );
    } else if (!uploads.loaded && uploads.loading) {
      body = const Center(child: UpProgressRing());
    } else if (!uploads.loaded && uploads.error != null) {
      body = _Message(
        text: ugcErrorMessage(l10n, uploads.error!),
        action: UpButton(
          label: l10n.commonRetry,
          size: UpButtonSize.sm,
          onPressed: () => unawaited(_load()),
        ),
      );
    } else if (uploads.items.isEmpty) {
      body = _Message(text: l10n.libraryUgcEmpty);
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: UpPageTokens.paddingX,
            vertical: UpSpacing.md,
          ),
          itemCount: uploads.items.length,
          itemBuilder: (context, i) => _UploadRow(
            upload: uploads.items[i],
            busy: uploads.busy.contains(uploads.items[i].id),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.surfacePads,
      body: SafeArea(
        child: Column(
          children: [
            UpTopBar(
              background: c.surfacePads,
              title: l10n.libraryUgcMyTitle,
              leading: UpIconButton(
                icon: Icons.arrow_back_rounded,
                semanticLabel: l10n.commonBack,
                onPressed: () => context.pop(),
              ),
            ),
            Expanded(child: body),
            if (account.signedIn)
              Padding(
                padding: const EdgeInsets.all(UpPageTokens.paddingX),
                child: UpButton(
                  key: const ValueKey('uploads-new'),
                  label: l10n.libraryUgcUploadAction,
                  icon: Icons.cloud_upload_rounded,
                  size: UpButtonSize.lg,
                  expand: true,
                  onPressed: () => unawaited(_pickKit(context)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickKit(BuildContext context) async {
    final l10n = context.l10n;
    final kits = await ref.read(kitsProvider.future);
    if (!context.mounted) return;
    final kitId = await showUpSheet<String>(
      context,
      builder: (ctx) => UpSheet(
        title: l10n.libraryUgcPickKitTitle,
        children: [
          if (kits.isEmpty)
            Padding(
              padding: const EdgeInsets.all(UpSpacing.xxl),
              child: UpText(
                l10n.libraryUgcPickKitEmpty,
                role: UpTextRole.body,
                color: UpTheme.of(ctx).colors.textSecondary,
                align: TextAlign.center,
              ),
            ),
          for (final k in kits)
            UgcChoiceRow(
              label: k.name,
              subtitle: l10n.libraryCatalogDetailPads(k.padCount),
              selected: false,
              onTap: () => Navigator.pop(ctx, k.id),
            ),
        ],
      ),
    );
    if (kitId == null || !context.mounted) return;
    ref.read(uploadProvider.notifier).reset();
    await context.push(Routes.uploadNew(kitId));
    if (mounted) unawaited(_load());
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = UpTheme.of(context).colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(UpSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: UpSpacing.lg,
          children: [
            UpText(
              text,
              role: UpTextRole.body,
              color: c.textSecondary,
              align: TextAlign.center,
              maxLines: 4,
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

class _UploadRow extends ConsumerWidget {
  const _UploadRow({required this.upload, required this.busy});
  final UploadItem upload;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final item = upload.item;
    final note = upload.takenDown
        ? l10n.libraryUgcTakenDownNote
        : upload.moderation == UploadModeration.hidden
        ? l10n.libraryUgcHiddenNote
        : null;
    final subtitle = [
      uploadStatusLabel(l10n, upload),
      LicenseInfo.of(item.license.id).badge,
      if (item.size > 0) l10n.libraryCatalogDetailSizeMb(sizeMb(item.size)),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: UpSheetTokens.itemGap),
      child: UpListItem(
        key: ValueKey('upload-${upload.id}'),
        icon: upload.isPublic
            ? Icons.public_rounded
            : upload.takenDown
            ? Icons.block_rounded
            : Icons.lock_rounded,
        title: item.title,
        subtitle: note == null ? subtitle : '$subtitle\n$note',
        trailing: busy
            ? const UpProgressRing()
            : const Icon(Icons.more_horiz_rounded),
        onTap: busy ? null : () => unawaited(_actions(context, ref)),
      ),
    );
  }

  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final action = await showUpSheet<_Action>(
      context,
      builder: (ctx) => UpSheet(
        title: upload.item.title,
        children: [
          if (upload.hasFile && !upload.takenDown)
            UpListItem(
              key: const ValueKey('upload-toggle-public'),
              icon: upload.visibility == UploadVisibility.public
                  ? Icons.lock_rounded
                  : Icons.public_rounded,
              title: upload.visibility == UploadVisibility.public
                  ? l10n.libraryUgcMakePrivate
                  : l10n.libraryUgcMakePublic,
              onTap: () => Navigator.pop(ctx, _Action.toggle),
            ),
          if (upload.hasFile && !upload.takenDown)
            UpListItem(
              key: const ValueKey('upload-restore'),
              icon: Icons.download_rounded,
              title: l10n.libraryUgcRestore,
              onTap: () => Navigator.pop(ctx, _Action.restore),
            ),
          UpListItem(
            key: const ValueKey('upload-delete'),
            icon: Icons.delete_outline_rounded,
            title: l10n.commonDelete,
            onTap: () => Navigator.pop(ctx, _Action.delete),
          ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _Action.toggle:
        await _toggle(context, ref);
      case _Action.restore:
        await _restore(context, ref);
      case _Action.delete:
        await _delete(context, ref);
    }
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final makePublic = upload.visibility != UploadVisibility.public;
    if (makePublic) {
      final ok = await showUpConfirm(
        context,
        title: l10n.libraryUgcPublicConfirmTitle,
        message: l10n.libraryUgcPublicConfirmBody,
        confirm: l10n.libraryUgcPublicConfirmOk,
        cancel: l10n.commonCancel,
      );
      if (!ok || !context.mounted) return;
    }
    try {
      await ref
          .read(myUploadsProvider.notifier)
          .setPublic(upload.id, makePublic);
      if (context.mounted) {
        showUpToast(
          context,
          makePublic
              ? l10n.libraryUgcMadePublicToast
              : l10n.libraryUgcMadePrivateToast,
        );
      }
    } on CatalogException catch (e) {
      if (context.mounted) showUpToast(context, ugcErrorMessage(l10n, e));
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      await ref.read(myUploadsProvider.notifier).restore(upload);
      if (context.mounted) {
        showUpToast(context, l10n.libraryUgcRestoredToast(upload.item.title));
      }
    } on CatalogException catch (e) {
      if (context.mounted) showUpToast(context, ugcErrorMessage(l10n, e));
    } on EngineException {
      if (context.mounted) showUpToast(context, l10n.libraryUgcErrGeneric);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await showUpConfirm(
      context,
      title: l10n.libraryUgcDeleteTitle,
      message: l10n.libraryUgcDeleteBody,
      confirm: l10n.commonDelete,
      cancel: l10n.commonCancel,
      danger: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(myUploadsProvider.notifier).delete(upload.id);
      if (context.mounted) showUpToast(context, l10n.libraryUgcDeletedToast);
    } on CatalogException catch (e) {
      if (context.mounted) showUpToast(context, ugcErrorMessage(l10n, e));
    }
  }
}

enum _Action { toggle, restore, delete }
