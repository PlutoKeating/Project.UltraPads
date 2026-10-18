import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tokens/up_tokens.dart';

/// Serves one file for one asset key; everything else is "not injected".
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.key, this.bytes);

  final String key;
  final ByteData bytes;

  @override
  Future<ByteData> load(String k) async {
    if (k == key) return bytes;
    throw FlutterError('missing $k');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(UpFonts.debugReset);

  test('loads injected private cuts and switches roles to them', () async {
    UpFonts.debugReset();
    // Any TTF stands in for the private file here.
    final Uint8List ttf = File(
      'assets/fonts/OpenSans-ExtraBold.ttf',
    ).readAsBytesSync();
    final _FakeBundle bundle = _FakeBundle(
      '${UpFonts.privateAssetDir}${UpFonts.privateFiles['Uni Sans Heavy']}',
      ByteData.sublistView(ttf),
    );
    final int before = UpFonts.revision.value;
    final Set<String> loaded = await UpFonts.loadPrivate(bundle: bundle);

    expect(loaded, <String>{'Uni Sans Heavy'});
    expect(UpFonts.revision.value, before + 1);

    // Default font set stays Open Sans even when Uni Sans is available.
    expect(
      UpThemes.neon.text[UpTextRole.title].fontFamily,
      'packages/up_tokens/Open Sans',
    );

    final UpTheme uni = UpThemes.neon.withFontSet(UpFontSet.uniSans);
    final TextStyle title = uni.text[UpTextRole.title];
    expect(title.fontFamily, 'Uni Sans Heavy');
    expect(
      title.fontWeight,
      FontWeight.w400,
      reason: 'single-weight family: no synthetic bold',
    );

    // Regular cut was not injected -> body falls back to Open Sans.
    expect(
      uni.text[UpTextRole.body].fontFamily,
      'packages/up_tokens/Open Sans',
    );
    expect(uni.text[UpTextRole.body].fontWeight, FontWeight.w400);
  });

  test('missing private fonts are not an error', () async {
    UpFonts.debugReset();
    final Set<String> loaded = await UpFonts.loadPrivate(
      bundle: _FakeBundle('nothing', ByteData(0)),
    );
    expect(loaded, isEmpty);
  });
}
