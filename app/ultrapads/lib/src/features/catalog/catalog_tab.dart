import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_i18n/up_i18n.dart';
import 'package:up_tokens/up_tokens.dart';
import 'package:up_ui/up_ui.dart';

import '../../routing/routes.dart';
import 'catalog_format.dart';
import 'catalog_models.dart';
import 'catalog_state.dart';

/// 速度筛选预设（BPM 下界, 上界）；null 表示不限。
const _tempoPresets = <(int?, int?)>[
  (null, 89),
  (90, 109),
  (110, 129),
  (130, 149),
  (150, null),
];

/// 搜索框输入停下多久后才请求（不是视觉时长）。
const _searchDebounceMs = 350;

/// 滚到离底部多少像素时预取下一页。
const _prefetchExtent = 400.0;

/// 官方曲库：搜索、按许可证 / 曲风 / 速度筛选、排序、分页加载、收藏与下载（docs/API.md §7）。
class CatalogTab extends ConsumerStatefulWidget {
  const CatalogTab({super.key});

  @override
  ConsumerState<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends ConsumerState<CatalogTab> {
  final _scroll = ScrollController();
  final _text = TextEditingController();
  Timer? _debounce;
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    unawaited(Future.microtask(_firstLoad));
  }

  Future<void> _firstLoad() async {
    if (!mounted) return;
    unawaited(
      ref.read(catalogFacetsProvider.future).then((_) {}, onError: (_) {}),
    );
    if (!ref.read(catalogListProvider).loaded) {
      await ref.read(catalogListProvider.notifier).refresh();
    }
    // 登录用户：顺手同步收藏与最近使用
    unawaited(ref.read(cloudStateProvider.notifier).sync());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _text.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < _prefetchExtent) {
      unawaited(ref.read(catalogListProvider.notifier).loadMore());
    }
  }

  CatalogQuery get _query => ref.read(catalogListProvider).query;

  /// 筛选面板用的 facets；取不到（离线）时面板里只剩已选项。
  Future<CatalogFacets?> _facets() async {
    try {
      return await ref.read(catalogFacetsProvider.future);
    } catch (_) {
      return null;
    }
  }

  /// 第一页没填满视口时没有滚动，不会触发预取：这里补一次。
  void _fillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final s = ref.read(catalogListProvider);
      if (s.hasMore &&
          !s.loading &&
          _scroll.position.extentAfter < _prefetchExtent) {
        unawaited(ref.read(catalogListProvider.notifier).loadMore());
      }
    });
  }

  void _setQuery(CatalogQuery q) =>
      unawaited(ref.read(catalogListProvider.notifier).setQuery(q));

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: _searchDebounceMs),
      () => _setQuery(_query.copyWith(text: v)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final list = ref.watch(catalogListProvider);
    final cloud = ref.watch(cloudStateProvider);
    final q = list.query;
    ref.listen(catalogListProvider, (_, _) => _fillViewport());

    final chips = <Widget>[
      if (q.isFiltered)
        UpChip(
          label: l10n.libraryCatalogClearFilters,
          icon: Icons.close_rounded,
          onTap: () => _setQuery(
            q.copyWith(
              licenses: const {},
              genre: () => null,
              bpmMin: () => null,
              bpmMax: () => null,
            ),
          ),
        ),
      UpChip(
        label: l10n.libraryCatalogFavoritesOnly,
        icon: Icons.favorite_rounded,
        variant: _favoritesOnly ? UpChipVariant.selected : UpChipVariant.normal,
        onTap: () => setState(() => _favoritesOnly = !_favoritesOnly),
      ),
      UpChip(
        label: switch (q.sort) {
          CatalogSort.newest => l10n.libraryCatalogSortNewest,
          CatalogSort.bpm => l10n.libraryCatalogSortBpm,
          CatalogSort.title => l10n.libraryCatalogSortTitle,
        },
        icon: Icons.sort_rounded,
        onTap: () => _pickSort(context),
      ),
      UpChip(
        label: q.licenses.isEmpty
            ? l10n.libraryCatalogFilterLicense
            : q.licenses.map((l) => LicenseInfo.of(l).badge).join(' · '),
        icon: Icons.verified_rounded,
        variant: q.licenses.isEmpty
            ? UpChipVariant.normal
            : UpChipVariant.selected,
        onTap: () => _pickLicense(context),
      ),
      UpChip(
        label: q.genre == null
            ? l10n.libraryCatalogFilterGenre
            : genreLabel(l10n, q.genre!),
        icon: Icons.graphic_eq_rounded,
        variant: q.genre == null
            ? UpChipVariant.normal
            : UpChipVariant.selected,
        onTap: () => _pickGenre(context),
      ),
      UpChip(
        label: q.bpmMin == null && q.bpmMax == null
            ? l10n.libraryCatalogFilterBpm
            : l10n.libraryCatalogBpmRange(q.bpmMin ?? 0, q.bpmMax ?? 999),
        icon: Icons.speed_rounded,
        variant: q.bpmMin == null && q.bpmMax == null
            ? UpChipVariant.normal
            : UpChipVariant.selected,
        onTap: () => _pickTempo(context),
      ),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            UpPageTokens.paddingX,
            UpSpacing.md,
            UpPageTokens.paddingX,
            UpSpacing.sm,
          ),
          child: UpSearchField(
            hint: l10n.libraryCatalogSearchHint,
            controller: _text,
            onChanged: _onSearch,
          ),
        ),
        SizedBox(
          height: UpKitCardTokens.marginTop + UpSpacing.huge,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: UpPageTokens.paddingX,
            ),
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: UpSpacing.sm),
            itemBuilder: (_, i) => Center(child: chips[i]),
          ),
        ),
        if (cloud.pending > 0 || cloud.syncing)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UpPageTokens.paddingX,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: UpText(
                cloud.syncing
                    ? l10n.settingsAccountSyncing
                    : l10n.settingsAccountPendingSync(cloud.pending),
                role: UpTextRole.caption,
                color: c.textMuted,
              ),
            ),
          ),
        Expanded(
          child: _favoritesOnly
              ? _FavoritesList(favorites: cloud.favorites.toList())
              : _ResultList(scroll: _scroll),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- 选择面板

  Future<void> _pickSort(BuildContext context) async {
    final l10n = context.l10n;
    final v = await showUpSheet<CatalogSort>(
      context,
      builder: (ctx) => UpSheet(
        title: l10n.libraryCatalogFilters,
        children: [
          for (final (s, label) in [
            (CatalogSort.newest, l10n.libraryCatalogSortNewest),
            (CatalogSort.bpm, l10n.libraryCatalogSortBpm),
            (CatalogSort.title, l10n.libraryCatalogSortTitle),
          ])
            _SheetRow(
              label: label,
              selected: _query.sort == s,
              onTap: () => Navigator.pop(ctx, s),
            ),
        ],
      ),
    );
    if (v != null) _setQuery(_query.copyWith(sort: v));
  }

  Future<void> _pickLicense(BuildContext context) async {
    final l10n = context.l10n;
    final facets = await _facets();
    if (!context.mounted) return;
    final ids = {
      for (final f in facets?.licenses ?? const <Facet>[]) f.id,
      ..._query.licenses,
    }.toList()..sort();
    final chosen = {..._query.licenses};
    await showUpSheet<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => UpSheet(
          title: l10n.libraryCatalogFilterLicense,
          children: [
            for (final id in ids)
              _SheetRow(
                label: LicenseInfo.of(id).badge,
                subtitle: licenseHints(l10n, LicenseInfo.of(id)).join(' '),
                selected: chosen.contains(id),
                onTap: () => setSheet(() {
                  if (!chosen.remove(id)) chosen.add(id);
                }),
              ),
            Padding(
              padding: const EdgeInsets.all(UpPageTokens.paddingX),
              child: UpButton(
                label: l10n.commonDone,
                expand: true,
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    _setQuery(_query.copyWith(licenses: chosen));
  }

  Future<void> _pickGenre(BuildContext context) async {
    final l10n = context.l10n;
    final facets = await _facets();
    if (!context.mounted) return;
    final ids = [for (final f in facets?.genres ?? const <Facet>[]) f.id];
    // '' 表示「全部」
    final v = await showUpSheet<String>(
      context,
      builder: (ctx) => UpSheet(
        title: l10n.libraryCatalogFilterGenre,
        children: [
          _SheetRow(
            label: l10n.libraryCatalogClearFilters,
            selected: _query.genre == null,
            onTap: () => Navigator.pop(ctx, ''),
          ),
          for (final g in ids)
            _SheetRow(
              label: genreLabel(l10n, g),
              selected: _query.genre == g,
              onTap: () => Navigator.pop(ctx, g),
            ),
        ],
      ),
    );
    if (v != null) {
      _setQuery(_query.copyWith(genre: () => v.isEmpty ? null : v));
    }
  }

  Future<void> _pickTempo(BuildContext context) async {
    final l10n = context.l10n;
    final v = await showUpSheet<(int?, int?)>(
      context,
      builder: (ctx) => UpSheet(
        title: l10n.libraryCatalogFilterBpm,
        children: [
          _SheetRow(
            label: l10n.libraryCatalogBpmAny,
            selected: _query.bpmMin == null && _query.bpmMax == null,
            onTap: () => Navigator.pop(ctx, (null, null)),
          ),
          for (final p in _tempoPresets)
            _SheetRow(
              label: l10n.libraryCatalogBpmRange(p.$1 ?? 0, p.$2 ?? 999),
              selected: _query.bpmMin == p.$1 && _query.bpmMax == p.$2,
              onTap: () => Navigator.pop(ctx, p),
            ),
        ],
      ),
    );
    if (v != null) {
      _setQuery(_query.copyWith(bpmMin: () => v.$1, bpmMax: () => v.$2));
    }
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = UpTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: UpPageTokens.paddingX),
      child: UpListItem(
        title: label,
        subtitle: subtitle,
        trailing: selected
            ? Icon(Icons.check_rounded, color: c.accentPrimary)
            : null,
        onTap: onTap,
      ),
    );
  }
}

// ======================================================================== 列表

class _ResultList extends ConsumerWidget {
  const _ResultList({required this.scroll});
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final list = ref.watch(catalogListProvider);

    if (!list.loaded && list.loading) {
      return const Center(child: UpProgressRing());
    }
    if (!list.loaded && list.error != null) {
      return _Message(
        text: list.error!.isNetwork
            ? l10n.libraryCatalogLoadFailedOffline
            : l10n.libraryCatalogLoadFailed,
        action: UpButton(
          label: l10n.commonRetry,
          size: UpButtonSize.sm,
          onPressed: () =>
              unawaited(ref.read(catalogListProvider.notifier).refresh()),
        ),
      );
    }
    if (list.items.isEmpty) {
      return _Message(text: l10n.libraryCatalogEmpty);
    }
    return RefreshIndicator(
      onRefresh: ref.read(catalogListProvider.notifier).refresh,
      child: ListView.builder(
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        // 头部的总数 + 条目 + 底部的加载状态
        itemCount: list.items.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                UpPageTokens.paddingX,
                UpSpacing.sm,
                UpPageTokens.paddingX,
                0,
              ),
              child: UpText(
                l10n.libraryCatalogTotal(list.total),
                role: UpTextRole.caption,
                color: c.textMuted,
              ),
            );
          }
          if (i == list.items.length + 1) {
            // 底部：加载更多的转圈，或加载失败的重试
            if (list.loading) {
              return const Padding(
                padding: EdgeInsets.all(UpSpacing.xl),
                child: Center(child: UpProgressRing()),
              );
            }
            if (list.error != null) {
              return Padding(
                padding: const EdgeInsets.all(UpSpacing.xl),
                child: Center(
                  child: UpButton(
                    label: l10n.commonRetry,
                    size: UpButtonSize.sm,
                    onPressed: () => unawaited(
                      ref.read(catalogListProvider.notifier).loadMore(),
                    ),
                  ),
                ),
              );
            }
            return const SizedBox(height: UpSpacing.xxl);
          }
          return CatalogItemCard(item: list.items[i - 1]);
        },
      ),
    );
  }
}

