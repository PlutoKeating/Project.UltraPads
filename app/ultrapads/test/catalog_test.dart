import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultrapads/src/account/account_state.dart';
import 'package:ultrapads/src/features/catalog/catalog_state.dart';
import 'package:ultrapads/src/features/catalog/catalog_tab.dart';
import 'package:ultrapads/src/features/recorder/save_recording_sheet.dart';
import 'package:ultrapads/src/routing/router.dart';
import 'package:ultrapads/src/routing/routes.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_ui/up_ui.dart';

import 'catalog_fixtures.dart';
import 'harness.dart';

/// UpText 会按排版角色改大小写（标题大写等），所以按忽略大小写匹配文字。
Finder ft(String text) => find.byWidgetPredicate(
  (w) => w is Text && w.data?.toLowerCase() == text.toLowerCase(),
);

Finder ftc(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data?.toLowerCase().contains(text.toLowerCase()) ?? false),
);

/// 下载会真的写临时文件（真实 IO），fake-async 下要放到 runAsync 里等。
Future<void> settleIo(WidgetTester t) async {
  // 真实 IO 与 fake-async 的微任务要交替推进几轮
  for (var i = 0; i < 8; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await t.pump(const Duration(milliseconds: 50));
  }
  await settle(t);
}

Future<AppHarness> _openCatalog(
  WidgetTester t, {
  FakeSite? site,
  FakeAuthFlow? authFlow,
  Size size = const Size(414, 1000),
}) async {
  // 比手机高一些：列表是懒构建的，要让几张卡片同时可见。
  final h = await pumpApp(t, site: site, authFlow: authFlow, size: size);
  h.container.read(routerProvider).push(Routes.kits);
  await settle(t);
  await t.tap(find.byIcon(Icons.cloud_download_rounded));
  await settle(t);
  return h;
}

