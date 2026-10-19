//! 导入歌曲并自动拆成 Kit（`runtime/up-split`）：本地完成速度 / 小节分析、可选的 Demucs 分轨，
//! 再按“一个音色组 = 一个完整段落，组内一个 pad = 一个乐器”的排布导入曲库（同官方曲库）。
//!
//! 流程：`split_capabilities` 查本机能否分轨 → `split_song`（进度流，结束于 `Done` / `Failed`）→ 可用 `split_cancel` 取消。
//! 分轨模型（htdemucs ONNX）不随应用分发，由 Dart 侧在用户同意后下载并校验，再把路径传进来。

use super::types::*;
use crate::frb_generated::StreamSink;
use crate::state::{self, lib_err};
use flutter_rust_bridge::frb;
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};

type R<T> = Result<T, UpError>;

static CANCEL: AtomicBool = AtomicBool::new(false);
static RUNNING: AtomicBool = AtomicBool::new(false);

/// 本机分轨能力。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SplitCapabilities {
    /// 当前可用内存足以跑 Demucs（单曲约 4.6 GB 以上）。
    pub separation_available: bool,
    /// 当前可用内存（MB），读不到为 `None`。
    pub available_memory_mb: Option<u32>,
    /// 分轨一首 4 分钟的歌需要的内存（MB）。
    pub separation_memory_mb: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SplitStage {
    LoadingModel,
    Decoding,
    Analyzing,
    Separating,
    Building,
    Importing,
}

#[derive(Debug, Clone, PartialEq)]
#[allow(clippy::large_enum_variant)]
pub enum SplitProgress {
    Progress {
        stage: SplitStage,
        /// 0..=1，该阶段内的完成比例。
        fraction: f32,
    },
    Done {
        kit: KitSummary,
        bpm: f32,
        sections: u32,
        /// 速度 / 小节估计是否可靠（不可靠时界面应提示可能偏拍）。
        reliable: bool,
        separated: bool,
    },
    Failed {
        error: UpError,
    },
}

const FOUR_MIN_FRAMES: usize = 4 * 60 * 44_100;

/// 查询本机能否分轨。
#[frb(sync)]
pub fn split_capabilities() -> SplitCapabilities {
    let need = up_split::demucs::PEAK_MB + (FOUR_MIN_FRAMES as u64 * 80) / (1024 * 1024);
    let have = up_split::separate::available_memory_mb();
    SplitCapabilities {
        separation_available: have.is_none_or(|h| h >= need),
        available_memory_mb: have.map(|h| h as u32),
        separation_memory_mb: need as u32,
    }
}

fn map_err(e: up_split::SplitError) -> UpError {
    use up_split::SplitError as S;
    let (code, tag) = match &e {
        S::Decode(_) => (ErrorCode::Codec, "decode"),
        S::TooShort { .. } => (ErrorCode::InvalidArgument, "too_short"),
        S::NoGrid { .. } => (ErrorCode::InvalidArgument, "no_grid"),
        S::InsufficientMemory { .. } => (ErrorCode::InvalidState, "insufficient_memory"),
        S::Model(_) => (ErrorCode::Format, "model"),
        S::Separate(_) => (ErrorCode::Internal, "separate"),
        S::Cancelled => (ErrorCode::InvalidState, "cancelled"),
        S::Kit(_) => (ErrorCode::Internal, "kit"),
    };
    UpError {
        code,
        message: format!("[{tag}] {e}"),
    }
}

fn stage(s: up_split::Stage) -> SplitStage {
    match s {
        up_split::Stage::Decoding => SplitStage::Decoding,
        up_split::Stage::Analyzing => SplitStage::Analyzing,
        up_split::Stage::Separating => SplitStage::Separating,
        up_split::Stage::Building => SplitStage::Building,
    }
}

