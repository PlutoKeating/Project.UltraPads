import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultrapads/src/account/auth_models.dart';
import 'package:ultrapads/src/account/token_store.dart';
import 'package:ultrapads/src/features/catalog/catalog_client.dart';
import 'package:ultrapads/src/features/catalog/catalog_models.dart';
import 'package:ultrapads/src/routing/router.dart';
import 'package:ultrapads/src/routing/routes.dart';
import 'package:ultrapads/src/ugc/ugc_client.dart';
import 'package:ultrapads/src/ugc/ugc_models.dart';
import 'package:ultrapads/src/ugc/ugc_state.dart';

import 'catalog_fixtures.dart';
import 'harness.dart';

/// UpText 会按排版角色改大小写，所以按忽略大小写匹配文字。
Finder ft(String text) => find.byWidgetPredicate(
  (w) => w is Text && w.data?.toLowerCase() == text.toLowerCase(),
);

Finder ftc(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data?.toLowerCase().contains(text.toLowerCase()) ?? false),
);

const _ugcId = 'ugc-00000000000000aa';

CatalogItem _ugcItem() => fixtureItem(
  _ugcId,
  title: 'Garage Jam',
  artist: 'Some Band',
  license: 'CC-BY-4.0',
  origin: 'ugc',
  genres: ['rock'],
);

MemoryTokenStore _signedIn() => MemoryTokenStore(
  AuthTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    idToken: fakeJwt({'sub': 'user-1', 'email': 'pluto@example.test'}),
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  ),
);

Map<String, Object?> _upload(
  String id,
  String title, {
  String visibility = 'private',
  String moderation = 'active',
  String status = 'published',
  String license = 'CC-BY-4.0',
}) => {
  'id': id,
  'title': title,
  'artist': 'Me',
  'credit': 'Me',
  'attribution': 'Me',
  'origin': 'ugc',
  'license': license,
  'source_declaration': 'own',
  'visibility': visibility,
  'moderation': moderation,
  'status': status,
  'size': status == 'published' ? 2048 : null,
  'sha256': null,
};

/// 下载 / 上传会走真实 IO，fake-async 下要放到 runAsync 里等。
Future<void> settleIo(WidgetTester t) async {
  for (var i = 0; i < 40; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 50));
  }
  await settle(t);
}

const _fileText = 'upkit-bytes-for-the-upload-test';

