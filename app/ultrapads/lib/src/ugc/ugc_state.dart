import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:up_engine/up_engine.dart';

import '../account/account_state.dart';
import '../features/catalog/catalog_models.dart';
import '../features/catalog/catalog_state.dart';
import '../state/engine_state.dart';
import 'ugc_client.dart';
import 'ugc_models.dart';

/// 用户上传客户端；站点地址未配置时为 null。
final ugcClientProvider = Provider<UgcClient?>((ref) {
  final api = ref.watch(catalogClientProvider);
  return api == null ? null : UgcClient(api);
});

Future<UgcClient?> _awaitClient(Ref ref) async {
  final api = await awaitCatalogClient(ref);
  return api == null ? null : UgcClient(api);
}

/// 上传 / 取回用的临时目录（测试中替换）。
final ugcTempDirProvider = Provider<Future<Directory> Function()>(
  (ref) => () async {
    final tmp = await getTemporaryDirectory();
    return Directory('${tmp.path}${Platform.pathSeparator}ugc');
  },
);

/// 把曲库里的 Kit 导出成临时 `.upkit` 文件（测试中替换）。
final ugcExportProvider = Provider<Future<File> Function(String kitId)>(
  (ref) => (kitId) async {
    final dir = await ref.read(ugcTempDirProvider)();
    await dir.create(recursive: true);
    final file = File(
      '${dir.path}${Platform.pathSeparator}${kitId.hashCode.toUnsigned(32)}.upkit',
    );
    await ref
        .read(engineProvider)
        .libraryExportKit(kitId, file.path, ExportFormat.upkit);
    return file;
  },
);

// ------------------------------------------------------------------ 我的上传

@immutable
class MyUploadsState {
  const MyUploadsState({
    this.items = const [],
    this.loading = false,
    this.loaded = false,
    this.error,
    this.busy = const {},
  });

  final List<UploadItem> items;
  final bool loading;
  final bool loaded;
  final CatalogException? error;

  /// 正在改可见性 / 删除 / 取回的条目 ID。
  final Set<String> busy;

  MyUploadsState copyWith({
    List<UploadItem>? items,
    bool? loading,
    bool? loaded,
    CatalogException? Function()? error,
    Set<String>? busy,
  }) => MyUploadsState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
    error: error != null ? error() : this.error,
    busy: busy ?? this.busy,
  );

  bool owns(String id) => items.any((i) => i.id == id);
}

class MyUploadsController extends Notifier<MyUploadsState> {
  @override
  MyUploadsState build() {
    // 退出登录后清空，换账号不残留上一个账号的列表
    ref.listen<AccountState>(accountProvider, (prev, next) {
      if (!next.signedIn && (prev?.signedIn ?? false)) {
        state = const MyUploadsState();
      }
    });
    return const MyUploadsState();
  }

  Future<void> refresh() async {
    if (!ref.read(accountProvider).signedIn) return;
    state = state.copyWith(loading: true, error: () => null);
    final client = await _awaitClient(ref);
    if (!ref.mounted) return;
    if (client == null) {
      state = state.copyWith(
        loading: false,
        error: () => const CatalogException('not_configured'),
      );
      return;
    }
    try {
      final items = await client.list();
      if (!ref.mounted) return;
      state = state.copyWith(items: items, loading: false, loaded: true);
    } on CatalogException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: () => e);
    }
  }

  void upsert(UploadItem item) {
    final others = [
      for (final i in state.items)
        if (i.id != item.id) i,
    ];
    state = state.copyWith(items: [item, ...others], loaded: true);
  }

  Future<T> _busy<T>(String id, Future<T> Function(UgcClient c) run) async {
    final client = await _awaitClient(ref);
    if (client == null) throw const CatalogException('not_configured');
    state = state.copyWith(busy: {...state.busy, id});
    try {
      return await run(client);
    } finally {
      if (ref.mounted) {
        state = state.copyWith(busy: {...state.busy}..remove(id));
      }
    }
  }

  /// 设为公开 / 改回私有。失败抛 [CatalogException]。
  Future<void> setPublic(String id, bool public) => _busy(id, (c) async {
    final item = await c.patch(id, {
      'visibility': public ? 'public' : 'private',
    });
    if (ref.mounted) upsert(item);
  });

  Future<void> delete(String id) => _busy(id, (c) async {
    await c.delete(id);
    if (!ref.mounted) return;
    state = state.copyWith(
      items: [
        for (final i in state.items)
          if (i.id != id) i,
      ],
    );
  });

  /// 取回自己的文件并导入曲库；返回导入得到的 Kit ID。
  Future<List<String>> restore(UploadItem item) => _busy(item.id, (c) async {
    final dir = await ref.read(ugcTempDirProvider)();
    final file = File('${dir.path}${Platform.pathSeparator}${item.id}.upkit');
    try {
      await c.downloadOwn(item, file);
      final report = await ref.read(engineProvider).libraryImport(file.path);
      return [for (final k in report.kits) k.id];
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  });
}

