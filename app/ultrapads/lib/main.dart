import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_fx/up_fx.dart';
import 'package:up_i18n/up_i18n.dart';

import 'src/app/app.dart';
import 'src/assets/private_assets.dart';
import 'src/engine/engine_bootstrap.dart';
import 'src/state/engine_state.dart';
import 'src/state/settings_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final assets = await PrivateAssets.load();
  final boot = await bootEngine();
  final locales = LocaleController(store: PrefsLocaleStore(prefs));

  await Future.wait([
    assets.registerFonts(),
    FxShaders.instance.load(),
    locales.load(),
    _initEngine(boot.client, prefs),
  ]);

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        privateAssetsProvider.overrideWithValue(assets),
        engineBootProvider.overrideWithValue(boot),
        localeControllerProvider.overrideWith((ref) => locales),
      ],
      child: const UltraPadsApp(),
    ),
  );
}

/// 初始化引擎：存储目录、音频设备、默认 Kit。任何一步失败都只记录日志，UI 照常启动并降级。
Future<void> _initEngine(EngineClient engine, SharedPreferences prefs) async {
  Future<void> step(String name, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      debugPrint('UltraPads: engine $name skipped ($e)');
    }
  }

  await step('init', () async {
    final support = await getApplicationSupportDirectory();
    final cache = await getTemporaryDirectory();
    await engine.init(AppDirs(dataDir: support.path, cacheDir: cache.path));
  });
  await step(
    'audio_start',
    () => engine.audioStart(
      AudioConfig(
        bufferFrames: prefs.getInt('bufferFrames'),
        outputDevice: prefs.getString('outputDevice'),
      ),
    ),
  );
  await step('default_kit', () async {
    if (engine.snapshot().kit != null) return;
    final kits = await engine.libraryListKits();
    if (kits.isNotEmpty) await engine.libraryLoadKit(kits.first.id);
  });
}
