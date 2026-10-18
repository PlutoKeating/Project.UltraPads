import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_engine/up_engine.dart';

import '../../account/account_state.dart';
import '../../config/app_links.dart';
import '../../state/engine_state.dart';
import '../../state/settings_state.dart';
import 'catalog_client.dart';
import 'catalog_models.dart';

/// 目录接口用的 HTTP 客户端（测试中替换为 MockClient）。
final catalogHttpClientProvider = Provider<http.Client>((ref) {
  final c = http.Client();
  ref.onDispose(c.close);
  return c;
});

/// 目录客户端；链接配置未载入或没有站点地址时为 null。
final catalogClientProvider = Provider<CatalogClient?>((ref) {
  final base = ref.watch(appLinksProvider).value?.siteBase;
  if (base == null) return null;
  return CatalogClient(
    base: base,
    client: ref.watch(catalogHttpClientProvider),
    token: () => ref.read(accountProvider.notifier).accessToken(),
  );
});

/// 等链接配置载入后取目录客户端（启动时配置还在读 asset，直接 read 会拿到 null）。
Future<CatalogClient?> awaitCatalogClient(Ref ref) async {
  try {
    await ref.read(appLinksProvider.future);
  } catch (_) {
    return null;
  }
  return ref.read(catalogClientProvider);
}

/// 下载临时目录（测试中替换）。
final catalogDownloadDirProvider = Provider<Future<Directory> Function()>(
  (ref) => () async {
    final tmp = await getTemporaryDirectory();
    return Directory('${tmp.path}${Platform.pathSeparator}catalog');
  },
);

// --------------------------------------------------------------------- 列表

@immutable
class CatalogListState {
  const CatalogListState({
    this.query = const CatalogQuery(),
    this.items = const [],
    this.nextCursor,
    this.total = 0,
    this.loading = false,
    this.loaded = false,
    this.error,
  });

  final CatalogQuery query;
  final List<CatalogItem> items;
  final String? nextCursor;
  final int total;
  final bool loading;

  /// 至少成功加载过一页。
  final bool loaded;
  final CatalogException? error;

  bool get hasMore => nextCursor != null;
}

/// 分页目录列表。[refresh] 重新加载第一页，[loadMore] 追加下一页；
/// 筛选变化后丢弃过期请求的结果。
class CatalogListController extends Notifier<CatalogListState> {
  int _generation = 0;

  @override
  CatalogListState build() => const CatalogListState();

  Future<void> setQuery(CatalogQuery q) async {
    if (q == state.query && state.loaded) return;
    state = CatalogListState(query: q);
    await refresh();
  }

  Future<void> refresh() async {
    final gen = ++_generation;
    final query = state.query;
    state = CatalogListState(query: query, loading: true);
    final client = await awaitCatalogClient(ref);
    if (gen != _generation || !ref.mounted) return;
    if (client == null) {
      state = CatalogListState(
        query: query,
        error: const CatalogException('not_configured'),
      );
      return;
    }
    try {
      final page = await client.list(query);
      if (gen != _generation) return;
      state = CatalogListState(
        query: query,
        items: page.items,
        nextCursor: page.nextCursor,
        total: page.total,
        loaded: true,
      );
    } on CatalogException catch (e) {
      if (gen != _generation) return;
      state = CatalogListState(query: query, error: e);
    }
  }

  Future<void> loadMore() async {
    final client = ref.read(catalogClientProvider);
    final cursor = state.nextCursor;
    if (client == null || cursor == null || state.loading) return;
    final gen = _generation;
    final s = state;
    state = CatalogListState(
      query: s.query,
      items: s.items,
      nextCursor: s.nextCursor,
      total: s.total,
      loaded: true,
      loading: true,
    );
    try {
      final page = await client.list(s.query, cursor: cursor);
      if (gen != _generation) return;
      state = CatalogListState(
        query: s.query,
        items: [...s.items, ...page.items],
        nextCursor: page.nextCursor,
        total: page.total,
        loaded: true,
      );
    } on CatalogException catch (e) {
      if (gen != _generation) return;
      state = CatalogListState(
        query: s.query,
        items: s.items,
        nextCursor: s.nextCursor,
        total: s.total,
        loaded: true,
        error: e,
      );
    }
  }
}

final catalogListProvider =
    NotifierProvider<CatalogListController, CatalogListState>(
      CatalogListController.new,
    );

final catalogFacetsProvider = FutureProvider<CatalogFacets>((ref) async {
  final client = await awaitCatalogClient(ref);
  if (client == null) throw const CatalogException('not_configured');
  return client.facets();
});

