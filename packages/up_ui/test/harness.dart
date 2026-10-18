import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_fx/up_fx.dart';
import 'package:up_tokens/up_tokens.dart';

/// 以指定皮肤包裹组件，背景为 surfacePads。
Widget harness(Widget child, {String theme = 'neon', Size? size}) {
  final t = UpThemes.byId(theme);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: t.toThemeData(),
    home: FxScope(
      tier: FxTier.lite,
      child: Scaffold(
        backgroundColor: t.colors.surfacePads,
        body: Center(
          child: size == null
              ? child
              : SizedBox.fromSize(size: size, child: child),
        ),
      ),
    ),
  );
}

Future<void> golden(
  WidgetTester t,
  Widget child,
  String name, {
  String theme = 'neon',
  Size surface = const Size(400, 300),
  Size? size,
}) async {
  await t.binding.setSurfaceSize(surface);
  t.view.devicePixelRatio = 1;
  await t.pumpWidget(harness(child, theme: theme, size: size));
  await t.pump(const Duration(milliseconds: 500));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
  await t.binding.setSurfaceSize(null);
}
