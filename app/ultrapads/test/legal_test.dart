import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultrapads/src/legal/third_party_licenses.dart';

void main() {
  test(
    'catalog sound font and separation model notices are registered',
    () async {
      registerThirdPartyLicenses();
      final entries = await LicenseRegistry.licenses.toList();
      final text = entries
          .where(
            (e) => e.packages.any(
              (p) =>
                  p == 'MuseScore_General SoundFont' || p.startsWith('Demucs'),
            ),
          )
          .map((e) => e.paragraphs.map((p) => p.text).join('\n'))
          .join('\n');
      expect(text, contains('Frank Wen'));
      expect(text, contains('S. Christian Collins'));
      expect(text, contains('Meta Platforms'));
      expect(text, contains('Permission is hereby granted'));
    },
  );
}
