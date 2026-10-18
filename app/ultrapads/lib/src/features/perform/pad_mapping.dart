import 'package:up_engine/up_engine.dart';
import 'package:up_ui/up_ui.dart';

import '../../assets/private_assets.dart';

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
            role: pads[i].color.index,
            loop: pads[i].mode == PadMode.loop,
            state: padVisual(states[i]),
            label: padNumberLabel(i % PadId.padsPerBank),
          ),
];

/// APK「NORMAL」皮肤 Lottie（`normal_<blue|green|orange|pink>.json`），
/// 只有注入了 APK 素材且用户开启「经典 pad 动画」时使用。
PadLottieSkin? classicLottieSkin(PrivateAssets assets) {
  String? color(int role) =>
      switch (ColorRole.values[role % ColorRole.values.length]) {
        ColorRole.blue || ColorRole.cyan => 'blue',
        ColorRole.green => 'green',
        ColorRole.yellow || ColorRole.orange => 'orange',
        ColorRole.pink || ColorRole.magenta || ColorRole.rose => 'pink',
      };
  if (assets.key('apk/lottie/normal_blue.json') == null) return null;
  return PadLottieSkin(
    assetFor: (role, {required loop}) =>
        assets.key('apk/lottie/normal_${color(role)}.json'),
  );
}
