import 'dart:math' as math;

import '../models.dart';

/// Mock 曲库中的一个 Kit（摘要 + 文档 + 采样 + 教程）。
final class DemoKit {
  const DemoKit(this.summary, this.doc, this.samples, this.tutorial);
  final KitSummary summary;
  final KitDoc doc;
  final List<SampleInfo> samples;
  final TutorialChart? tutorial;
}

/// 确定性的演示数据（不含任何受版权保护的素材，只有名字和参数）。
abstract final class DemoLibrary {
  /// 曲风键，顺序与截图底部的曲风栏一致。UI 用它查 i18n 文案和图标。
  static const genres = [
    'hiphop',
    'funkbr',
    'kpop',
    'rock',
    'disco',
    'edm',
    'pop',
    'trap',
  ];

  static List<DemoKit> kits() => [
    makeKit(
      id: 'demo:sunset',
      name: 'SUNSET',
      artist: 'UltraPads',
      song: 'Sunset',
      genre: 'edm',
      bpm: 80,
      color: ColorRole.orange,
      featured: true,
      tutorial: true,
    ),
    makeKit(
      id: 'demo:best-hip-hop',
      name: 'BEST HIP HOP',
      song: 'Hip-Hop Music',
      genre: 'hiphop',
      bpm: 92,
      color: ColorRole.yellow,
      featured: true,
      tutorial: true,
      banks: 2,
    ),
    makeKit(
      id: 'demo:loud-rock',
      name: 'LOUD ROCK',
      song: 'Rock Music',
      genre: 'rock',
      bpm: 128,
      color: ColorRole.green,
      isNew: true,
    ),
    makeKit(
      id: 'demo:party-dance',
      name: 'PARTY DANCE',
      song: 'Pop Music',
      genre: 'pop',
      bpm: 124,
      color: ColorRole.pink,
      isNew: true,
    ),
    makeKit(
      id: 'demo:pretty-kpop',
      name: 'PRETTY K-POP',
      song: 'K-Pop Music',
      genre: 'kpop',
      bpm: 118,
      color: ColorRole.pink,
      featured: true,
    ),
    makeKit(
      id: 'demo:along-trap',
      name: 'ALONG TRAP',
      song: 'Trap Music',
      genre: 'trap',
      bpm: 140,
      color: ColorRole.blue,
      featured: true,
    ),
    makeKit(
      id: 'demo:crazy-house',
      name: 'CRAZY HOUSE',
      song: 'House Music',
      genre: 'disco',
      bpm: 126,
      color: ColorRole.purple,
      featured: true,
      downloaded: false,
    ),
    makeKit(
      id: 'demo:funk-br',
      name: 'BAILE FUNK',
      song: 'Funk BR',
      genre: 'funkbr',
      bpm: 130,
      color: ColorRole.green,
      downloaded: false,
    ),
  ];

  /// 配色布局：与内置 Kit「Sunset」一致——中列（pad 2/5/8/11）是蓝色 Loop，
  /// 同列同 choke 组；4.7.0 约定「蓝色 = Loop」。
  static const _palette = [
    ColorRole.orange, ColorRole.blue, ColorRole.pink, //
    ColorRole.green, ColorRole.blue, ColorRole.orange,
    ColorRole.pink, ColorRole.blue, ColorRole.green,
    ColorRole.orange, ColorRole.blue, ColorRole.pink,
  ];

