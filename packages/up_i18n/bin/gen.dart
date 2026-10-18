// Regenerates lib/src/generated from the ARB files, then runs the checker.
//
//   dart run up_i18n:gen
import 'dart:io';

import 'package:up_i18n/src/tooling/arb_tools.dart';

Future<void> main() async {
  final String root = packageRoot();
  final int code = await runGenL10n(root);
  if (code != 0) {
    exitCode = code;
    return;
  }
  final List<ArbIssue> errors = checkArbs(
    readArbDir('$root/lib/l10n'),
  ).where((ArbIssue i) => i.isError).toList();
  errors.forEach(stderr.writeln);
  if (errors.isNotEmpty) exitCode = 1;
}
