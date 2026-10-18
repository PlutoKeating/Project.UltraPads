import 'package:flutter/widgets.dart';

import 'generated/up_l10n.dart';

/// Locale utilities shared by [LocaleController] and the app shell.
abstract final class UpLocales {
  /// Used when nothing in the user's preference list is supported.
  static const Locale fallback = Locale('en');

  /// Locales with an ARB file (generated from lib/l10n/app_*.arb).
  static List<Locale> get supported => UpL10n.supportedLocales;

  /// Picks the best supported locale for a preference list (system order).
  ///
  /// For each requested locale, in order: exact match, then same language +
  /// script, then same language + country, then same language. Falls back to
  /// [fallback] (or the first supported locale).
  static Locale resolve(
    Iterable<Locale>? requested, {
    Iterable<Locale>? supported,
  }) {
    final List<Locale> sup = (supported ?? UpLocales.supported).toList(
      growable: false,
    );
    for (final Locale r in requested ?? const <Locale>[]) {
      final Locale? m = match(r, sup);
      if (m != null) return m;
    }
    return sup.contains(fallback) ? fallback : sup.first;
  }

  /// Best supported match for a single locale, or null.
  static Locale? match(Locale r, List<Locale> sup) {
    bool same(Locale a, Locale b) =>
        a.languageCode == b.languageCode &&
        a.scriptCode == b.scriptCode &&
        a.countryCode == b.countryCode;
    for (final Locale s in sup) {
      if (same(s, r)) return s;
    }
    final Iterable<Locale> lang = sup.where(
      (Locale s) => s.languageCode == r.languageCode,
    );
    if (lang.isEmpty) return null;
    if (r.scriptCode != null) {
      for (final Locale s in lang) {
        if (s.scriptCode == r.scriptCode && s.countryCode == null) return s;
      }
    }
    if (r.countryCode != null) {
      for (final Locale s in lang) {
        if (s.countryCode == r.countryCode && s.scriptCode == null) return s;
      }
    }
    for (final Locale s in lang) {
      if (s.scriptCode == null && s.countryCode == null) return s;
    }
    return lang.first;
  }

  /// `zh-Hant-TW`, `pt-BR`, `en`.
  static String toTag(Locale locale) => locale.toLanguageTag();

  /// Parses `zh-Hant-TW`, `zh_Hant_TW`, `pt_BR`, `en`.
  static Locale parse(String tag) {
    final List<String> parts = tag.trim().split(RegExp('[-_]'));
    if (parts.isEmpty || parts.first.isEmpty) {
      throw FormatException('Empty locale tag', tag);
    }
    String? script;
    String? country;
    for (final String p in parts.skip(1)) {
      if (p.length == 4) {
        script = p[0].toUpperCase() + p.substring(1).toLowerCase();
      } else if (p.isNotEmpty) {
        country = p.toUpperCase();
      }
    }
    return Locale.fromSubtags(
      languageCode: parts.first.toLowerCase(),
      scriptCode: script,
      countryCode: country,
    );
  }

  /// Strings for [locale] without a BuildContext (resolved with fallback).
  /// Messages with date placeholders need `initializeDateFormatting()` from
  /// `package:intl/date_symbol_data_local.dart` first (the Material
  /// localization delegates do this automatically inside an app).
  static UpL10n lookup(Locale locale) =>
      lookupUpL10n(resolve(<Locale>[locale]));

  /// For `MaterialApp.localeListResolutionCallback`.
  static Locale resolutionCallback(
    List<Locale>? locales,
    Iterable<Locale> supported,
  ) => resolve(locales, supported: supported);
}

/// `context.l10n.commonOk`
extension UpL10nContext on BuildContext {
  UpL10n get l10n => UpL10n.of(this);
}
