// Scaffolds a new language.
//
//   dart run up_i18n:add_locale <code>     e.g. ja, pt-BR, zh-Hant
//
// 1. copies app_en.arb -> app_<code>.arb (messages in English, marked pending)
// 2. regenerates UpL10n (supportedLocales now includes the new locale)
// 3. prints the remaining manual steps.
import 'dart:io';

import 'package:up_i18n/src/tooling/arb_tools.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1 || args.first.startsWith('-')) {
    stderr.writeln(
      'usage: dart run up_i18n:add_locale <code>   (e.g. ja, pt-BR, zh-Hant)',
    );
    exitCode = 64;
    return;
  }
  final String root = packageRoot();
  final String path;
  try {
    path = createLocaleArb('$root/lib/l10n', args.first);
  } on Object catch (e) {
    stderr.writeln('add_locale: $e');
    exitCode = 1;
    return;
  }
  stdout.writeln('created $path');
  final int code = await runGenL10n(root);
  if (code != 0) {
    exitCode = code;
    return;
  }
  stdout.writeln('''
next steps:
  1. translate every message in ${path.split(Platform.pathSeparator).last}
     (start with localeNativeName / localeEnglishName), then delete "@@x-status"
  2. dart run up_i18n:check --strict      # no missing keys, no untranslated warnings
  3. iOS/macOS: add the code to CFBundleLocalizations in Info.plist
''');
}
