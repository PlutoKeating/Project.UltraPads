import 'package:flutter_test/flutter_test.dart';
import 'package:up_engine/up_engine.dart';

void main() {
  late MockEngineClient engine;
  final events = <EngineEvent>[];

  setUp(() {
    engine = MockEngineClient(realtime: false);
    events.clear();
    engine.events.listen(events.add);
  });

  tearDown(() => engine.dispose());

  PadId firstWhere(PadMode mode) => PadId.all.firstWhere(
    (p) =>
        engine.snapshot().paramsOf(p).mode == mode &&
        !engine.snapshot().paramsOf(p).isEmpty,
  );

  test('PadId flat/row/column', () {
    expect(PadId.flat(13), const PadId(1, 1));
    expect(const PadId(0, 4).row, 1);
    expect(const PadId(0, 4).column, 1);
    expect(PadId.all.length, PadId.banks * PadId.padsPerBank);
    expect(const PadId(2, 0).toString(), 'PadId(C1)');
  });

  test('KitDoc sound groups: add, remove (later groups shift), move', () {
    PadParams p(String s) => PadParams(sample: s);
    final pads = List<PadParams>.filled(PadId.total, PadParams.empty);
    pads[const PadId(0, 0).flat] = p('a');
    pads[const PadId(1, 0).flat] = p('b');
    var doc = KitDoc(id: 'k', name: 'K', pads: pads);
    expect(doc.groupCount, 2, reason: 'derived from the pads');

    doc = doc.addGroup();
    expect(doc.groupCount, 3, reason: 'empty group C is kept');
    doc = doc.withPad(const PadId(2, 5), p('c'));

    final moved = doc.moveGroup(2, 0);
    expect(moved.pad(const PadId(0, 5)).sample, 'c');
    expect(moved.pad(const PadId(1, 0)).sample, 'a');
    expect(moved.pad(const PadId(2, 0)).sample, 'b');

    final removed = doc.removeGroup(0);
    expect(removed.groupCount, 2);
    expect(removed.pad(const PadId(0, 0)).sample, 'b');
    expect(removed.pad(const PadId(1, 5)).sample, 'c');
    expect(removed.pad(const PadId(2, 5)).isEmpty, isTrue);

    final single = KitDoc(
      id: 'k',
      name: 'K',
      pads: List.filled(PadId.total, PadParams.empty),
    );
    expect(single.removeGroup(0).groupCount, 1, reason: 'at least one group');
    var full = single;
    for (var i = 0; i < PadId.banks + 2; i++) {
      full = full.addGroup();
    }
    expect(full.groupCount, PadId.banks);
    expect(full.canAddGroup, isFalse);
  });

  test('one-shot plays then returns to idle', () async {
    final pad = firstWhere(PadMode.oneShot);
    engine.padDown(pad);
    expect(engine.snapshot().stateOf(pad), PadPlayState.playing);
    engine.advance(const Duration(seconds: 5));
    expect(engine.snapshot().stateOf(pad), PadPlayState.idle);
  });

  test('loop toggles and starts transport; second loop is quantized', () async {
    final loops = PadId.all
        .where((p) => engine.snapshot().paramsOf(p).mode == PadMode.loop)
        .toList();
    engine.padDown(loops[0]);
    expect(engine.snapshot().stateOf(loops[0]), PadPlayState.playing);
    expect(engine.snapshot().transport.playing, isTrue);
    engine.advance(const Duration(milliseconds: 100));
    engine.padDown(loops[1]);
    expect(engine.snapshot().stateOf(loops[1]), PadPlayState.pending);
    engine.advance(const Duration(seconds: 4));
    expect(engine.snapshot().stateOf(loops[1]), PadPlayState.playing);
  });

  test('choke group stops other pads in same group', () {
    final a = const PadId(0, 0);
    final b = const PadId(0, 3); // same column → same group
    engine.padDown(a);
    engine.padDown(b);
    expect(engine.snapshot().stateOf(a), PadPlayState.idle);
    expect(engine.snapshot().stateOf(b), PadPlayState.playing);
  });

  test('StopAll stops everything', () {
    engine.padDown(const PadId(0, 0));
    engine.padDown(const PadId(0, 1));
    engine.send(const StopAllCmd());
    expect(
      engine.snapshot().padStates.every((s) => s == PadPlayState.idle),
      isTrue,
    );
  });

  test('recording creates a track', () async {
    engine.send(const StartRecordingCmd());
    engine.advance(const Duration(seconds: 3));
    engine.send(const StopRecordingCmd());
    final tracks = await engine.tracksList();
    expect(tracks, hasLength(1));
    expect(tracks.first.durationSecs, closeTo(3, 0.01));
    await Future<void>.delayed(Duration.zero);
    expect(events.whereType<RecorderEvent>().last.track, isNotNull);
  });

  test('load kit emits KitLoaded', () async {
    final kits = await engine.libraryListKits();
    await engine.libraryLoadKit(kits[1].id);
    await Future<void>.delayed(Duration.zero);
    expect(engine.snapshot().kit!.id, kits[1].id);
    expect(events.whereType<KitLoadedEvent>(), isNotEmpty);
  });

  test('save kit updates current pads', () async {
    final id = engine.snapshot().kit!.id;
    final doc = await engine.libraryGetKit(id);
    await engine.librarySaveKit(
      doc.withPad(
        const PadId(0, 0),
        doc.pads[0].copyWith(color: ColorRole.blue),
      ),
    );
    expect(engine.snapshot().paramsOf(const PadId(0, 0)).color, ColorRole.blue);
  });

  test('controller mode forwards pads instead of playing', () async {
    await engine.hubControllerConnect(DemoLibrary.peers.first);
    engine.padDown(const PadId(0, 0));
    expect(engine.forwardedPadEvents, 1);
    expect(engine.snapshot().stateOf(const PadId(0, 0)), PadPlayState.idle);
    expect(engine.snapshot().controllerMode, isTrue);
  });

  test('hub pairing validates code', () async {
    final peer = DemoLibrary.peers.first;
    expect(() => engine.hubPair(peer, '12'), throwsA(isA<EngineException>()));
    final d = await engine.hubPair(peer, '123456');
    expect(d.id, peer.id);
    expect((await engine.hubTrustedDevices()).single.id, peer.id);
    expect((await engine.hubKnownPeers()).single.paired, isTrue);
    expect(await engine.hubRevoke(peer.id), isTrue);
    expect(await engine.hubTrustedDevices(), isEmpty);
  });

  test('controller local echo also plays locally', () async {
    await engine.hubControllerConnect(DemoLibrary.peers.first);
    engine.hubControllerSetLocalEcho(true);
    expect(engine.hubControllerStatus().localEcho, isTrue);
    engine.padDown(const PadId(0, 0));
    expect(engine.forwardedPadEvents, 1);
    expect(engine.snapshot().stateOf(const PadId(0, 0)), PadPlayState.playing);
    await engine.hubControllerDisconnect();
    expect(engine.hubControllerStatus().connected, isFalse);
  });

  test(
    'hub server issues pairing codes, probe and sync report progress',
    () async {
      await expectLater(
        engine.hubNewPairingCode(),
        throwsA(isA<EngineException>()),
      );
      final s = await engine.hubStartServer('Desk');
      expect(s.addresses, isNotEmpty);
      expect((await engine.hubNewPairingCode()).code, hasLength(6));
      expect((await engine.hubServerInfo())?.name, 'Desk');
      final peer = await engine.hubProbe('10.0.2.2:47100');
      expect(peer.port, 47100);
      final events = <HubEvent>[];
      final sub = engine.events.listen((e) {
        if (e is HubEventWrapper) events.add(e.event);
      });
      await engine.hubSync(peer);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(events.first, isA<HubSyncStarted>());
      expect(events.whereType<HubSyncProgress>().last.fraction, 1);
      expect(events.last, isA<HubSyncFinished>());
      await engine.hubStopServer();
      expect(await engine.hubServerInfo(), isNull);
    },
  );

  test('discover emits found events and stops', () async {
    final first = await engine.hubDiscover().first;
    expect(first, isA<HubPeerFound>());
    await engine.hubDiscoverStop();
  });

  test('color roles map to the token palette in one place', () {
    expect(ColorRole.pink.paletteIndex, 0);
    expect(ColorRole.orange.paletteIndex, 1);
    expect(ColorRole.blue.paletteIndex, 3);
    for (var i = 0; i < ColorRole.palette.length; i++) {
      expect(ColorRole.palette[i].paletteIndex, i);
    }
    expect(ColorRole.fromPalette(9), ColorRole.orange);
  });

  test('sample preview does not occupy a pad', () async {
    final kit = engine.snapshot().pads.firstWhere((p) => !p.isEmpty);
    await engine.samplePreview(kit.sample!);
    expect(engine.previewSample, kit.sample);
    expect(
      engine.snapshot().padStates.every((s) => s == PadPlayState.idle),
      isTrue,
    );
    await engine.samplePreviewStop();
    expect(engine.previewSample, isNull);
  });

  test('waveform deterministic', () {
    expect(DemoLibrary.waveform('a', 16), DemoLibrary.waveform('a', 16));
  });

  test('tutorial available for sunset', () async {
    final chart = await engine.tutorialGet('demo:sunset');
    expect(chart, isNotNull);
    expect(chart!.steps.first.page, 0);
  });
}
