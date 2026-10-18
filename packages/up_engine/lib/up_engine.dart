/// UltraPads 引擎客户端接口（纯 Dart）。
///
/// - [EngineClient]：UI 访问引擎的唯一接口；
/// - 数据类与协议：`models.dart`、`protocol.dart`；
/// - [MockEngineClient]：内存模拟实现，供 UI 开发和测试。
library;

export 'src/engine_client.dart';
export 'src/mock/demo_library.dart';
export 'src/mock/mock_engine_client.dart';
export 'src/models.dart';
export 'src/protocol.dart';
