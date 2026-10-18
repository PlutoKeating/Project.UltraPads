import 'package:flutter/foundation.dart';
import 'package:up_engine/up_engine.dart';

import 'ffi_engine_client.dart';

/// 启动参数 `--dart-define=UP_ENGINE=mock|ffi`（默认 ffi）。
const String engineFlag = String.fromEnvironment(
  'UP_ENGINE',
  defaultValue: 'ffi',
);

/// 启动结果：所用引擎，以及 FFI 是否因加载失败而回退到 Mock。
class EngineBoot {
  const EngineBoot(this.client, {this.fallbackReason});
  final EngineClient client;

  /// 非空表示请求了 FFI 但加载失败，已回退到 Mock。
  final String? fallbackReason;
}

Future<EngineBoot> bootEngine() async {
  if (engineFlag == 'mock') return EngineBoot(MockEngineClient());
  try {
    return EngineBoot(await FfiEngineClient.create());
  } catch (e) {
    debugPrint(
      'UltraPads: FFI engine unavailable ($e); using MockEngineClient',
    );
    return EngineBoot(MockEngineClient(), fallbackReason: '$e');
  }
}
