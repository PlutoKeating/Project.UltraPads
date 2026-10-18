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
}