void main() {
  tearDown(cleanTempDirs);

  testWidgets('catalog tab: lists songs with licence badges, golden', (
    t,
  ) async {
    final h = await _openCatalog(t);
    // 第一页（2 条）填不满视口，自动接着加载第二页
    expect(find.byType(CatalogItemCard), findsNWidgets(3));
    expect(ft('Dusk Run'), findsWidgets);
    expect(ft('River'), findsWidgets);
    expect(ft('CC0'), findsOneWidget);
    expect(ft('BY-SA'), findsOneWidget);
    expect(ft('BY-NC'), findsOneWidget);
    expect(ft('3 songs'), findsOneWidget);
    expect(h.site.requests.where((r) => r.path == '/api/catalog').length, 2);
    await shot(t, 'library_catalog');
  });

  testWidgets('catalog tab is not loaded until it is opened', (t) async {
    final h = await pumpApp(t);
    h.container.read(routerProvider).push(Routes.kits);
    await settle(t);
    expect(h.site.requests.where((r) => r.path == '/api/catalog'), isEmpty);
  });

  testWidgets('scrolling near the end loads the next page', (t) async {
    final site = FakeSite([
      for (var i = 0; i < 60; i++)
        fixtureItem('song-${i.toString().padLeft(2, '0')}', title: 'Song $i'),
    ], pageSize: 10);
    await _openCatalog(t, site: site, size: phone);
    int pages() => site.requests.where((r) => r.path == '/api/catalog').length;
    final before = pages();
    expect(before, lessThan(6)); // 60 条不会一次全载入
    for (var i = 0; i < 8; i++) {
      await t.drag(find.byType(ListView).last, const Offset(0, -1500));
      await settle(t);
    }
    expect(pages(), greaterThan(before));
    expect(
      site.requests
          .where((r) => r.path == '/api/catalog')
          .last
          .uri
          .queryParameters['cursor'],
      isNotNull,
    );
  });

  testWidgets('search is debounced and sent as q', (t) async {
    final h = await _openCatalog(t);
    await t.enterText(find.byType(TextField).last, 'riv');
    await t.pump(const Duration(milliseconds: 100));
    expect(
      h.site.requests.where((r) => r.uri.queryParameters['q'] == 'riv'),
      isEmpty,
    );
    await t.pump(const Duration(milliseconds: 400));
    await settle(t);
    expect(ft('River'), findsWidgets);
    expect(ft('Dusk Run'), findsNothing);
  });

  testWidgets('licence filter sheet narrows the list; clear restores it', (
    t,
  ) async {
    final h = await _openCatalog(t);
    await t.tap(ft('License'));
    await settle(t);
    // 面板里列出服务端 facets 的许可证，带说明
    expect(ftc('Share-alike'), findsOneWidget);
    await t.tap(ft('BY-SA').last);
    await settle(t);
    await t.tap(ft('Done'));
    await settle(t);
    expect(h.site.requests.last.uri.queryParameters['license'], 'CC-BY-SA-4.0');
    expect(ft('River'), findsWidgets);
    expect(ft('Dusk Run'), findsNothing);
    await t.tap(ft('Clear filters'));
    await settle(t);
    expect(ft('Dusk Run'), findsWidgets);
  });

  testWidgets('empty result and offline error with retry', (t) async {
    final site = FakeSite(sampleItems());
    final h = await _openCatalog(t, site: site);
    await t.enterText(find.byType(TextField).last, 'zzz');
    await t.pump(const Duration(milliseconds: 500));
    await settle(t);
    expect(ft('No songs match these filters.'), findsOneWidget);

    site.failWith = 503;
    await t.enterText(find.byType(TextField).last, 'q');
    await t.pump(const Duration(milliseconds: 500));
    await settle(t);
    expect(ft('Couldn’t reach the official catalog.'), findsOneWidget);
    site.failWith = null;
    await t.tap(ft('Retry'));
    await settle(t);
    expect(find.byType(CatalogItemCard), findsNothing); // 'q' 没有匹配
    expect(h.site.requests.last.uri.queryParameters['q'], 'q');
  });

  testWidgets('detail → download → play loads the imported kit', (t) async {
    final h = await _openCatalog(t);
    await t.tap(find.byType(CatalogItemCard).at(0));
    await settle(t);
    expect(ft('Dusk Run'), findsWidgets);
    expect(ftc('CC0: public domain'), findsOneWidget);
    expect(ftc('“Dusk Run” by UltraPads'), findsOneWidget);
    expect(ft('Download'), findsOneWidget);
    await shot(t, 'catalog_detail');

    await t.tap(ft('Download'));
    await settleIo(t);
    expect(ft('Play'), findsOneWidget);
    expect(ft('Dusk Run is ready to play'), findsOneWidget);
    expect(h.container.read(catalogRecordsProvider).keys, ['synth-dusk-run']);

    // 提示条盖在按钮上，等它消失
    await t.pump(const Duration(seconds: 5));
    await settle(t);
    await t.tap(ft('Play'));
    await settle(t);
    expect(h.engine.snapshot().kit!.id, 'imported:synth-dusk-run');
    expect(find.byType(PadGrid), findsOneWidget);
  });

  testWidgets(
    'download failure shows a message and keeps the Download button',
    (t) async {
      final site = FakeSite(sampleItems())..corruptDownloads = true;
      await _openCatalog(t, site: site);
      await t.tap(find.byType(CatalogItemCard).at(0));
      await settle(t);
      await t.tap(ft('Download'));
      await settleIo(t);
      expect(
        ft('The file didn’t pass verification. Try again.'),
        findsOneWidget,
      );
      expect(ft('Download'), findsOneWidget);
    },
  );

  testWidgets('restricted licences explain themselves on the detail page', (
    t,
  ) async {
    await _openCatalog(t);
    await t.tap(find.byType(CatalogItemCard).at(1));
    await settle(t);
    expect(ftc('Attribution: credit the creator'), findsOneWidget);
    expect(ftc('Share-alike'), findsOneWidget);
    expect(ftc('Non-commercial'), findsNothing);
  });

  testWidgets('favourite while signed out queues; signing in syncs it', (
    t,
  ) async {
    final h = await _openCatalog(t);
    await t.tap(find.byIcon(Icons.favorite_border_rounded).first);
    await settle(t);
    expect(h.container.read(cloudStateProvider).favorites, {'synth-dusk-run'});
    expect(h.site.favorites, isEmpty);
    expect(h.container.read(cloudStateProvider).pending, 1);

    await h.container.read(accountProvider.notifier).signIn();
    await settle(t);
    expect(h.site.favorites, {'synth-dusk-run'});
    expect(h.container.read(cloudStateProvider).pending, 0);

    // 收藏视图
    await t.tap(ft('Favorites'));
    await settle(t);
    expect(ft('Dusk Run'), findsWidgets);
    expect(ft('River'), findsNothing);
  });

  testWidgets('settings: sign in with the account, then sign out', (t) async {
    final h = await pumpApp(t);
    h.container.read(routerProvider).push(Routes.settings);
    await settle(t);
    final signIn = find.byKey(const ValueKey('account-sign-in'));
    await t.scrollUntilVisible(
      signIn,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      ft('Keep favorites and recently played in sync across your devices.'),
      findsOneWidget,
    );
    await t.tap(find.descendant(of: signIn, matching: find.byType(UpButton)));
    await settle(t);
    expect(h.authFlow.calls, 1);
    expect(h.authFlow.page?.title, 'Signed in');
    expect(ft('Signed in as pluto@example.test'), findsOneWidget);
    await t.tap(ft('Sign out'));
    await settle(t);
    expect(find.byKey(const ValueKey('account-sign-in')), findsOneWidget);
  });

  testWidgets('settings: a failed sign-in is reported', (t) async {
    final h = await pumpApp(t, authFlow: FakeAuthFlow(Exception('x')));
    h.container.read(routerProvider).push(Routes.settings);
    await settle(t);
    final signIn = find.byKey(const ValueKey('account-sign-in'));
    await t.scrollUntilVisible(
      signIn,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.descendant(of: signIn, matching: find.byType(UpButton)));
    await settle(t);
    expect(ft('Sign-in didn’t complete. Try again.'), findsOneWidget);
  });

  testWidgets('recording a downloaded CC BY-SA kit shows the credits notice', (
    t,
  ) async {
    final h = await _openCatalog(t);
    await t.runAsync(
      () => h.container
          .read(catalogDownloadProvider.notifier)
          .download(sampleItems()[1]),
    );
    unawaited(h.engine.libraryLoadKit('imported:album-river'));
    await settle(t);
    h.engine.send(const StartRecordingCmd());
    h.engine.advance(const Duration(seconds: 2));
    h.engine.send(const StopRecordingCmd());
    await settle(t);
    expect(find.byType(SaveRecordingSheet), findsOneWidget);
    expect(ft('This recording uses licensed material'), findsOneWidget);
    expect(ftc('“River” by Tom McKenzie'), findsOneWidget);
    expect(ftc('Share your work under the same license.'), findsOneWidget);
    expect(ftc('Non-commercial use only.'), findsNothing);
  });

  testWidgets('no credits notice for CC0 material', (t) async {
    final h = await _openCatalog(t);
    await t.runAsync(
      () => h.container
          .read(catalogDownloadProvider.notifier)
          .download(sampleItems().first),
    );
    unawaited(h.engine.libraryLoadKit('imported:synth-dusk-run'));
    await settle(t);
    h.engine.send(const StartRecordingCmd());
    h.engine.advance(const Duration(seconds: 2));
    h.engine.send(const StopRecordingCmd());
    await settle(t);
    expect(find.byType(SaveRecordingSheet), findsOneWidget);
    expect(ft('This recording uses licensed material'), findsNothing);
  });
}
