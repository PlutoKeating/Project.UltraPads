//! Firewheel 0.14 backend.

use crate::*;
use audioadapter_buffers::direct::InterleavedSlice;
use firewheel::channel_config::{ChannelConfig, ChannelCount};
use firewheel::node::{
    AudioNode, AudioNodeInfo, AudioNodeProcessor, ConstructProcessorContext, EmptyConfig,
    NodeError, ProcBuffers, ProcExtra, ProcInfo, ProcessStatus, StreamStatus,
};
use firewheel::processor::BufferOutOfSpaceMode;
use firewheel::{ActivateInfo, FirewheelConfig, FirewheelContext};
use std::cell::Cell;
use std::num::NonZeroU32;
use std::time::Duration;

/// Wraps one of our processors as a Firewheel node.
struct Adapter {
    spec: NodeSpec,
    processor: Cell<Option<Box<dyn NodeProcessor>>>,
}

#[derive(Debug)]
struct AlreadyActivated;
impl std::fmt::Display for AlreadyActivated {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("node processor was already constructed")
    }
}
impl std::error::Error for AlreadyActivated {}

impl AudioNode for Adapter {
    type Configuration = EmptyConfig;

    fn info(&self, _: &EmptyConfig) -> Result<AudioNodeInfo, NodeError> {
        let count = |n: usize| ChannelCount::new(n as u32).unwrap_or(ChannelCount::MAX);
        Ok(AudioNodeInfo::new()
            .debug_name(self.spec.name)
            .channel_config(ChannelConfig {
                num_inputs: count(self.spec.inputs),
                num_outputs: count(self.spec.outputs),
            }))
    }

    fn construct_processor(
        &self,
        _: &EmptyConfig,
        _: ConstructProcessorContext,
    ) -> Result<impl AudioNodeProcessor, NodeError> {
        let inner = self
            .processor
            .take()
            .ok_or_else(|| NodeError(Box::new(AlreadyActivated)))?;
        Ok(AdapterProcessor { inner })
    }
}

struct AdapterProcessor {
    inner: Box<dyn NodeProcessor>,
}

impl AudioNodeProcessor for AdapterProcessor {
    fn process(
        &mut self,
        info: &ProcInfo,
        buffers: ProcBuffers,
        _: &mut ProcExtra,
    ) -> ProcessStatus {
        let pi = ProcessInfo {
            frames: info.frames,
            sample_rate: info.sample_rate.get(),
        };
        self.inner.process(&pi, buffers.inputs, buffers.outputs);
        ProcessStatus::OutputsModified
    }
}

pub(crate) struct FirewheelGraph {
    ctx: FirewheelContext,
    ids: Vec<firewheel::node::NodeID>,
}

// Note: `FirewheelContext` is `!Send`; the graph must stay on the thread
// that created it (see `GraphDesc`).

impl FirewheelGraph {
    pub fn new(output_channels: usize) -> Self {
        let cfg = FirewheelConfig {
            num_graph_inputs: ChannelCount::ZERO,
            num_graph_outputs: ChannelCount::new(output_channels as u32)
                .unwrap_or(ChannelCount::STEREO),
            // Never allocate on the audio thread; we size queues generously.
            buffer_out_of_space_mode: BufferOutOfSpaceMode::DropEvents,
            ..Default::default()
        };
        let ctx = FirewheelContext::new(cfg);
        let out = ctx.graph_out_node_id();
        Self {
            ctx,
            ids: vec![out],
        }
    }

    fn id(&self, n: NodeId) -> UpResult<firewheel::node::NodeID> {
        self.ids
            .get(n.0 as usize)
            .copied()
            .ok_or_else(|| UpError::not_found("node"))
    }
}

impl AudioGraph for FirewheelGraph {
    fn backend(&self) -> GraphBackend {
        GraphBackend::Firewheel
    }

    fn add_node(&mut self, spec: NodeSpec, processor: Box<dyn NodeProcessor>) -> UpResult<NodeId> {
        check_spec(&spec)?;
        let id = self
            .ctx
            .add_node(
                Adapter {
                    spec,
                    processor: Cell::new(Some(processor)),
                },
                None,
            )
            .map_err(|e| UpError::audio(format!("firewheel add_node: {e}")))?;
        self.ids.push(id);
        Ok(NodeId((self.ids.len() - 1) as u32))
    }

    fn connect(
        &mut self,
        src: NodeId,
        src_port: usize,
        dst: NodeId,
        dst_port: usize,
    ) -> UpResult<()> {
        let (s, d) = (self.id(src)?, self.id(dst)?);
        self.ctx
            .connect(s, d, &[(src_port as u32, dst_port as u32)], true)
            .map(|_| ())
            .map_err(|e| UpError::invalid(format!("connect: {e}")))
    }

    fn output_node(&self) -> NodeId {
        NodeId(0)
    }

    fn activate(&mut self, cfg: StreamConfig) -> UpResult<Box<dyn GraphProcessor>> {
        let sr =
            NonZeroU32::new(cfg.sample_rate).ok_or_else(|| UpError::invalid("sample rate 0"))?;
        let mb = NonZeroU32::new(cfg.max_block_frames as u32)
            .ok_or_else(|| UpError::invalid("max block 0"))?;
        let processor = self
            .ctx
            .activate(ActivateInfo {
                sample_rate: sr,
                max_block_frames: mb,
                num_stream_in_channels: 0,
                num_stream_out_channels: cfg.output_channels as u32,
                input_to_output_latency_seconds: 0.0,
            })
            .map_err(|e| UpError::audio(format!("firewheel activate: {e}")))?;
        // Compile the graph and ship the schedule to the processor.
        self.ctx
            .update()
            .map_err(|e| UpError::audio(format!("firewheel update: {e}")))?;
        Ok(Box::new(FwProcessor {
            inner: processor,
            started: None,
            elapsed: Duration::ZERO,
            sample_rate: cfg.sample_rate,
        }))
    }

    fn update(&mut self) -> UpResult<()> {
        self.ctx
            .update()
            .map_err(|e| UpError::audio(format!("firewheel update: {e}")))
    }
}

struct FwProcessor {
    inner: firewheel::processor::FirewheelProcessor,
    started: Option<std::time::Instant>,
    elapsed: Duration,
    sample_rate: u32,
}

impl GraphProcessor for FwProcessor {
    fn process_interleaved(&mut self, out: &mut [f32], channels: usize) {
        let channels = channels.max(1);
        let frames = out.len() / channels;
        let empty: [f32; 0] = [];
        let (Ok(input), Ok(mut output)) = (
            InterleavedSlice::new(&empty[..], 0, frames),
            InterleavedSlice::new_mut(&mut out[..frames * channels], channels, frames),
        ) else {
            out.fill(0.0);
            return;
        };
        let now = std::time::Instant::now();
        let start = *self.started.get_or_insert(now);
        let _ = start;
        self.inner.process(
            &input,
            &mut output,
            firewheel::backend::BackendProcessInfo {
                frames,
                process_timestamp: Some(now),
                duration_since_stream_start: self.elapsed,
                input_stream_status: StreamStatus::empty(),
                output_stream_status: StreamStatus::empty(),
                dropped_frames: 0,
                process_to_playback_delay: None,
            },
        );
        self.elapsed += Duration::from_secs_f64(frames as f64 / self.sample_rate.max(1) as f64);
    }
}
