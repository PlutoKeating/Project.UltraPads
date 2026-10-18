import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_links.dart';
import '../../state/settings_state.dart';
import '../../update/update_controller.dart';

/// 设置 → 关于 → 软件更新：自动检查开关、状态与当前可做的一个动作（docs/ARCHITECTURE.md §10）。
class UpdateSection extends ConsumerWidget {
  const UpdateSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final s = ref.watch(updateProvider);
    final ctrl = ref.read(updateProvider.notifier);
    final info = s.info;
    final manual = info?.installMode == UpdateInstallMode.manual;
    final percent = ((s.progress ?? 0) * 100).round();

    final String? status = switch (s.phase) {
      UpdatePhase.idle => null,
      UpdatePhase.checking => l10n.settingsUpdateChecking,
      UpdatePhase.upToDate => l10n.settingsUpdateUpToDate,
      UpdatePhase.available when manual => l10n.settingsUpdateManualHint,
      UpdatePhase.available ||
      UpdatePhase.ready => l10n.settingsUpdateAvailable(info!.latest),
      UpdatePhase.downloading =>
        s.mirror
            ? l10n.settingsUpdateDownloading(percent)
            : l10n.settingsUpdateDownloadingGithub(percent),
      UpdatePhase.failed =>
        info == null
            ? l10n.settingsUpdateCheckFailed
            : l10n.settingsUpdateFailed,
    };

    Future<void> openDownloadPage() async {
      final uri = ref.read(appLinksProvider).value?.downloadPage;
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    Future<void> finish() async {
      final done = await ctrl.finish();
      if (!done &&
          context.mounted &&
          ref.read(updateProvider).phase == UpdatePhase.ready) {
        showUpToast(context, l10n.settingsUpdateInstallPermission);
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

    final Widget? action = switch (s.phase) {
      UpdatePhase.available when manual => button(
        l10n.settingsUpdateDownloadPage,
        openDownloadPage,
      ),
      UpdatePhase.available => button(l10n.settingsUpdateNow, ctrl.start),
      UpdatePhase.downloading => button(
        l10n.commonCancel,
        ctrl.cancel,
        primary: false,
      ),
      UpdatePhase.ready =>
        info!.installMode == UpdateInstallMode.selfUpdate
            ? button(l10n.settingsUpdateRestart, finish)
            : button(l10n.settingsUpdateInstall, finish),
      UpdatePhase.failed when info?.available ?? false => button(
        l10n.commonRetry,
        ctrl.start,
        primary: false,
      ),
      _ => null,
    };
    final checkable = switch (s.phase) {
      UpdatePhase.idle || UpdatePhase.upToDate || UpdatePhase.failed => true,
      _ => false,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UpListItem(
          key: const ValueKey('settings-update'),
          icon: Icons.system_update_rounded,
          title: checkable && action == null
              ? l10n.settingsUpdateCheckNow
              : l10n.settingsUpdateTitle,
          subtitle: status,
          trailing: action,
          onTap: checkable ? ctrl.check : null,
        ),
        if (info != null && info.available && info.notesUrl.isNotEmpty) ...[
          const SizedBox(height: UpSheetTokens.itemGap),
          UpListItem(
            icon: Icons.notes_rounded,
            title: l10n.settingsUpdateReleaseNotes,
            onTap: () => launchUrl(
              Uri.parse(info.notesUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
        const SizedBox(height: UpSheetTokens.itemGap),
        UpSwitchRow(
          title: l10n.settingsUpdateAutoCheck,
          subtitle: l10n.settingsUpdateAutoCheckHint,
          value: settings.autoUpdateCheck,
          onChanged: ref.read(settingsProvider.notifier).setAutoUpdateCheck,
        ),
      ],
    );
  }
}
