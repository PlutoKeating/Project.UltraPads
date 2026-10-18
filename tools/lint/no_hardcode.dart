// UltraPads "no hard-coded design values / copy" lint.
//
//   dart run tools/lint/no_hardcode.dart            # scan default UI roots
//   dart run tools/lint/no_hardcode.dart path ...   # scan given files/dirs
//   dart run tools/lint/no_hardcode.dart --json     # machine-readable output
//
// Reports colour literals, Material colour constants, numeric radii /
// durations / insets / font sizes and literal UI copy. Values must come from
// `package:up_tokens` (UpTheme.of(context), Up*Tokens) and copy from
// `package:up_i18n` (UpL10n.of(context)).
//
// Suppress a single finding with a reason, on the same line or on a
// comment-only line directly above:
//   // up-lint-ignore: <reason>
// An ignore without a reason is itself a violation.
//
// Exit code: 0 = clean, 1 = violations, 64 = usage error.
import 'dart:convert';
import 'dart:io';

/// Directories scanned when no path is given (relative to the repo root).
const List<String> defaultRoots = <String>[
  'packages/up_ui/lib',
  'packages/up_fx/lib',
  'app/ultrapads/lib',
];

/// Generated code is never linted.
bool isExcluded(String path) {
  final String p = path.replaceAll('\\', '/');
  return p.contains('/lib/src/rust/') ||
      p.contains('/generated/') ||
      p.endsWith('.g.dart') ||
      p.endsWith('.freezed.dart') ||
      p.endsWith('.gr.dart') ||
      p.endsWith('.mocks.dart') ||
      p.endsWith('frb_generated.dart') ||
      p.endsWith('frb_generated.io.dart') ||
      p.endsWith('frb_generated.web.dart');
}

/// `Colors.<name>` members that are not design decisions.
const Set<String> allowedMaterialColors = <String>{'transparent'};

const String ignoreMarker = 'up-lint-ignore';

class Violation {
  Violation(
    this.path,
    this.line,
    this.column,
    this.rule,
    this.message,
    this.source,
  );

  final String path;
  final int line;
  final int column;
  final String rule;
  final String message;
  final String source;

  Map<String, Object> toJson() => <String, Object>{
    'path': path,
    'line': line,
    'column': column,
    'rule': rule,
    'message': message,
  };

  @override
  String toString() =>
      '$path:$line:$column  [$rule] $message\n    ${source.trim()}';
}

class _Rule {
  const _Rule(
    this.id,
    this.pattern,
    this.message, {
    this.onStrings = false,
    this.accept,
  });

  final String id;
  final RegExp pattern;
  final String message;

  /// Match against comment-stripped code that still contains string literals
  /// (otherwise string contents are blanked out first).
  final bool onStrings;

  /// Optional extra predicate on the match.
  final bool Function(RegExpMatch m)? accept;
}

final RegExp _num = RegExp(r'(?<![\w.$])-?(?:\d+\.?\d*|\.\d+)(?![\w.])');
final RegExp _letters = RegExp(r'[A-Za-z぀-ヿ㐀-鿿가-힯]');

bool _hasNonZeroNumber(String args) {
  for (final RegExpMatch m in _num.allMatches(args)) {
    if (double.tryParse(m.group(0)!) != 0) return true;
  }
  return false;
}

/// Literal copy = has a letter after removing `$name` / `${...}` interpolation.
bool _isCopy(String literalBody) {
  final String stripped = literalBody
      .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
      .replaceAll(RegExp(r'\$[A-Za-z_]\w*'), '');
  return _letters.hasMatch(stripped);
}