final myUploadsProvider = NotifierProvider<MyUploadsController, MyUploadsState>(
  MyUploadsController.new,
);

// ------------------------------------------------------------------ 上传流程

enum UploadPhase { idle, exporting, creating, uploading, done, failed }

@immutable
class UploadState {
  const UploadState({
    this.phase = UploadPhase.idle,
    this.progress = 0,
    this.error,
    this.result,
  });

  final UploadPhase phase;

  /// 上传阶段的进度 0..1。
  final double progress;
  final Object? error;
  final UploadItem? result;

  bool get running =>
      phase == UploadPhase.exporting ||
      phase == UploadPhase.creating ||
      phase == UploadPhase.uploading;
}

/// 导出 → 建条目 → 流式上传。失败或取消时尽力删掉已建的空条目，不占用账号配额。
class UploadController extends Notifier<UploadState> {
  UploadCancel? _cancel;

  @override
  UploadState build() => const UploadState();

  void cancel() => _cancel?.cancel();

  void reset() {
    if (!state.running) state = const UploadState();
  }

  Future<UploadItem?> upload(String kitId, UploadDraft draft) async {
    if (state.running) return null;
    final cancel = _cancel = UploadCancel();
    state = const UploadState(phase: UploadPhase.exporting);
    UgcClient? client;
    String? createdId;
    File? file;
    try {
      client = await _awaitClient(ref);
      if (client == null) throw const CatalogException('not_configured');
      file = await ref.read(ugcExportProvider)(kitId);
      if (cancel.cancelled) throw const CatalogCancelled();
      final size = await file.length();
      if (size > maxUploadBytes) {
        throw const CatalogException('too_large', status: 413);
      }
      final digest = await sha256OfFile(file);
      if (cancel.cancelled) throw const CatalogCancelled();
      state = const UploadState(phase: UploadPhase.creating);
      final created = await client.create(draft);
      createdId = created.id;
      if (cancel.cancelled) throw const CatalogCancelled();
      state = const UploadState(phase: UploadPhase.uploading);
      final done = await client.uploadFile(
        created.id,
        file,
        sha256Hex: digest,
        cancel: cancel,
        onProgress: (sent, total) {
          if (ref.mounted) {
            state = UploadState(
              phase: UploadPhase.uploading,
              progress: total == 0 ? 0 : sent / total,
            );
          }
        },
      );
      ref.read(myUploadsProvider.notifier).upsert(done);
      state = UploadState(phase: UploadPhase.done, progress: 1, result: done);
      return done;
    } on CatalogCancelled {
      await _discard(client, createdId);
      state = const UploadState();
      return null;
    } catch (e) {
      await _discard(client, createdId);
      state = UploadState(phase: UploadPhase.failed, error: e);
      return null;
    } finally {
      _cancel = null;
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  Future<void> _discard(UgcClient? client, String? id) async {
    if (client == null || id == null) return;
    try {
      await client.delete(id);
    } catch (_) {}
  }
}

final uploadProvider = NotifierProvider<UploadController, UploadState>(
  UploadController.new,
);

/// 举报一条公开的用户上传（调用 `reportUploadProvider` 取得函数）。失败抛 [CatalogException]。
final reportUploadProvider =
    Provider<
      Future<void> Function(String id, ReportReason reason, String? note)
    >(
      (ref) => (id, reason, note) async {
        final client = await _awaitClient(ref);
        if (client == null) throw const CatalogException('not_configured');
        await client.report(id, reason, note: note);
      },
    );
