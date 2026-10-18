import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../routing/routes.dart';
import '../../state/library_state.dart';
import 'catalog_format.dart';
import 'catalog_models.dart';
import 'catalog_state.dart';

/// 目录条目详情：封面、署名与许可证、来源链接，以及下载 / 更新 / 演奏。
class CatalogDetailPage extends ConsumerWidget {
  const CatalogDetailPage({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final item = ref.watch(catalogItemProvider(itemId));
    return Scaffold(
      backgroundColor: c.surfacePads,
      body: SafeArea(
        child: Column(
          children: [
            UpTopBar(
              background: c.surfacePads,
              leading: UpIconButton(
                icon: Icons.arrow_back_rounded,
                semanticLabel: l10n.commonBack,
                onPressed: () => context.pop(),
              ),
              trailing: [
                if (item.value case final it?) _FavoriteButton(item: it),
              ],
            ),
            Expanded(
              child: item.when(
                data: (it) => _Body(item: it),
                loading: () => const Center(child: UpProgressRing()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(UpSpacing.xxxl),
                    child: UpText(
                      e is CatalogException && e.notFound
                          ? l10n.libraryCatalogNotFound
                          : e is CatalogException && e.isNetwork
                          ? l10n.libraryCatalogLoadFailedOffline
                          : l10n.libraryCatalogLoadFailed,
                      role: UpTextRole.body,
                      color: c.textSecondary,
                      align: TextAlign.center,
                      maxLines: 4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.item});
  final CatalogItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final favorite = ref.watch(
      cloudStateProvider.select((s) => s.favorites.contains(item.id)),
    );
    return UpIconButton(
      icon: favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      color: favorite ? c.accentPrimary : null,
      semanticLabel: favorite
          ? l10n.libraryCatalogRemoveFavorite
          : l10n.libraryCatalogAddFavorite,
      onPressed: () => unawaited(
        ref.read(cloudStateProvider.notifier).toggleFavorite(item.id),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.item});
  final CatalogItem item;

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      await ref.read(catalogDownloadProvider.notifier).download(item);
      if (context.mounted) {
        showUpToast(context, l10n.libraryCatalogImportedToast(item.title));
      }
    } on CatalogCancelled {
      // 用户取消：不提示
    } on CatalogException catch (e) {
      if (!context.mounted) return;
      showUpToast(context, switch (e.code) {
        'hash_mismatch' => l10n.libraryCatalogDownloadCorrupt,
        'not_found' => l10n.libraryCatalogDownloadNotFound,
        _ => l10n.libraryCatalogDownloadFailed,
      });
    } on EngineException {
      if (context.mounted) {
        showUpToast(context, l10n.libraryCatalogDownloadFailed);
      }
    }
  }

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final rec = ref.read(catalogRecordsProvider)[item.id];
    final kitId = rec?.kitIds.firstOrNull;
    if (kitId == null) return;
    final ok = await ref.read(kitLoadProvider.notifier).load(kitId);
    if (!context.mounted) return;
    if (!ok) {
      showUpToast(context, l10n.errorEngineUnsupported);
      return;
    }
    unawaited(ref.read(cloudStateProvider.notifier).recordRecent(item.id));
    context.go(Routes.perform);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final records = ref.watch(catalogRecordsProvider);
    final downloading = ref.watch(
      catalogDownloadProvider.select((m) => m.containsKey(item.id)),
    );
    final progress = ref.watch(
      catalogDownloadProvider.select((m) => m[item.id]),
    );
    final loadingKit = ref
        .watch(kitLoadProvider)
        .keys
        .any((k) => records[item.id]?.kitIds.contains(k) ?? false);
    final status = downloadStatusOf(item, records);
    final hints = licenseHints(l10n, item.license);

    Widget section(String title, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: UpSpacing.xs,
      children: [
        UpText(title, role: UpTextRole.titleSm, color: c.textSecondary),
        child,
      ],
    );

    final Widget action;
    if (downloading) {
      action = Row(
        spacing: UpSpacing.lg,
        children: [
          Expanded(
            child: UpButton(
              label: progress == null
                  ? l10n.commonLoading
                  : l10n.libraryCatalogDownloadingPercent(
                      (progress * 100).round(),
                    ),
              size: UpButtonSize.lg,
              expand: true,
            ),
          ),
          UpButton(
            label: l10n.commonCancel,
            variant: UpButtonVariant.outline,
            size: UpButtonSize.lg,
            onPressed: () =>
                ref.read(catalogDownloadProvider.notifier).cancel(item.id),
          ),
        ],
      );
    } else if (loadingKit) {
      action = const Center(child: UpProgressRing());
    } else {
      action = Column(
        spacing: UpSpacing.sm,
        children: [
          UpButton(
            label: status == DownloadStatus.none
                ? l10n.libraryCatalogDownload
                : l10n.libraryCatalogPlay,
            icon: status == DownloadStatus.none
                ? Icons.download_rounded
                : Icons.play_arrow_rounded,
            size: UpButtonSize.lg,
            expand: true,
            onPressed: () => status == DownloadStatus.none
                ? unawaited(_download(context, ref))
                : unawaited(_play(context, ref)),
          ),
          if (status == DownloadStatus.updateAvailable)
            UpButton(
              label: l10n.libraryCatalogUpdateAvailable,
              icon: Icons.system_update_alt_rounded,
              variant: UpButtonVariant.outline,
              expand: true,
              onPressed: () => unawaited(_download(context, ref)),
            ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(UpPageTokens.paddingX),
            children: [
              Center(
                child: KitCover(
                  title: item.title,
                  overline: originLabel(l10n, item.origin),
                  role: roleOf(item),
                  size: UpBannerTokens.height * 2,
                ),
              ),
              const SizedBox(height: UpSpacing.xxl),
              if (item.artist.isNotEmpty)
                UpText(
                  l10n.libraryCatalogByArtist(item.artist),
                  role: UpTextRole.inspired,
                  color: c.textSecondary,
                  align: TextAlign.center,
                ),
              UpText(
                item.title,
                role: UpTextRole.headline,
                color: c.textPrimary,
                align: TextAlign.center,
                maxLines: 3,
              ),
              const SizedBox(height: UpSpacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: UpSpacing.sm,
                runSpacing: UpSpacing.xs,
                children: [
                  LicenseBadge(license: item.license),
                  if (item.bpm > 0)
                    UpBadge(label: l10n.performTempo(item.bpm.round())),
                  for (final g in item.genres)
                    UpBadge(label: genreLabel(l10n, g)),
                  if (item.groupCount > 0)
                    UpBadge(
                      label: l10n.libraryCatalogDetailGroups(item.groupCount),
                    ),
                  if (item.padCount > 0)
                    UpBadge(
                      label: l10n.libraryCatalogDetailPads(item.padCount),
                    ),
                  if (item.durationSecs > 0)
                    UpBadge(
                      label: l10n.libraryCatalogDetailLoop(
                        item.durationSecs.toStringAsFixed(1),
                      ),
                    ),
                  if (item.size > 0)
                    UpBadge(
                      label: l10n.libraryCatalogDetailSizeMb(sizeMb(item.size)),
                    ),
                ],
              ),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: UpSpacing.xl),
                UpText(
                  item.description,
                  role: UpTextRole.body,
                  color: c.textSecondary,
                  maxLines: 8,
                ),
              ],
              const SizedBox(height: UpSpacing.xxl),
              section(
                l10n.libraryCatalogDetailLicense,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: UpSpacing.xs,
                  children: [
                    for (final h in hints)
                      UpText(
                        h,
                        role: UpTextRole.bodySm,
                        color: c.textPrimary,
                        maxLines: 3,
                      ),
                  ],
                ),
              ),
              if (item.attribution.isNotEmpty) ...[
                const SizedBox(height: UpSpacing.xl),
                section(
                  l10n.libraryCatalogDetailCredits,
                  UpText(
                    item.attribution,
                    role: UpTextRole.bodySm,
                    color: c.textPrimary,
                    maxLines: 6,
                  ),
                ),
              ],
              const SizedBox(height: UpSpacing.xl),
              Wrap(
                spacing: UpSpacing.sm,
                runSpacing: UpSpacing.sm,
                children: [
                  if (item.licenseUrl.isNotEmpty)
                    UpButton(
                      label: l10n.libraryCatalogDetailOpenLicense,
                      icon: Icons.open_in_new_rounded,
                      variant: UpButtonVariant.outline,
                      size: UpButtonSize.sm,
                      onPressed: () => unawaited(_open(item.licenseUrl)),
                    ),
                  if (item.sourceUrl.isNotEmpty)
                    UpButton(
                      label: l10n.libraryCatalogDetailOpenSource,
                      icon: Icons.open_in_new_rounded,
                      variant: UpButtonVariant.outline,
                      size: UpButtonSize.sm,
                      onPressed: () => unawaited(_open(item.sourceUrl)),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(UpPageTokens.paddingX),
          child: action,
        ),
      ],
    );
  }
}
