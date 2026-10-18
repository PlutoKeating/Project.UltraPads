import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ultrapads/src/account/account_state.dart';
import 'package:ultrapads/src/account/auth_models.dart';
import 'package:ultrapads/src/account/token_store.dart';
import 'package:ultrapads/src/config/app_links.dart';
import 'package:ultrapads/src/features/catalog/catalog_models.dart';
import 'package:ultrapads/src/features/catalog/catalog_state.dart';
import 'package:ultrapads/src/state/engine_state.dart';
import 'package:ultrapads/src/state/settings_state.dart';
import 'package:up_engine/up_engine.dart';

import 'catalog_fixtures.dart';

AuthTokens _tokens() => AuthTokens(
  accessToken: 'tok',
  refreshToken: 'r',
  idToken: fakeJwt({'sub': 'u1', 'email': 'a@b.test'}),
  expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
);

Future<ProviderContainer> _make(
  FakeSite site, {
  bool signedIn = false,
  Map<String, Object> prefs = const {},
  MockEngineClient? engine,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  final dir = tempDir();
  final c = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(p),
      appLinksProvider.overrideWith(
        (ref) => Future.value(
          AppLinks(
            siteBase: Uri.parse('https://site.test'),
            idIssuer: Uri.parse('https://id.test/'),
          ),
        ),
      ),
      catalogHttpClientProvider.overrideWithValue(site.client()),
      catalogDownloadDirProvider.overrideWithValue(() async => dir),
      tokenStoreProvider.overrideWithValue(
        MemoryTokenStore(signedIn ? _tokens() : null),
      ),
      engineProvider.overrideWithValue(
        engine ?? MockEngineClient(realtime: false),
      ),
      ...overrides,
    ],
  );
  addTearDown(c.dispose);
  await c.read(appLinksProvider.future);
  c.read(accountProvider);
  await pumpEventQueue();
  return c;
}