fn run(
    path: &str,
    title: Option<String>,
    model_path: Option<String>,
    known_bpm: Option<f32>,
    sink: &StreamSink<SplitProgress>,
) -> R<SplitProgress> {
    let lib = state::library()?;
    let emit = |stage: SplitStage, fraction: f32| {
        let _ = sink.add(SplitProgress::Progress { stage, fraction });
    };
    let p = Path::new(path);
    let bytes = std::fs::read(p).map_err(|e| UpError {
        code: if e.kind() == std::io::ErrorKind::NotFound {
            ErrorCode::NotFound
        } else {
            ErrorCode::Io
        },
        message: format!("{path}: {e}"),
    })?;
    let ext = p
        .extension()
        .and_then(|e| e.to_str())
        .map(str::to_ascii_lowercase);
    let title = title.filter(|t| !t.trim().is_empty()).unwrap_or_else(|| {
        p.file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("Imported song")
            .to_owned()
    });
    emit(SplitStage::Decoding, 0.0);
    let audio = up_codec::decode_bytes(bytes, ext.as_deref())
        .map_err(|e| map_err(up_split::SplitError::Decode(e.to_string())))?;

    let demucs = match &model_path {
        Some(m) => {
            emit(SplitStage::LoadingModel, 0.0);
            let d = up_split::demucs::Demucs::load(Path::new(m)).map_err(map_err)?;
            emit(SplitStage::LoadingModel, 1.0);
            Some(d)
        }
        None => None,
    };
    let opts = up_split::SplitOptions {
        title: &title,
        separator: demucs.as_ref().map(|d| d as &dyn up_split::Separator),
        known_bpm: known_bpm.map(f64::from),
        ..Default::default()
    };
    let outcome = up_split::split_song(&audio, &opts, &mut |s, f| {
        emit(stage(s), f);
        !CANCEL.load(Ordering::Relaxed)
    })
    .map_err(map_err)?;

    emit(SplitStage::Importing, 0.0);
    let mut doc = outcome.kit.doc;
    doc.authors = vec![];
    let opts = up_format::upkit::BuildOptions {
        generator: Some("UltraPads song splitter".into()),
        ..Default::default()
    };
    let pkg =
        up_format::upkit::UpkitPackage::build(&doc, outcome.kit.assets, &opts).map_err(|e| {
            UpError {
                code: ErrorCode::Format,
                message: e.to_string(),
            }
        })?;
    let zip = up_library::archive::zip_to_vec(&pkg.zip_entries()).map_err(lib_err)?;
    let rep = lib
        .import_zip_bytes(&format!("{title}.upkit"), &zip)
        .map_err(lib_err)?;
    let id = rep
        .kits
        .first()
        .map(|k| k.kit_id.clone())
        .ok_or_else(|| UpError {
            code: ErrorCode::Internal,
            message: "import produced no kit".into(),
        })?;
    let summary = lib.kit_summary(&id).map_err(lib_err)?;
    state::core()?.emit(up_engine::EngineEvent::LibraryChanged);
    Ok(SplitProgress::Done {
        kit: kit_summary_from_library(&summary, &lib),
        bpm: outcome.grid.bpm as f32,
        sections: outcome.sections.len() as u32,
        reliable: outcome.grid.reliable(),
        separated: outcome.separated,
    })
}

/// 把 `path` 指向的歌拆成 Kit 并导入曲库，进度经 `sink` 推送。立即返回；同一时刻只有一个拆分。
///
/// * `model_path`：给了就先用 Demucs 分轨（每个乐器一个 pad），不给就只拆整曲混音（每段 pad 1 是整段，其余是 2 / 1 小节片段）。
/// * `known_bpm`：已知速度时给出，只在 ±0.5 BPM 内精扫，结果更稳。
pub fn split_song(
    path: String,
    title: Option<String>,
    model_path: Option<String>,
    known_bpm: Option<f32>,
    sink: StreamSink<SplitProgress>,
) -> R<()> {
    state::library()?;
    if RUNNING.swap(true, Ordering::AcqRel) {
        return Err(UpError {
            code: ErrorCode::InvalidState,
            message: "[busy] a split is already running".into(),
        });
    }
    CANCEL.store(false, Ordering::Relaxed);
    std::thread::Builder::new()
        .name("up-split".into())
        .spawn(move || {
            let res = run(&path, title, model_path, known_bpm, &sink);
            let _ = sink.add(match res {
                Ok(done) => done,
                Err(error) => SplitProgress::Failed { error },
            });
            RUNNING.store(false, Ordering::Release);
        })
        .map_err(|e| {
            RUNNING.store(false, Ordering::Release);
            UpError {
                code: ErrorCode::Internal,
                message: format!("spawn split: {e}"),
            }
        })?;
    Ok(())
}

/// 取消正在进行的拆分（流以 `Failed { [cancelled] }` 结束）。
pub fn split_cancel() {
    CANCEL.store(true, Ordering::Relaxed);
}
