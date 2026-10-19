import 'package:flutter/foundation.dart';

const _mit =
    '''Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.''';

/// 随官方曲库和本地分轨使用的第三方素材 / 模型的许可声明（出现在「设置 → 关于 → 开源许可」）。
///
/// * MuseScore_General SoundFont（MIT）：官方曲库里原创合成曲目的音色，要求保留版权与许可声明。
/// * Demucs 与 htdemucs 的 ONNX 导出（MIT）：导入歌曲时本地分轨用的模型，由用户同意后下载，不随应用分发。
final List<({List<String> packages, String text})> thirdPartyNotices = [
  (
    packages: ['MuseScore_General SoundFont'],
    text: '''MuseScore_General.sf2 is shared under the MIT license.

FluidR3 (original version) by Frank Wen, Copyright (c) 2000-02
Mono conversion (FluidR3Mono) by Michael Cowgill, Copyright (c) 2014-17
Adaptation for MuseScore_General.sf2 by S. Christian Collins, Copyright (c) 2018-19
Temple Blocks instrument provided by Ethan Winer, Copyright (c) 2002
Drumline Cymbals provided by Michael Schorsch, Copyright (c) 2016

$_mit''',
  ),
  (
    packages: ['Demucs (htdemucs) model'],
    text:
        '''Hybrid Transformer Demucs (htdemucs): Copyright (c) Meta Platforms, Inc. and affiliates, MIT License
(https://github.com/facebookresearch/demucs). Used for on-device stem separation when importing a song.
The ONNX export (https://huggingface.co/adowu/htdemucs-onnx, MIT) is downloaded on request and is not bundled with the app.

$_mit''',
  ),
];

/// 在 [LicenseRegistry] 登记 [thirdPartyNotices]（应用启动时调用一次）。
void registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final n in thirdPartyNotices) {
      yield LicenseEntryWithLineBreaks(n.packages, n.text);
    }
  });
}
