use up_graph::*;
use up_rt::alloc_check::{CountingAlloc, count_allocs};

#[global_allocator]
static A: CountingAlloc = CountingAlloc;

/// Emits a ramp on two outputs.
struct Ramp {
    n: u64,
}
impl NodeProcessor for Ramp {
    fn process(&mut self, info: &ProcessInfo, _i: &[&[f32]], outputs: &mut [&mut [f32]]) {
        let (l, r) = outputs.split_at_mut(1);
        for (f, (a, b)) in l[0]
            .iter_mut()
            .zip(r[0].iter_mut())
            .take(info.frames)
            .enumerate()
        {
            let v = ((self.n + f as u64) % 100) as f32 / 100.0;
            *a = v;
            *b = -v;
        }
        self.n += info.frames as u64;
    }
}

/// Scales inputs by 0.5.
struct Half;
impl NodeProcessor for Half {
    fn process(&mut self, info: &ProcessInfo, inputs: &[&[f32]], outputs: &mut [&mut [f32]]) {
        for (o, i) in outputs.iter_mut().zip(inputs) {
            for f in 0..info.frames {
                o[f] = i[f] * 0.5;
            }
        }
    }
}

/// Returns the graph too: dropping a Firewheel context deactivates its processor.
fn build(backend: GraphBackend) -> (Box<dyn AudioGraph>, Box<dyn GraphProcessor>) {
    let mut g = new_graph(backend, 2).unwrap();
    let a = g
        .add_node(
            NodeSpec {
                name: "ramp",
                inputs: 0,
                outputs: 2,
            },
            Box::new(Ramp { n: 0 }),
        )
        .unwrap();
    let b = g
        .add_node(
            NodeSpec {
                name: "ramp2",
                inputs: 0,
                outputs: 2,
            },
            Box::new(Ramp { n: 0 }),
        )
        .unwrap();
    let h = g
        .add_node(
            NodeSpec {
                name: "half",
                inputs: 2,
                outputs: 2,
            },
            Box::new(Half),
        )
        .unwrap();
    for p in 0..2 {
        g.connect(a, p, h, p).unwrap();
        g.connect(b, p, h, p).unwrap(); // summed
        g.connect(h, p, g.output_node(), p).unwrap();
    }
    let p = g
        .activate(StreamConfig {
            sample_rate: 48_000,
            max_block_frames: 256,
            output_channels: 2,
        })
        .unwrap();
    (g, p)
}

fn render(p: &mut dyn GraphProcessor, blocks: usize, block: usize) -> Vec<f32> {
    let mut out = vec![0.0; blocks * block * 2];
    for chunk in out.chunks_mut(block * 2) {
        p.process_interleaved(chunk, 2);
    }
    out
}

#[test]
fn serial_backend_sums_and_chains() {
    let (_g, mut p) = build(GraphBackend::Serial);
    let out = render(p.as_mut(), 4, 1000); // > max block: split internally
    for f in 0..4000 {
        let v = (f % 100) as f32 / 100.0;
        assert!((out[f * 2] - v).abs() < 1e-6, "frame {f}");
        assert!((out[f * 2 + 1] + v).abs() < 1e-6);
    }
}

#[test]
fn firewheel_matches_serial_after_declick() {
    let (_g1, mut fw) = build(GraphBackend::Firewheel);
    let (_g2, mut se) = build(GraphBackend::Serial);
    let a = render(fw.as_mut(), 20, 512);
    let b = render(se.as_mut(), 20, 512);
    // Firewheel fades the graph in (declick) during the first ~10 ms.
    let skip = 48_000 / 50 * 2;
    for (i, (x, y)) in a.iter().zip(&b).enumerate().skip(skip) {
        assert!((x - y).abs() < 1e-5, "sample {i}: {x} vs {y}");
    }
    assert!(a.iter().any(|s| *s != 0.0));
}

#[test]
fn both_backends_process_without_allocating() {
    for backend in [GraphBackend::Serial, GraphBackend::Firewheel] {
        let (_g, mut p) = build(backend);
        let mut out = vec![0.0; 512 * 2];
        for _ in 0..4 {
            p.process_interleaved(&mut out, 2);
        }
        let ((), n) = count_allocs(|| {
            for _ in 0..200 {
                p.process_interleaved(&mut out, 2);
            }
        });
        assert_eq!(n, 0, "{backend:?} allocated {n} times");
    }
}

#[test]
fn serial_rejects_backward_edges() {
    let mut g = new_graph(GraphBackend::Serial, 2).unwrap();
    let a = g
        .add_node(
            NodeSpec {
                name: "a",
                inputs: 2,
                outputs: 2,
            },
            Box::new(Half),
        )
        .unwrap();
    let b = g
        .add_node(
            NodeSpec {
                name: "b",
                inputs: 2,
                outputs: 2,
            },
            Box::new(Half),
        )
        .unwrap();
    assert!(g.connect(b, 0, a, 0).is_err());
    assert!(g.connect(a, 5, b, 0).is_err());
}
