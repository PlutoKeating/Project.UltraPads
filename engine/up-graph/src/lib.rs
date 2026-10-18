//! Audio graph abstraction (ADR-0001 #18: "thin in-house trait, first
//! implementation on Firewheel"; see docs/adr/0003-audio-graph.md).
//!
//! The engine builds its signal flow only through [`AudioGraph`] /
//! [`NodeProcessor`]; no Firewheel type leaks out of this crate.
//!
//! * [`GraphBackend::Firewheel`] — `firewheel` 0.14 graph compiler and
//!   executor (default).
//! * [`GraphBackend::Serial`] — built-in executor that runs nodes in
//!   insertion order. Used as a reference implementation in tests and as a
//!   fallback for targets where Firewheel is unavailable.
//!
//! Ports are mono channels (`f32` planar). A stereo bus is two ports.

#[cfg(feature = "firewheel")]
mod fw;
mod serial;

use up_core::{UpError, UpResult};

/// Maximum ports (channels) per node (Firewheel limit).
pub const MAX_PORTS: usize = 64;

/// Node identifier within one graph.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct NodeId(pub(crate) u32);

/// Static description of a node.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct NodeSpec {
    pub name: &'static str,
    pub inputs: usize,
    pub outputs: usize,
}

/// Per-block information passed to nodes.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ProcessInfo {
    pub frames: usize,
    pub sample_rate: u32,
}

/// A realtime node. `process` must not allocate, lock or block.
/// Every output buffer must be fully written (they contain stale data).
pub trait NodeProcessor: Send + 'static {
    fn process(&mut self, info: &ProcessInfo, inputs: &[&[f32]], outputs: &mut [&mut [f32]]);
}

/// Stream parameters for [`AudioGraph::activate`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct StreamConfig {
    pub sample_rate: u32,
    /// Largest block the graph processes at once (bigger host buffers are
    /// split internally).
    pub max_block_frames: usize,
    /// Interleaved output channels expected by the host.
    pub output_channels: usize,
}

/// Audio-thread side of an activated graph.
pub trait GraphProcessor: Send {
    /// Render `out.len() / channels` frames into interleaved `out`.
    fn process_interleaved(&mut self, out: &mut [f32], channels: usize);
}

/// Control-thread side of a graph. Not `Send`: a graph lives on the thread
/// that instantiated it (Firewheel's context is single-threaded). Use
/// [`GraphDesc`] to describe a graph on one thread and build it on another.
pub trait AudioGraph {
    fn backend(&self) -> GraphBackend;

    /// Add a node. Must happen before [`AudioGraph::activate`].
    fn add_node(&mut self, spec: NodeSpec, processor: Box<dyn NodeProcessor>) -> UpResult<NodeId>;

    /// Connect `src.src_port → dst.dst_port`. Multiple edges into one input
    /// port are summed.
    fn connect(
        &mut self,
        src: NodeId,
        src_port: usize,
        dst: NodeId,
        dst_port: usize,
    ) -> UpResult<()>;

    /// The graph output node; its input ports are the device channels.
    fn output_node(&self) -> NodeId;

    /// Compile and hand out the realtime processor. The graph must be kept
    /// alive while the processor runs: dropping it deactivates the stream
    /// (Firewheel) and the processor then outputs silence.
    fn activate(&mut self, cfg: StreamConfig) -> UpResult<Box<dyn GraphProcessor>>;

    /// Control-thread housekeeping (flush graph changes, free retired
    /// schedules). Call regularly (~60 Hz) while active.
    fn update(&mut self) -> UpResult<()>;
}

/// Available backends.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum GraphBackend {
    #[cfg_attr(feature = "firewheel", default)]
    Firewheel,
    #[cfg_attr(not(feature = "firewheel"), default)]
    Serial,
}

/// Create an empty graph with `output_channels` graph outputs.
pub fn new_graph(backend: GraphBackend, output_channels: usize) -> UpResult<Box<dyn AudioGraph>> {
    if output_channels == 0 || output_channels > MAX_PORTS {
        return Err(UpError::invalid("graph output channels must be 1..=64"));
    }
    match backend {
        #[cfg(feature = "firewheel")]
        GraphBackend::Firewheel => Ok(Box::new(fw::FirewheelGraph::new(output_channels))),
        #[cfg(not(feature = "firewheel"))]
        GraphBackend::Firewheel => Err(UpError::not_implemented(
            "built without the firewheel feature",
        )),
        GraphBackend::Serial => Ok(Box::new(serial::SerialGraph::new(output_channels))),
    }
}

pub(crate) fn check_spec(spec: &NodeSpec) -> UpResult<()> {
    if spec.inputs > MAX_PORTS || spec.outputs > MAX_PORTS {
        return Err(UpError::invalid(format!(
            "node {} has too many ports (max {MAX_PORTS})",
            spec.name
        )));
    }
    Ok(())
}

/// Backend-agnostic, `Send` description of a graph. Build it anywhere, then
/// call [`GraphDesc::instantiate`] on the thread that will own the graph.
pub struct GraphDesc {
    output_channels: usize,
    nodes: Vec<(NodeSpec, Box<dyn NodeProcessor>)>,
    edges: Vec<(usize, usize, usize, usize)>,
}

/// Node handle inside a [`GraphDesc`]. `DescNode::OUTPUT` is the graph output.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DescNode(usize);

impl DescNode {
    pub const OUTPUT: DescNode = DescNode(usize::MAX);
}

impl GraphDesc {
    pub fn new(output_channels: usize) -> Self {
        Self {
            output_channels,
            nodes: Vec::new(),
            edges: Vec::new(),
        }
    }

    pub fn add_node(&mut self, spec: NodeSpec, processor: Box<dyn NodeProcessor>) -> DescNode {
        self.nodes.push((spec, processor));
        DescNode(self.nodes.len() - 1)
    }

    pub fn connect(&mut self, src: DescNode, src_port: usize, dst: DescNode, dst_port: usize) {
        self.edges.push((src.0, src_port, dst.0, dst_port));
    }

    /// Connect `ports` consecutive ports starting at the given offsets.
    pub fn connect_ports(
        &mut self,
        src: DescNode,
        src_first: usize,
        dst: DescNode,
        dst_first: usize,
        ports: usize,
    ) {
        for p in 0..ports {
            self.connect(src, src_first + p, dst, dst_first + p);
        }
    }

    /// Build the graph with `backend` on the current thread.
    pub fn instantiate(self, backend: GraphBackend) -> UpResult<Box<dyn AudioGraph>> {
        let mut g = new_graph(backend, self.output_channels)?;
        let ids: Vec<NodeId> = self
            .nodes
            .into_iter()
            .map(|(spec, p)| g.add_node(spec, p))
            .collect::<UpResult<_>>()?;
        let out = g.output_node();
        let resolve = |n: usize| -> UpResult<NodeId> {
            if n == usize::MAX {
                Ok(out)
            } else {
                ids.get(n)
                    .copied()
                    .ok_or_else(|| UpError::not_found("graph node"))
            }
        };
        for (s, sp, d, dp) in self.edges {
            g.connect(resolve(s)?, sp, resolve(d)?, dp)?;
        }
        Ok(g)
    }
}
