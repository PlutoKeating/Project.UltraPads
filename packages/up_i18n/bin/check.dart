// Validates ARB files: missing / extra keys, placeholder mismatches, key
// naming. Untranslated (identical) strings are warnings unless --strict.
//
//   dart run up_i18n:check [--strict]
import 'dart:io';

import 'package:up_i18n/src/tooling/arb_tools.dart';

void main(List<String> args) {
  final bool strict = args.contains('--strict');
  final String root = packageRoot();
  final List<ArbFile> files = readArbDir('$root/lib/l10n');
  final List<ArbIssue> issues = checkArbs(files);
  for (final ArbIssue i in issues) {
    (i.isError ? stderr : stdout).writeln(i);
  }
  final int errors = issues.where((ArbIssue i) => i.isError).length;
  final int warnings = issues.length - errors;
  stdout.writeln(
    'up_i18n: ${files.length} locales (${files.map((ArbFile f) => f.locale).join(', ')}), '
    '${files.first.keys.length} keys, $errors errors, $warnings warnings',
  );
  if (errors > 0 || (strict && warnings > 0)) exitCode = 1;
}
