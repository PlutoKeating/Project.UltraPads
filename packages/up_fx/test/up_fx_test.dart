import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_fx/up_fx.dart';

const _spec = GlowSpec(
  color: Color(0xFFFF00AA),
  spread: 12,
  radius: 8,
  intensity: 1,
);

void main() {
  test('SpringSpec settles at target', () {
    const s = SpringSpec(stiffness: 500, damping: 30, mass: 1);
    final sim = s.simulate(1, 0.9);
    expect(sim.x(2), closeTo(0.9, 1e-3));
  });

  testWidgets('NeonGlow falls back to BoxShadow in lite tier', (t) async {
    await t.pumpWidget(
      const FxScope(
        tier: FxTier.lite,
        child: NeonGlow(spec: _spec, child: SizedBox(width: 40, height: 40)),
      ),
    );
    final box = t.widget<DecoratedBox>(find.byType(DecoratedBox));
    expect((box.decoration as BoxDecoration).boxShadow, isNotEmpty);
  });

  testWidgets('NeonGlow renders nothing extra with reduced motion', (t) async {
    await t.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: NeonGlow(spec: _spec, child: SizedBox(width: 40, height: 40)),
      ),
    );
    expect(find.byType(DecoratedBox), findsNothing);
    expect(
      FxMotion.duration(
        t.element(find.byType(SizedBox)),
        const Duration(seconds: 1),
      ),
      Duration.zero,
    );
  });

  testWidgets('SegmentedLottie shows fallback when asset missing', (t) async {
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SegmentedLottie(
          asset: 'assets/does_not_exist.json',
          split: 0.5,
          fallback: (_) => const Text('fallback'),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('fallback'), findsOneWidget);
  });

  testWidgets('LoopBreathe paints when active', (t) async {
    await t.pumpWidget(
      const FxScope(
        tier: FxTier.lite,
        child: SizedBox(
          width: 50,
          height: 50,
          child: LoopBreathe(
            active: true,
            color: Color(0xFF00FFFF),
            radius: 6,
            strokeWidth: 2,
            period: Duration(milliseconds: 800),
            minOpacity: 0.4,
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('DitheredGradient shader compiles and paints (full tier)', (
    t,
  ) async {
    // 包内测试的资源键不带 `packages/up_fx/` 前缀：直接编译加载以验证着色器有效。
    final program = await t.runAsync(
      () => ui.FragmentProgram.fromAsset('shaders/dither_gradient.frag'),
    );
    expect(program, isNotNull);
    FxShaders.instance.gradient = program;
    for (final tier in FxTier.values) {
      await t.pumpWidget(
        FxScope(
          tier: tier,
          child: const SizedBox(
            width: 80,
            height: 60,
            child: DitheredGradient(
              colors: [Color(0xFFFF2288), Color(0xFFEE1177), Color(0xFF990044)],
              stops: [0, 0.5, 1],
              radial: true,
              extent: 0.75,
              cornerRadius: 8,
            ),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsWidgets);
      expect(t.takeException(), isNull);
    }
  });
}
