//! `PadSink`：Hub 把远端控制器的 pad 事件交给引擎的出口。

use crate::identity::DeviceId;

/// 接收远端 pad 事件。由主代理在 up-ffi 中接到引擎（`pad_down/pad_up/stop_all`）。
///
/// - 调用发生在 Hub 的 UDP 接收任务上，**同一会话内严格按序**（已去重、已丢弃过期乱序包）；
/// - 实现必须快速、非阻塞（例如写入无锁队列），否则会推高后续事件的延迟；
/// - `velocity` 为 0..=127（与 MIDI 一致），引擎可按 `velocity as f32 / 127.0` 归一化。
pub trait PadSink: Send + Sync + 'static {
    /// 按下 pad。
    fn pad_down(&self, origin: &DeviceId, bank: u8, index: u8, velocity: u8);
    /// 抬起 pad。
    fn pad_up(&self, origin: &DeviceId, bank: u8, index: u8);
    /// 停止所有发声。
    fn stop_all(&self, origin: &DeviceId);
    /// 控制器会话建立。
    fn controller_connected(&self, _origin: &DeviceId, _name: &str) {}
    /// 控制器会话结束（主动关闭、超时或设备被撤销）。结束前 Hub 会对仍按住的 pad 补发 `pad_up`。
    fn controller_disconnected(&self, _origin: &DeviceId) {}
}

/// 丢弃所有事件的 sink（Hub 不需要控制器功能时使用）。
#[derive(Debug, Default, Clone, Copy)]
pub struct NullPadSink;

impl PadSink for NullPadSink {
    fn pad_down(&self, _: &DeviceId, _: u8, _: u8, _: u8) {}
    fn pad_up(&self, _: &DeviceId, _: u8, _: u8) {}
    fn stop_all(&self, _: &DeviceId) {}
}
