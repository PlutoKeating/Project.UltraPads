import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ultrapads/src/app/app.dart';
import 'package:ultrapads/src/assets/private_assets.dart';
import 'package:ultrapads/src/config/app_links.dart';
import 'package:ultrapads/src/engine/engine_bootstrap.dart';
import 'package:ultrapads/src/state/engine_state.dart';

import 'package:ultrapads/src/state/settings_state.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_fx/up_fx.dart';
import 'package:up_i18n/up_i18n.dart';

final AppLinks _links = AppLinks.fromJson(
  jsonDecode(File(AppLinks.asset).readAsStringSync()) as Map<String, dynamic>,
);

/// 手机尺寸（4.7.0 设计画布 828×1472 ÷ 2）。
const phone = Size(414, 736);

class AppHarness {
  AppHarness(this.engine, this.container);
  final MockEngineClient engine;
  final ProviderContainer container;
}

/// 启动完整应用（Mock 引擎、无私有素材、FX lite 分级）。
Future<AppHarness> pumpApp(
  WidgetTester t, {
  bool onboarded = true,
  Map<String, Object> prefs = const {},
  Size size = phone,
  MockEngineClient? engine,
}) async {
  await t.binding.setSurfaceSize(size);
  t.view.devicePixelRatio = 1;
  SharedPreferences.setMockInitialValues({
    'onboarded': onboarded,
    // 首次引导默认已看过，避免挡住其它测试；引导自己的测试显式传 false。
    'firstGuideSeen': true,
    ...prefs,
  });
  final p = await SharedPreferences.getInstance();
  engine ??= MockEngineClient(realtime: false);
  final locales = LocaleController(store: InMemoryLocaleStore('en'));
  await locales.load();
  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(p),
      privateAssetsProvider.overrideWithValue(PrivateAssets.none),
      engineBootProvider.overrideWithValue(EngineBoot(engine)),
      localeControllerProvider.overrideWith((ref) => locales),
      // 外部链接配置：同步读入，避免 rootBundle 异步加载让 golden 不稳定。
      appLinksProvider.overrideWith((ref) => Future.value(_links)),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const FxScope(tier: FxTier.lite, child: UltraPadsApp()),
    ),
  );
  await settle(t);
  return AppHarness(engine, container);
}

/// 有无限循环动画（loop pad、轮播）时不能用 pumpAndSettle。
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> shot(WidgetTester t, String name) async {
  await settle(t);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}
