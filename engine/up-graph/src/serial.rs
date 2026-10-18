//! Built-in serial graph executor.

use crate::*;

struct Edge {
    src: usize,
    src_port: usize,
    dst: usize,
    dst_port: usize,
}

/// Nodes are executed in insertion order; edges must go from an earlier to
/// a later node (or to the output node), which guarantees a valid
/// topological order and rules out cycles.
pub(crate) struct SerialGraph {
    output_channels: usize,
    /// Index 0 is the output node.
    specs: Vec<NodeSpec>,
    nodes: Vec<Option<Box<dyn NodeProcessor>>>,
    edges: Vec<Edge>,
}

impl SerialGraph {
    pub fn new(output_channels: usize) -> Self {
        Self {
            output_channels,
            specs: vec![NodeSpec {
                name: "graph_out",
                inputs: output_channels,
                outputs: 0,
            }],
            nodes: vec![None],
            edges: Vec::new(),
        }
    }
}

impl AudioGraph for SerialGraph {
    fn backend(&self) -> GraphBackend {
        GraphBackend::Serial
    }

    fn add_node(&mut self, spec: NodeSpec, processor: Box<dyn NodeProcessor>) -> UpResult<NodeId> {
        check_spec(&spec)?;
        self.specs.push(spec);
        self.nodes.push(Some(processor));
        Ok(NodeId((self.specs.len() - 1) as u32))
    }

    fn connect(
        &mut self,
        src: NodeId,
        src_port: usize,
        dst: NodeId,
        dst_port: usize,
    ) -> UpResult<()> {
        let (s, d) = (src.0 as usize, dst.0 as usize);
        let ss = self
            .specs
            .get(s)
            .ok_or_else(|| UpError::not_found("source node"))?;
        let ds = self
            .specs
            .get(d)
            .ok_or_else(|| UpError::not_found("destination node"))?;
        if src_port >= ss.outputs || dst_port >= ds.inputs {
            return Err(UpError::invalid("port out of range"));
        }
        if s == 0 || (d != 0 && d <= s) {
            return Err(UpError::invalid(
                "serial graph edges must go from an earlier node to a later node",
            ));
        }
        self.edges.push(Edge {
            src: s,
            src_port,
            dst: d,
            dst_port,
        });
        Ok(())
    }

    fn output_node(&self) -> NodeId {
        NodeId(0)
    }

    fn activate(&mut self, cfg: StreamConfig) -> UpResult<Box<dyn GraphProcessor>> {
        if cfg.output_channels == 0 || cfg.max_block_frames == 0 {
            return Err(UpError::invalid("invalid stream config"));
        }
        let mut nodes = Vec::with_capacity(self.nodes.len());
        for (i, n) in self.nodes.iter_mut().enumerate() {
            if i == 0 {
                nodes.push(None);
                continue;
            }
            nodes.push(Some(
                n.take()
                    .ok_or_else(|| UpError::state("graph already activated"))?,
            ));
        }
        let block = cfg.max_block_frames;
        let buf = |n: usize| (0..n).map(|_| vec![0.0f32; block]).collect::<Vec<_>>();
        Ok(Box::new(SerialProcessor {
            sample_rate: cfg.sample_rate,
            block,
            graph_outputs: self.output_channels,
            inputs: self.specs.iter().map(|s| buf(s.inputs)).collect(),
            outputs: self.specs.iter().map(|s| buf(s.outputs)).collect(),
            nodes,
            edges: std::mem::take(&mut self.edges),
        }))
    }

    fn update(&mut self) -> UpResult<()> {
        Ok(())
    }
}

struct SerialProcessor {
    sample_rate: u32,
    block: usize,
    graph_outputs: usize,
    inputs: Vec<Vec<Vec<f32>>>,
    outputs: Vec<Vec<Vec<f32>>>,
    nodes: Vec<Option<Box<dyn NodeProcessor>>>,
    edges: Vec<Edge>,
}

impl SerialProcessor {
    fn run_block(&mut self, frames: usize) {
        let info = ProcessInfo {
            frames,
            sample_rate: self.sample_rate,
        };
        for i in (1..self.nodes.len()).chain(std::iter::once(0)) {
            // Gather inputs.
            for port in self.inputs[i].iter_mut() {
                port[..frames].fill(0.0);
            }
            for e in self.edges.iter().filter(|e| e.dst == i) {
                let (src_buf, dst_buf) = (
                    &self.outputs[e.src][e.src_port],
                    &mut self.inputs[i][e.dst_port],
                );
                for (d, s) in dst_buf[..frames].iter_mut().zip(&src_buf[..frames]) {
                    *d += *s;
                }
            }
            if i == 0 {
                break;
            }
            let Some(node) = self.nodes[i].as_mut() else {
                continue;
            };
            let empty: &[f32] = &[];
            let mut ins: [&[f32]; MAX_PORTS] = [empty; MAX_PORTS];
            for (slot, b) in ins.iter_mut().zip(self.inputs[i].iter()) {
                *slot = &b[..frames];
            }
            let n_in = self.inputs[i].len();
            let n_out = self.outputs[i].len();
            let mut it = self.outputs[i].iter_mut();
            let mut outs: [&mut [f32]; MAX_PORTS] =
                std::array::from_fn(|_| it.next().map_or(&mut [][..], |b| &mut b[..frames]));
            node.process(&info, &ins[..n_in], &mut outs[..n_out]);
        }
    }
}

impl GraphProcessor for SerialProcessor {
    fn process_interleaved(&mut self, out: &mut [f32], channels: usize) {
        let channels = channels.max(1);
        let total = out.len() / channels;
        let mut done = 0;
        while done < total {
            let frames = (total - done).min(self.block);
            self.run_block(frames);
            for f in 0..frames {
                let frame = &mut out[(done + f) * channels..(done + f + 1) * channels];
                for (c, s) in frame.iter_mut().enumerate() {
                    *s = if c < self.graph_outputs {
                        self.inputs[0][c][f]
                    } else {
                        0.0
                    };
                }
            }
            done += frames;
        }
    }
}
