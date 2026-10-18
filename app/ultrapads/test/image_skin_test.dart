import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultrapads/src/assets/private_assets.dart';
import 'package:ultrapads/src/features/perform/pad_mapping.dart';

/// image 类皮肤：只有注入了私有素材包位图时才用位图，否则保持 token 绘制。
void main() {
  // 只是清单键名（不含任何素材内容）。
  const pkg = 'ios/skin/padChristmas/Skin_padChristmas__';
  final assets = PrivateAssets.fromEntries({
    '${pkg}img_pad_pink.png': 'assets/private_manifest/a.png',
    '${pkg}img_pad_pink_on.png': 'assets/private_manifest/b.png',
    '${pkg}img_pad_blue.png': 'assets/private_manifest/c.png',
  });

  String? path(ImageProvider? p) => (p as AssetImage?)?.assetName;

  test('christmas preset uses injected bitmaps', () {
    final skin = imageSkinFor(assets, 'preset-christmas')!;
    expect(path(skin.imageFor(0, loop: false, on: false)), endsWith('a.png'));
    expect(path(skin.imageFor(0, loop: false, on: true)), endsWith('b.png'));
    expect(path(skin.imageFor(3, loop: true, on: false)), endsWith('c.png'));
    expect(skin.imageFor(3, loop: true, on: true), isNull);
    // 缺少的颜色退回 pink。
    expect(path(skin.imageFor(7, loop: false, on: false)), endsWith('a.png'));
  });

  test('no injection or non-image skin → token drawing', () {
    expect(imageSkinFor(PrivateAssets.none, 'preset-christmas'), isNull);
    expect(imageSkinFor(assets, 'preset-default'), isNull);
    expect(imageSkinFor(assets, 'neon'), isNull);
    expect(imageSkinFor(assets, 'preset-pets'), isNull);
  });
}