final List<_Rule> _rules = <_Rule>[
  _Rule(
    'color-literal',
    RegExp(r'\bColor\s*\(\s*0[xX]'),
    'Colour literal; use a semantic colour from UpTheme.of(context).colors',
  ),
  _Rule(
    'color-literal',
    RegExp(r'\bColor\.(?:fromARGB|fromRGBO|from)\s*\('),
    'Colour constructor; use a semantic colour from UpTheme.of(context).colors',
  ),
  _Rule(
    'material-color',
    RegExp(r'\b(?:Colors|CupertinoColors)\.([A-Za-z_]\w*)'),
    'Material colour constant; use a semantic colour token',
    accept: (RegExpMatch m) => !allowedMaterialColors.contains(m.group(1)),
  ),
  _Rule(
    'radius-literal',
    RegExp(r'\b(?:BorderRadius|Radius)\.circular\s*\(\s*-?[\d.]'),
    'Numeric radius; use a radius token (Up*Tokens.radius / UpRadii)',
  ),
  _Rule(
    'radius-literal',
    RegExp(r'(?<![\w)\]])\.circular\s*\(\s*-?[\d.]'),
    'Numeric radius (dot shorthand); use a radius token',
  ),
  _Rule(
    'duration-literal',
    RegExp(
      r'\bDuration\s*\(\s*(?:milliseconds|microseconds|seconds|minutes)\s*:\s*\d',
    ),
    'Numeric duration; use UpDurations / Up*Tokens motion tokens',
  ),
  _Rule(
    'edge-insets-literal',
    RegExp(
      r'\bEdgeInsets(?:Directional)?\.(?:all|symmetric|only|fromLTRB|fromSTEB)\s*\(([^()]*)\)',
    ),
    'Numeric insets; use spacing tokens (UpSpacing / Up*Tokens.padding)',
    accept: (RegExpMatch m) => _hasNonZeroNumber(m.group(1)!),
  ),
  _Rule(
    'edge-insets-literal',
    RegExp(
      r'(?<![\w)\]])\.(?:all|symmetric|only|fromLTRB|fromSTEB)\s*\(([^()]*)\)',
    ),
    'Numeric insets (dot shorthand); use spacing tokens',
    accept: (RegExpMatch m) => _hasNonZeroNumber(m.group(1)!),
  ),
  _Rule(
    'font-size-literal',
    RegExp(r'\bfontSize\s*:\s*-?[\d.]'),
    'Numeric fontSize; use a typography role (UpTheme.of(context).text[UpTextRole.x])',
  ),
  _Rule(
    'text-literal',
    RegExp(
      r'''\b(?:Text|SelectableText)\s*\(\s*(?:r)?(['"])((?:\\.|(?!\1).)*)\1''',
    ),
    'Literal UI copy; use UpL10n.of(context).<key>',
    onStrings: true,
    accept: (RegExpMatch m) => _isCopy(m.group(2)!),
  ),
  _Rule(
    'text-literal',
    RegExp(
      r'''\b(?:TextSpan\s*\(\s*text|tooltip|semanticsLabel|semanticLabel|hintText|labelText|helperText|errorText)\s*:\s*(?:r)?(['"])((?:\\.|(?!\1).)*)\1''',
    ),
    'Literal UI copy; use UpL10n.of(context).<key>',
    onStrings: true,
    accept: (RegExpMatch m) => _isCopy(m.group(2)!),
  ),
];

