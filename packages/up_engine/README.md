# up_engine

UI 访问引擎的唯一接口（纯 Dart，库代码不依赖 Flutter / FRB）。

- `EngineClient`（`lib/src/engine_client.dart`）：`docs/API.md` §3 的全部能力——音频、事件流、快照、
  pad 热路径（`padDown` / `padUp` / `send` / `snapshot` 为同步）、曲库、编辑 Kit、采样、作品、教程、Hub。
  未实现的能力抛 `EngineNotImplemented`。
- 数据类（`models.dart`）：`PadId`、`PadParams`、`ColorRole`（顺序 = token 调色板下标）、`KitSummary`、
  `KitDoc`、`TutorialChart`（时间轴步骤 + 判定窗口）、`TrackInfo`、Hub 类型…
- 协议（`protocol.dart`）：`Command`（sealed）与 `EngineEvent`（sealed）。
- `MockEngineClient`：内存模拟——pad 状态机（one-shot / loop / gate、choke、量化 Pending）、走带、电平、
  录音 → 作品、曲库 / 导入 / 保存、时间轴教程、Hub（发现、6 位码配对、同步进度、控制器模式）。
  `realtime: false` 时由 `advance()` 驱动时钟，测试可确定性复现。
- `DemoLibrary`：确定性演示数据（只有名字和参数，没有素材）。

FFI 实现在应用里：`app/ultrapads/lib/src/engine/ffi_engine_client.dart`。

```bash
flutter test   # 状态机、量化、choke、录音、控制器模式、配对校验
```
