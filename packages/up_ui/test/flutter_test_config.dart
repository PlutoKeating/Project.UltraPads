import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 为 golden 加载真实字体：up_tokens 的 Montserrat（开源回退字体）和
/// Flutter SDK 自带的 Material Icons，避免 Ahem 方块。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadTestFonts();
  return testMain();
}

Future<void> loadTestFonts() async {
  // up_tokens 打包的开源字体（Open Sans；兼容旧的 Montserrat 回退）。
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final byFamily = <String, List<String>>{};
  for (final key in manifest.listAssets()) {
    if (!key.startsWith('packages/up_tokens/') || !key.endsWith('.ttf')) {
      continue;
    }
    final file = key.split('/').last;
    final family = file.startsWith('OpenSans')
        ? 'Open Sans'
        : file.split('-').first;
    byFamily.putIfAbsent('packages/up_tokens/$family', () => []).add(key);
  }
  for (final e in byFamily.entries) {
    final loader = FontLoader(e.key);
    for (final a in e.value) {
      loader.addFont(rootBundle.load(a));
    }
    await loader.load();
  }

  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final f = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (f.existsSync()) {
      final bytes = f.readAsBytesSync();
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await icons.load();
    }
  }
}