/// 单个条目：先在已载入的列表里找，没有再向服务端取（来自收藏 / 最近使用的 ID）。
final catalogItemProvider = FutureProvider.family<CatalogItem, String>((
  ref,
  id,
) async {
  for (final i in ref.read(catalogListProvider).items) {
    if (i.id == id) return i;
  }
  final rec = ref.read(catalogRecordsProvider)[id];
  if (rec != null) return rec.item;
  final client = await awaitCatalogClient(ref);
  if (client == null) throw const CatalogException('not_configured');
  return client.item(id);
});

// ------------------------------------------------------------ 已下载记录

/// 一个已下载并导入的目录条目：导入得到的 Kit，以及当时的条目元数据（署名用）。
@immutable
class CatalogRecord {
  const CatalogRecord({
    required this.item,
    this.kitIds = const [],
    this.kitNames = const [],
    this.downloadedAtMs = 0,
  });

  final CatalogItem item;
  final List<String> kitIds;
  final List<String> kitNames;
  final int downloadedAtMs;

  Map<String, Object?> toJson() => {
    'item': item.toJson(),
    'kits': kitIds,
    'names': kitNames,
    'at': downloadedAtMs,
  };

  static CatalogRecord? fromJson(Object? j) {
    if (j is! Map || j['item'] is! Map) return null;
    try {
      return CatalogRecord(
        item: CatalogItem.fromJson((j['item']! as Map).cast<String, Object?>()),
        kitIds: [
          if (j['kits'] is List)
            for (final e in j['kits']! as List) '$e',
        ],
        kitNames: [
          if (j['names'] is List)
            for (final e in j['names']! as List) '$e',
        ],
        downloadedAtMs: (j['at'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

/// 已下载的目录条目（本机偏好，存在 SharedPreferences）。
class CatalogRecordsController extends Notifier<Map<String, CatalogRecord>> {
  static const _k = 'catalog.records';

  @override
  Map<String, CatalogRecord> build() {
    final raw = ref.watch(prefsProvider).getString(_k);
    if (raw == null) return const {};
    try {
      final j = jsonDecode(raw) as Map<String, Object?>;
      return {
        for (final e in j.entries) e.key: ?CatalogRecord.fromJson(e.value),
      };
    } catch (_) {
      return const {};
    }
  }

  void put(CatalogRecord r) {
    state = {...state, r.item.id: r};
    unawaited(
      ref
          .read(prefsProvider)
          .setString(
            _k,
            jsonEncode({
              for (final e in state.entries) e.key: e.value.toJson(),
            }),
          ),
    );
  }
}

final catalogRecordsProvider =
    NotifierProvider<CatalogRecordsController, Map<String, CatalogRecord>>(
      CatalogRecordsController.new,
    );

/// 条目是否已下载（且本机版本与目录里的内容一致）。
enum DownloadStatus { none, downloaded, updateAvailable }

DownloadStatus downloadStatusOf(
  CatalogItem item,
  Map<String, CatalogRecord> records,
) {
  final r = records[item.id];
  if (r == null) return DownloadStatus.none;
  return item.sha256.isNotEmpty && r.item.sha256 != item.sha256
      ? DownloadStatus.updateAvailable
      : DownloadStatus.downloaded;
}

/// 某个 Kit 名字对应的目录条目（导出 / 分享录音时的署名来源）。
final catalogAttributionsProvider = Provider.family<List<CatalogItem>, String>((
  ref,
  kitName,
) {
  if (kitName.isEmpty) return const [];
  return [
    for (final r in ref.watch(catalogRecordsProvider).values)
      if (r.kitNames.contains(kitName)) r.item,
  ];
});

// ------------------------------------------------------------------- 下载

/// 下载 → 校验 → 导入曲库。状态是进行中条目的进度（0..1，未知时为 null）。
class CatalogDownloadController extends Notifier<Map<String, double?>> {
  final _cancels = <String, DownloadCancel>{};

  @override
  Map<String, double?> build() => const {};

  void cancel(String id) => _cancels[id]?.cancel();

  /// 返回导入得到的 Kit ID。失败抛 [CatalogException] / [EngineException]，
  /// 取消抛 [CatalogCancelled]。
  Future<List<String>> download(CatalogItem item) async {
    if (state.containsKey(item.id)) return const [];
    final cancel = _cancels[item.id] = DownloadCancel();
    state = {...state, item.id: 0};
    File? file;
    try {
      final client = await awaitCatalogClient(ref);
      if (client == null) throw const CatalogException('not_configured');
      if (cancel.cancelled) throw const CatalogCancelled();
      final dir = await ref.read(catalogDownloadDirProvider)();
      file = File('${dir.path}${Platform.pathSeparator}${item.id}.upkit');
      await client.download(
        item,
        file,
        cancel: cancel,
        onProgress: (got, total) {
          state = {
            ...state,
            item.id: total == null || total == 0 ? null : got / total,
          };
        },
      );
      final report = await ref.read(engineProvider).libraryImport(file.path);
      final prev = ref.read(catalogRecordsProvider)[item.id];
      final kits = report.kits;
      ref
          .read(catalogRecordsProvider.notifier)
          .put(
            CatalogRecord(
              item: item,
              kitIds: kits.isEmpty
                  ? (prev?.kitIds ?? const [])
                  : [for (final k in kits) k.id],
              kitNames: kits.isEmpty
                  ? (prev?.kitNames ?? const [])
                  : [for (final k in kits) k.name],
              downloadedAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      unawaited(ref.read(cloudStateProvider.notifier).recordRecent(item.id));
      return ref.read(catalogRecordsProvider)[item.id]!.kitIds;
    } finally {
      _cancels.remove(item.id);
      state = {...state}..remove(item.id);
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (_) {}
    }
  }
}

final catalogDownloadProvider =
    NotifierProvider<CatalogDownloadController, Map<String, double?>>(
      CatalogDownloadController.new,
    );

// --------------------------------------------------------- 云端收藏 / 最近使用

@immutable
class CloudState {
  const CloudState({
    this.favorites = const {},
    this.recent = const [],
    this.downloads = const [],
    this.syncing = false,
    this.pending = 0,
  });

  /// 收藏的条目 ID（本机视图：已含尚未同步的改动）。
  final Set<String> favorites;
  final List<StampedId> recent;
  final List<StampedId> downloads;
  final bool syncing;

  /// 还没送达服务端的改动数。
  final int pending;

  CloudState copyWith({
    Set<String>? favorites,
    List<StampedId>? recent,
    List<StampedId>? downloads,
    bool? syncing,
    int? pending,
  }) => CloudState(
    favorites: favorites ?? this.favorites,
    recent: recent ?? this.recent,
    downloads: downloads ?? this.downloads,
    syncing: syncing ?? this.syncing,
    pending: pending ?? this.pending,
  );
}

/// 收藏与最近使用：本地先生效并持久化；每个改动排进待发队列，登录且联网时按序送达服务端，
/// 失败则留在队列里下次再试；登录后拉取服务端状态与本地合并（并集，待发改动优先）。
class CloudStateController extends Notifier<CloudState> {
  static const _kFav = 'catalog.favorites';
  static const _kRecent = 'catalog.recent';
  static const _kDownloads = 'catalog.downloads';
  static const _kPending = 'catalog.pending';
  static const recentLimit = 100;

  List<_Op> _pending = [];
  bool _flushing = false;

  @override
  CloudState build() {
    final prefs = ref.watch(prefsProvider);
    _pending = _decodeOps(prefs.getString(_kPending));
    // 登录状态变化时同步（启动恢复登录、首次登录）
    ref.listen<AccountState>(accountProvider, (prev, next) {
      if (next.signedIn && !(prev?.signedIn ?? false)) unawaited(sync());
    });
    if (ref.read(accountProvider).signedIn) unawaited(Future.microtask(sync));
    return CloudState(
      favorites: (prefs.getStringList(_kFav) ?? const []).toSet(),
      recent: _decodeStamped(prefs.getString(_kRecent)),
      downloads: _decodeStamped(prefs.getString(_kDownloads)),
      pending: _pending.length,
    );
  }

  SharedPreferences get _prefs => ref.read(prefsProvider);

  bool get _signedIn => ref.read(accountProvider).signedIn;

  Future<void> toggleFavorite(String id) async {
    final fav = {...state.favorites};
    final add = fav.add(id);
    if (!add) fav.remove(id);
    state = state.copyWith(favorites: fav);
    await _prefs.setStringList(_kFav, fav.toList());
    _enqueue(_Op(add ? _OpKind.favAdd : _OpKind.favRemove, id));
    unawaited(flush());
  }

  Future<void> recordRecent(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = _mergeStamped(state.recent, [StampedId(id, now)]);
    state = state.copyWith(recent: next);
    await _prefs.setString(_kRecent, _encodeStamped(next));
    _enqueue(_Op(_OpKind.recent, id));
    unawaited(flush());
  }

  void _enqueue(_Op op) {
    // 同一条目的收藏改动只保留最后一个，避免长队列
    if (op.kind != _OpKind.recent) {
      _pending.removeWhere((o) => o.kind != _OpKind.recent && o.id == op.id);
    }
    _pending.add(op);
    _persistPending();
  }

  void _persistPending() {
    state = state.copyWith(pending: _pending.length);
    unawaited(
      _prefs.setString(
        _kPending,
        jsonEncode([for (final o in _pending) o.toJson()]),
      ),
    );
  }

  /// 把待发队列送达服务端。未登录或联网失败时原样保留。
  Future<void> flush() async {
    if (_flushing || !_signedIn) return;
    _flushing = true;
    try {
      final client = await awaitCatalogClient(ref);
      if (client == null) return;
      while (_pending.isNotEmpty && ref.mounted) {
        final op = _pending.first;
        try {
          switch (op.kind) {
            case _OpKind.favAdd:
              await client.putFavorite(op.id);
            case _OpKind.favRemove:
              await client.deleteFavorite(op.id);
            case _OpKind.recent:
              await client.postRecent(op.id);
          }
        } on CatalogException catch (e) {
          if (!ref.mounted) return;
          // 条目已不在目录里（404）：这个改动永远送不达，丢掉；其余错误留待下次
          if (e.notFound) {
            _pending.removeAt(0);
            _persistPending();
            continue;
          }
          return;
        }
        if (!ref.mounted) return;
        _pending.removeAt(0);
        _persistPending();
      }
    } finally {
      _flushing = false;
    }
  }

  /// 登录后：先送达待发改动，再拉取服务端状态与本地合并。
  Future<void> sync() =>
      _inflight ??= _sync().whenComplete(() => _inflight = null);

  Future<void>? _inflight;

  Future<void> _sync() async {
    if (!_signedIn) return;
    state = state.copyWith(syncing: true);
    try {
      final client = await awaitCatalogClient(ref);
      if (client == null || !ref.mounted) return;
      await flush();
      final remote = await client.meState();
      if (!ref.mounted) return;
      final fav = {...remote.favorites, ...state.favorites};
      // 待发的取消收藏要压过服务端的旧状态
      for (final o in _pending) {
        if (o.kind == _OpKind.favRemove) fav.remove(o.id);
        if (o.kind == _OpKind.favAdd) fav.add(o.id);
      }
      final recent = _mergeStamped(state.recent, remote.recent);
      final downloads = _mergeStamped(state.downloads, remote.downloads);
      state = state.copyWith(
        favorites: fav,
        recent: recent,
        downloads: downloads,
      );
      await _prefs.setStringList(_kFav, fav.toList());
      await _prefs.setString(_kRecent, _encodeStamped(recent));
      await _prefs.setString(_kDownloads, _encodeStamped(downloads));
      // 本地有而服务端没有的收藏（登录前收藏的）补送
      for (final id in fav.difference(remote.favorites.toSet())) {
        if (!_pending.any((o) => o.id == id)) {
          _enqueue(_Op(_OpKind.favAdd, id));
        }
      }
      await flush();
    } on CatalogException {
      // 离线或令牌问题：保留本地状态，下次再同步
    } finally {
      if (ref.mounted) state = state.copyWith(syncing: false);
    }
  }

  static List<StampedId> _mergeStamped(List<StampedId> a, List<StampedId> b) {
    final latest = <String, int>{};
    for (final s in [...a, ...b]) {
      final cur = latest[s.id];
      if (cur == null || s.atMs > cur) latest[s.id] = s.atMs;
    }
    final out = [for (final e in latest.entries) StampedId(e.key, e.value)]
      ..sort((x, y) => y.atMs.compareTo(x.atMs));
    return out.length > recentLimit ? out.sublist(0, recentLimit) : out;
  }

  static String _encodeStamped(List<StampedId> l) => jsonEncode([
    for (final s in l) {'id': s.id, 'at_ms': s.atMs},
  ]);

  static List<StampedId> _decodeStamped(String? raw) {
    if (raw == null) return const [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          StampedId('${(e as Map)['id']}', (e['at_ms'] as num?)?.toInt() ?? 0),
      ];
    } catch (_) {
      return const [];
    }
  }

  static List<_Op> _decodeOps(String? raw) {
    if (raw == null) return [];
    try {
      return [for (final e in jsonDecode(raw) as List) ?_Op.fromJson(e)];
    } catch (_) {
      return [];
    }
  }
}

enum _OpKind { favAdd, favRemove, recent }

class _Op {
  const _Op(this.kind, this.id);
  final _OpKind kind;
  final String id;

  Map<String, Object?> toJson() => {'k': kind.name, 'id': id};

  static _Op? fromJson(Object? j) {
    if (j is! Map) return null;
    final kind = _OpKind.values.where((k) => k.name == j['k']).firstOrNull;
    final id = j['id'];
    return kind == null || id is! String ? null : _Op(kind, id);
  }
}

final cloudStateProvider = NotifierProvider<CloudStateController, CloudState>(
  CloudStateController.new,
);
