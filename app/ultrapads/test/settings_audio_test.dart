import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultrapads/src/features/settings/settings_page.dart';
import 'package:ultrapads/src/routing/router.dart';
import 'package:ultrapads/src/routing/routes.dart';

import 'harness.dart';

void main() {
  testWidgets('settings renders when audio failed to start (no NaN crash)', (
    t,
  ) async {
    final h = await pumpApp(t, size: const Size(414, 1600));
    await h.engine.audioStop();
    h.container.read(routerProvider).push(Routes.settings);
    await settle(t);
    expect(t.takeException(), isNull);
    expect(find.byType(SettingsPage), findsOneWidget);
  });
}