void main() {
  tearDown(cleanTempDirs);

  group('form validation', () {
    UploadDraft draft({
      String title = 'Song',
      String credit = 'Me',
      String license = 'CC-BY-4.0',
      String url = '',
    }) => UploadDraft(
      title: title,
      credit: credit,
      license: license,
      declaration: SourceDeclaration.own,
      sourceUrl: url,
    );

    test('a complete, confirmed form is valid', () {
      expect(validateUpload(draft(), confirmed: true).any, isFalse);
      expect(
        validateUpload(
          draft(url: 'https://example.test/x'),
          confirmed: true,
        ).any,
        isFalse,
      );
    });

    test('every required field is checked', () {
      expect(validateUpload(draft(title: '  '), confirmed: true).title, isTrue);
      expect(
        validateUpload(draft(title: 'x' * 121), confirmed: true).title,
        isTrue,
      );
      expect(validateUpload(draft(credit: ''), confirmed: true).credit, isTrue);
      expect(
        validateUpload(draft(credit: 'x' * 501), confirmed: true).credit,
        isTrue,
      );
      expect(
        validateUpload(draft(license: 'GPL-3.0'), confirmed: true).license,
        isTrue,
      );
      expect(
        validateUpload(draft(url: 'ftp://x.test'), confirmed: true).sourceUrl,
        isTrue,
      );
      expect(
        validateUpload(draft(url: 'not a url'), confirmed: true).sourceUrl,
        isTrue,
      );
      expect(validateUpload(draft(), confirmed: false).confirmed, isTrue);
    });

    test(
      'draft json omits empty optional fields and keeps the declaration',
      () {
        final j = draft().toJson();
        expect(j['source_declaration'], 'own');
        expect(j.containsKey('source_url'), isFalse);
        expect(j.containsKey('description'), isFalse);
      },
    );
  });

  group('client', () {
    test(
      'uploadFile refuses a file over the limit without a request',
      () async {
        final site = FakeSite(sampleItems());
        final api = CatalogClient(
          base: Uri.parse('https://site.test'),
          client: site.client(),
          token: () async => 'tok',
        );
        final dir = tempDir();
        final big = File('${dir.path}/big.upkit');
        final raf = await big.open(mode: FileMode.write);
        await raf.truncate(maxUploadBytes + 1); // 稀疏文件，不占磁盘
        await raf.close();
        await expectLater(
          UgcClient(api).uploadFile('ugc-1', big),
          throwsA(
            isA<CatalogException>().having((e) => e.code, 'code', 'too_large'),
          ),
        );
        expect(site.requests, isEmpty);
      },
    );

    test(
      'uploadFile that is already cancelled throws CatalogCancelled',
      () async {
        final site = FakeSite(sampleItems());
        site.uploads['ugc-1'] = _upload('ugc-1', 'X', status: 'draft');
        final api = CatalogClient(
          base: Uri.parse('https://site.test'),
          client: site.client(),
          token: () async => 'tok',
        );
        final dir = tempDir();
        final f = File('${dir.path}/a.upkit')..writeAsStringSync(_fileText);
        final cancel = UploadCancel()..cancel();
        await expectLater(
          UgcClient(api).uploadFile('ugc-1', f, cancel: cancel),
          throwsA(isA<CatalogCancelled>()),
        );
      },
    );

    test('uploadFile sends length, digest and bearer token', () async {
      final site = FakeSite(sampleItems());
      site.uploads['ugc-1'] = _upload('ugc-1', 'X', status: 'draft');
      final api = CatalogClient(
        base: Uri.parse('https://site.test'),
        client: site.client(),
        token: () async => 'tok',
      );
      final dir = tempDir();
      final f = File('${dir.path}/a.upkit')..writeAsStringSync(_fileText);
      final digest = await sha256OfFile(f);
      final progress = <int>[];
      final item = await UgcClient(api).uploadFile(
        'ugc-1',
        f,
        sha256Hex: digest,
        onProgress: (sent, total) => progress.add(sent),
      );
      expect(item.hasFile, isTrue);
      final put = site.requests.single;
      expect(put.method, 'PUT');
      expect(put.path, '/api/me/uploads/ugc-1/file');
      expect(put.contentLength, _fileText.length);
      expect(put.headers['X-Sha256'], digest);
      expect(put.authorization, 'Bearer tok');
      expect(put.body, _fileText);
      expect(progress.last, _fileText.length);
    });
  });

  group('community in the catalog', () {
    Future<AppHarness> openCatalog(
      WidgetTester t, {
      bool signedIn = false,
    }) async {
      final h = await pumpApp(
        t,
        site: FakeSite([...sampleItems(), _ugcItem()], pageSize: 10),
        tokenStore: signedIn ? _signedIn() : null,
        size: const Size(414, 1000),
      );
      h.container.read(routerProvider).push(Routes.kits);
      await settle(t);
      await t.tap(find.byIcon(Icons.cloud_download_rounded));
      await settle(t);
      return h;
    }

    testWidgets('the source filter narrows the list to community uploads', (
      t,
    ) async {
      final h = await openCatalog(t);
      expect(ft('Garage Jam'), findsWidgets);
      expect(ft('Dusk Run'), findsWidgets);
      // 筛选条横向滚动：来源在最后
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('catalog-origin-chip')),
        100,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.tap(find.byKey(const ValueKey('catalog-origin-chip')));
      await settle(t);
      expect(ft('All sources'), findsOneWidget);
      await t.tap(ft('Community'));
      await settle(t);
      expect(ft('Garage Jam'), findsWidgets);
      expect(ft('Dusk Run'), findsNothing);
      expect(
        h.site.requests.any((r) => r.uri.queryParameters['origin'] == 'ugc'),
        isTrue,
      );
    });

    testWidgets('a community item shows its notice; reporting needs sign-in', (
      t,
    ) async {
      final h = await openCatalog(t);
      h.container.read(routerProvider).push(Routes.catalogItem(_ugcId));
      await settle(t);
      expect(ft('Community'), findsWidgets);
      expect(
        ftc('Credit and licence are declared by the uploader'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('catalog-report')));
      await settle(t);
      expect(ft('Sign in to report a kit.'), findsOneWidget);
      expect(h.site.reports, isEmpty);
    });

    testWidgets('reporting sends the reason and note', (t) async {
      final h = await openCatalog(t, signedIn: true);
      h.container.read(routerProvider).push(Routes.catalogItem(_ugcId));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('catalog-report')));
      await settle(t);
      expect(ft('Report this kit'), findsOneWidget);
      await t.tap(ft('Inappropriate content'));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'loud and rude');
      await t.tap(ft('Send report'));
      await settle(t);
      expect(h.site.reports.single, {
        'id': _ugcId,
        'reason': 'inappropriate',
        'note': 'loud and rude',
      });
      expect(ft('Report received. Thank you.'), findsOneWidget);
    });

    testWidgets('your own upload has no report button', (t) async {
      final h = await openCatalog(t, signedIn: true);
      h.site.uploads[_ugcId] = _upload(
        _ugcId,
        'Garage Jam',
        visibility: 'public',
      );
      await h.container.read(myUploadsProvider.notifier).refresh();
      h.container.read(routerProvider).push(Routes.catalogItem(_ugcId));
      await settle(t);
      expect(ft('Community'), findsWidgets);
      expect(find.byKey(const ValueKey('catalog-report')), findsNothing);
    });

    testWidgets('a report for a kit that is no longer public says so', (
      t,
    ) async {
      final h = await openCatalog(t, signedIn: true);
      h.container.read(routerProvider).push(Routes.catalogItem(_ugcId));
      await settle(t);
      h.site.items.removeWhere((i) => i.id == _ugcId);
      await t.tap(find.byKey(const ValueKey('catalog-report')));
      await settle(t);
      await t.tap(ft('Send report'));
      await settle(t);
      expect(ft('This kit is no longer public.'), findsOneWidget);
    });
  });

  group('my uploads', () {
    testWidgets('signed out: asks to sign in, then shows the empty state', (
      t,
    ) async {
      final h = await pumpApp(t);
      h.container.read(routerProvider).push(Routes.uploads);
      await settle(t);
      expect(ft('Sign in to upload and manage your kits.'), findsOneWidget);
      expect(find.byKey(const ValueKey('uploads-new')), findsNothing);
      await t.tap(find.byKey(const ValueKey('uploads-sign-in')));
      await settle(t);
      expect(h.authFlow.calls, 1);
      expect(
        ft('No uploads yet. New uploads are private by default.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('uploads-new')), findsOneWidget);
    });

    testWidgets(
      'lists every state and makes an upload public after confirming',
      (t) async {
        final site = FakeSite(sampleItems());
        site.uploads
          ..['ugc-0000000000000001'] = _upload(
            'ugc-0000000000000001',
            'Draft Kit',
            status: 'draft',
          )
          ..['ugc-0000000000000002'] = _upload(
            'ugc-0000000000000002',
            'Private Kit',
          )
          ..['ugc-0000000000000003'] = _upload(
            'ugc-0000000000000003',
            'Shared Kit',
            visibility: 'public',
            license: 'CC-BY-NC-4.0',
          )
          ..['ugc-0000000000000004'] = _upload(
            'ugc-0000000000000004',
            'Gone Kit',
            moderation: 'taken_down',
          )
          ..['ugc-0000000000000005'] = _upload(
            'ugc-0000000000000005',
            'Flagged Kit',
            visibility: 'public',
            moderation: 'hidden',
          );
        final h = await pumpApp(
          t,
          site: site,
          tokenStore: _signedIn(),
          size: const Size(414, 1000),
        );
        h.container.read(routerProvider).push(Routes.uploads);
        await settle(t);
        expect(ftc('No file yet'), findsOneWidget);
        expect(ftc('Private · BY'), findsOneWidget);
        expect(ftc('Public · BY-NC'), findsOneWidget);
        expect(ftc('Taken down'), findsWidgets);
        expect(ftc('You can only delete it'), findsOneWidget);
        expect(ftc('Hidden (under review)'), findsOneWidget);
      await shot(t, 'ugc_my_uploads');

        await t.tap(ft('Private Kit'));
        await settle(t);
        await t.tap(find.byKey(const ValueKey('upload-toggle-public')));
        await settle(t);
        expect(ft('Share this kit publicly?'), findsOneWidget);
        // 取消：不发请求
        await t.tap(ft('Cancel'));
        await settle(t);
        expect(site.requests.where((r) => r.method == 'PATCH'), isEmpty);

        await t.tap(ft('Private Kit'));
        await settle(t);
        await t.tap(find.byKey(const ValueKey('upload-toggle-public')));
        await settle(t);
        await t.tap(ft('Make public').last);
        await settle(t);
        final patch = site.requests.singleWhere((r) => r.method == 'PATCH');
        expect(jsonDecode(patch.body), {'visibility': 'public'});
        expect(site.uploads['ugc-0000000000000002']!['visibility'], 'public');
        expect(ft('Now public'), findsOneWidget);
      },
    );

    testWidgets('delete asks first, then removes the upload', (t) async {
      final site = FakeSite(sampleItems());
      site.uploads['ugc-0000000000000001'] = _upload(
        'ugc-0000000000000001',
        'Old Kit',
      );
      final h = await pumpApp(t, site: site, tokenStore: _signedIn());
      h.container.read(routerProvider).push(Routes.uploads);
      await settle(t);
      await t.tap(ft('Old Kit'));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('upload-delete')));
      await settle(t);
      expect(ft('Delete this upload?'), findsOneWidget);
      await t.tap(ft('Delete').last);
      await settle(t);
      expect(site.uploads, isEmpty);
      expect(ft('Old Kit'), findsNothing);
      expect(ft('Deleted'), findsOneWidget);
    });

    testWidgets('a taken-down upload can only be deleted', (t) async {
      final site = FakeSite(sampleItems());
      site.uploads['ugc-0000000000000001'] = _upload(
        'ugc-0000000000000001',
        'Gone Kit',
        moderation: 'taken_down',
      );
      final h = await pumpApp(t, site: site, tokenStore: _signedIn());
      h.container.read(routerProvider).push(Routes.uploads);
      await settle(t);
      await t.tap(ft('Gone Kit'));
      await settle(t);
      expect(find.byKey(const ValueKey('upload-toggle-public')), findsNothing);
      expect(find.byKey(const ValueKey('upload-restore')), findsNothing);
      expect(find.byKey(const ValueKey('upload-delete')), findsOneWidget);
    });

    testWidgets('settings links to my uploads when signed in', (t) async {
      final h = await pumpApp(t, tokenStore: _signedIn());
      h.container.read(routerProvider).push(Routes.settings);
      await settle(t);
      final row = find.byKey(const ValueKey('account-my-uploads'));
      await t.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(row);
      await settle(t);
      expect(find.byKey(const ValueKey('uploads-new')), findsOneWidget);
    });
  });

  group('upload flow', () {
    Future<AppHarness> openForm(WidgetTester t, FakeSite site) async {
      final dir = tempDir();
      final h = await pumpApp(
        t,
        site: site,
        tokenStore: _signedIn(),
        size: const Size(414, 1400),
        overrides: [
          ugcExportProvider.overrideWithValue((kitId) async {
            final f = File('${dir.path}/export.upkit');
            await f.writeAsString(_fileText);
            return f;
          }),
        ],
      );
      h.container.read(routerProvider).push(Routes.uploads);
      await settle(t);
      await t.tap(find.byKey(const ValueKey('uploads-new')));
      await settle(t);
      await t.tap(ft('SUNSET'));
      await settle(t);
      return h;
    }

    testWidgets('validates, then creates the entry and streams the file', (
      t,
    ) async {
      final site = FakeSite(sampleItems());
      await openForm(t, site);
      expect(ft('Upload a kit'), findsWidgets);
      // 标题已按 Kit 名预填；署名为空、没确认 → 不发请求
      await t.tap(find.byKey(const ValueKey('upload-submit')));
      await settle(t);
      expect(ft('Enter a credit (up to 500 characters)'), findsOneWidget);
      expect(
        ft('Please confirm you have the right to share it'),
        findsOneWidget,
      );
      expect(site.requests.where((r) => r.method == 'POST'), isEmpty);

      await t.enterText(find.byKey(const ValueKey('field-credit')), 'Pluto');
      await t.tap(find.byKey(const ValueKey('field-confirm')));
      await t.pump();
      await t.ensureVisible(find.byKey(const ValueKey('upload-submit')));
      await t.tap(find.byKey(const ValueKey('upload-submit')));
      await settleIo(t);

      final post = site.requests.singleWhere((r) => r.method == 'POST');
      final body = jsonDecode(post.body) as Map<String, Object?>;
      expect(body['title'], 'SUNSET');
      expect(body['credit'], 'Pluto');
      expect(body['license'], 'CC-BY-4.0');
      expect(body['source_declaration'], 'own');
      final put = site.requests.singleWhere((r) => r.method == 'PUT');
      expect(put.contentLength, _fileText.length);
      expect(
        put.headers['X-Sha256'],
        sha256.convert(utf8.encode(_fileText)).toString(),
      );
      final stored = site.uploads.values.single;
      expect(stored['visibility'], 'private');
      expect(stored['status'], 'published');
      expect(ft('Uploaded. It’s private for now.'), findsOneWidget);
      expect(find.byKey(const ValueKey('upload-finish')), findsOneWidget);
    });

    testWidgets('the licensed declaration and licence choice are sent', (
      t,
    ) async {
      final site = FakeSite(sampleItems());
      await openForm(t, site);
      await t.enterText(find.byKey(const ValueKey('field-credit')), 'Someone');
      await t.tap(find.byKey(const ValueKey('declaration-licensed')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('field-license')));
      await settle(t);
      await t.tap(ft('BY-SA').first);
      await settle(t);
      await t.tap(find.byKey(const ValueKey('field-confirm')));
      await t.pump();
      await t.ensureVisible(find.byKey(const ValueKey('upload-submit')));
      await t.tap(find.byKey(const ValueKey('upload-submit')));
      await settleIo(t);
      final body =
          jsonDecode(site.requests.singleWhere((r) => r.method == 'POST').body)
              as Map<String, Object?>;
      expect(body['source_declaration'], 'licensed');
      expect((body['license']! as String).startsWith('CC-BY-SA'), isTrue);
    });

    testWidgets('a rejected file shows a friendly error and leaves no entry', (
      t,
    ) async {
      final site = FakeSite(sampleItems())..failUploadFileWith = 422;
      await openForm(t, site);
      await t.enterText(find.byKey(const ValueKey('field-credit')), 'Pluto');
      await t.tap(find.byKey(const ValueKey('field-confirm')));
      await t.pump();
      await t.ensureVisible(find.byKey(const ValueKey('upload-submit')));
      await t.tap(find.byKey(const ValueKey('upload-submit')));
      await settleIo(t);
      expect(
        ft(
          'The server rejected the file as invalid or damaged in transit. Try again.',
        ),
        findsOneWidget,
      );
      expect(site.uploads, isEmpty);
      // 可以再试一次
      expect(find.byKey(const ValueKey('upload-submit')), findsOneWidget);
    });

    testWidgets('the account quota is reported', (t) async {
      final site = FakeSite(sampleItems())..uploadQuota = 0;
      await openForm(t, site);
      await t.enterText(find.byKey(const ValueKey('field-credit')), 'Pluto');
      await t.tap(find.byKey(const ValueKey('field-confirm')));
      await t.pump();
      await t.ensureVisible(find.byKey(const ValueKey('upload-submit')));
      await t.tap(find.byKey(const ValueKey('upload-submit')));
      await settleIo(t);
      expect(
        ft('You’ve reached the limit of 50 uploads. Delete some first.'),
        findsOneWidget,
      );
      expect(site.requests.where((r) => r.method == 'PUT'), isEmpty);
    });
  });
}
