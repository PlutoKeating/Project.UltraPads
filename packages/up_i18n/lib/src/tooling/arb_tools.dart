// Pure-Dart ARB tooling shared by bin/ scripts and tests (no Flutter imports).
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

/// Feature domains a message key must start with (see README "Key naming").
const List<String> arbKeyDomains = <String>[
  'locale',
  'common',
  'nav',
  'perform',
  'library',
  'kitEditor',
  'loadSound',
  'record',
  'works',
  'tutorial',
  'skin',
  'skinEditor',
  'settings',
  'hub',
  'pairing',
  'error',
  'permission',
  'share',
  'a11y',
  'time',
  'unit',
  'onboarding',
];

/// Keys allowed to stay identical to the template in other locales
/// (brand names, units, letters).
const Set<String> arbIdenticalAllowed = <String>{
  'performBankA',
  'performBankB',
  'performTempo',
  'settingsMidi',
  'settingsSampleRateValue',
  'libraryGenreKpop',
  'performPadLabel',
};

const String templateLocale = 'en';

final RegExp _keyPattern = RegExp(r'^[a-z][a-zA-Z0-9]*$');
final RegExp _localePattern = RegExp(
  r'^([a-z]{2,3})(?:_([A-Z][a-z]{3}))?(?:_([A-Z]{2}|[0-9]{3}))?$',
);

/// Normalises `pt-br`, `zh-hant-tw`, `ja` into ARB file form (`pt_BR`,
/// `zh_Hant_TW`, `ja`). Throws [FormatException] for anything else.
String normalizeLocaleCode(String input) {
  final List<String> parts = input.trim().split(RegExp('[-_]'));
  final StringBuffer b = StringBuffer(parts.first.toLowerCase());
  for (final String p in parts.skip(1)) {
    if (p.length == 4) {
      b.write('_${p[0].toUpperCase()}${p.substring(1).toLowerCase()}');
    } else {
      b.write('_${p.toUpperCase()}');
    }
  }
  final String code = b.toString();
  if (!_localePattern.hasMatch(code)) {
    throw FormatException(
      'Invalid locale code (expected e.g. ja, pt_BR, zh_Hant)',
      input,
    );
  }
  return code;
}

class ArbFile {
  ArbFile(this.path, this.data);

  factory ArbFile.read(String path) {
    final Object? json = jsonDecode(File(path).readAsStringSync());
    if (json is! Map<String, Object?>) {
      throw FormatException('ARB root must be an object', path);
    }
    return ArbFile(path, json);
  }

  final String path;
  final Map<String, Object?> data;

  String get locale => (data['@@locale'] as String?) ?? _localeFromName(path);

  /// Message keys (no `@` metadata).
  List<String> get keys => <String>[
    for (final String k in data.keys)
      if (!k.startsWith('@')) k,
  ];

  String message(String key) => data[key]! as String;

  static String _localeFromName(String path) {
    final String name = path.split(Platform.pathSeparator).last;
    return name.substring('app_'.length, name.length - '.arb'.length);
  }
}

/// Argument names used in an ICU message (`{name}`, `{count, plural, ...}`),
/// including arguments nested inside plural/select branches.
Set<String> icuArguments(String message) {
  final _IcuScanner s = _IcuScanner(message);
  s.message(topLevel: true);
  return s.args;
}

class _IcuScanner {
  _IcuScanner(this.src);

  final String src;
  final Set<String> args = <String>{};
  int i = 0;

  bool get done => i >= src.length;

  /// Plain text up to an unmatched `}` (or end at top level).
  void message({bool topLevel = false}) {
    while (!done) {
      final String c = src[i];
      if (c == '{') {
        i++;
        argument();
      } else if (c == '}') {
        if (topLevel) throw FormatException('Unbalanced }', src, i);
        return;
      } else {
        i++;
      }
    }
    if (!topLevel) throw FormatException('Unclosed {', src, i);
  }

  void ws() {
    while (!done && src[i].trim().isEmpty) {
      i++;
    }
  }

  String word() {
    final int start = i;
    while (!done && !' ,{}\t\n'.contains(src[i])) {
      i++;
    }
    return src.substring(start, i);
  }

  void expect(String c) {
    if (done || src[i] != c) throw FormatException('Expected $c', src, i);
    i++;
  }

  void argument() {
    ws();
    final String name = word();
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) {
      throw FormatException('Invalid argument name "$name"', src, i);
    }
    args.add(name);
    ws();
    if (!done && src[i] == '}') {
      i++;
      return;
    }
    expect(',');
    ws();
    final String type = word();
    ws();
    if (!done && src[i] == '}') {
      i++;
      return;
    }
    expect(',');
    if (type == 'plural' || type == 'select' || type == 'selectordinal') {
      while (true) {
        ws();
        if (!done && src[i] == '}') {
          i++;
          return;
        }
        final String selector = word();
        if (selector.isEmpty) throw FormatException('Missing selector', src, i);
        ws();
        expect('{');
        message();
        expect('}');
      }
    }
    // number/date style argument: skip to the closing brace.
    while (!done && src[i] != '}') {
      i++;
    }
    expect('}');
  }
}

class ArbIssue {
  ArbIssue(this.severity, this.locale, this.key, this.message);

  final String severity; // error | warning
  final String locale;
  final String? key;
  final String message;

