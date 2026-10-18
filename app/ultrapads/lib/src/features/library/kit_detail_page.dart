import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../routing/routes.dart';
import '../../state/engine_state.dart';
import '../../state/library_state.dart';
import '../perform/pad_mapping.dart';
import 'genres.dart';

/// Kit 预览（4.7.0 `modalUnlockKit` 去掉解锁/付费按钮）：大封面、INSPIRED BY、
/// 歌名、曲风 / BPM、pad 配色预览、LET'S PLAY。
class KitDetailPage extends ConsumerWidget {
  const KitDetailPage({super.key, required this.kitId});
  final String kitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final kit = ref.watch(kitSummaryProvider(kitId));
    final loading = ref.watch(kitLoadProvider).containsKey(kitId);
    final favorite = ref.watch(favoritesProvider).contains(kitId);
    final doc = ref.watch(_kitDocProvider(kitId)).value;

    Future<void> play() async {
      final ok = await ref.read(kitLoadProvider.notifier).load(kitId);
      if (!context.mounted) return;
      if (!ok) {
        showUpToast(context, l10n.errorEngineUnsupported);
        return;
      }
      context.go(Routes.perform);
    }

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
                UpIconButton(
                  icon: favorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: favorite ? c.accentPrimary : null,
                  semanticLabel: favorite
                      ? l10n.libraryRemoveFavorite
                      : l10n.libraryAddFavorite,
                  onPressed: () =>
                      ref.read(favoritesProvider.notifier).toggle(kitId),
                ),
              ],
            ),
            if (kit == null)
              const Expanded(child: Center(child: UpProgressRing()))
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(UpPageTokens.paddingX),
                  children: [
                    Center(
                      child: Semantics(
                        label: l10n.a11yKitCover(kit.name),
                        child: KitCover(
                          title: kit.name,
                          overline: l10n.libraryKitBadge,
                          role: kit.color.index,
                          size: UpBannerTokens.height * 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: UpSpacing.xxl),
                    if (kit.artist.isNotEmpty)
                      UpText(
                        l10n.libraryInspiredBy(kit.artist),
                        role: UpTextRole.inspired,
                        color: c.textSecondary,
                        align: TextAlign.center,
                      ),
                    UpText(
                      kit.name,
                      role: UpTextRole.headline,
                      color: c.textPrimary,
                      align: TextAlign.center,
                    ),
                    if (kit.song.isNotEmpty)
                      UpText(
                        kit.song,
                        role: UpTextRole.body,
                        color: c.textSecondary,
                        align: TextAlign.center,
                      ),
                    const SizedBox(height: UpSpacing.md),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: UpSpacing.sm,
                      children: [
                        if (genreSpec(kit.genre) != null)
                          UpBadge(label: genreSpec(kit.genre)!.label(l10n)),
                        UpBadge(label: l10n.performTempo(kit.bpm.round())),
                        if (kit.hasTutorial)
                          UpBadge(
                            label: l10n.tutorialTitle,
                            kind: UpBadgeKind.top,
                          ),
                        if (kit.isNew)
                          UpBadge(
                            label: l10n.commonNew,
                            kind: UpBadgeKind.isNew,
                          ),
                      ],
                    ),
                    const SizedBox(height: UpSpacing.xxl),
                    if (doc != null)
                      Center(
                        child: SizedBox(
                          width: UpBannerTokens.width,
                          height:
                              UpBannerTokens.width * PadId.rows / PadId.columns,
                          child: IgnorePointer(
                            child: PadGrid(
                              pads: padDataFrom(
                                doc.pads,
                                List.filled(PadId.total, PadPlayState.idle),
                              ),
                              bank: 0,
                              onPadDown: (_, _) {},
                              onPadUp: (_, _) {},
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (kit != null)
              Padding(
                padding: const EdgeInsets.all(UpPageTokens.paddingX),
                child: loading
                    ? const UpProgressRing()
                    : UpButton(
                        label: kit.downloaded
                            ? l10n.libraryLetsPlay
                            : l10n.libraryDownloadKit,
                        icon: kit.downloaded
                            ? Icons.play_arrow_rounded
                            : Icons.download_rounded,
                        size: UpButtonSize.lg,
                        expand: true,
                        onPressed: play,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

final _kitDocProvider = FutureProvider.family<KitDoc?, String>(
  (ref, id) => tryEngine(() => ref.watch(engineProvider).libraryGetKit(id)),
);
