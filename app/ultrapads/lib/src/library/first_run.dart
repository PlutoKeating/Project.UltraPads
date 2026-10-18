import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_engine/up_engine.dart';

import '../assets/private_assets.dart';

/// 开发便利（桌面）：`--dart-define=UP_PRIVATE_KITS=<private-assets/compat-ios>`
/// 时直接用曲库导入器读取该目录（不经注入、不复制资源）。
const String privateKitsDirFlag = String.fromEnvironment('UP_PRIVATE_KITS');

/// 打包的 CC0 示例 Kit 目录（`content/kits/*.upkit` 的副本）。
const String bundledKitsDir = 'assets/kits/';

/// CC0 starter Kit 的固定 ID（`content/kits/ultrapads-starter.upkit` manifest）。
const String starterKitId = '0192f0c0-5a17-7000-8000-00000000c0de';

/// 原版 4.7.0 默认 Kit 的名字。
const String originalDefaultKitName = 'sunset';

/// 默认加载顺序：原版 Sunset（已注入私有素材时）→ CC0 starter → 第一个。
KitSummary? pickDefaultKit(List<KitSummary> kits) {
  if (kits.isEmpty) return null;
  for (final k in kits) {
    if (k.name.trim().toLowerCase() == originalDefaultKitName) return k;
  }
  for (final k in kits) {
    if (k.id == starterKitId) return k;
  }
  return kits.first;
}

/// 首次启动：
/// 1. 曲库为空时导入打包的 CC0 Kit（`library_import_bytes`）；
/// 2. 注入了私有素材（`just inject-assets`）且这批素材还没导入过时，把
///    `privateKits` 还原成原目录结构（临时目录），交给原 App 素材导入器
///    （`library_import`，6 个内置 Kit + 目录 + 教程）；桌面也可以用
///    [privateKitsDirFlag] 直接导入 private-assets 目录；
/// 3. 引擎还没有 Kit 时按 [pickDefaultKit] 加载默认 Kit。
///
/// 每一步失败只记录日志，不影响启动。
class FirstRunImporter {
  FirstRunImporter({
    required this.engine,
    required this.prefs,
    required this.assets,
    required this.tempDir,
    AssetBundle? bundle,
  }) : bundle = bundle ?? rootBundle;

  final EngineClient engine;
  final SharedPreferences prefs;
  final PrivateAssets assets;
  final AssetBundle bundle;

  /// 还原私有 Kit 用的临时目录（用完删除）。
  final Future<Directory> Function() tempDir;

  static const _privateKey = 'privateKitsImported';
  static const _privateDirKey = 'privateKitsDirImported';

  Future<void> run() async {
    await _step('bundled kits', _importBundled);
    await _step('private kits', _importPrivate);
    await _step('private kits dir', _importPrivateDir);
    await _step('default kit', _loadDefault);
  }

  Future<void> _step(String name, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      debugPrint('UltraPads: first run $name skipped ($e)');
    }
  }

  Future<void> _importBundled() async {
    if ((await engine.libraryListKits()).isNotEmpty) return;
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final files =
        manifest
            .listAssets()
            .where((a) => a.startsWith(bundledKitsDir) && a.endsWith('.upkit'))
            .toList()
          ..sort();
    for (final path in files) {
      final data = await bundle.load(path);
      await engine.libraryImportBytes(
        path.substring(bundledKitsDir.length),
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
  }

  Future<void> _importPrivate() async {
    if (assets.privateKits.isEmpty) return;
    final stamp = assets.generatedAt;
    if (prefs.getString(_privateKey) == stamp) return;
    final root = await tempDir();
    try {
      for (final MapEntry(key: rel, value: asset)
          in assets.privateKits.entries) {
        final file = File('${root.path}/$rel');
        await file.parent.create(recursive: true);
        final data = await bundle.load(asset);
        await file.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      }
      await engine.libraryImport(root.path);
      await prefs.setString(_privateKey, stamp);
    } finally {
      if (root.existsSync()) await root.delete(recursive: true);
    }
  }

  Future<void> _importPrivateDir() async {
    if (privateKitsDirFlag.isEmpty) return;
    if (prefs.getString(_privateDirKey) == privateKitsDirFlag) return;
    await engine.libraryImport(privateKitsDirFlag);
    await prefs.setString(_privateDirKey, privateKitsDirFlag);
  }

  Future<void> _loadDefault() async {
    if (engine.snapshot().kit != null) return;
    final kit = pickDefaultKit(await engine.libraryListKits());
    if (kit != null) await engine.libraryLoadKit(kit.id);
  }
}
