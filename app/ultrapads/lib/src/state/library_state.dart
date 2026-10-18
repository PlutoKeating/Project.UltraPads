import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_engine/up_engine.dart';

import 'engine_state.dart';
import 'settings_state.dart';

/// 正在加载 / 下载的 Kit → 进度（null = 不定进度）。UI 侧的操作状态。
class KitLoadController extends Notifier<Map<String, double?>> {
  @override
  Map<String, double?> build() => const {};

  /// 加载 Kit（引擎负责下载 / 解码，完成后推送 KitLoaded）。
  /// 返回 false 表示引擎未实现。
  Future<bool> load(String kitId) async {
    state = {...state, kitId: null};
    try {
      return await tryEngineDo(
        () => ref.read(engineProvider).libraryLoadKit(kitId),
      );
    } finally {
      state = {...state}..remove(kitId);
    }
  }
}

final kitLoadProvider =
    NotifierProvider<KitLoadController, Map<String, double?>>(
      KitLoadController.new,
    );

/// 收藏（用户偏好，存在本机）。
class FavoritesController extends Notifier<Set<String>> {
  static const _k = 'favorites';

  @override
  Set<String> build() =>
      (ref.watch(prefsProvider).getStringList(_k) ?? const []).toSet();

  void toggle(String id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
    ref.read(prefsProvider).setStringList(_k, next.toList());
  }
}

final favoritesProvider = NotifierProvider<FavoritesController, Set<String>>(
  FavoritesController.new,
);

/// 单个 Kit 摘要。
final kitSummaryProvider = Provider.family<KitSummary?, String>((ref, id) {
  final kits = ref.watch(kitsProvider).value ?? const <KitSummary>[];
  for (final k in kits) {
    if (k.id == id) return k;
  }
  return null;
});