  static DemoKit makeKit({
    required String id,
    required String name,
    String artist = '',
    String song = '',
    String genre = 'pop',
    double bpm = 120,
    ColorRole color = ColorRole.pink,
    bool featured = false,
    bool isNew = false,
    bool tutorial = false,
    bool downloaded = true,
    int banks = 1,
    KitSource source = KitSource.builtin,
  }) {
    final samples = <SampleInfo>[];
    final pads = List<PadParams>.filled(PadId.total, PadParams.empty);
    for (var flat = 0; flat < banks * PadId.padsPerBank; flat++) {
      final pad = PadId.flat(flat);
      final loop = pad.column == 1;
      final barSecs = 60 / bpm * 4;
      final s = SampleInfo(
        id: '$id/pad${flat + 1}',
        name: '${name.toLowerCase()} ${flat + 1}',
        durationSecs: loop
            ? barSecs * (pad.row.isEven ? 1 : 2)
            : 1.0 + (flat % 5) * 0.2,
      );
      samples.add(s);
      pads[flat] = PadParams(
        mode: loop ? PadMode.loop : PadMode.oneShot,
        color: _palette[pad.index],
        chokeGroup: pad.column + 1,
        sample: s.id,
      );
    }
    final doc = KitDoc(id: id, name: name, pads: pads, bpm: bpm, genre: genre);
    final summary = KitSummary(
      id: id,
      name: name,
      artist: artist,
      song: song,
      genre: genre,
      bpm: bpm,
      padCount: banks * PadId.padsPerBank,
      hasTutorial: tutorial,
      isNew: isNew,
      isFeatured: featured,
      downloaded: downloaded,
      source: source,
      color: color,
    );
    return DemoKit(
      summary,
      doc,
      samples,
      tutorial ? _tutorial(id, banks, bpm) : null,
    );
  }

  /// 演示教程：时间轴格式（每 [_step] 秒一步，与 Sunset 的半小节间隔一致）。
  static TutorialChart _tutorial(String kit, int banks, double bpm) {
    final step = 60 / bpm * 2;
    var t = step;
    final steps = <TutorialStep>[
      const TutorialStep(page: 0, timeSecs: 0, kind: TutorialStepKind.page),
    ];
    void tap(PadId p, {TutorialStepKind kind = TutorialStepKind.tap}) {
      steps.add(TutorialStep(pads: [p], timeSecs: t, kind: kind));
      t += step;
    }

    tap(const PadId(0, 1), kind: TutorialStepKind.loopOn);
    for (final i in [0, 3, 6, 9, 2, 5, 8, 0]) {
      tap(PadId(0, i));
    }
    tap(const PadId(0, 4), kind: TutorialStepKind.loopOn);
    for (final i in [0, 2, 3, 5]) {
      tap(PadId(0, i));
    }
    if (banks > 1) {
      steps.add(
        TutorialStep(page: 1, timeSecs: t, kind: TutorialStepKind.page),
      );
      t += step;
      for (final i in [0, 2, 5, 8]) {
        tap(PadId(1, i));
      }
      steps.add(
        TutorialStep(page: 0, timeSecs: t, kind: TutorialStepKind.page),
      );
      t += step;
    }
    tap(const PadId(0, 1), kind: TutorialStepKind.loopOff);
    tap(const PadId(0, 4), kind: TutorialStepKind.loopOff);
    return TutorialChart(kit: kit, steps: steps, bpm: bpm, durationSecs: t);
  }

  /// 确定性伪波形：0..1 峰值概要。
  static List<double> waveform(String seed, int buckets) {
    var h = 0x811c9dc5;
    for (final c in seed.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    final rnd = math.Random(h);
    return List.generate(buckets, (i) {
      final env = math.sin(math.pi * (i + 0.5) / buckets);
      return (0.25 + 0.75 * rnd.nextDouble()) * (0.35 + 0.65 * env);
    });
  }

  static const peers = [
    HubPeer(
      id: 'peer-desktop-1',
      name: 'Studio PC',
      kind: HubPeerKind.desktop,
      address: '192.168.1.20',
      port: 47100,
      addresses: ['192.168.1.20:47100'],
    ),
    HubPeer(
      id: 'peer-laptop-2',
      name: 'Laptop',
      kind: HubPeerKind.desktop,
      address: '192.168.1.31',
      port: 47100,
      addresses: ['192.168.1.31:47100'],
    ),
  ];
}