/// 收藏视图：逐个取条目详情（先查已载入列表和本机记录，再问服务端）。
class _FavoritesList extends ConsumerWidget {
  const _FavoritesList({required this.favorites});
  final List<String> favorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (favorites.isEmpty) {
      return _Message(text: l10n.libraryCatalogEmptyFavorites);
    }
    return ListView.builder(
      itemCount: favorites.length,
      itemBuilder: (context, i) {
        final item = ref.watch(catalogItemProvider(favorites[i]));
        return item.when(
          data: (it) => CatalogItemCard(item: it),
          loading: () => const SizedBox(
            height: UpKitCardTokens.height,
            child: Center(child: UpProgressRing()),
          ),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
    );
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

/// 目录条目卡：封面、标题 / 作者 / BPM · 曲风 · 大小、许可证徽标、收藏心形、下载状态。
class CatalogItemCard extends ConsumerWidget {
  const CatalogItemCard({super.key, required this.item});
  final CatalogItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = UpTheme.of(context).colors;
    final records = ref.watch(catalogRecordsProvider);
    final progress = ref.watch(
      catalogDownloadProvider.select((m) => m.containsKey(item.id)),
    );
    final value = ref.watch(catalogDownloadProvider.select((m) => m[item.id]));
    final favorite = ref.watch(
      cloudStateProvider.select((s) => s.favorites.contains(item.id)),
    );
    final status = downloadStatusOf(item, records);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UpPageTokens.paddingX,
        UpKitCardTokens.marginTop,
        UpPageTokens.paddingX,
        0,
      ),
      child: KitCard(
        title: item.title,
        overline: item.artist.isEmpty ? null : item.artist,
        subtitle: itemSubtitle(l10n, item),
        role: roleOf(item),
        status: progress
            ? KitStatus.downloading
            : status == DownloadStatus.none
            ? KitStatus.notDownloaded
            : KitStatus.ready,
        progress: value,
        badge: LicenseBadge(license: item.license),
        trailing: UpIconButton(
          icon: favorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          color: favorite ? c.accentPrimary : null,
          semanticLabel: favorite
              ? l10n.libraryCatalogRemoveFavorite
              : l10n.libraryCatalogAddFavorite,
          onPressed: () => unawaited(
            ref.read(cloudStateProvider.notifier).toggleFavorite(item.id),
          ),
        ),
        onTap: () => context.push(Routes.catalogItem(item.id)),
      ),
    );
  }
}
