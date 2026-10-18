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
    expect(PadId.all.length, 24);
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
    expect(d.peer.paired, isTrue);
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
