import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:up_i18n/src/tooling/arb_tools.dart';

void main() {
  test('repository ARB files are complete and consistent', () {
    final List<ArbIssue> issues = checkArbs(readArbDir('lib/l10n'));
    expect(
      issues.where((ArbIssue i) => i.isError),
      isEmpty,
      reason: issues.join('\n'),
    );
  });

  test('icuArguments handles nested plural/select branches', () {
    expect(icuArguments('Hi {name}'), <String>{'name'});
    expect(
      icuArguments(
        '{count, plural, =1{Yesterday} other{{count} days by {who}}}',
      ),
      <String>{'count', 'who'},
    );
    expect(icuArguments('{c, select, a{A} other{B}}'), <String>{'c'});
    expect(() => icuArguments('{oops'), throwsFormatException);
  });

  test('normalizeLocaleCode', () {
    expect(normalizeLocaleCode('ja'), 'ja');
    expect(normalizeLocaleCode('pt-br'), 'pt_BR');
    expect(normalizeLocaleCode('zh-hant-tw'), 'zh_Hant_TW');
    expect(() => normalizeLocaleCode('english'), throwsFormatException);
  });

  group('with a temp ARB dir', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('up_i18n_test');
      File('${dir.path}/app_en.arb').writeAsStringSync(
        jsonEncode(<String, Object?>{
          '@@locale': 'en',
          'commonOk': 'OK',
          'commonHello': 'Hello {name}',
          '@commonHello': <String, Object?>{
            'placeholders': <String, Object?>{
              'name': <String, Object?>{'type': 'String'},
            },
          },
        }),
      );
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('add_locale copies the template and flags untranslated messages', () {
      final String path = createLocaleArb(dir.path, 'pt-BR');
      expect(path, endsWith('app_pt_BR.arb'));
      final Map<String, Object?> json =
          jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
      expect(json['@@locale'], 'pt_BR');
      expect(json['commonHello'], 'Hello {name}');
      expect(json.containsKey('@commonHello'), isFalse);
      final List<ArbIssue> issues = checkArbs(readArbDir(dir.path));
      expect(issues.where((ArbIssue i) => i.isError), isEmpty);
      expect(
        issues.where((ArbIssue i) => i.severity == 'warning'),
        hasLength(2),
      );
      expect(() => createLocaleArb(dir.path, 'pt_BR'), throwsStateError);
    });

    test('missing keys, extra keys and placeholder drift are errors', () {
      File('${dir.path}/app_de.arb').writeAsStringSync(
        jsonEncode(<String, Object?>{
          '@@locale': 'de',
          'commonHello': 'Hallo {nme}',
          'commonExtra': 'x',
        }),
      );
      final List<String> msgs = checkArbs(
        readArbDir(dir.path),
      ).map((ArbIssue i) => '${i.key}:${i.message}').toList();
      expect(msgs, contains('commonOk:missing translation'));
      expect(
        msgs.any((String m) => m.startsWith('commonExtra:key not in template')),
        isTrue,
      );
      expect(
        msgs.any((String m) => m.startsWith('commonHello:placeholders')),
        isTrue,
      );
    });
  });
}
