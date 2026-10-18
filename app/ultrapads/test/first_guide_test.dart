import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultrapads/src/features/onboarding/first_guide.dart';
import 'package:ultrapads/src/state/settings_state.dart';

import 'harness.dart';

/// 演奏页首次引导（参考设计 FirstGuide）。
void main() {
  testWidgets('first guide: 4 steps, golden, done persists', (t) async {
    final h = await pumpApp(t, prefs: {'firstGuideSeen': false});
    expect(find.byType(FirstGuideOverlay), findsOneWidget);
    expect(find.text('STEP 1/4'), findsOneWidget);
    expect(find.byKey(const ValueKey('first-guide-bubble')), findsOneWidget);
    await shot(t, 'first_guide');
    for (var i = 2; i <= 4; i++) {
      await t.tap(find.byKey(const ValueKey('first-guide-next')));
      await settle(t);
      expect(find.text('STEP $i/4'), findsOneWidget);
    }
    expect(find.text("LET'S PLAY"), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('first-guide-next')));
    await settle(t);
    expect(find.byType(FirstGuideOverlay), findsNothing);
    expect(h.container.read(settingsProvider).firstGuideSeen, isTrue);
    expect(h.container.read(prefsProvider).getBool('firstGuideSeen'), isTrue);
  });

  testWidgets('first guide: skip closes it; settings can show it again', (
    t,
  ) async {
    final h = await pumpApp(t, prefs: {'firstGuideSeen': false});
    await t.tap(find.byKey(const ValueKey('first-guide-skip')));
    await settle(t);
    expect(find.byType(FirstGuideOverlay), findsNothing);
    h.container.read(settingsProvider.notifier).setFirstGuideSeen(false);
    await settle(t);
    expect(find.byType(FirstGuideOverlay), findsOneWidget);
  });

  testWidgets('first guide: tapping inside the highlighted hole advances', (
    t,
  ) async {
    await pumpApp(t, prefs: {'firstGuideSeen': false});
    final pad = t.getRect(find.byType(FirstGuideOverlay));
    expect(pad, isNotNull);
    // 第一步高亮左上角第一个 pad：点它的中心。
    final grid = t.getRect(find.byKey(const ValueKey('first-guide-bubble')));
    expect(grid.width, greaterThan(0));
    await t.tapAt(const Offset(60, 200));
    await settle(t);
    expect(find.text('STEP 2/4'), findsOneWidget);
  });
}
