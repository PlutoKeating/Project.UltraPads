import 'package:file_picker/file_picker.dart';
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
import '../catalog/catalog_tab.dart';
import '../split/split_song_sheet.dart';
import 'genres.dart';

/// 曲库（参考设计 `MenuScene`）：顶部导航（✕ / 标题 / 🔍），KITS / FEED / PROFILE 三个 Tab。
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  int _tab = 0;

  /// 已经打开过的 Tab。官方曲库 Tab 第一次被选中才构建（构建即联网加载目录），
  /// 其余 Tab 保持原有的一次性构建。
  final _visited = <int>{0};
  bool _searching = false;
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final titles = [
      l10n.navKits,
      l10n.navFeed,
      l10n.navCatalog,
      l10n.navProfile,
    ];
    return Scaffold(
      backgroundColor: c.surfacePage,
      body: SafeArea(
        child: Column(
          children: [
            UpTopBar(
              centerTitle: true,
              leading: UpIconButton(
                icon: Icons.close_rounded,
                semanticLabel: l10n.commonClose,
                onPressed: () => context.pop(),
              ),
              title: _searching ? l10n.commonSearch : titles[_tab],
              trailing: [
                UpIconButton(
                  icon: _searching
                      ? Icons.search_off_rounded
                      : Icons.search_rounded,
                  semanticLabel: l10n.commonSearch,
                  onPressed: () => setState(() {
                    _searching = !_searching;
                    _query.clear();
                  }),
                ),
              ],
            ),
            if (_searching)
              Padding(
                padding: const EdgeInsets.all(UpPageTokens.paddingX),
                child: UpSearchField(
                  hint: l10n.librarySearchHint,
                  controller: _query,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            Expanded(
              child: _searching
                  ? KitList(query: _query.text)
                  : IndexedStack(
                      index: _tab,
                      children: [
                        const KitsTab(),
                        const FeedTab(),
                        _visited.contains(2)
                            ? const CatalogTab()
                            : const SizedBox.shrink(),
                        const ProfileTab(),
                      ],
                    ),
            ),
            if (!_searching)
              UpTabBar(
                index: _tab,
                onChanged: (i) => setState(() {
                  _tab = i;
                  _visited.add(i);
                }),
                items: [
                  UpTabItem(
                    icon: Icons.library_music_rounded,
                    label: l10n.navKits,
                  ),
                  UpTabItem(icon: Icons.whatshot_rounded, label: l10n.navFeed),
                  UpTabItem(
                    icon: Icons.cloud_download_rounded,
                    label: l10n.navCatalog,
                  ),
                  UpTabItem(icon: Icons.person_rounded, label: l10n.navProfile),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// KITS：曲风筛选 + 新曲推送卡 + 纵向 Kit 列表。
class KitsTab extends ConsumerStatefulWidget {
  const KitsTab({super.key});

  @override
  ConsumerState<KitsTab> createState() => _KitsTabState();
}

class _KitsTabState extends ConsumerState<KitsTab> {
  String? _genre;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kits = ref.watch(kitsProvider).value ?? const <KitSummary>[];
    final fresh = kits.where((k) => k.isNew).toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: UpSpacing.lg),
            child: GenreRow(
              children: [
                for (final g in genreSpecs)
                  GenreIcon(
                    label: g.label(l10n),
                    role: g.role.index,
                    icon: g.icon,
                    selected: _genre == g.key,
                    onTap: () =>
                        setState(() => _genre = _genre == g.key ? null : g.key),
                  ),
              ],
            ),
          ),
        ),
        if (fresh.isNotEmpty && _genre == null)
          SliverToBoxAdapter(child: _NewKitCard(kit: fresh.first)),
        KitList.sliver(genre: _genre),
      ],
    );
  }
}

/// 新曲推送卡（「New kit: …」）。
class _NewKitCard extends StatelessWidget {
  const _NewKitCard({required this.kit});
  final KitSummary kit;

  @override
  Widget build(BuildContext context) {
    final c = UpTheme.of(context).colors;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UpPageTokens.paddingX,
        0,
        UpPageTokens.paddingX,
        UpSpacing.lg,
      ),
      child: PressScale(
        onTap: () => context.push(Routes.kit(kit.id)),
        child: Container(
          padding: const EdgeInsets.all(UpSpacing.lg),
          decoration: BoxDecoration(
            gradient: c.brandBackground.linear(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(UpRadii.xl),
          ),
          child: Row(
            spacing: UpSpacing.lg,
            children: [
              Icon(
                Icons.notifications_active_rounded,
                color: c.iconOnAccent,
                size: UpSizes.iconLg,
              ),
              Expanded(
                child: UpText(
                  l10n.libraryNewKitAvailable(kit.name),
                  role: UpTextRole.titleSm,
                  color: c.textOnAccent,
                  maxLines: 2,
                ),
              ),
              UpBadge(label: l10n.commonNew, kind: UpBadgeKind.isNew),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kit 列表行（缩略图 + INSPIRED BY + 歌名 + 状态）。可作为 sliver 或普通列表使用。
class KitList extends ConsumerWidget {
  const KitList({super.key, this.query = '', this.genre, this.filter})
    : _sliver = false;
  const KitList.sliver({super.key, this.query = '', this.genre, this.filter})
    : _sliver = true;

  final String query;
  final String? genre;
  final bool Function(KitSummary)? filter;
  final bool _sliver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final kits = ref.watch(kitsProvider).value ?? const <KitSummary>[];
    final current = ref.watch(engineViewProvider.select((v) => v.kit?.id));
    final loading = ref.watch(kitLoadProvider);
    final q = query.trim().toLowerCase();
    final list = kits.where((k) {
      if (genre != null && k.genre != genre) return false;
      if (filter != null && !filter!(k)) return false;
      if (q.isEmpty) return true;
      return '${k.name} ${k.artist} ${k.song}'.toLowerCase().contains(q);
    }).toList();

    Widget item(KitSummary k) => Padding(
      padding: const EdgeInsets.fromLTRB(
        UpPageTokens.paddingX,
        UpKitCardTokens.marginTop,
        UpPageTokens.paddingX,
        0,
      ),
      child: KitCard(
        title: k.name,
        overline: l10n.performInspiredBy,
        subtitle: k.song.isNotEmpty ? k.song : genreSpec(k.genre)?.label(l10n),
        role: k.color.index,
        selected: k.id == current,
        status: loading.containsKey(k.id)
            ? KitStatus.downloading
            : k.downloaded
            ? KitStatus.ready
            : KitStatus.notDownloaded,
        progress: loading[k.id],
        badge: k.isNew
            ? UpBadge(label: l10n.commonNew, kind: UpBadgeKind.isNew)
            : null,
        onTap: () => context.push(Routes.kit(k.id)),
      ),
    );

    if (list.isEmpty) {
      final empty = Padding(
        padding: const EdgeInsets.all(UpSpacing.xxxl),
        child: UpText(
          q.isEmpty ? l10n.libraryEmpty : l10n.libraryNoResults(query),
          role: UpTextRole.body,
          color: c.textSecondary,
          align: TextAlign.center,
          maxLines: 3,
        ),
      );
      return _sliver ? SliverToBoxAdapter(child: empty) : empty;
    }
    if (_sliver) {
      return SliverList.builder(
        itemCount: list.length,
        itemBuilder: (_, i) => item(list[i]),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) => item(list[i]),
    );
  }
}

/// FEED：Featured 轮播 + 最新大卡 + 艺人 + 推荐。
class FeedTab extends ConsumerWidget {
  const FeedTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final kits = ref.watch(kitsProvider).value ?? const <KitSummary>[];
    final featured = kits.where((k) => k.isFeatured).toList();
    final latest = kits.where((k) => k.isNew).toList();
    final artists = {
      for (final k in kits)
        if (k.artist.isNotEmpty) k.artist: k,
    }.values.toList();

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(
        UpPageTokens.paddingX,
        UpSpacing.xxl,
        UpPageTokens.paddingX,
        UpSpacing.md,
      ),
      child: UpText(title, role: UpTextRole.titleSm, color: c.textSecondary),
    );

    return ListView(
      children: [
        if (featured.isNotEmpty) ...[
          section(l10n.libraryFeatured),
          BannerCarousel(
            itemCount: featured.length,
            onTap: (i) => context.push(Routes.kit(featured[i].id)),
            itemBuilder: (context, i, focused) => KitCover(
              title: featured[i].name,
              overline: l10n.libraryKitBadge,
              role: featured[i].color.index,
              size: UpBannerTokens.width,
            ),
          ),
        ],
        if (latest.isNotEmpty) ...[
          section(l10n.libraryNewSongs),
          for (final k in latest)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: UpPageTokens.paddingX,
                vertical: UpSpacing.xs,
              ),
              child: KitCard(
                large: true,
                title: k.name,
                overline: l10n.libraryKitBadge,
                subtitle: k.song,
                role: k.color.index,
                onTap: () => context.push(Routes.kit(k.id)),
              ),
            ),
        ],
        if (artists.isNotEmpty) ...[
          section(l10n.libraryArtists),
          SizedBox(
            height: UpKitCardTokens.coverSizeLarge + UpSpacing.huge,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: UpPageTokens.paddingX,
              ),
              children: [
                for (final k in artists)
                  Padding(
                    padding: const EdgeInsets.only(right: UpSpacing.lg),
                    child: PressScale(
                      onTap: () => context.push(Routes.kit(k.id)),
                      child: Column(
                        spacing: UpSpacing.xs,
                        children: [
                          KitCover(
                            title: k.artist,
                            role: k.color.index,
                            size: UpKitCardTokens.coverSizeLarge,
                          ),
                          UpText(
                            k.artist,
                            role: UpTextRole.labelSm,
                            color: c.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        section(l10n.libraryRecommended),
        SizedBox(
          height: (UpKitCardTokens.height + UpKitCardTokens.marginTop) * 4,
          child: KitList(filter: (k) => !k.isNew),
        ),
        const SizedBox(height: UpSpacing.xxl),
      ],
    );
  }
}

/// PROFILE：我的录音 / 创建 Kit / 导入 / 我的设备 + 子 Tab（已下载 / 收藏 / 我的 Kit）。
class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  int _sub = 0;

  Future<void> _import() async {
    final l10n = context.l10n;
    final files = await FilePicker.pickFiles();
    final path = files.firstOrNull?.path;
    if (path == null || !mounted) return;
    final report = await tryEngine(
      () => ref.read(engineProvider).libraryImport(path),
    );
    if (!mounted) return;
    showUpToast(
      context,
      report == null
          ? l10n.errorEngineUnsupported
          : l10n.libraryKitCount(report.kits.length),
    );
  }

  Future<void> _splitSong() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    final path = files.firstOrNull?.path;
    if (path == null || !mounted) return;
    await showSplitSongSheet(context, path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final favorites = ref.watch(favoritesProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(UpPageTokens.paddingX),
          child: Column(
            spacing: UpSheetTokens.itemGap,
            children: [
              UpListItem(
                icon: Icons.mic_external_on_rounded,
                title: l10n.worksTitle,
                onTap: () => context.push(Routes.tracks),
              ),
              UpListItem(
                icon: Icons.add_box_rounded,
                title: l10n.kitEditorNewKit,
                onTap: () => context.push(Routes.editor),
              ),
              UpListItem(
                icon: Icons.file_download_rounded,
                title: l10n.libraryImportKit,
                subtitle: l10n.libraryImportFromFile,
                onTap: _import,
              ),
              UpListItem(
                icon: Icons.content_cut_rounded,
                title: l10n.librarySplitEntryTitle,
                subtitle: l10n.librarySplitEntrySubtitle,
                onTap: _splitSong,
              ),
              UpListItem(
                icon: Icons.devices_rounded,
                title: l10n.hubTitle,
                subtitle: l10n.libraryImportFromDevices,
                onTap: () => context.push(Routes.hub),
              ),
            ],
          ),
        ),
        UpSegmentTabs(
          labels: [
            l10n.libraryDownloaded,
            l10n.libraryFavorites,
            l10n.libraryMyKits,
          ],
          index: _sub,
          onChanged: (i) => setState(() => _sub = i),
        ),
        Expanded(
          child: KitList(
            key: ValueKey(_sub),
            filter: switch (_sub) {
              0 => (k) => k.downloaded,
              1 => (k) => favorites.contains(k.id),
              _ =>
                (k) =>
                    k.source == KitSource.user ||
                    k.source == KitSource.imported,
            },
          ),
        ),
      ],
    );
  }
}
