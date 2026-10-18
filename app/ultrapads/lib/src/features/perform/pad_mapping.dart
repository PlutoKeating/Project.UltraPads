import 'package:flutter/widgets.dart';
import 'package:up_engine/up_engine.dart';
import 'package:up_ui/up_ui.dart';

import '../../assets/private_assets.dart';
import '../../state/settings_state.dart';

/// 4.7.0 image 类皮肤（整张 pad 插画）在注入素材中的包名。
const Map<String, String> _imageSkinPackages = {
  'christmas': 'padChristmas',
  'pets': 'padPets',
  'muertos': 'padMuertos',
  'halloween': 'padHalloween',
};

/// 调色板下标 → 原 App 位图的颜色名（4.7.0 只有 pink/orange/green/blue，
/// Halloween 多一个 purple；扩展角色按色相就近）。
const List<String> _bitmapColors = [
  'pink',
  'orange',
  'green',
  'blue',
  'pink',
  'orange',
  'blue',
  'purple',
];

/// 当前皮肤是 image 类预设且注入了 4.7.0 皮肤位图时，返回位图皮肤；
/// 否则 null（保持 token 程序化绘制）。[skinId] 为设置中的皮肤 id。
PadImageSkin? imageSkinFor(PrivateAssets assets, String skinId) {
  if (!skinId.startsWith(presetPrefix)) return null;
  final pkg = _imageSkinPackages[skinId.substring(presetPrefix.length)];
  if (pkg == null) return null;
  String? find(Iterable<String> files) {
    for (final f in files) {
      final k = assets.key('ios/skin/$pkg/Skin_${pkg}__$f.png');
      if (k != null) return k;
    }
    return null;
  }

  // 至少要有一张基础位图，否则当作没注入。
  if (find(_bitmapColors.map((c) => 'img_pad_$c')) == null) return null;
  return PadImageSkin(
    imageFor: (role, {required loop, required on}) {
      final c = _bitmapColors[role % _bitmapColors.length];
      final path = on
          ? find(['img_pad_${c}_on', 'img_pad_on_$c'])
          : find([
              if (c == 'blue') 'img_${c}_pets',
              'img_pad_$c',
              // 缺少的颜色（例如 purple）退回 pink。
              'img_pad_pink',
            ]);
      return path == null ? null : AssetImage(path);
    },
  );
}

/// 引擎 pad 状态 → 组件展示数据。
PadVisualState padVisual(PadPlayState s) => switch (s) {
  PadPlayState.idle => PadVisualState.idle,
  PadPlayState.pending => PadVisualState.pending,
  PadPlayState.playing => PadVisualState.playing,
  PadPlayState.stopping => PadVisualState.stopping,
};

/// pad 编号：1–9、A、B、C（APK NUMBER 皮肤，两页都从 1 开始）。
String padNumberLabel(int index) =>
    index < 9 ? '${index + 1}' : String.fromCharCode(0x41 + index - 9);

List<PadData> padDataFrom(List<PadParams> pads, List<PadPlayState> states) => [
  for (var i = 0; i < PadId.total; i++)
    pads[i].isEmpty
        ? PadData.empty
        : PadData(
            role: pads[i].color.paletteIndex,
            loop: pads[i].mode == PadMode.loop,
            state: padVisual(states[i]),
            label: padNumberLabel(i % PadId.padsPerBank),
          ),
];

/// APK「NORMAL」皮肤 Lottie（`normal_<blue|green|orange|pink>.json`），
/// 只有注入了 APK 素材且用户开启「经典 pad 动画」时使用。
PadLottieSkin? classicLottieSkin(PrivateAssets assets) {
  String? color(int role) => switch (ColorRole.fromPalette(role)) {
    ColorRole.blue ||
    ColorRole.cyan ||
    ColorRole.grey ||
    ColorRole.neutral => 'blue',
    ColorRole.green || ColorRole.lime => 'green',
    ColorRole.yellow || ColorRole.orange => 'orange',
    ColorRole.pink || ColorRole.purple || ColorRole.red => 'pink',
  };
  if (assets.key('apk/lottie/normal_blue.json') == null) return null;
  return PadLottieSkin(
    assetFor: (role, {required loop}) =>
        assets.key('apk/lottie/normal_${color(role)}.json'),
  );
}

/// 当前歌曲的音色组数（每组 [PadId.padsPerBank] 个 pad）：引擎给出的组数优先，
/// 否则按最后一个非空 pad 所在的组推断；没有 Kit 时为 1。
int groupCountOf(KitSummary? kit, List<PadParams> pads) {
  if (kit?.hasBankB ?? false) return 2;
  var last = 0;
  for (var i = 0; i < pads.length; i++) {
    if (!pads[i].isEmpty) last = i ~/ PadId.padsPerBank;
  }
  return last + 1;
}
