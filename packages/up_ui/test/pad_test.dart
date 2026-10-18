import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_ui/up_ui.dart';

import 'harness.dart';

List<PadData> demoPads() => [
  for (var i = 0; i < 24; i++)
    switch (i % 12) {
      11 => PadData.empty,
      1 || 7 => PadData(role: i % 8, loop: true, label: '${i % 12 + 1}'),
      4 => PadData(
        role: 3,
        loop: true,
        state: PadVisualState.playing,
        label: '5',
      ),
      8 => PadData(role: 2, state: PadVisualState.pending, label: '9'),
      _ => PadData(role: i % 8, label: '${i % 12 + 1}'),
    },
];

void main() {
  for (final theme in ['neon', 'outline', 'light']) {
    testWidgets('PadGrid $theme', (t) async {
      await golden(
        t,
        PadGrid(
          pads: demoPads(),
          bank: 0,
          onPadDown: (_, _) {},
          onPadUp: (_, _) {},
          showLabels: theme == 'outline',
        ),
        'pad_grid_$theme',
        theme: theme,
        surface: const Size(360, 480),
        size: const Size(340, 460),
      );
    });
  }

  testWidgets('UpPad states', (t) async {
    await golden(
      t,
      const Row(
        spacing: 8,
        children: [
          Expanded(child: UpPad(data: PadData(role: 0))),
          Expanded(child: UpPad(data: PadData(role: 1), pressed: true)),
          Expanded(child: UpPad(data: PadData(role: 3, loop: true))),
          Expanded(
            child: UpPad(
              data: PadData(role: 4, loop: true, state: PadVisualState.playing),
            ),
          ),
          Expanded(child: UpPad(data: PadData())),
          Expanded(child: UpPad(data: PadData(role: 2), dimmed: true)),
          Expanded(
            child: UpPad(
              data: PadData(role: 6),
              highlighted: true,
              selected: true,
            ),
          ),
        ],
      ),
      'pad_states',
      surface: const Size(560, 120),
      size: const Size(540, 80),
    );
  });

  testWidgets('PadGrid multi-touch: down/up per pointer and immediate press', (
    t,
  ) async {
    final downs = <(int, int)>[];
    final ups = <(int, int)>[];
    final key = GlobalKey<PadGridState>();
    await t.pumpWidget(
      harness(
        PadGrid(
          key: key,
          pads: demoPads(),
          bank: 0,
          onPadDown: (b, i) => downs.add((b, i)),
          onPadUp: (b, i) => ups.add((b, i)),
        ),
        size: const Size(300, 400),
      ),
    );
    final origin = t.getTopLeft(find.byType(PadGrid));
    final g1 = await t.startGesture(origin + const Offset(10, 10));
    final g2 = await t.startGesture(origin + const Offset(150, 390));
    await t.pump();
    expect(downs, [(0, 0), (0, 10)]);
    expect(key.currentState!.pressedPads, {0, 10});
    await g1.up();
    await t.pump();
    expect(ups, [(0, 0)]);
    await g2.cancel();
    await t.pump();
    expect(ups, [(0, 0), (0, 10)]);
    expect(key.currentState!.pressedPads, isEmpty);
  });

  testWidgets('empty pad ignores touches; bank B maps to bank 1', (t) async {
    final downs = <(int, int)>[];
    await t.pumpWidget(
      harness(
        PadGrid(
          pads: demoPads(),
          bank: 1,
          onPadDown: (b, i) => downs.add((b, i)),
          onPadUp: (_, _) {},
        ),
        size: const Size(300, 400),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    final origin = t.getTopLeft(find.byType(PadGrid));
    await t.tapAt(origin + const Offset(290, 390)); // index 11 → empty
    await t.tapAt(origin + const Offset(150, 10)); // index 1
    expect(downs, [(1, 1)]);
  });
}
