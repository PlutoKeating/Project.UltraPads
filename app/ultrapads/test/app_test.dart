import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultrapads/src/features/recorder/save_recording_sheet.dart';
import 'package:ultrapads/src/routing/router.dart';
import 'package:ultrapads/src/routing/routes.dart';
import 'package:ultrapads/src/state/engine_state.dart';
import 'package:ultrapads/src/state/perform_state.dart';
import 'package:ultrapads/src/state/settings_state.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_ui/up_ui.dart';

import 'harness.dart';

void main() {
  testWidgets('perform page: kit name, pads, golden', (t) async {
    await pumpApp(t);
    expect(find.text('SUNSET'), findsOneWidget);
    expect(find.byType(UpPad), findsNWidgets(12));
    await shot(t, 'perform_neon');
  });

  testWidgets('pad pointer down triggers engine immediately (Listener, sync)', (
    t,
  ) async {
    final h = await pumpApp(t);
    final grid = find.byType(PadGrid);
    final origin = t.getTopLeft(grid);
    final size = t.getSize(grid);
    // pad 2（中列第一行）是 loop
    final g = await t.startGesture(
      origin + Offset(size.width / 2, size.height / 8),
    );
    expect(
      h.engine.snapshot().stateOf(const PadId(0, 1)),
      PadPlayState.playing,
    );
    await g.up();
    await t.pump(const Duration(milliseconds: 50));
    expect(h.engine.snapshot().transport.playing, isTrue);
    h.engine.send(const StopAllCmd());
    await t.pump();
  });

  testWidgets('tool row expands and collapses', (t) async {
    await pumpApp(t);
    await t.tap(find.byIcon(Icons.more_vert_rounded));
    await settle(t);
    expect(find.byIcon(Icons.palette_rounded), findsOneWidget);
    await shot(t, 'perform_tools_expanded');
  });

  testWidgets('skins sheet switches skin with animated theme', (t) async {
    final h = await pumpApp(t);
    await t.tap(find.byIcon(Icons.more_vert_rounded));
    await settle(t);
    await t.tap(find.byIcon(Icons.palette_rounded));
    await settle(t);
    expect(find.byType(SkinTile), findsWidgets);
    await shot(t, 'skins_sheet');
    await t.tap(find.byType(SkinTile).at(1));
    await settle(t);
    expect(h.container.read(settingsProvider).skinId, startsWith(presetPrefix));
  });

  testWidgets('tutorial: timed fills, judgement, speed modal', (t) async {
    final h = await pumpApp(t);
    await t.tap(
      find.text('LEARN TO PLAY').evaluate().isEmpty
          ? find.text('Learn to play')
          : find.text('LEARN TO PLAY'),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    final session = h.container.read(tutorialProvider);
    expect(session, isNotNull);
    expect(session!.timed, isTrue);
    await shot(t, 'perform_tutorial');
    // 速度框
    await t.tap(find.byType(SpeedPill));
    await settle(t);
    await t.tap(find.byType(UpListItem).at(1));
    await settle(t);
    expect(h.container.read(tutorialProvider)!.speed, 0.7);
  });

  testWidgets('A/B bank button toggles page (two-bank kit)', (t) async {
    final h = await pumpApp(t);
    unawaited(h.engine.libraryLoadKit('demo:best-hip-hop'));
    await settle(t);
    expect(find.byType(BankButton), findsOneWidget);
    await t.tap(find.byType(BankButton));
    await settle(t);
    expect(h.container.read(bankProvider), 1);
  });

  testWidgets('keyboard maps keys to pads', (t) async {
    final h = await pumpApp(t);
    await t.sendKeyDownEvent(LogicalKeyboardKey.keyQ);
    expect(
      h.engine.snapshot().stateOf(const PadId(0, 3)),
      PadPlayState.playing,
    );
    await t.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
    await t.pump();
  });

  for (final (route, name) in [
    (Routes.kits, 'library_kits'),
    (Routes.kit('demo:sunset'), 'kit_detail'),
    (Routes.editor, 'editor'),
    (Routes.tracks, 'tracks_empty'),
    (Routes.settings, 'settings'),
    (Routes.hub, 'hub'),
    (Routes.skinEditor, 'skin_editor'),
  ]) {
    testWidgets('page $name renders', (t) async {
      final h = await pumpApp(t);
      h.container.read(routerProvider).push(route);
      await shot(t, name);
      expect(h.engine.snapshot().kit, isNotNull);
    });
  }

  testWidgets('library tabs: feed and profile', (t) async {
    final h = await pumpApp(t);
    h.container.read(routerProvider).push(Routes.kits);
    await settle(t);
    await t.tap(find.byIcon(Icons.whatshot_rounded));
    await shot(t, 'library_feed');
    await t.tap(find.byIcon(Icons.person_rounded));
    await shot(t, 'library_profile');
  });

  testWidgets('kit detail LET\'S PLAY loads kit and returns to perform', (
    t,
  ) async {
    final h = await pumpApp(t);
    h.container.read(routerProvider).push(Routes.kit('demo:loud-rock'));
    await settle(t);
    await t.tap(find.byType(UpButton).last);
    await settle(t);
    expect(h.engine.snapshot().kit!.id, 'demo:loud-rock');
    expect(find.byType(PadGrid), findsOneWidget);
  });

  testWidgets('recording: record → save sheet → tracks list', (t) async {
    final h = await pumpApp(t);
    h.engine.send(const StartRecordingCmd());
    h.engine.advance(const Duration(seconds: 2));
    h.engine.send(const StopRecordingCmd());
    await settle(t);
    expect(find.byType(SaveRecordingSheet), findsOneWidget);
    await shot(t, 'save_recording');
    await t.tap(
      find.text('SAVE').evaluate().isEmpty
          ? find.text('Save')
          : find.text('SAVE'),
    );
    await settle(t);
    h.container.read(routerProvider).push(Routes.tracks);
    await shot(t, 'tracks');
    expect(find.byType(TrackCard), findsOneWidget);
  });

  testWidgets('onboarding → style → perform', (t) async {
    final h = await pumpApp(t, onboarded: false);
    await shot(t, 'onboarding');
    for (var i = 0; i < 4; i++) {
      await t.tap(find.byType(UpButton).last);
      await settle(t);
    }
    await shot(t, 'onboarding_style');
    await t.tap(find.byType(UpListItem).first);
    await t.tap(find.byType(UpButton).last);
    await settle(t);
    expect(h.container.read(settingsProvider).onboarded, isTrue);
    expect(find.byType(PadGrid), findsOneWidget);
  });

  testWidgets('chinese locale renders', (t) async {
    final h = await pumpApp(t);
    await h.container
        .read(localeControllerProvider)
        .setLocale(const Locale('zh'));
    expect(h.container.read(engineProvider).backendName, 'mock');
    await shot(t, 'perform_zh');
  });
}
