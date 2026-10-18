# ADR-0003 音频图：自研薄抽象 + Firewheel 实现

- 状态：已接受
- 日期：2026-10-18
- 关联：ADR-0001 #18（"自研薄抽象 trait，首个实现接 Firewheel"）

## 背景

引擎需要一张实时音频图：v0.0.1 是 `Pad Sampler（24 路立体声 + 试听）→ Mixer → Master（增益/限幅/电平/录音抽头）→ 设备`，后续要扩展效果链、发送/总线、插件槽（CLAP/VST3）。要求：音频线程零分配零锁、可离线渲染、Linux/Android 必须可用、Web(WASM) 预留。

## 评估（firewheel 0.14.0，crates.io 最新）

在独立工程中实测（`default-features = false, features = ["std"]`，不带 cpal 后端）：

| 项目 | 结论 |
|---|---|
| 手动驱动 | `FirewheelContext::activate(ActivateInfo)` 返回 `FirewheelProcessor`，`process(&dyn Adapter, &mut dyn AdapterMut, BackendProcessInfo)` 可由我们自己的 cpal 回调或离线循环调用；超过 `max_block_frames` 的块内部自动切分 |
| 自定义节点 | `AudioNode` + `AudioNodeProcessor`，每个端口一个单声道，最多 64 端口（24 路立体声 + 试听 = 50 端口可行）；多条边进同一输入自动求和 |
| 实时性 | 预热两块后 100+ 块、Firewheel 事件路径、rtrb 路径、运行中增删节点，`assert_no_alloc` 均为 0 次分配；需把 `buffer_out_of_space_mode` 设为不在音频线程分配 |
| 控制粒度 | Firewheel 自带事件需控制线程 `update()` 才送达（非逐事件无锁）；因此 pad 命令走**我们自己的**无锁队列直达节点，单块延迟 |
| 平台 | `x86_64-linux-android`、`aarch64-linux-android`（NDK 28，API 26）编译通过；`wasm32-unknown-unknown` `cargo check` 通过（运行时需提供时间戳或开 `bevy_platform/web`，否则 `Instant::now()` 会 panic） |
| 约束 | `FirewheelContext` **不是 `Send`**，必须固定在一个线程；**丢弃 context 会停用 processor**（输出静音）；激活时默认 10 ms declick 淡入 |

## 决定

1. `engine/up-graph` 定义薄抽象：`NodeProcessor`（`process(info, inputs, outputs)`，平面 f32）、`AudioGraph`（`add_node`/`connect`/`activate`/`update`）、`GraphProcessor`（`process_interleaved`），以及可跨线程构建的 `GraphDesc`。引擎其它 crate 不出现任何 Firewheel 类型。
2. 首个（默认）实现 `GraphBackend::Firewheel`：适配器把 `NodeProcessor` 包成 Firewheel 节点；`DropEvents` 模式避免音频线程分配；`process_timestamp` 由我们提供。
3. 同时提供内建 `GraphBackend::Serial`（按插入顺序执行、边只能指向后面的节点，因而天然无环）：作为参考实现用于对照测试（两后端离线渲染逐采样一致，误差 < 1e-5），以及 Firewheel 不可用的目标（如 WASM 运行时问题未解决前）的后备。feature `firewheel` 默认开启，关闭后仅剩 Serial。
4. 线程归属：图在 `up-engine` 的**控制线程**上实例化、激活并以约 60 Hz 调用 `update()`；只有 `GraphProcessor` 被移交给音频回调。引擎句柄全部释放后控制线程退出、图随之销毁。
5. 实时命令不走 Firewheel 事件：`EngineHandle::send` 写入无锁 MPSC 队列（`crossbeam_queue::ArrayQueue`），节点在每块开头消费；音频→控制方向（事件、回收、录音）用 rtrb SPSC。

## 后果

- 后续效果链/总线/插件槽直接作为新的 `NodeProcessor` 节点接入，复用 Firewheel 的图编译与缓冲复用。
- 启动时 10 ms 淡入只影响流开始，不影响触发延迟；离线 golden 测试使用 Serial 后端或跳过前 10 ms。
- 若未来 Firewheel 不再满足需求，只需替换 `up-graph` 的后端实现。