/// Returns (codeWithStrings, codeWithoutStrings): comments are replaced by
/// spaces in both; string contents are blanked in the second. Offsets and
/// line breaks are preserved.
(String, String) maskSource(String src) {
  final StringBuffer withStrings = StringBuffer();
  final StringBuffer noStrings = StringBuffer();
  void put(String c, {required bool comment, required bool inString}) {
    final String blank = c == '\n' ? '\n' : ' ';
    withStrings.write(comment ? blank : c);
    noStrings.write(comment || inString ? blank : c);
  }

  int i = 0;
  final int n = src.length;
  int blockDepth = 0;
  while (i < n) {
    final String c = src[i];
    final String next = i + 1 < n ? src[i + 1] : '';
    if (blockDepth > 0) {
      if (c == '/' && next == '*') {
        blockDepth++;
        put(c, comment: true, inString: false);
        put(next, comment: true, inString: false);
        i += 2;
      } else if (c == '*' && next == '/') {
        blockDepth--;
        put(c, comment: true, inString: false);
        put(next, comment: true, inString: false);
        i += 2;
      } else {
        put(c, comment: true, inString: false);
        i++;
      }
      continue;
    }
    if (c == '/' && next == '/') {
      while (i < n && src[i] != '\n') {
        put(src[i], comment: true, inString: false);
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      blockDepth = 1;
      put(c, comment: true, inString: false);
      put(next, comment: true, inString: false);
      i += 2;
      continue;
    }
    final bool raw =
        c == 'r' &&
        (next == "'" || next == '"') &&
        (i == 0 || !RegExp(r'\w').hasMatch(src[i - 1]));
    if (c == "'" || c == '"' || raw) {
      if (raw) {
        put(c, comment: false, inString: false);
        i++;
      }
      final String q = src[i];
      final bool triple = src.startsWith('$q$q$q', i);
      final String close = triple ? '$q$q$q' : q;
      for (int k = 0; k < close.length; k++) {
        put(q, comment: false, inString: false);
      }
      i += close.length;
      while (i < n) {
        if (!raw && src[i] == '\\' && i + 1 < n) {
          put(src[i], comment: false, inString: true);
          put(src[i + 1], comment: false, inString: true);
          i += 2;
          continue;
        }
        if (src.startsWith(close, i)) {
          for (int k = 0; k < close.length; k++) {
            put(q, comment: false, inString: false);
          }
          i += close.length;
          break;
        }
        if (!triple && src[i] == '\n') break; // unterminated: recover
        put(src[i], comment: false, inString: true);
        i++;
      }
      continue;
    }
    put(c, comment: false, inString: false);
    i++;
  }
  return (withStrings.toString(), noStrings.toString());
}

/// Scans one Dart source. [path] is only used for reporting.
List<Violation> scanSource(String path, String source) {
  final List<String> lines = const LineSplitter().convert(source);
  final (String withStrings, String noStrings) = maskSource(source);
  final List<int> lineStarts = <int>[0];
  for (int i = 0; i < source.length; i++) {
    if (source[i] == '\n') lineStarts.add(i + 1);
  }
  int lineOf(int offset) {
    int lo = 0;
    int hi = lineStarts.length - 1;
    while (lo < hi) {
      final int mid = (lo + hi + 1) >> 1;
      if (lineStarts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  final List<Violation> out = <Violation>[];
  final RegExp ignoreRe = RegExp('//\\s*$ignoreMarker\\s*(?::\\s*(.*))?\$');

  // Lines covered by a valid ignore; flag ignores without a reason.
  final Set<int> ignored = <int>{};
  for (int l = 0; l < lines.length; l++) {
    final RegExpMatch? m = ignoreRe.firstMatch(lines[l]);
    if (m == null) continue;
    final String reason = (m.group(1) ?? '').trim();
    if (reason.isEmpty) {
      out.add(
        Violation(
          path,
          l + 1,
          m.start + 1,
          'ignore-without-reason',
          'up-lint-ignore needs a reason: `// $ignoreMarker: <why>`',
          lines[l],
        ),
      );
      continue;
    }
    ignored.add(l);
    if (lines[l].trim().startsWith('//') && l + 1 < lines.length)
      ignored.add(l + 1);
  }

  final Set<String> seen = <String>{};
  for (final _Rule rule in _rules) {
    final String text = rule.onStrings ? withStrings : noStrings;
    for (final RegExpMatch m in rule.pattern.allMatches(text)) {
      if (rule.accept != null && !rule.accept!(m)) continue;
      final int line = lineOf(m.start);
      if (ignored.contains(line)) continue;
      final int col = m.start - lineStarts[line] + 1;
      if (!seen.add('$line:$col:${rule.id}')) continue;
      out.add(
        Violation(path, line + 1, col, rule.id, rule.message, lines[line]),
      );
    }
  }
  out.sort(
    (Violation a, Violation b) => a.line != b.line
        ? a.line.compareTo(b.line)
        : a.column.compareTo(b.column),
  );
  return out;
}

/// Dart files under [roots] (files or directories), minus generated code.
List<File> collectFiles(List<String> roots) {
  final List<File> files = <File>[];
  for (final String r in roots) {
    final FileSystemEntityType t = FileSystemEntity.typeSync(r);
    if (t == FileSystemEntityType.file) {
      if (r.endsWith('.dart') && !isExcluded(r)) files.add(File(r));
    } else if (t == FileSystemEntityType.directory) {
      files.addAll(
        Directory(r)
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((File f) => f.path.endsWith('.dart') && !isExcluded(f.path)),
      );
    }
  }
  files.sort((File a, File b) => a.path.compareTo(b.path));
  return files;
}

String _repoRoot() {
  Directory d = Directory.current;
  for (int i = 0; i < 8; i++) {
    if (File('${d.path}/justfile').existsSync() &&
        Directory('${d.path}/packages').existsSync()) {
      return d.path;
    }
    if (d.parent.path == d.path) break;
    d = d.parent;
  }
  return Directory.current.path;
}

void main(List<String> args) {
  final bool asJson = args.contains('--json');
  if (args.contains('-h') || args.contains('--help')) {
    stdout.writeln(
      'usage: dart run tools/lint/no_hardcode.dart [--json] [path ...]',
    );
    return;
  }
  final List<String> paths = args
      .where((String a) => !a.startsWith('--'))
      .toList();
  final String root = _repoRoot();
  final List<String> roots = paths.isNotEmpty
      ? paths
      : <String>[for (final String r in defaultRoots) '$root/$r'];

  final List<File> files = collectFiles(roots);
  final List<Violation> all = <Violation>[];
  for (final File f in files) {
    final String rel = f.path.startsWith('$root/')
        ? f.path.substring(root.length + 1)
        : f.path;
    all.addAll(scanSource(rel, f.readAsStringSync()));
  }

  if (asJson) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert(<String, Object>{
        'files': files.length,
        'violations': <Object>[for (final Violation v in all) v.toJson()],
      }),
    );
  } else {
    for (final Violation v in all) {
      stdout.writeln(v);
    }
    stdout.writeln(
      all.isEmpty
          ? 'no_hardcode: ${files.length} files clean'
          : 'no_hardcode: ${all.length} violation(s) in ${files.length} files',
    );
  }
  if (all.isNotEmpty) exitCode = 1;
}
