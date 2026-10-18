import 'package:flutter/widgets.dart';

import 'locales.dart';

/// Persistence port for the user's language choice. The app supplies an
/// implementation (shared_preferences, engine settings, ...); the stored value
/// is a BCP-47 tag or null for "follow system".
abstract interface class LocaleStore {
  Future<String?> read();
  Future<void> write(String? languageTag);
}

/// Non-persistent store (tests, previews).
class InMemoryLocaleStore implements LocaleStore {
  InMemoryLocaleStore([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? languageTag) async => value = languageTag;
}

/// Holds the user's language preference: either follow the system or a
/// manually chosen supported locale.
///
/// ```dart
/// MaterialApp(
///   locale: controller.locale,                 // null = follow system
///   supportedLocales: UpL10n.supportedLocales,
///   localizationsDelegates: UpL10n.localizationsDelegates,
///   localeListResolutionCallback: UpLocales.resolutionCallback,
/// )
/// ```
class LocaleController extends ChangeNotifier {
  LocaleController({required LocaleStore store, List<Locale>? supported})
    : _store = store,
      _supported = supported ?? UpLocales.supported;

  final LocaleStore _store;
  final List<Locale> _supported;
  Locale? _locale;

  /// Manually selected locale, or null when following the system.
  Locale? get locale => _locale;

  bool get followsSystem => _locale == null;

  List<Locale> get supported => List<Locale>.unmodifiable(_supported);

  /// Restores the stored choice. Unknown / no-longer-supported tags revert to
  /// "follow system".
  Future<void> load() async {
    final String? tag = await _store.read();
    Locale? next;
    if (tag != null) {
      try {
        next = UpLocales.match(UpLocales.parse(tag), _supported);
      } on FormatException {
        next = null;
      }
    }
    if (next != _locale) {
      _locale = next;
      notifyListeners();
    }
  }

  /// Selects [locale] (must be supported or matchable), or null = system.
  Future<void> setLocale(Locale? locale) async {
    final Locale? next = locale == null
        ? null
        : UpLocales.match(locale, _supported);
    if (locale != null && next == null) {
      throw ArgumentError.value(locale, 'locale', 'Not supported');
    }
    await _store.write(next == null ? null : UpLocales.toTag(next));
    if (next != _locale) {
      _locale = next;
      notifyListeners();
    }
  }

  Future<void> followSystem() => setLocale(null);

  /// Effective locale given the platform preference list.
  Locale resolve(List<Locale> systemLocales) =>
      _locale ?? UpLocales.resolve(systemLocales, supported: _supported);
}
