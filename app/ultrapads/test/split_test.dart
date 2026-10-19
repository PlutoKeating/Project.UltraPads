import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ultrapads/src/features/split/split_song_sheet.dart';
import 'package:ultrapads/src/split/model_store.dart';
import 'package:ultrapads/src/split/split_controller.dart';
import 'package:ultrapads/src/state/engine_state.dart';
import 'package:up_engine/up_engine.dart';

import 'catalog_fixtures.dart';
import 'harness.dart';

final _bytes = utf8.encode('fake-onnx-model-bytes' * 50);
final _model = SeparationModel(
  url: 'https://models.invalid/m.onnx',
  sha256: sha256.convert(_bytes).toString(),
  bytes: _bytes.length,
  fileName: 'm.onnx',
);

ModelStore _store(Directory dir, {List<int>? body, int status = 200}) =>
    ModelStore(
      dir: () async => dir,
      model: _model,
      client: MockClient.streaming((req, _) async {
        final data = body ?? _bytes;
        return http.StreamedResponse(
          Stream.fromIterable([
            data.sublist(0, data.length ~/ 2),
            data.sublist(data.length ~/ 2),
          ]),
          status,
          contentLength: data.length,
        );
      }),
    );

void main() {
  group('ModelStore', () {
    test('downloads, verifies sha256 and reports installed', () async {
      final dir = tempDir();
      final store = _store(dir);
      expect(await store.installed(), isNull);
      final seen = <int>[];
      final f = await store.download(onProgress: (got, total) => seen.add(got));
      expect(await f.readAsBytes(), _bytes);
      expect(seen.last, _bytes.length);
      expect(await store.installed(), isNotNull);
      expect(File('${f.path}.part').existsSync(), isFalse);
      await store.remove();
      expect(await store.installed(), isNull);
    });

    test('rejects a model whose checksum does not match', () async {
      final dir = tempDir();
      final store = _store(dir, body: List.of(_bytes)..[3] ^= 1);
      await expectLater(
        store.download(),
        throwsA(
          isA<ModelDownloadFailed>().having(
            (e) => e.reason,
            'reason',
            'checksum',
          ),
        ),
      );
      expect(await store.installed(), isNull);
      expect(dir.listSync(), isEmpty);
    });

    test('maps HTTP errors and honours cancel', () async {
      final dir = tempDir();
      await expectLater(
        _store(dir, status: 404).download(),
        throwsA(
          isA<ModelDownloadFailed>().having(
            (e) => e.reason,
            'reason',
            'http_404',
          ),
        ),
      );
      final cancel = ModelCancel()..cancel();
      await expectLater(
        _store(dir).download(cancel: cancel),
        throwsA(isA<ModelDownloadCancelled>()),
      );
      expect(dir.listSync(), isEmpty);
    });
  });

  group('SplitController', () {
    ProviderContainer container(MockEngineClient engine, ModelStore store) {
      final c = ProviderContainer(
        overrides: [
          engineProvider.overrideWithValue(engine),
          modelStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('quick split goes straight to the engine without a model', () async {
      final engine = MockEngineClient(realtime: false);
      final c = container(engine, _store(tempDir()));
      await c
          .read(splitProvider.notifier)
          .start(path: '/s/a.mp3', separate: false);
      final s = c.read(splitProvider);
      expect(s.phase, SplitPhase.done);
      expect(s.done!.separated, isFalse);
      expect(engine.splitRequests, ['/s/a.mp3|']);
    });

    test(
      'separation downloads the model first, then passes its path',
      () async {
        final engine = MockEngineClient(realtime: false);
        final dir = tempDir();
        final c = container(engine, _store(dir));
        await c
            .read(splitProvider.notifier)
            .start(path: '/s/a.mp3', separate: true);
        expect(c.read(splitProvider).phase, SplitPhase.done);
        expect(c.read(splitProvider).done!.separated, isTrue);
        expect(engine.splitRequests.single, endsWith('m.onnx'));
        expect(engine.splitRequests.single, startsWith('/s/a.mp3|${dir.path}'));
        // 第二次不再下载
        await c
            .read(splitProvider.notifier)
            .start(path: '/s/b.mp3', separate: true);
        expect(engine.splitRequests, hasLength(2));
      },
    );

    test(
      'model download failure is reported and the engine is not called',
      () async {
        final engine = MockEngineClient(realtime: false);
        final c = container(engine, _store(tempDir(), status: 500));
        await c
            .read(splitProvider.notifier)
            .start(path: '/s/a.mp3', separate: true);
        final s = c.read(splitProvider);
        expect(s.phase, SplitPhase.failed);
        expect(s.failure, 'model_http_500');
        expect(engine.splitRequests, isEmpty);
      },
    );

    test('engine failures keep their tag', () async {
      final engine = MockEngineClient(realtime: false)
        ..splitResult = const SplitFailed(
          EngineException(ErrorCode.invalidArgument, '[too_short] 音频太短'),
        );
      final c = container(engine, _store(tempDir()));
      await c
          .read(splitProvider.notifier)
          .start(path: '/s/a.mp3', separate: false);
      expect(c.read(splitProvider).failure, startsWith('[too_short]'));
    });
  });

  testWidgets('split sheet: choose quick split and see the result', (t) async {
    final engine = MockEngineClient(realtime: false);
    final h = await pumpApp(t, engine: engine);
    final ctx = t.element(find.byType(Scaffold).first);
    unawaited(showSplitSongSheet(ctx, '/songs/My Song.mp3'));
    await settle(t);
    expect(_text('My Song'), findsOneWidget);
    await t.tap(_text('Quick split (whole mix)'));
    await t.pump();
    await t.tap(_text('Start'));
    await settle(t);
    expect(engine.splitRequests.single, '/songs/My Song.mp3|');
    expect(h.container.read(splitProvider).phase, SplitPhase.done);
    expect(
      _text('Created “imported”: 3 sections, about 100 BPM'),
      findsNothing,
    );
    expect(_text('Load and play'), findsOneWidget);
  });
}

/// 标题与按钮会转成大写：按不区分大小写匹配。
Finder _text(String text) => find.byWidgetPredicate(
  (w) => w is Text && w.data?.toLowerCase() == text.toLowerCase(),
);
