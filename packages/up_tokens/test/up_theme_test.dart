import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tokens/up_tokens.dart';

void main() {
  group('generated tokens', () {
    test('APK-calibrated values reach Dart', () {
      expect(UpThemes.neon.colors.surfaceApp, const Color(0xFF202629));
      expect(UpThemes.neon.colors.accentPrimary, const Color(0xFFF73873));
      expect(UpThemes.neon.colors.padShapeRadiusRatio, closeTo(0.12, 1e-9));
      expect(UpPadGridTokens.columns * UpPadGridTokens.rows, 12);
      expect(UpPadTokens.gap, 2);
      expect(UpPadGridTokens.bankSwitch, const Duration(milliseconds: 100));
      expect(UpDurations.loopRevolution, const Duration(milliseconds: 817));
      expect(UpPadTokens.pressCurve, const Cubic(0.6, 0, 0.4, 1));
      expect(UpSprings.snappy.stiffness, 900);
    });

    test('every built-in theme exposes the same token keys', () {
      for (final String id in UpSemanticThemes.ids) {
        final UpSemantic s = UpSemanticThemes.byId[id]!;
        for (final UpSemanticTokenInfo info in UpSemantic.tokens) {
          expect(
            () => s.valueOf(info.key),
            returnsNormally,
            reason: '$id ${info.key}',
          );
        }
      }
      expect(UpThemes.light.brightness, Brightness.light);
      expect(UpThemes.outline.colors.padIdleFillOpacity, 0);
    });

    test('pad palette wraps by role index', () {
      final UpSemantic s = UpThemes.neon.colors;
      expect(UpSemantic.padPaletteLength, 8);
      expect(s.padRole(0), s.padRole(UpSemantic.padPaletteLength));
      expect(s.padRole(3).core, s.padPalette3Core);
      expect(s.padPalette, hasLength(UpSemantic.padPaletteLength));
    });
  });

  group('lerp', () {
    test('endpoints and midpoint', () {
      final UpTheme a = UpThemes.neon;
      final UpTheme b = UpThemes.light;
      expect(a.lerp(b, 0), same(a));
      expect(a.lerp(b, 1), same(b));
      final UpTheme mid = a.lerp(b, 0.5);
      expect(
        mid.colors.surfaceApp,
        Color.lerp(a.colors.surfaceApp, b.colors.surfaceApp, 0.5),
      );
      expect(mid.brightness, Brightness.light);
      expect(
        UpSemantic.lerp(a.colors, b.colors, 0.25).padIdleBevel,
        closeTo(
          a.colors.padIdleBevel +
              (b.colors.padIdleBevel - a.colors.padIdleBevel) * 0.25,
          1e-9,
        ),
      );
    });

    test('gradients with different stop counts', () {
      const UpGradient two = UpGradient(
        colors: <Color>[Color(0xFF000000), Color(0xFFFFFFFF)],
        stops: <double>[0, 1],
      );
      const UpGradient three = UpGradient(
        colors: <Color>[
          Color(0xFFFF0000),
          Color(0xFF00FF00),
          Color(0xFF0000FF),
        ],
        stops: <double>[0, 0.5, 1],
      );
      final UpGradient g = UpGradient.lerp(two, three, 1);
      expect(g.colors, three.colors);
      expect(g.stops, three.stops);
    });

    testWidgets('ThemeData.lerp animates the extension', (
      WidgetTester tester,
    ) async {
      final ThemeData t = ThemeData.lerp(
        UpThemes.neon.toThemeData(),
        UpThemes.outline.toThemeData(),
        0.5,
      );
      expect(t.extension<UpTheme>(), isNotNull);
    });
  });

  group('custom skins', () {
    test('overrides apply on top of the base theme', () {
      final UpTheme custom = UpTheme.custom(
        UpThemes.outline,
        UpSemanticOverrides(<String, Object>{
          'pad.palette.0.core': const Color(0xFF123456),
          'pad.shape.radiusRatio': 0.25,
        }),
        id: 'mine',
      );
      expect(custom.colors.padPalette0Core, const Color(0xFF123456));
      expect(custom.colors.padShapeRadiusRatio, 0.25);
      expect(custom.colors.surfaceApp, UpThemes.outline.colors.surfaceApp);
      expect(custom.baseId, 'outline');
      expect(custom.isCustom, isTrue);
    });

    test('invalid keys and types are rejected', () {
      expect(
        () => UpSemanticOverrides(<String, Object>{'nope': 1}),
        throwsArgumentError,
      );
      expect(
        () => UpSemanticOverrides(<String, Object>{'surface.app': 1}),
        throwsArgumentError,
      );
      expect(
        () => UpSemanticOverrides(<String, Object>{
          'pad.idle.glow': const Color(0xFF000000),
        }),
        throwsArgumentError,
      );
    });

    test('JSON round trip', () {
      final UpSkin skin = UpSkin(
        id: 'mine',
        name: 'Mine',
        baseId: 'neon',
        overrides: UpSemanticOverrides(<String, Object>{
          'surface.app': const Color(0x80112233),
          'pad.idle.glow': 0.5,
          'brand.background': const UpGradient(
            colors: <Color>[Color(0xFF000000), Color(0xFFFFFFFF)],
            stops: <double>[0, 1],
          ),
        }),
      );
      final String encoded = skin.encode();
      expect(encoded, contains('"surface.app":"#11223380"'));
      final UpSkin decoded = UpSkin.decode(encoded);
      expect(decoded, skin);
      expect(UpTheme.fromSkin(decoded).colors.padIdleGlow, 0.5);
    });

    test('unknown keys are skipped and reported', () {
      final List<String> unknown = <String>[];
      final UpSemanticOverrides o = UpSemanticOverrides.fromJson(
        <String, Object?>{'future.token': '#FFFFFF', 'text.primary': '#000000'},
        onUnknownKey: unknown.add,
      );
      expect(unknown, <String>['future.token']);
      expect(o.values.keys, <String>['text.primary']);
      expect(
        () => UpSemanticOverrides.fromJson(<String, Object?>{
          'text.primary': 'red',
        }),
        throwsFormatException,
      );
    });

    test('diff recovers the overrides', () {
      final UpSemantic base = UpThemes.neon.colors;
      final UpSemantic edited = base.copyWith(
        textPrimary: const Color(0xFF00FF00),
      );
      expect(UpSemanticOverrides.diff(base, edited).values, <String, Object>{
        'text.primary': const Color(0xFF00FF00),
      });
    });
  });

  group('helpers', () {
    test('glow shadows scale with intensity and vanish at 0', () {
      final List<BoxShadow> s = UpPadTokens.glowPressed.shadows(
        const Color(0xFFFF0000),
        intensity: 0.5,
      );
      expect(s, hasLength(UpPadTokens.glowPressed.layers.length));
      expect(
        s.first.color.a,
        closeTo(UpPadTokens.glowPressed.layers.first.opacity * 0.5, 0.01),
      );
      expect(
        UpPadTokens.glowPressed.shadows(const Color(0xFFFF0000), intensity: 0),
        isEmpty,
      );
    });

    test(
      'typography falls back to bundled Montserrat until Uni Sans loads',
      () {
        UpFonts.debugReset();
        final TextStyle title = UpThemes.neon.text[UpTextRole.title];
        expect(title.fontFamily, 'packages/up_tokens/Montserrat');
        expect(title.fontWeight, FontWeight.w800);
        expect(title.color, UpThemes.neon.colors.textPrimary);
        expect(UpThemes.neon.text.format(UpTextRole.title, 'Songs'), 'SONGS');
        expect(UpThemes.neon.text.format(UpTextRole.body, 'Songs'), 'Songs');
      },
    );

    test('colour codec', () {
      expect(UpColorCodec.encode(const Color(0xFF0A0B0C)), '#0A0B0C');
      expect(UpColorCodec.decode('#0A0B0C7F'), const Color(0x7F0A0B0C));
      expect(() => UpColorCodec.decode('#XYZ'), throwsFormatException);
    });

    testWidgets('UpTheme.of reads the extension', (WidgetTester tester) async {
      late UpTheme seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: UpThemes.light.toThemeData(),
          home: Builder(
            builder: (BuildContext context) {
              seen = UpTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen.id, 'light');
    });
  });
}
