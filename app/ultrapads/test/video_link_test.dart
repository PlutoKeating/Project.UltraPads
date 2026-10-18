import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ultrapads/src/config/app_links.dart';
import 'package:up_ui/up_ui.dart';

import 'harness.dart';

void main() {
  final links = AppLinks.fromJson(
    jsonDecode(File(AppLinks.asset).readAsStringSync()) as Map<String, dynamic>,
  );

  test('video link: config template per language, kit link first', () {
    final en = links.videoFor(languageCode: 'en', kitName: 'SUNSET')!;
    expect(en.queryParameters.values.single, contains('SUNSET'));
    final zh = links.videoFor(languageCode: 'zh', kitName: 'SUNSET')!;
    expect(zh.host, isNot(en.host));
    final fr = links.videoFor(languageCode: 'fr', kitName: 'X')!;
    expect(fr.host, en.host, reason: 'unknown language → default');
    final own = links.videoFor(
      languageCode: 'en',
      kitName: 'SUNSET',
      kitVideoUrl: 'https://example.org/v',
    );
    expect(own.toString(), 'https://example.org/v');
    expect(const AppLinks().videoFor(languageCode: 'en'), isNull);
  });

  testWidgets('perform page shows the video tutorial button (top bar)', (
    t,
  ) async {
    await pumpApp(t);
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle(t);
    expect(find.byType(VideoTutorialButton), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
  });
}