  bool get isError => severity == 'error';

  @override
  String toString() =>
      '[$severity] $locale${key == null ? '' : ' · $key'}: $message';
}

/// Lists `app_*.arb` in [arbDir], template first.
List<ArbFile> readArbDir(String arbDir) {
  final List<ArbFile> files =
      Directory(arbDir)
          .listSync()
          .whereType<File>()
          .where((File f) => RegExp(r'app_[A-Za-z_]+\.arb$').hasMatch(f.path))
          .map((File f) => ArbFile.read(f.path))
          .toList()
        ..sort(
          (ArbFile a, ArbFile b) => a.locale == templateLocale
              ? -1
              : b.locale == templateLocale
              ? 1
              : a.locale.compareTo(b.locale),
        );
  if (files.isEmpty || files.first.locale != templateLocale) {
    throw StateError('Template app_$templateLocale.arb not found in $arbDir');
  }
  return files;
}

/// Validates every locale against the template.
List<ArbIssue> checkArbs(List<ArbFile> files) {
  final List<ArbIssue> issues = <ArbIssue>[];
  final ArbFile template = files.first;
  final Set<String> templateKeys = template.keys.toSet();

  for (final String key in template.keys) {
    if (!_keyPattern.hasMatch(key)) {
      issues.add(
        ArbIssue(
          'error',
          template.locale,
          key,
          'key must be lowerCamelCase ASCII',
        ),
      );
    }
    if (!arbKeyDomains.any(
      (String d) =>
          key == d ||
          (key.startsWith(d) &&
              key.length > d.length &&
              key[d.length].toUpperCase() == key[d.length]),
    )) {
      issues.add(
        ArbIssue(
          'error',
          template.locale,
          key,
          'key must start with a domain prefix: ${arbKeyDomains.join(', ')}',
        ),
      );
    }
    final Object? meta = template.data['@$key'];
    final Set<String> args = _safeArgs(template, key, issues);
    final Set<String> declared = meta is Map && meta['placeholders'] is Map
        ? (meta['placeholders']! as Map<Object?, Object?>).keys
              .cast<String>()
              .toSet()
        : <String>{};
    if (!_setEquals(args, declared)) {
      issues.add(
        ArbIssue(
          'error',
          template.locale,
          key,
          'placeholders declared $declared but message uses $args',
        ),
      );
    }
  }

  for (final ArbFile f in files.skip(1)) {
    final Set<String> keys = f.keys.toSet();
    for (final String k in templateKeys.difference(keys)) {
      issues.add(ArbIssue('error', f.locale, k, 'missing translation'));
    }
    for (final String k in keys.difference(templateKeys)) {
      issues.add(
        ArbIssue(
          'error',
          f.locale,
          k,
          'key not in template app_$templateLocale.arb',
        ),
      );
    }
    for (final String k in keys.intersection(templateKeys)) {
      final Set<String> want = _safeArgs(template, k, <ArbIssue>[]);
      final Set<String> got = _safeArgs(f, k, issues);
      if (!_setEquals(want, got)) {
        issues.add(
          ArbIssue(
            'error',
            f.locale,
            k,
            'placeholders $got differ from template $want',
          ),
        );
      }
      if (f.message(k) == template.message(k) &&
          !arbIdenticalAllowed.contains(k)) {
        issues.add(
          ArbIssue(
            'warning',
            f.locale,
            k,
            'identical to template (untranslated?)',
          ),
        );
      }
    }
  }
  return issues;
}

Set<String> _safeArgs(ArbFile f, String key, List<ArbIssue> issues) {
  final Object? v = f.data[key];
  if (v is! String) {
    issues.add(ArbIssue('error', f.locale, key, 'message must be a string'));
    return <String>{};
  }
  try {
    return icuArguments(v);
  } on FormatException catch (e) {
    issues.add(
      ArbIssue('error', f.locale, key, 'malformed ICU message: ${e.message}'),
    );
    return <String>{};
  }
}

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

/// Creates `app_<code>.arb` from the template: messages copied in the
/// template language and marked as pending translation.
String createLocaleArb(String arbDir, String code) {
  final String locale = normalizeLocaleCode(code);
  final String target = '$arbDir${Platform.pathSeparator}app_$locale.arb';
  if (File(target).existsSync()) {
    throw StateError('$target already exists');
  }
  final ArbFile template = ArbFile.read(
    '$arbDir${Platform.pathSeparator}app_$templateLocale.arb',
  );
  final Map<String, Object?> out = <String, Object?>{
    '@@locale': locale,
    '@@x-status':
        'pending-translation (copied from $templateLocale; remove when done)',
    for (final String k in template.keys) k: template.message(k),
  };
  File(
    target,
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(out)}\n');
  return target;
}

/// Package root of up_i18n, resolved through the package config so the
/// scripts work from any working directory in the workspace.
String packageRoot() {
  final Uri? lib = Isolate.resolvePackageUriSync(Uri.parse('package:up_i18n/'));
  if (lib != null && lib.isScheme('file')) {
    return Directory.fromUri(lib).parent.path;
  }
  return Directory.current.path;
}

/// Runs `flutter gen-l10n` in the package root.
Future<int> runGenL10n(String root) async {
  final Process p = await Process.start(
    'flutter',
    <String>['gen-l10n'],
    workingDirectory: root,
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  return p.exitCode;
}
