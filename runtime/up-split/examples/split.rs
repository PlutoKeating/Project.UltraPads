//! 开发用命令行：`cargo run -p up-split --release --example split -- <音频> <输出目录> [模型.onnx]`
//! 把一首歌拆成 Kit 目录（kit.json + samples/），带模型路径时先分轨。

use std::path::Path;

use up_split::{SplitOptions, Stage, split_song};

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.len() < 2 {
        eprintln!("用法：split <音频> <输出目录> [模型.onnx]");
        std::process::exit(2);
    }
    let bytes = std::fs::read(&args[0]).expect("读文件");
    let ext = Path::new(&args[0])
        .extension()
        .and_then(|e| e.to_str())
        .map(str::to_lowercase);
    let audio = up_codec::decode_bytes(bytes, ext.as_deref()).expect("解码");
    #[cfg(feature = "demucs")]
    let sep = args
        .get(2)
        .map(|m| up_split::demucs::Demucs::load(Path::new(m)).expect("加载模型"));
    #[cfg(not(feature = "demucs"))]
    let sep: Option<up_split::demucs::Demucs> = None;
    let opts = SplitOptions {
        title: Path::new(&args[0])
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("song"),
        separator: sep.as_ref().map(|s| s as &dyn up_split::Separator),
        ..Default::default()
    };
    let out = split_song(&audio, &opts, &mut |stage, p| {
        if matches!(stage, Stage::Separating) {
            eprint!("\r分轨 {:>3.0}%", p * 100.0);
        }
        true
    })
    .expect("拆分");
    eprintln!();
    println!(
        "bpm {:.2} offset {:.3} conf {:.1} drift {:.4} reliable {}",
        out.grid.bpm,
        out.grid.offset,
        out.grid.confidence,
        out.grid.drift,
        out.grid.reliable()
    );
    println!(
        "sections {:?}",
        out.sections.iter().map(|s| s.start_bar).collect::<Vec<_>>()
    );
    let dir = Path::new(&args[1]);
    std::fs::create_dir_all(dir.join("samples")).unwrap();
    std::fs::write(
        dir.join("kit.json"),
        serde_json::to_vec_pretty(&out.kit.doc).unwrap(),
    )
    .unwrap();
    for (rel, bytes) in &out.kit.assets {
        std::fs::write(dir.join(rel), bytes).unwrap();
    }
    println!("{} pads", out.kit.doc.pads.len());
}
