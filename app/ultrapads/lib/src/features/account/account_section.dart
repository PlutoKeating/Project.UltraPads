import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../account/account_state.dart';
import '../../account/auth_flow.dart';
import '../../config/app_links.dart';
import '../../routing/routes.dart';
import '../catalog/catalog_state.dart';

/// 设置 → 账号：PlutoKeating 账号的登录 / 退出，以及云端收藏同步状态（docs/API.md §7.1）。
class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final account = ref.watch(accountProvider);
    final cloud = ref.watch(cloudStateProvider);
    final ctrl = ref.read(accountProvider.notifier);

    ref.listen<AccountState>(accountProvider, (prev, next) {
      final wasSigningIn = prev?.status == AccountStatus.signingIn;
      if (wasSigningIn && next.signedIn) {
        showUpToast(context, l10n.settingsAccountSignedInToast);
      } else if (next.status == AccountStatus.signedOut &&
          next.error != AccountError.none &&
          prev?.error != next.error) {
        showUpToast(
          context,
          next.error == AccountError.notConfigured
              ? l10n.settingsAccountNotConfigured
              : l10n.settingsAccountSignInFailed,
        );
      }
    });

    void signIn() => unawaited(
      ctrl.signIn(
        page: LoopbackPage(
          title: l10n.settingsAccountLoopbackTitle,
          body: l10n.settingsAccountLoopbackBody,
        ),
      ),
    );

    Future<void> manage() async {
      final uri = ref.read(appLinksProvider).value?.idSettingsPage;
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    UpButton button(
      String label,
      VoidCallback onPressed, {
      bool primary = true,
    }) => UpButton(
      label: label,
      onPressed: onPressed,
      size: UpButtonSize.sm,
      variant: primary ? UpButtonVariant.primary : UpButtonVariant.secondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: switch (account.status) {
        AccountStatus.loading => const [],
        AccountStatus.signedOut => [
          UpListItem(
            key: const ValueKey('account-sign-in'),
            icon: Icons.account_circle_rounded,
            title: l10n.settingsAccountSignIn,
            subtitle: l10n.settingsAccountSignInHint,
            trailing: button(l10n.settingsAccountSignIn, signIn),
            onTap: signIn,
          ),
        ],
        AccountStatus.signingIn => [
          UpListItem(
            key: const ValueKey('account-signing-in'),
            icon: Icons.hourglass_top_rounded,
            title: l10n.settingsAccountSigningIn,
            trailing: button(
              l10n.settingsAccountSignInCancel,
              ctrl.cancelSignIn,
              primary: false,
            ),
          ),
        ],
        AccountStatus.signedIn => [
          UpListItem(
            key: const ValueKey('account-signed-in'),
            icon: Icons.account_circle_rounded,
            title: l10n.settingsAccountSignedInAs(
              account.profile?.label ?? l10n.commonUnknown,
            ),
            subtitle: cloud.syncing
                ? l10n.settingsAccountSyncing
                : cloud.pending > 0
                ? l10n.settingsAccountPendingSync(cloud.pending)
                : null,
            trailing: button(l10n.settingsAccountSignOut, () async {
              await ctrl.signOut();
              if (context.mounted) {
                showUpToast(context, l10n.settingsAccountSignedOutToast);
              }
            }, primary: false),
          ),
          const SizedBox(height: UpSheetTokens.itemGap),
          UpListItem(
            key: const ValueKey('account-my-uploads'),
            icon: Icons.cloud_upload_rounded,
            title: l10n.libraryUgcMyUploads,
            onTap: () => unawaited(context.push(Routes.uploads)),
          ),
          if (ref.watch(appLinksProvider).value?.idSettingsPage != null) ...[
            const SizedBox(height: UpSheetTokens.itemGap),
            UpListItem(
              icon: Icons.manage_accounts_rounded,
              title: l10n.settingsAccountManage,
              onTap: manage,
            ),
          ],
        ],
      },
    );
  }
}
