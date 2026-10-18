import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:up_i18n/up_i18n.dart';

void main() {
  group('UpLocales.resolve', () {
    test('exact and language matches', () {
      expect(
        UpLocales.resolve(const <Locale>[Locale('zh')]),
        const Locale('zh'),
      );
      expect(
        UpLocales.resolve(const <Locale>[Locale('zh', 'CN')]),
        const Locale('zh'),
      );
      expect(
        UpLocales.resolve(const <Locale>[
          Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
            countryCode: 'TW',
          ),
        ]),
        const Locale('zh'),
      );
      expect(
        UpLocales.resolve(const <Locale>[Locale('en', 'GB')]),
        const Locale('en'),
      );
    });

    test('falls back through the preference list, then to English', () {
      expect(
        UpLocales.resolve(const <Locale>[Locale('fr'), Locale('zh')]),
        const Locale('zh'),
      );
      expect(
        UpLocales.resolve(const <Locale>[Locale('fr'), Locale('de')]),
        UpLocales.fallback,
      );
      expect(UpLocales.resolve(null), UpLocales.fallback);
    });

    test('prefers script/region specific entries when they exist', () {
      const List<Locale> sup = <Locale>[
        Locale('zh'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        Locale('pt'),
        Locale('pt', 'BR'),
      ];
      expect(
        UpLocales.resolve(const <Locale>[
          Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
            countryCode: 'HK',
          ),
        ], supported: sup),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
      expect(
        UpLocales.resolve(const <Locale>[Locale('pt', 'BR')], supported: sup),
        const Locale('pt', 'BR'),
      );
      expect(
        UpLocales.resolve(const <Locale>[Locale('pt', 'PT')], supported: sup),
        const Locale('pt'),
      );
    });

    test('parse / toTag round trip', () {
      expect(
        UpLocales.parse('zh_Hant_TW'),
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'TW',
        ),
      );
      expect(UpLocales.parse('pt-br'), const Locale('pt', 'BR'));
      expect(UpLocales.toTag(UpLocales.parse('zh-Hant-TW')), 'zh-Hant-TW');
    });

    test('lookup without context falls back to English', () {
      expect(UpLocales.lookup(const Locale('zh')).commonOk, '确定');
      expect(UpLocales.lookup(const Locale('fr')).commonOk, 'OK');
    });
  });

  group('LocaleController', () {
    test('follows system by default and persists manual choice', () async {
      final InMemoryLocaleStore store = InMemoryLocaleStore();
      final LocaleController c = LocaleController(store: store);
      await c.load();
      expect(c.followsSystem, isTrue);
      expect(c.resolve(const <Locale>[Locale('zh', 'CN')]), const Locale('zh'));

      int notified = 0;
      c.addListener(() => notified++);
      await c.setLocale(const Locale('en', 'US'));
      expect(c.locale, const Locale('en'));
      expect(store.value, 'en');
      expect(c.resolve(const <Locale>[Locale('zh')]), const Locale('en'));
      expect(notified, 1);

      final LocaleController restored = LocaleController(store: store);
      await restored.load();
      expect(restored.locale, const Locale('en'));

      await c.followSystem();
      expect(store.value, isNull);
      expect(c.followsSystem, isTrue);
    });

    test('rejects unsupported locales and ignores stale stored tags', () async {
      final LocaleController c = LocaleController(
        store: InMemoryLocaleStore('fr'),
      );
      await c.load();
      expect(c.followsSystem, isTrue);
      expect(() => c.setLocale(const Locale('fr')), throwsArgumentError);
    });
  });

  group('messages', () {
    test('ICU plural, select, number and date placeholders', () async {
      // Inside an app GlobalMaterialLocalizations does this; context-free use must too.
      await initializeDateFormatting();
      final UpL10n en = lookupUpL10n(const Locale('en'));
      final UpL10n zh = lookupUpL10n(const Locale('zh'));
      expect(en.libraryKitCount(0), 'No kits');
      expect(en.libraryKitCount(1), '1 kit');
      expect(en.libraryKitCount(5), '5 kits');
      expect(zh.libraryKitCount(5), '5 个音色包');
      expect(en.onboardingPlayStyle('jam'), 'Jam with friends');
      expect(en.onboardingPlayStyle('whatever'), 'Just exploring');
      expect(en.performSpeed(1), 'Speed 1.0×');
      expect(
        en.worksRecordedOn(DateTime(2026, 10, 18)),
        'Recorded Oct 18, 2026',
      );
      expect(zh.performLoadingKit('Sunset'), '正在加载 Sunset…');
    });

    testWidgets('UpL10n.of and context.l10n inside MaterialApp', (
      WidgetTester tester,
    ) async {
      late String a;
      late String b;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: UpL10n.supportedLocales,
          localizationsDelegates: UpL10n.localizationsDelegates,
          localeListResolutionCallback: UpLocales.resolutionCallback,
          home: Builder(
            builder: (BuildContext context) {
              a = UpL10n.of(context).navSettings;
              b = context.l10n.localeNativeName;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(a, '设置');
      expect(b, '简体中文');
    });
  });
}
