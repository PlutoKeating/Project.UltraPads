import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ultrapads/src/features/catalog/catalog_client.dart';
import 'package:ultrapads/src/features/catalog/catalog_models.dart';

import 'catalog_fixtures.dart';

void main() {
  tearDown(cleanTempDirs);

  final a = fixtureItem('synth-dusk-run');
  final b = fixtureItem(
    'album-river',
    title: 'River',
    license: 'CC-BY-SA-4.0',
    bpm: 96,
    genres: ['rock'],
  );
  final c = fixtureItem(
    'online-neon',
    title: 'Neon',
    license: 'CC-BY-NC-4.0',
    bpm: 140,
    genres: ['edm'],
  );

  CatalogClient clientFor(FakeSite site, {String? token}) => CatalogClient(
    base: Uri.parse('https://site.test'),
    client: site.client(),
    token: () async => token,
  );

  test(
    'list: pagination, filters and sort go through as query params',
    () async {
      final site = FakeSite([a, b, c]);
      final client = clientFor(site);
      final first = await client.list(const CatalogQuery());
      expect(first.items.map((i) => i.id), ['synth-dusk-run', 'album-river']);
      expect(first.nextCursor, '2');
      expect(first.total, 3);

      final second = await client.list(
        const CatalogQuery(),
        cursor: first.nextCursor,
      );
      expect(second.items.single.id, 'online-neon');
      expect(second.nextCursor, isNull);

      final filtered = await client.list(
        const CatalogQuery(
          text: 'ri',
          licenses: {'CC-BY-SA-4.0', 'CC0-1.0'},
          genre: 'rock',
          bpmMin: 90,
          bpmMax: 110,
          sort: CatalogSort.bpm,
        ),
      );
      expect(filtered.items.single.id, 'album-river');
      final q = site.requests.last.uri.queryParameters;
      expect(q['q'], 'ri');
      expect(q['license'], 'CC-BY-SA-4.0,CC0-1.0');
      expect(q['genre'], 'rock');
      expect(q['bpm_min'], '90');
      expect(q['bpm_max'], '110');
      expect(q['sort'], 'bpm');
    },
  );

  test('item parses licence flags and 404 maps to not_found', () async {
    final client = clientFor(FakeSite([a, b]));
    final item = await client.item('album-river');
    expect(item.license.badge, 'BY-SA');
    expect(item.license.shareAlike, isTrue);
    expect(item.license.nonCommercial, isFalse);
    expect(item.license.needsAttribution, isTrue);
    expect(
      () => client.item('nope'),
      throwsA(
        isA<CatalogException>()
            .having((e) => e.code, 'code', 'not_found')
            .having((e) => e.notFound, 'notFound', isTrue),
      ),
    );
  });

  test('licence helper covers CC0, PD, NC and SA', () {
    expect(LicenseInfo.of('CC0-1.0').badge, 'CC0');
    expect(LicenseInfo.of('CC0-1.0').needsAttribution, isFalse);
    expect(LicenseInfo.of('PD').needsAttribution, isFalse);
    expect(LicenseInfo.of('CC-BY-4.0').badge, 'BY');
    final nc = LicenseInfo.of('CC-BY-NC-SA-4.0');
    expect(nc.badge, 'BY-NC-SA');
    expect(nc.nonCommercial && nc.shareAlike, isTrue);
  });

  test('facets', () async {
    final f = await clientFor(FakeSite([a, b, c])).facets();
    expect(
      f.licenses.map((e) => e.id),
      containsAll(['CC0-1.0', 'CC-BY-SA-4.0']),
    );
    expect(f.genres.map((e) => e.id), containsAll(['house', 'rock', 'edm']));
  });

  test('network failure maps to CatalogException(network)', () async {
    final client = CatalogClient(
      base: Uri.parse('https://site.test'),
      client: MockClient((_) async => throw const SocketException('down')),
    );
    expect(
      () => client.list(const CatalogQuery()),
      throwsA(
        isA<CatalogException>().having((e) => e.isNetwork, 'isNetwork', isTrue),
      ),
    );
  });

  test('server error body is surfaced as code + status', () async {
    final site = FakeSite([a])..failWith = 500;
    expect(
      () => clientFor(site).list(const CatalogQuery()),
      throwsA(
        isA<CatalogException>()
            .having((e) => e.code, 'code', 'down')
            .having((e) => e.status, 'status', 500),
      ),
    );
  });

  group('download', () {
    test(
      'streams to disk, reports progress, verifies sha256, sends token',
      () async {
        final site = FakeSite([a]);
        final client = clientFor(site, token: 'tok');
        final dest = File('${tempDir().path}/x.upkit');
        final seen = <int>[];
        await client.download(
          a,
          dest,
          onProgress: (got, total) => seen.add(got),
        );
        expect(dest.readAsBytesSync(), fixtureFile(a.id));
        expect(seen.last, a.size);
        expect(seen.length, greaterThan(1));
        expect(site.requests.last.authorization, 'Bearer tok');
      },
    );

    test('hash mismatch deletes the file and throws', () async {
      final site = FakeSite([a])..corruptDownloads = true;
      final dest = File('${tempDir().path}/x.upkit');
      await expectLater(
        clientFor(site).download(a, dest),
        throwsA(
          isA<CatalogException>().having(
            (e) => e.code,
            'code',
            'hash_mismatch',
          ),
        ),
      );
      expect(dest.existsSync(), isFalse);
    });

    test(
      'cancel before start throws CatalogCancelled and leaves no file',
      () async {
        final site = FakeSite([a]);
        final cancel = DownloadCancel()..cancel();
        final dest = File('${tempDir().path}/x.upkit');
        await expectLater(
          clientFor(site).download(a, dest, cancel: cancel),
          throwsA(isA<CatalogCancelled>()),
        );
        expect(dest.existsSync(), isFalse);
      },
    );

    test(
      'cancel mid-stream stops the transfer and removes the partial file',
      () async {
        final controller = StreamController<List<int>>();
        final client = CatalogClient(
          base: Uri.parse('https://site.test'),
          client: MockClient.streaming(
            (req, body) async => http.StreamedResponse(
              controller.stream,
              200,
              contentLength: 100000,
            ),
          ),
        );
        final cancel = DownloadCancel();
        final dest = File('${tempDir().path}/x.upkit');
        final f = client.download(
          a,
          dest,
          cancel: cancel,
          onProgress: (got, _) {
            if (got > 0) cancel.cancel();
          },
        );
        controller.add(List.filled(1024, 1));
        await expectLater(f, throwsA(isA<CatalogCancelled>()));
        expect(dest.existsSync(), isFalse);
        await controller.close();
      },
    );

    test('404 maps to not_found', () async {
      final site = FakeSite([]);
      final dest = File('${tempDir().path}/x.upkit');
      await expectLater(
        clientFor(site).download(a, dest),
        throwsA(
          isA<CatalogException>().having((e) => e.notFound, 'notFound', isTrue),
        ),
      );
    });
  });

  group('account data', () {
    test('requires a token', () async {
      final client = clientFor(FakeSite([a]));
      expect(
        () => client.meState(),
        throwsA(
          isA<CatalogException>().having(
            (e) => e.unauthorized,
            'unauthorized',
            isTrue,
          ),
        ),
      );
    });

    test('favorites, recent and state round-trip', () async {
      final site = FakeSite([a, b]);
      final client = clientFor(site, token: 'tok');
      await client.putFavorite('synth-dusk-run');
      await client.putFavorite('album-river');
      await client.deleteFavorite('album-river');
      await client.postRecent('synth-dusk-run');
      final s = await client.meState();
      expect(s.favorites, ['synth-dusk-run']);
      expect(s.recent.single.id, 'synth-dusk-run');
      expect(
        () => client.putFavorite('ghost'),
        throwsA(
          isA<CatalogException>().having((e) => e.notFound, 'notFound', isTrue),
        ),
      );
    });
  });
}