void main() {
  tearDown(cleanTempDirs);

  group('list controller', () {
    test('loads the first page, then appends the next', () async {
      final site = FakeSite(sampleItems());
      final c = await _make(site);
      final ctrl = c.read(catalogListProvider.notifier);
      await ctrl.refresh();
      var s = c.read(catalogListProvider);
      expect(s.items.length, 2);
      expect(s.total, 3);
      expect(s.hasMore, isTrue);
      expect(s.loaded, isTrue);

      await ctrl.loadMore();
      s = c.read(catalogListProvider);
      expect(s.items.map((i) => i.id), [
        'synth-dusk-run',
        'album-river',
        'online-neon',
      ]);
      expect(s.hasMore, isFalse);
      // 没有更多时不再请求
      final n = site.requests.length;
      await ctrl.loadMore();
      expect(site.requests.length, n);
    });

    test('changing the query restarts from the first page', () async {
      final site = FakeSite(sampleItems());
      final c = await _make(site);
      final ctrl = c.read(catalogListProvider.notifier);
      await ctrl.refresh();
      await ctrl.setQuery(const CatalogQuery(licenses: {'CC-BY-SA-4.0'}));
      final s = c.read(catalogListProvider);
      expect(s.items.single.id, 'album-river');
      expect(s.total, 1);
      expect(s.query.licenses, {'CC-BY-SA-4.0'});
    });

    test('a failed first load keeps the error; refresh recovers', () async {
      final site = FakeSite(sampleItems())..failWith = 503;
      final c = await _make(site);
      final ctrl = c.read(catalogListProvider.notifier);
      await ctrl.refresh();
      expect(c.read(catalogListProvider).error?.status, 503);
      expect(c.read(catalogListProvider).loaded, isFalse);
      site.failWith = null;
      await ctrl.refresh();
      expect(c.read(catalogListProvider).error, isNull);
      expect(c.read(catalogListProvider).items, isNotEmpty);
    });
  });

  group('download', () {
    test(
      'verifies, imports through the engine and records attribution',
      () async {
        final site = FakeSite(sampleItems());
        final engine = MockEngineClient(realtime: false);
        final c = await _make(site, engine: engine);
        final item = sampleItems()[1];
        final progress = <double?>[];
        c.listen(catalogDownloadProvider, (_, s) => progress.add(s[item.id]));

        final kitIds = await c
            .read(catalogDownloadProvider.notifier)
            .download(item);
        expect(kitIds, ['imported:album-river']);
        expect(progress.first, 0);
        expect(progress.last, isNull); // 结束后条目从进行中移除
        expect(c.read(catalogDownloadProvider), isEmpty);

        final rec = c.read(catalogRecordsProvider)[item.id]!;
        expect(rec.kitNames, ['ALBUM-RIVER']);
        expect(
          downloadStatusOf(item, c.read(catalogRecordsProvider)),
          DownloadStatus.downloaded,
        );
        // 目录里内容变了（sha256 不同）→ 有更新
        final changed = fixtureItem(
          'album-river',
          title: 'River v2',
          license: 'CC-BY-SA-4.0',
        ).toJson()..['sha256'] = 'f' * 64;
        expect(
          downloadStatusOf(
            CatalogItem.fromJson(changed),
            c.read(catalogRecordsProvider),
          ),
          DownloadStatus.updateAvailable,
        );
        expect(
          c.read(catalogAttributionsProvider('ALBUM-RIVER')).single.id,
          'album-river',
        );
        expect(c.read(catalogAttributionsProvider('other')), isEmpty);
        // 下载的临时文件已清理
        final dir = await c.read(catalogDownloadDirProvider)();
        expect(dir.listSync(), isEmpty);
        // 下载计入最近使用
        expect(c.read(cloudStateProvider).recent.first.id, 'album-river');
      },
    );

    test('corrupt download: error, no record, no leftover file', () async {
      final site = FakeSite(sampleItems())..corruptDownloads = true;
      final c = await _make(site);
      final item = sampleItems().first;
      await expectLater(
        c.read(catalogDownloadProvider.notifier).download(item),
        throwsA(
          isA<CatalogException>().having(
            (e) => e.code,
            'code',
            'hash_mismatch',
          ),
        ),
      );
      expect(c.read(catalogRecordsProvider), isEmpty);
      expect(c.read(catalogDownloadProvider), isEmpty);
      expect((await c.read(catalogDownloadDirProvider)()).listSync(), isEmpty);
    });

    test('records persist across restarts', () async {
      final site = FakeSite(sampleItems());
      final c = await _make(site);
      await c
          .read(catalogDownloadProvider.notifier)
          .download(sampleItems().first);
      final saved = c.read(prefsProvider).getString('catalog.records');
      expect(saved, isNotNull);
      final c2 = await _make(site, prefs: {'catalog.records': saved!});
      expect(c2.read(catalogRecordsProvider).keys, ['synth-dusk-run']);
    });
  });

  group('cloud state (favorites / recent)', () {
    test(
      'signed out: toggles apply locally and queue; sign-in flushes them',
      () async {
        final site = FakeSite(sampleItems());
        final c = await _make(site);
        final cloud = c.read(cloudStateProvider.notifier);
        await cloud.toggleFavorite('album-river');
        await cloud.toggleFavorite('synth-dusk-run');
        await cloud.toggleFavorite('synth-dusk-run'); // 取消
        expect(c.read(cloudStateProvider).favorites, {'album-river'});
        expect(c.read(cloudStateProvider).pending, 2);
        expect(
          site.requests.where((r) => r.path.startsWith('/api/me')),
          isEmpty,
        );

        // 持久化：重启后待发队列还在
        final prefs = c.read(prefsProvider);
        final c2 = await _make(
          site,
          signedIn: true,
          prefs: {
            'catalog.favorites': prefs.getStringList('catalog.favorites')!,
            'catalog.pending': prefs.getString('catalog.pending')!,
          },
        );
        c2.read(cloudStateProvider);
        await pumpEventQueue(times: 50);
        expect(site.favorites, {'album-river'});
        expect(c2.read(cloudStateProvider).pending, 0);
        expect(c2.read(cloudStateProvider).favorites, {'album-river'});
        expect(site.requests.last.authorization, 'Bearer tok');
      },
    );

    test('sync merges server favorites with local ones', () async {
      final site = FakeSite(sampleItems())..favorites.add('online-neon');
      final c = await _make(
        site,
        signedIn: true,
        prefs: {
          'catalog.favorites': ['album-river'],
        },
      );
      await c.read(cloudStateProvider.notifier).sync();
      expect(c.read(cloudStateProvider).favorites, {
        'album-river',
        'online-neon',
      });
      // 本地独有的收藏补送到服务端
      expect(site.favorites, {'album-river', 'online-neon'});
    });

    test('a pending un-favorite wins over the stale server state', () async {
      final site = FakeSite(sampleItems())..favorites.add('album-river');
      final c = await _make(
        site,
        signedIn: true,
        prefs: {
          'catalog.favorites': ['album-river'],
        },
      );
      await pumpEventQueue(times: 50);
      await c.read(cloudStateProvider.notifier).toggleFavorite('album-river');
      await pumpEventQueue(times: 50);
      expect(c.read(cloudStateProvider).favorites, isEmpty);
      expect(site.favorites, isEmpty);
    });

    test(
      'network failure leaves changes queued; a 404 item is dropped',
      () async {
        final site = FakeSite(sampleItems());
        final c = await _make(site, signedIn: true);
        site.failWith = 503;
        final cloud = c.read(cloudStateProvider.notifier);
        await cloud.toggleFavorite('album-river');
        await pumpEventQueue(times: 50);
        expect(c.read(cloudStateProvider).pending, 1);
        expect(c.read(cloudStateProvider).favorites, {'album-river'});

        site.failWith = null;
        await cloud.toggleFavorite('ghost'); // 目录里没有 → 404 → 丢弃
        await cloud.flush();
        await pumpEventQueue(times: 50);
        expect(c.read(cloudStateProvider).pending, 0);
        expect(site.favorites, {'album-river'});
      },
    );

    test(
      'recent is capped and ordered newest first, merged with the server',
      () async {
        final site = FakeSite(sampleItems())
          ..recent.addAll(['online-neon', 'album-river']);
        final c = await _make(site, signedIn: true);
        final cloud = c.read(cloudStateProvider.notifier);
        await cloud.recordRecent('synth-dusk-run');
        await cloud.sync();
        final ids = c.read(cloudStateProvider).recent.map((e) => e.id).toList();
        expect(ids.first, 'synth-dusk-run');
        expect(ids, containsAll(['album-river', 'online-neon']));
        expect(site.recent, contains('synth-dusk-run'));
      },
    );
  });

  test('cancelling a download mid-stream deletes the partial file', () async {
    final site = FakeSite(sampleItems());
    final c = await _make(site);
    final item = sampleItems().first;
    final ctrl = c.read(catalogDownloadProvider.notifier);
    final f = ctrl.download(item);
    ctrl.cancel(item.id);
    await expectLater(f, throwsA(isA<CatalogCancelled>()));
    expect(c.read(catalogDownloadProvider), isEmpty);
    expect(c.read(catalogRecordsProvider), isEmpty);
    expect(Directory.systemTemp.existsSync(), isTrue);
  });
}
