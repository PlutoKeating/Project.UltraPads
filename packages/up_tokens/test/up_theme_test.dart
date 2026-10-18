import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tokens/up_tokens.dart';

void main() {
  group('generated tokens', () {
    test('calibrated values reach Dart', () {
      // Reference design values.
      final UpSemantic c = UpThemes.neon.colors;
      expect(c.surfacePads, const Color(0xFF242B2E));
      expect(c.surfacePage, const Color(0xFF262B2F));
      expect(c.surfaceRaised, const Color(0xFF2C3336));
      expect(c.surfaceKitEditor, const Color(0xFFEE4286));
      expect(c.accentPrimary, const Color(0xFFFD1A68));
      expect(c.padShapeRadiusRatio, closeTo(0.10, 1e-9));
      expect(c.padRole(3).mid, const Color(0xFF00CBF7));
      expect(c.padRole(1).mid, const Color(0xFFEB7F00));
      expect(c.padRole(2).mid, const Color(0xFF00C200));
      expect(c.padRole(0).mid, const Color(0xFFF73470));
      expect(c.padPressedFlashOpacity, closeTo(0.8, 1e-9));
      expect(UpPadGridTokens.columns * UpPadGridTokens.rows, 12);
      expect(UpPadTokens.gap, 2);
      expect(UpPadGridTokens.bankSwitch, const Duration(milliseconds: 200));
      expect(UpPadTokens.pressRelease, const Duration(milliseconds: 100));
      expect(UpPadTokens.loopRevolution, const Duration(milliseconds: 1200));
      expect(UpPadTokens.loopFlashHalf, const Duration(milliseconds: 600));
      expect(UpSheetTokens.enter, const Duration(milliseconds: 400));
      expect(UpPadTokens.pressCurve, UpEasings.quadOut);
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

  group('skin presets', () {
    test('16 original skins in panel order, all resolvable', () {
      expect(UpSkinPresets.all, hasLength(16));
      expect(UpSkinPresets.all.first.id, 'default');
      expect(UpSkinPresets.all.last.id, 'halloween');
      for (final UpSkinPreset p in UpSkinPresets.all) {
        final UpTheme t = p.toTheme();
        expect(t.baseId, p.baseId, reason: p.id);
        expect(p.nameKey, startsWith('skinPreset'));
      }
    });

    test('preset values come from the reference design', () {
      final UpSemantic circle = UpSkinPresets.byId('circle')!.toTheme().colors;
      expect(circle.padShapeRadiusRatio, 0.5);
      expect(circle.padPressedScale, 0.9);
      expect(circle.padRole(3).mid, const Color(0xFF04C9E2));
      expect(circle.padRole(3).pressed, const Color(0xFFC2F2FC));
      final UpSemantic number = UpSkinPresets.byId('number')!.toTheme().colors;
      expect(number.padShowNumber, 1);
      expect(UpSkinPresets.byId('nope'), isNull);
    });

    test('preset -> skin JSON round trip keeps the font set', () {
      final UpSkin skin = UpSkinPresets.byId(
        'polished',
      )!.toSkin(fontSet: UpFontSet.uniSans);
      final UpSkin back = UpSkin.decode(skin.encode());
      expect(back, skin);
      expect(back.fontSet, UpFontSet.uniSans);
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

    test('typography uses bundled Open Sans', () {
      UpFonts.debugReset();
      final TextStyle title = UpThemes.neon.text[UpTextRole.title];
      expect(title.fontFamily, 'packages/up_tokens/Open Sans');
      expect(title.fontWeight, FontWeight.w800);
      expect(title.fontSize, 17.5);
      expect(title.color, UpThemes.neon.colors.textPrimary);
      expect(UpThemes.neon.text.format(UpTextRole.title, 'Songs'), 'SONGS');
      expect(UpThemes.neon.text.format(UpTextRole.body, 'Songs'), 'Songs');
      // Uni Sans requested but not injected -> still Open Sans.
      expect(
        UpThemes.neon
            .withFontSet(UpFontSet.uniSans)
            .text[UpTextRole.title]
            .fontFamily,
        'packages/up_tokens/Open Sans',
      );
    });

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
