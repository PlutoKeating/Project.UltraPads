// Unit tests for tools/lint/no_hardcode.dart. Dependency-free on purpose (the
// workspace root has no `test` package):
//   dart run tools/lint/test/no_hardcode_test.dart
import 'dart:io';

import '../no_hardcode.dart';

int _failures = 0;
int _passed = 0;

void check(String name, bool ok, [Object? detail]) {
  if (ok) {
    _passed++;
  } else {
    _failures++;
    stderr.writeln('FAIL $name${detail == null ? '' : '\n  $detail'}');
  }
}

List<String> rules(String src) =>
    scanSource('t.dart', src).map((Violation v) => v.rule).toList();

void expectRules(String name, String src, List<String> expected) {
  final List<String> got = rules(src);
  check(
    name,
    got.join(',') == expected.join(','),
    'expected $expected, got $got',
  );
}

void main() {
  // colours
  expectRules('Color literal', "final c = Color(0xFF112233);", <String>[
    'color-literal',
  ]);
  expectRules('const Color literal', "const c = Color( 0x80FFFFFF );", <String>[
    'color-literal',
  ]);
  expectRules(
    'Color.fromARGB',
    "final c = Color.fromARGB(255, 1, 2, 3);",
    <String>['color-literal'],
  );
  expectRules('Colors.red', "final c = Colors.red;", <String>[
    'material-color',
  ]);
  expectRules('Colors.white70', "final c = Colors.white70;", <String>[
    'material-color',
  ]);
  expectRules(
    'CupertinoColors',
    "final c = CupertinoColors.systemBlue;",
    <String>['material-color'],
  );
  expectRules(
    'Colors.transparent allowed',
    "final c = Colors.transparent;",
    <String>[],
  );
  expectRules(
    'token colour ok',
    "final c = UpTheme.of(context).colors.surfaceApp;",
    <String>[],
  );

  // shape / motion / spacing / type
  expectRules(
    'BorderRadius.circular(8)',
    "r: BorderRadius.circular(8),",
    <String>['radius-literal'],
  );
  expectRules('Radius.circular(4.5)', "r: Radius.circular(4.5),", <String>[
    'radius-literal',
  ]);
  expectRules(
    'dot shorthand circular',
    "borderRadius: .circular(12),",
    <String>['radius-literal'],
  );
  expectRules(
    'token radius ok',
    "r: BorderRadius.circular(UpChipTokens.radius),",
    <String>[],
  );
  expectRules(
    'Duration(milliseconds: 300)',
    "d: const Duration(milliseconds: 300),",
    <String>['duration-literal'],
  );
  expectRules('Duration(seconds: 1)', "d: Duration(seconds: 1),", <String>[
    'duration-literal',
  ]);
  expectRules('Duration token ok', "d: UpDurations.slow,", <String>[]);
  expectRules('Duration.zero ok', "d: Duration.zero,", <String>[]);
  expectRules('EdgeInsets.all(8)', "p: EdgeInsets.all(8),", <String>[
    'edge-insets-literal',
  ]);
  expectRules(
    'EdgeInsets.symmetric mixed',
    "p: EdgeInsets.symmetric(horizontal: UpSpacing.md, vertical: 4),",
    <String>['edge-insets-literal'],
  );
  expectRules(
    'EdgeInsets multi-line',
    "p: EdgeInsets.only(\n  left: UpSpacing.md,\n  top: 6,\n),",
    <String>['edge-insets-literal'],
  );
  expectRules('EdgeInsets dot shorthand', "padding: .all(16),", <String>[
    'edge-insets-literal',
  ]);
  expectRules(
    'EdgeInsets tokens ok',
    "p: EdgeInsets.all(UpSpacing.md),",
    <String>[],
  );
  expectRules('EdgeInsets zero ok', "p: EdgeInsets.only(left: 0),", <String>[]);
  expectRules('fontSize literal', "style: TextStyle(fontSize: 14),", <String>[
    'font-size-literal',
  ]);
  expectRules(
    'fontSize token ok',
    "style: TextStyle(fontSize: UpFontSizes.md),",
    <String>[],
  );

  // copy
  expectRules("Text('…') English", "Text('Hello'),", <String>['text-literal']);
  expectRules('Text("…") Chinese', 'const Text("设置"),', <String>[
    'text-literal',
  ]);
  expectRules('Text with escaped quote', r"Text('it\'s'),", <String>[
    'text-literal',
  ]);
  expectRules('Text numeric only ok', "Text('42'),", <String>[]);
  expectRules('Text interpolation only ok', r"Text('$count'),", <String>[]);
  expectRules('Text interpolation + copy', r"Text('$count kits'),", <String>[
    'text-literal',
  ]);
  expectRules('Text l10n ok', "Text(UpL10n.of(context).commonOk),", <String>[]);
  expectRules('Text on next line', "Text(\n  'Songs',\n),", <String>[
    'text-literal',
  ]);
  expectRules('tooltip literal', "IconButton(tooltip: 'Close')", <String>[
    'text-literal',
  ]);
  expectRules('TextSpan literal', "TextSpan(text: 'Tap')", <String>[
    'text-literal',
  ]);

  // comments / strings are not code
  expectRules(
    'line comment ignored',
    "// Color(0xFF000000) Colors.red Text('x')",
    <String>[],
  );
  expectRules(
    'doc comment ignored',
    "/// Example: `BorderRadius.circular(8)`",
    <String>[],
  );
  expectRules(
    'block comment ignored',
    "/* Duration(milliseconds: 3)\n Colors.red */ final a = 1;",
    <String>[],
  );
  expectRules(
    'pattern inside string ignored',
    "final s = 'Colors.red Color(0xFF000000)';",
    <String>[],
  );

  // ignores
  expectRules(
    'same-line ignore',
    "final c = Colors.black; // up-lint-ignore: golden test backdrop",
    <String>[],
  );
  expectRules(
    'previous-line ignore',
    "// up-lint-ignore: debug overlay only\nfinal c = Color(0xFFFF0000);",
    <String>[],
  );
  expectRules(
    'ignore needs reason',
    "final c = Colors.black; // up-lint-ignore",
    <String>['material-color', 'ignore-without-reason'],
  );
  expectRules(
    'ignore covers one line only',
    "// up-lint-ignore: x\nfinal a = 1;\nfinal c = Colors.red;",
    <String>['material-color'],
  );

  // positions
  final List<Violation> v = scanSource(
    'a.dart',
    "void f() {\n  final c = Colors.red;\n}",
  );
  check(
    'line/column reported',
    v.length == 1 && v.first.line == 2 && v.first.column == 13,
    v,
  );

  // exclusions
  check(
    'rust bindings excluded',
    isExcluded('app/ultrapads/lib/src/rust/api/simple.dart'),
  );
  check('generated excluded', isExcluded('packages/up_ui/lib/src/foo.g.dart'));
  check(
    'frb excluded',
    isExcluded('app/ultrapads/lib/src/rust/frb_generated.dart'),
  );
  check('ui source included', !isExcluded('packages/up_ui/lib/src/pad.dart'));

  // collectFiles on a temp tree
  final Directory tmp = Directory.systemTemp.createTempSync('no_hardcode');
  try {
    File('${tmp.path}/lib/a.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync("final c = Colors.red;");
    File('${tmp.path}/lib/src/rust/b.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync("final c = Colors.red;");
    final List<File> files = collectFiles(<String>[tmp.path]);
    check(
      'collectFiles skips generated',
      files.length == 1 && files.first.path.endsWith('a.dart'),
      files,
    );
  } finally {
    tmp.deleteSync(recursive: true);
  }

  stdout.writeln('no_hardcode tests: $_passed passed, $_failures failed');
  if (_failures > 0) exitCode = 1;
}
