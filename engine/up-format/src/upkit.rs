//! `.upkit` 包的逻辑模型，以及 [`KitDoc`] ↔ `kit.sfz` + `ultrapads-kit.json` + `manifest.json` 的映射。
//!
//! 包结构（规格 §6.2）：
//! ```text
//! mimetype               application/vnd.ultrapads.kit+zip（ZIP 首条目，STORED）
//! manifest.json          包元数据 + 每个文件的 blake3
//! kit.sfz                标准 SFZ：声音行为唯一真相源
//! ultrapads-kit.json     交互/布局/外观扩展
//! samples/…  tutorials/…  skin/…  LICENSE.txt
//! ```
//! 本模块只处理“文件名 → 字节”的映射；ZIP 读写与限额在 `up-library`。

use std::collections::{BTreeMap, BTreeSet};

use crate::kit::{
    ChokeMode, KitDoc, KitTempo, Launch, LaunchMode, MAX_PADS, PadAddr, PadColor, PadDoc, PadKind,
    Quantize, SampleLayer,
};
use crate::kit_json::{KitJson, KitTempoJson, PadJson};
use crate::manifest::Manifest;
use crate::sfz::{self, Header, IncludeResolver, Section, SfzFile, fmt_num};
use crate::{FormatError, Result, Warning, kit_json, manifest};

pub const MIMETYPE_FILE: &str = "mimetype";
pub const SFZ_FILE: &str = "kit.sfz";
pub const SAMPLES_DIR: &str = "samples";

// ---------------------------------------------------------------------------
// KitDoc → SFZ / JSON
// ---------------------------------------------------------------------------

fn loop_mode_for(pad: &PadDoc) -> &'static str {
    match (pad.kind, pad.launch.mode) {
        (PadKind::Loop, LaunchMode::Gate) => "loop_sustain",
        (PadKind::Loop, _) => "loop_continuous",
        (PadKind::OneShot, LaunchMode::Gate) => "no_loop",
        (PadKind::OneShot, _) => "one_shot",
    }
}

/// 生成只使用 UltraPads SFZ Profile 白名单 opcode 的 `kit.sfz`。
pub fn kit_to_sfz(doc: &KitDoc) -> SfzFile {
    let mut file = SfzFile {
        header_comment: Some(format!(
            "UltraPads Kit: {}\n声音定义；交互/布局信息见 ultrapads-kit.json\npad 音符 = 36 + 平铺序号（A1=36 … B12=59）",
            doc.name
        )),
        sections: Vec::new(),
    };
    let mut control = Section::new(Header::Control);
    let mut pads: Vec<&PadDoc> = doc.pads.iter().collect();
    pads.sort_by_key(|p| p.addr);
    for p in &pads {
        if let Some(name) = &p.name {
            control.push(&format!("label_key{}", p.note), sanitize_value(name));
        }
    }
    if !control.opcodes.is_empty() {
        file.sections.push(control);
    }
    let bpb = doc.beats_per_bar();
    for p in pads {
        if p.layers.is_empty() {
            continue;
        }
        let title = format!(
            "---- Pad {}{}{} ----",
            p.addr.bank_letter(),
            p.addr.index + 1,
            p.name
                .as_deref()
                .map(|n| format!(": {n}"))
                .unwrap_or_default()
        );
        let mut g = Section::new(Header::Group).with_comment(title);
        g.push("key", p.note);
        g.push("loop_mode", loop_mode_for(p));
        if let Some(group) = p.choke_group {
            g.push("group", group);
        }
        if let Some(off_by) = p.choked_by {
            g.push("off_by", off_by);
            match p.choke_mode {
                ChokeMode::Fast => {
                    g.push("off_mode", "fast");
                }
                ChokeMode::Normal => {
                    g.push("off_mode", "normal");
                }
                ChokeMode::Time(t) => {
                    g.push("off_mode", "time");
                    g.push("off_time", fmt_num(f64::from(t)));
                }
            }
        }
        if p.self_choke {
            g.push("note_polyphony", 1);
        }
        if let Some(n) = p.seq_length.filter(|n| *n > 1) {
            g.push("seq_length", n);
        }
        if let Some(beats) = p.launch.quantize.beats(bpb) {
            g.push("sync_beats", fmt_num(beats));
        }
        if p.pan != 0.0 {
            g.push(
                "pan",
                fmt_num(f64::from((p.pan * 100.0).clamp(-100.0, 100.0))),
            );
        }
        if let Some(name) = &p.name {
            g.push("group_label", sanitize_value(name));
        }
        file.sections.push(g);
        for l in &p.layers {
            let mut r = Section::new(Header::Region);
            r.push("sample", &l.sample);
            if l.lovel != 0 || l.hivel != 127 {
                r.push("lovel", l.lovel);
                r.push("hivel", l.hivel);
            }
            if let Some(pos) = l.seq_position {
                r.push("seq_position", pos);
            }
            if let Some([lo, hi]) = l.rand_range {
                r.push("lorand", fmt_num(f64::from(lo)));
                r.push("hirand", fmt_num(f64::from(hi)));
            }
            if let Some(root) = l.root_key {
                r.push("pitch_keycenter", root);
            }
            if let Some(s) = l.start_frame {
                r.push("offset", s);
            }
            if let Some(e) = l.end_frame {
                r.push("end", e);
            }
            if let (Some(s), Some(e)) = (l.loop_start, l.loop_end) {
                r.push("loop_start", s);
                r.push("loop_end", e);
            }
            if l.tune_cents != 0 {
                r.push("tune", l.tune_cents);
            }
            if l.transpose != 0 {
                r.push("transpose", l.transpose);
            }
            let vol = p.gain_db + l.volume_db;
            if vol != 0.0 {
                r.push("volume", fmt_num(f64::from(vol)));
            }
            file.sections.push(r);
        }
    }
    file
}

fn sanitize_value(s: &str) -> String {
    s.replace(['\n', '\r', '<', '='], " ").trim().to_string()
}

/// 生成 `ultrapads-kit.json`。
pub fn kit_to_json(doc: &KitDoc) -> KitJson {
    let mut j = KitJson::new(doc.pad_count);
    j.tempo = doc.tempo.map(|t| KitTempoJson {
        bpm: t.bpm,
        time_signature: t.time_signature,
    });
    j.tutorials = doc.tutorials.clone();
    j.skin = doc.skin.clone();
    j.cover = doc.cover.clone();
    j.theme_color = doc.theme_color.clone();
    let mut pads: Vec<&PadDoc> = doc.pads.iter().collect();
    pads.sort_by_key(|p| p.addr);
    for p in pads {
        let mut pj = PadJson::new(p.note);
        pj.bank = Some(p.addr.bank_letter().into());
        pj.index = Some(p.addr.index);
        pj.name = p.name.clone();
        pj.color = Some(p.color.clone());
        pj.icon = p.icon.clone();
        pj.kind = Some(p.kind);
        pj.launch = Some(p.launch);
        pj.tempo = p.tempo;
        pj.exclusive = p.exclusive.clone();
        pj.extra = p.extra.clone();
        j.pads.push(pj);
    }
    j
}

/// 构建包时的附加信息（纯格式层不读时钟，由调用方传入）。
#[derive(Debug, Clone, Default)]
pub struct BuildOptions {
    pub created: Option<String>,
    pub updated: Option<String>,
    pub generator: Option<String>,
}

/// `.upkit` 的逻辑模型：规范化的包内路径 → 字节。
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct UpkitPackage {
    pub files: BTreeMap<String, Vec<u8>>,
}

/// 读取包的结果。
#[derive(Debug, Clone)]
pub struct LoadedPackage {
    pub doc: KitDoc,
    /// 包内的 manifest（没有 manifest 时为根据内容重新生成的）。
    pub manifest: Manifest,
    pub warnings: Vec<Warning>,
}

/// 读取选项。
#[derive(Debug, Clone)]
pub struct ReadOptions {
    /// 没有 `manifest.json` 时报错（默认只警告）。
    pub require_manifest: bool,
    /// 用于没有 manifest/JSON 时的 Kit 名称与 ID。
    pub fallback_name: String,
    pub fallback_id: String,
}

impl Default for ReadOptions {
    fn default() -> Self {
        Self {
            require_manifest: false,
            fallback_name: "Untitled Kit".into(),
            fallback_id: "urn:uuid:00000000-0000-0000-0000-000000000000".into(),
        }
    }
}

struct PackageResolver<'a> {
    files: &'a BTreeMap<String, Vec<u8>>,
    base: String,
}

impl IncludeResolver for PackageResolver<'_> {
    fn resolve(&mut self, path: &str) -> std::result::Result<String, String> {
        let p = crate::path::join(&self.base, path).map_err(|e| e.to_string())?;
        let bytes = self
            .files
            .get(&p)
            .ok_or_else(|| format!("包内不存在 {p}"))?;
        String::from_utf8(bytes.clone()).map_err(|_| format!("{p} 不是 UTF-8"))
    }
}

fn parent_dir(path: &str) -> String {
    match path.rfind('/') {
        Some(i) => path[..i].to_string(),
        None => String::new(),
    }
}

impl UpkitPackage {
    /// 由“路径 → 字节”构造，路径会被规范化；拒绝不安全路径与重复路径。
    pub fn from_files<I, S>(files: I) -> Result<Self>
    where
        I: IntoIterator<Item = (S, Vec<u8>)>,
        S: AsRef<str>,
    {
        let mut map = BTreeMap::new();
        for (p, bytes) in files {
            let norm = crate::path::normalize(p.as_ref())?;
            if map.insert(norm.clone(), bytes).is_some() {
                return Err(FormatError::UnsafePath {
                    path: norm,
                    reason: "重复的包内路径",
                });
            }
        }
        Ok(Self { files: map })
    }

    /// 由 KitDoc 和资源文件（采样、教程、封面……，键为包内路径）构建完整包。
    pub fn build(
        doc: &KitDoc,
        assets: BTreeMap<String, Vec<u8>>,
        options: &BuildOptions,
    ) -> Result<Self> {
        doc.validate()?;
        let mut files = Self::from_files(assets)?.files;
        for p in doc.sample_paths() {
            if !files.contains_key(&p) {
                return Err(FormatError::MissingFile(p));
            }
        }
        for reserved in [
            MIMETYPE_FILE,
            manifest::FILE_NAME,
            kit_json::FILE_NAME,
            SFZ_FILE,
        ] {
            files.remove(reserved);
        }
        files.insert(
            SFZ_FILE.into(),
            kit_to_sfz(doc).to_sfz_string().into_bytes(),
        );
        files.insert(kit_json::FILE_NAME.into(), kit_to_json(doc).to_vec_pretty());
        let mut m = Manifest::new(doc.id.clone(), doc.name.clone());
        m.description = doc.description.clone();
        m.authors = doc.authors.clone();
        if let Some(l) = &doc.license {
            m.license = l.clone();
        }
        m.genres = doc.genres.clone();
        m.tags = doc.tags.clone();
        m.source = doc.source.clone();
        m.created = options.created.clone();
        m.updated = options.updated.clone();
        if let Some(g) = &options.generator {
            m.generator = Some(g.clone());
        }
        for (p, bytes) in &files {
            m.upsert(Manifest::entry_for(p, bytes)?);
        }
        files.insert(manifest::FILE_NAME.into(), m.to_vec_pretty());
        files.insert(
            MIMETYPE_FILE.into(),
            crate::UPKIT_MEDIA_TYPE.as_bytes().to_vec(),
        );
        Ok(Self { files })
    }

    /// 写 ZIP 的条目顺序：`mimetype` 首条目（STORED），音频 STORED，其余 Deflate。
    /// 返回 `(路径, 字节, 是否 STORED)`。
    pub fn zip_entries(&self) -> Vec<(&str, &[u8], bool)> {
        let mut v = Vec::with_capacity(self.files.len());
        if let Some(m) = self.files.get(MIMETYPE_FILE) {
            v.push((MIMETYPE_FILE, m.as_slice(), true));
        }
        for (p, b) in &self.files {
            if p == MIMETYPE_FILE {
                continue;
            }
            let stored = crate::path::media_type_for(p).starts_with("audio/")
                && !p.ends_with(".mid")
                || crate::path::media_type_for(p).starts_with("image/");
            v.push((p.as_str(), b.as_slice(), stored));
        }
        v
    }

    /// 校验并解析包。
    pub fn read(&self, options: &ReadOptions) -> Result<LoadedPackage> {
        let mut warnings = Vec::new();
        if let Some(m) = self.files.get(MIMETYPE_FILE) {
            if m.trim_ascii() != crate::UPKIT_MEDIA_TYPE.as_bytes() {
                warnings.push(Warning::new(
                    "upkit.mimetype",
                    format!("mimetype 不是 {}", crate::UPKIT_MEDIA_TYPE),
                ));
            }
        }
        let manifest = match self.files.get(manifest::FILE_NAME) {
            Some(bytes) => {
                let m = Manifest::from_slice(bytes)?;
                for entry in &m.files {
                    let data = self
                        .files
                        .get(&entry.path)
                        .ok_or_else(|| FormatError::MissingFile(entry.path.clone()))?;
                    m.verify(&entry.path, data)?;
                }
                for p in self.files.keys() {
                    if p != MIMETYPE_FILE && p != manifest::FILE_NAME && m.find(p).is_none() {
                        warnings.push(Warning::new(
                            "upkit.unlisted_file",
                            format!("{p} 未登记在 manifest 中，未做哈希校验"),
                        ));
                    }
                }
                Some(m)
            }
            None if options.require_manifest => {
                return Err(FormatError::MissingFile(manifest::FILE_NAME.into()));
            }
            None => {
                warnings.push(Warning::new(
                    "upkit.no_manifest",
                    "包中没有 manifest.json，未做哈希校验",
                ));
                None
            }
        };
        let json = match self.files.get(kit_json::FILE_NAME) {
            Some(b) => Some(KitJson::from_slice(b)?),
            None => {
                warnings.push(Warning::new(
                    "upkit.no_kit_json",
                    "包中没有 ultrapads-kit.json，按默认布局加载",
                ));
                None
            }
        };
        let sfz_path = json
            .as_ref()
            .map(|j| crate::path::normalize(&j.sfz))
            .transpose()?
            .unwrap_or_else(|| SFZ_FILE.to_string());
        let sfz_path = if self.files.contains_key(&sfz_path) {
            sfz_path
        } else {
            // 兜底：包根目录下唯一的 .sfz
            let candidates: Vec<&String> = self
                .files
                .keys()
                .filter(|p| p.ends_with(".sfz") && !p.contains('/'))
                .collect();
            match candidates.as_slice() {
                [one] => (*one).clone(),
                _ => return Err(FormatError::MissingFile(sfz_path)),
            }
        };
        let text = std::str::from_utf8(&self.files[&sfz_path])
            .map_err(|_| FormatError::InvalidKit(format!("{sfz_path} 不是 UTF-8")))?;
        let mut resolver = PackageResolver {
            files: &self.files,
            base: parent_dir(&sfz_path),
        };
        let parsed = sfz::parse_with(text, &mut resolver, &sfz::ParseOptions::default())?;
        warnings.extend(parsed.warnings);
        let base = parent_dir(&sfz_path);
        let (mut doc, w) = kit_from_parts(
            manifest.as_ref(),
            &parsed.file,
            json.as_ref(),
            &base,
            options,
        );
        warnings.extend(w);
        // 采样存在性 + sample_id
        for pad in &mut doc.pads {
            pad.layers.retain(|l| {
                if self.files.contains_key(&l.sample) {
                    true
                } else {
                    warnings.push(Warning::new(
                        "upkit.missing_sample",
                        format!("采样 {} 不在包中，已忽略该 region", l.sample),
                    ));
                    false
                }
            });
            for l in &mut pad.layers {
                l.sample_id = Some(match manifest.as_ref().and_then(|m| m.find(&l.sample)) {
                    Some(e) => e.blake3.clone(),
                    None => crate::blake3_hex(&self.files[&l.sample]),
                });
            }
        }
        let manifest = match manifest {
            Some(m) => m,
            None => {
                let mut m = Manifest::new(doc.id.clone(), doc.name.clone());
                for (p, b) in &self.files {
                    if p != MIMETYPE_FILE {
                        m.upsert(Manifest::entry_for(p, b)?);
                    }
                }
                m
            }
        };
        Ok(LoadedPackage {
            doc,
            manifest,
            warnings,
        })
    }
}

// ---------------------------------------------------------------------------
// SFZ / JSON / manifest → KitDoc
// ---------------------------------------------------------------------------

fn decode_loop_mode(mode: Option<&str>, has_loop_points: bool) -> (PadKind, LaunchMode) {
    match mode {
        Some("loop_continuous") => (PadKind::Loop, LaunchMode::Toggle),
        Some("loop_sustain") => (PadKind::Loop, LaunchMode::Gate),
        Some("no_loop") => (PadKind::OneShot, LaunchMode::Gate),
        Some("one_shot") => (PadKind::OneShot, LaunchMode::Trigger),
        _ if has_loop_points => (PadKind::Loop, LaunchMode::Toggle),
        _ => (PadKind::OneShot, LaunchMode::Trigger),
    }
}

fn bank_index(bank: Option<&str>, index: Option<u8>) -> Option<PadAddr> {
    let b = match bank.map(|s| s.trim().to_ascii_uppercase()) {
        Some(s) => crate::kit::BANK_LETTERS.iter().position(|l| *l == s)? as u8,
        None => 0,
    };
    let i = index?;
    (i < crate::kit::PADS_PER_BANK).then_some(PadAddr { bank: b, index: i })
}

/// 把 SFZ（+ 可选 JSON 与 manifest）映射为 KitDoc。`base` 是 SFZ 所在目录（包内相对路径）。
///
/// 映射规则：
/// - 每个 region 归属其键位（`lokey..hikey` 为范围时取 `pitch_keycenter` 或 `lokey`）
/// - JSON 中显式给出 bank/index 的音符优先；其余音符若全部落在 36..=59 则按默认映射，
///   否则按音符升序依次填入空闲 pad（超过 24 个音符的部分丢弃并警告）
/// - `loop_mode` → kind/launch；`group`/`off_by`/`off_mode` → choke；`sync_beats` → 量化
pub fn kit_from_parts(
    manifest: Option<&Manifest>,
    sfz: &SfzFile,
    json: Option<&KitJson>,
    base: &str,
    options: &ReadOptions,
) -> (KitDoc, Vec<Warning>) {
    let mut warnings = Vec::new();
    let control = sfz.control();
    let regions = sfz.regions();

    let mut doc = KitDoc::new(
        manifest
            .map(|m| m.id.clone())
            .unwrap_or_else(|| options.fallback_id.clone()),
        manifest
            .map(|m| m.name.clone())
            .unwrap_or_else(|| options.fallback_name.clone()),
    );
    if let Some(m) = manifest {
        doc.description = m.description.clone();
        doc.authors = m.authors.clone();
        doc.license = Some(m.license.clone());
        doc.genres = m.genres.clone();
        doc.tags = m.tags.clone();
        doc.source = m.source.clone();
    }
    if let Some(j) = json {
        doc.tempo = j.tempo.map(|t| KitTempo {
            bpm: t.bpm,
            time_signature: t.time_signature,
        });
        doc.tutorials = j.tutorials.clone();
        doc.skin = j.skin.clone();
        doc.cover = j.cover.clone();
        doc.theme_color = j.theme_color.clone();
    }
    let bpb = doc.beats_per_bar();

    // 1. region → 音符
    let mut by_note: BTreeMap<u8, Vec<&sfz::Region>> = BTreeMap::new();
    for r in &regions {
        if r.trigger() == "release" || r.trigger() == "release_key" {
            warnings.push(Warning::new(
                "sfz.release_trigger",
                format!("region #{} 是 release 触发，打击垫不支持，已忽略", r.index),
            ));
            continue;
        }
        let Some((lo, hi)) = r.key_range() else {
            warnings.push(Warning::new(
                "sfz.no_key",
                format!("region #{} 没有 key/lokey/hikey，已忽略", r.index),
            ));
            continue;
        };
        let note = if lo == hi {
            lo
        } else {
            let c = r
                .pitch_keycenter()
                .filter(|c| (lo..=hi).contains(c))
                .unwrap_or(lo);
            warnings.push(Warning::new(
                "sfz.key_range",
                format!("region #{} 覆盖 {lo}..={hi}，打击垫只取音符 {c}", r.index),
            ));
            c
        };
        by_note.entry(note).or_default().push(r);
    }

    // 2. 音符 → pad
    let mut explicit: BTreeMap<u8, PadAddr> = BTreeMap::new();
    if let Some(j) = json {
        for pj in &j.pads {
            match bank_index(pj.bank.as_deref(), pj.index) {
                Some(addr) => {
                    explicit.insert(pj.note, addr);
                }
                None if pj.index.is_some() || pj.bank.is_some() => warnings.push(Warning::new(
                    "kit_json.bad_address",
                    format!("音符 {} 的 bank/index 非法，改用自动分配", pj.note),
                )),
                None => {}
            }
        }
    }
    let mut notes: BTreeSet<u8> = by_note.keys().copied().collect();
    if let Some(j) = json {
        notes.extend(j.pads.iter().map(|p| p.note));
    }
    let all_default = notes
        .iter()
        .filter(|n| !explicit.contains_key(n))
        .all(|n| PadAddr::from_default_note(*n).is_some());
    let mut used: BTreeSet<PadAddr> = explicit.values().copied().collect();
    let mut assignment: BTreeMap<u8, PadAddr> = BTreeMap::new();
    for n in &notes {
        if let Some(a) = explicit.get(n) {
            assignment.insert(*n, *a);
        } else if all_default {
            let a = PadAddr::from_default_note(*n).expect("已检查");
            if used.insert(a) {
                assignment.insert(*n, a);
            } else {
                warnings.push(Warning::new(
                    "kit.pad_conflict",
                    format!("音符 {n} 的默认 pad 已被占用，已忽略"),
                ));
            }
        }
    }
    if !all_default {
        warnings.push(Warning::new(
            "kit.remapped_notes",
            "SFZ 音符不在 36..=59 内，已按音符升序依次分配到 pad",
        ));
        let mut free = (0..MAX_PADS)
            .map(PadAddr::from_flat)
            .filter(|a| !used.contains(a));
        for n in &notes {
            if assignment.contains_key(n) {
                continue;
            }
            match free.next() {
                Some(a) => {
                    assignment.insert(*n, a);
                }
                None => warnings.push(Warning::new(
                    "kit.too_many_pads",
                    format!("音符 {n} 超出 24 个 pad，已丢弃"),
                )),
            }
        }
    }

    // 3. 构造 pad
    for (note, addr) in &assignment {
        let mut pad = PadDoc::new(*addr);
        pad.note = *note;
        let regs = by_note.get(note).map(Vec::as_slice).unwrap_or_default();
        if let Some(first) = regs.first() {
            let has_loop = first.loop_start().is_some() && first.loop_end().is_some();
            let (kind, mode) = decode_loop_mode(first.loop_mode(), has_loop);
            pad.kind = kind;
            pad.launch.mode = mode;
            if let Some(b) = first.sync_beats() {
                pad.launch.quantize = Quantize::from_beats(b, bpb);
            }
            pad.choke_group = first
                .group()
                .and_then(|g| u32::try_from(g).ok())
                .filter(|g| *g > 0);
            pad.choked_by = first
                .off_by()
                .and_then(|g| u32::try_from(g).ok())
                .filter(|g| *g > 0);
            pad.choke_mode = match first.off_mode() {
                Some("normal") => ChokeMode::Normal,
                Some("time") => ChokeMode::Time(first.off_time().unwrap_or(0.006) as f32),
                _ => ChokeMode::Fast,
            };
            pad.self_choke = first.get("note_polyphony") == Some("1");
            pad.seq_length = first.seq_length().filter(|n| *n > 1);
            pad.pan = (first.pan() / 100.0).clamp(-1.0, 1.0) as f32;
            // SFZ 中 region 的 volume 会覆盖 group 的；导出时写的是“pad 增益 + 层增益”的绝对值，
            // 读回时以第一个 region 的音量作为 pad 增益，其余层记相对值。
            pad.gain_db = first.volume_db() as f32;
            pad.name = control
                .key_labels
                .get(note)
                .cloned()
                .or_else(|| first.label().map(str::to_string))
                .or_else(|| {
                    // 有 JSON 条目时以 JSON 为准（可能故意不命名）；否则用文件名兜底
                    let in_json = json.is_some_and(|j| j.pads.iter().any(|p| p.note == *note));
                    first
                        .sample()
                        .filter(|_| !in_json)
                        .map(|s| crate::path::file_stem(s).to_string())
                });
        }
        for r in regs {
            let Some(raw) = r.sample_path() else {
                warnings.push(Warning::new(
                    "sfz.no_sample",
                    format!("region #{} 没有 sample=，已忽略", r.index),
                ));
                continue;
            };
            if raw.starts_with('*') {
                warnings.push(Warning::new(
                    "sfz.generator",
                    format!("region #{} 使用内置发生器 {raw}，不支持", r.index),
                ));
                continue;
            }
            let path = match crate::path::join(base, &raw) {
                Ok(p) => p,
                Err(e) => {
                    warnings.push(Warning::new("sfz.unsafe_sample_path", e.to_string()));
                    continue;
                }
            };
            let mut l = SampleLayer::new(path);
            let (lo, hi) = r.vel_range();
            l.lovel = lo;
            l.hivel = hi;
            l.seq_position = r.seq_position();
            if let (Some(lo), Some(hi)) = (r.lorand(), r.hirand()) {
                l.rand_range = Some([lo as f32, hi as f32]);
            }
            if r.get("pitch_keycenter").is_some() {
                l.root_key = r.pitch_keycenter();
            }
            l.start_frame = r.offset();
            l.end_frame = r.end().and_then(|e| u64::try_from(e).ok());
            l.loop_start = r.loop_start();
            l.loop_end = r.loop_end();
            l.tune_cents = r.tune_cents() as i32;
            l.transpose = r.transpose() as i32;
            l.volume_db = r.volume_db() as f32 - pad.gain_db;
            pad.layers.push(l);
        }
        doc.pads.push(pad);
    }

    // 4. JSON 覆盖
    if let Some(j) = json {
        for pj in &j.pads {
            let Some(pad) = doc.pads.iter_mut().find(|p| p.note == pj.note) else {
                continue;
            };
            if pj.name.is_some() {
                pad.name = pj.name.clone();
            }
            if let Some(c) = &pj.color {
                pad.color = c.clone();
            }
            pad.icon = pj.icon.clone();
            if let Some(k) = pj.kind {
                pad.kind = k;
            }
            let sfz_quantize = pad.launch.quantize;
            let defaults = match pad.kind {
                PadKind::Loop => j.defaults.loop_.as_ref(),
                PadKind::OneShot => j.defaults.one_shot.as_ref(),
            };
            if let Some(l) = pj.launch.or_else(|| defaults.and_then(|d| d.launch)) {
                pad.launch = merge_launch(l, sfz_quantize, bpb, &mut warnings, pj.note);
            }
            pad.tempo = pj.tempo;
            pad.exclusive = pj.exclusive.clone();
            pad.extra = pj.extra.clone();
        }
    }

    // 5. 颜色缺省：loop 蓝色，其余按 choke 组轮换（与参考设计的列配色习惯一致）
    let json_colored: BTreeSet<u8> = json
        .map(|j| {
            j.pads
                .iter()
                .filter(|p| p.color.is_some())
                .map(|p| p.note)
                .collect()
        })
        .unwrap_or_default();
    for pad in &mut doc.pads {
        if !json_colored.contains(&pad.note) {
            pad.color = default_color(pad);
        }
    }

    // 布局 = 声明的组数与 pad 实际用到的组数中较大者（12 的倍数，至少一组）
    let declared = json
        .map(|j| j.layout.pad_count)
        .filter(|n| *n > 0 && n % crate::kit::PADS_PER_BANK == 0 && *n <= crate::kit::MAX_PADS)
        .unwrap_or(crate::kit::PADS_PER_BANK);
    let used = doc
        .pads
        .iter()
        .map(|p| (p.addr.bank + 1) * crate::kit::PADS_PER_BANK)
        .max()
        .unwrap_or(crate::kit::PADS_PER_BANK);
    doc.pad_count = declared.max(used);
    doc.sort_pads();
    (doc, warnings)
}

fn merge_launch(
    l: Launch,
    sfz_quantize: Quantize,
    bpb: u8,
    warnings: &mut Vec<Warning>,
    note: u8,
) -> Launch {
    let json_beats = l.quantize.beats(bpb);
    let sfz_beats = sfz_quantize.beats(bpb);
    if sfz_beats.is_some() && json_beats.is_some() && json_beats != sfz_beats {
        warnings.push(Warning::new(
            "kit.quantize_conflict",
            format!("音符 {note}：JSON 量化与 SFZ sync_beats 不一致，以 SFZ 为准"),
        ));
        return Launch {
            quantize: sfz_quantize,
            ..l
        };
    }
    l
}

/// 未指定颜色时的默认颜色角色。
pub fn default_color(pad: &PadDoc) -> PadColor {
    use crate::kit::ColorRole::*;
    if pad.kind == PadKind::Loop {
        return PadColor::Role(Blue);
    }
    let cycle = [Orange, Pink, Green, Purple];
    let k = pad
        .choke_group
        .map(|g| g as usize)
        .unwrap_or(usize::from(pad.addr.index % 3));
    PadColor::Role(cycle[k % cycle.len()])
}

/// 重写所有层的采样路径（导入 SFZ/WAV 文件夹时把外部路径映射为 `samples/<name>`）。
pub fn remap_samples(doc: &mut KitDoc, mut f: impl FnMut(&str) -> String) {
    for pad in &mut doc.pads {
        for l in &mut pad.layers {
            l.sample = f(&l.sample);
        }
    }
}

/// 在 `taken` 中为文件名分配不冲突的 `samples/<name>` 路径。
pub fn unique_sample_path(file_name: &str, taken: &mut BTreeSet<String>) -> String {
    let stem = crate::path::file_stem(file_name);
    let ext = crate::path::extension_lower(file_name).unwrap_or_else(|| "wav".into());
    let safe = sanitize_file_stem(stem);
    let mut candidate = format!("{SAMPLES_DIR}/{safe}.{ext}");
    let mut n = 2;
    while !taken.insert(candidate.clone()) {
        candidate = format!("{SAMPLES_DIR}/{safe}-{n}.{ext}");
        n += 1;
    }
    candidate
}

fn sanitize_file_stem(stem: &str) -> String {
    let s: String = stem
        .chars()
        .map(|c| {
            if c.is_alphanumeric() || matches!(c, '-' | '_' | '.' | ' ') {
                c
            } else {
                '_'
            }
        })
        .collect();
    let s = s.trim().trim_matches('.').to_string();
    if s.is_empty() { "sample".into() } else { s }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::kit::{ColorRole, LoopTempo, Retrigger, Stretch, TutorialRef};
    use crate::wav;

    fn wav_bytes(frames: usize) -> Vec<u8> {
        wav::encode_pcm16(1, 44_100, &vec![0.1; frames])
    }

    pub(crate) fn sample_doc() -> (KitDoc, BTreeMap<String, Vec<u8>>) {
        let mut doc = KitDoc::new("urn:uuid:0192f0c0-0000-7000-8000-000000000001", "Test Kit");
        doc.pad_count = 24;
        doc.authors = vec!["Tester".into()];
        doc.license = Some("CC0-1.0".into());
        doc.genres = vec!["hip-hop".into()];
        doc.tempo = Some(KitTempo {
            bpm: 92.0,
            time_signature: [4, 4],
        });
        doc.tutorials = vec![TutorialRef {
            id: "first".into(),
            path: "tutorials/first/tutorial.json".into(),
        }];
        let mut assets = BTreeMap::new();

        let mut kick = PadDoc::new(PadAddr::from_flat(0));
        kick.name = Some("Kick".into());
        kick.color = PadColor::Role(ColorRole::Orange);
        kick.self_choke = true;
        let mut l1 = SampleLayer::new("samples/kick_soft.wav");
        l1.hivel = 100;
        let mut l2 = SampleLayer::new("samples/kick_hard.wav");
        l2.lovel = 101;
        l2.volume_db = 2.0;
        kick.layers = vec![l1, l2];
        kick.gain_db = -3.0;

        let mut hh = PadDoc::new(PadAddr::from_flat(1));
        hh.name = Some("HH Closed".into());
        hh.choke_group = Some(3);
        hh.seq_length = Some(2);
        let mut a = SampleLayer::new("samples/hh_rr1.wav");
        a.seq_position = Some(1);
        let mut b = SampleLayer::new("samples/hh_rr2.wav");
        b.seq_position = Some(2);
        hh.layers = vec![a, b];
        hh.pan = -0.25;

        let mut oh = PadDoc::new(PadAddr::from_flat(2));
        oh.name = Some("HH Open".into());
        oh.choke_group = Some(4);
        oh.choked_by = Some(3);
        oh.choke_mode = ChokeMode::Time(0.03);
        oh.launch.mode = LaunchMode::Gate;
        let mut l = SampleLayer::new("samples/hh_open.wav");
        l.tune_cents = -10;
        l.root_key = Some(40);
        oh.layers = vec![l];

        let mut lp = PadDoc::new(PadAddr { bank: 1, index: 0 });
        lp.name = Some("Groove".into());
        lp.kind = PadKind::Loop;
        lp.launch = Launch {
            mode: LaunchMode::Toggle,
            quantize: Quantize::Bar,
            retrigger: Retrigger::Restart,
        };
        lp.choke_group = Some(10);
        lp.choked_by = Some(10);
        lp.exclusive = Some("loops-B".into());
        lp.tempo = Some(LoopTempo {
            bpm: 92.0,
            beats: Some(16.0),
            time_signature: [4, 4],
            stretch: Stretch::Beats,
        });
        let mut l = SampleLayer::new("samples/loop 92bpm.wav");
        l.loop_start = Some(0);
        l.loop_end = Some(999);
        l.start_frame = Some(0);
        l.end_frame = Some(999);
        lp.layers = vec![l];
        lp.color = PadColor::Hex("#3FA7FF".into());

        doc.pads = vec![kick, hh, oh, lp];
        for p in doc.sample_paths() {
            assets.insert(p, wav_bytes(1000));
        }
        assets.insert(
            "tutorials/first/tutorial.json".into(),
            br#"{"id":"first","steps":[]}"#.to_vec(),
        );
        (doc, assets)
    }

    #[test]
    fn roundtrip_kitdoc_through_package() {
        let (doc, assets) = sample_doc();
        let pkg = UpkitPackage::build(&doc, assets, &BuildOptions::default()).unwrap();
        assert_eq!(pkg.zip_entries()[0].0, MIMETYPE_FILE);
        let sfz_text = String::from_utf8(pkg.files[SFZ_FILE].clone()).unwrap();
        // 导出的 SFZ 只用白名单 opcode
        let parsed = sfz::parse(&sfz_text).unwrap();
        assert!(parsed.warnings.is_empty(), "{:?}", parsed.warnings);
        assert!(sfz_text.contains("sync_beats=4"));
        assert!(sfz_text.contains("off_mode=time"));

        let loaded = pkg.read(&ReadOptions::default()).unwrap();
        assert!(loaded.warnings.is_empty(), "{:?}", loaded.warnings);
        let mut expected = doc.clone();
        for p in &mut expected.pads {
            for l in &mut p.layers {
                l.sample_id = Some(crate::blake3_hex(&pkg.files[&l.sample]));
            }
        }
        // 未设颜色的 pad 读回后得到默认色
        for p in &mut expected.pads {
            if p.addr.flat() == 1 || p.addr.flat() == 2 {
                p.color = loaded.doc.pad(p.addr).unwrap().color.clone();
            }
        }
        assert_eq!(loaded.doc, expected);
    }

    #[test]
    fn tampered_package_is_rejected() {
        let (doc, assets) = sample_doc();
        let mut pkg = UpkitPackage::build(&doc, assets, &BuildOptions::default()).unwrap();
        pkg.files.get_mut("samples/kick_hard.wav").unwrap()[50] ^= 0xFF;
        assert!(matches!(
            pkg.read(&ReadOptions::default()),
            Err(FormatError::HashMismatch { .. })
        ));
        let (doc, assets) = sample_doc();
        let mut pkg = UpkitPackage::build(&doc, assets, &BuildOptions::default()).unwrap();
        pkg.files.remove("samples/hh_rr1.wav");
        assert!(matches!(
            pkg.read(&ReadOptions::default()),
            Err(FormatError::MissingFile(_))
        ));
    }

    #[test]
    fn degrades_without_json_and_manifest() {
        let sfz = "<global> loop_mode=one_shot\n<region> key=36 sample=samples/a.wav\n<region> key=49 sample=samples/b.wav loop_mode=loop_continuous\n";
        let pkg = UpkitPackage::from_files([
            ("kit.sfz", sfz.as_bytes().to_vec()),
            ("samples/a.wav", wav_bytes(10)),
            ("samples/b.wav", wav_bytes(10)),
        ])
        .unwrap();
        let loaded = pkg.read(&ReadOptions::default()).unwrap();
        let codes: Vec<_> = loaded.warnings.iter().map(|w| w.code.as_str()).collect();
        assert!(codes.contains(&"upkit.no_manifest"));
        assert!(codes.contains(&"upkit.no_kit_json"));
        assert_eq!(loaded.doc.pad_count, 24);
        let b = loaded.doc.pad(PadAddr { bank: 1, index: 1 }).unwrap();
        assert_eq!(b.kind, PadKind::Loop);
        assert_eq!(b.color, PadColor::Role(ColorRole::Blue));
        assert_eq!(b.name.as_deref(), Some("b"));
        assert_eq!(loaded.manifest.files.len(), 3);
        assert!(
            UpkitPackage::from_files([("kit.sfz", Vec::new())])
                .unwrap()
                .read(&ReadOptions {
                    require_manifest: true,
                    ..ReadOptions::default()
                })
                .is_err()
        );
    }

    #[test]
    fn gm_style_notes_are_remapped() {
        let sfz = "<region> key=35 sample=k.wav\n<region> key=38 sample=s.wav\n<region> key=42 sample=h.wav\n<region> key=0 hikey=127 pitch_keycenter=60 sample=p.wav";
        let parsed = sfz::parse(sfz).unwrap();
        let (doc, w) = kit_from_parts(None, &parsed.file, None, "", &ReadOptions::default());
        assert!(w.iter().any(|w| w.code == "kit.remapped_notes"));
        assert!(w.iter().any(|w| w.code == "sfz.key_range"));
        let notes: Vec<u8> = doc.pads.iter().map(|p| p.note).collect();
        assert_eq!(notes, vec![35, 38, 42, 60]);
        assert_eq!(doc.pads[0].addr, PadAddr::from_flat(0));
        assert_eq!(doc.pads[3].addr, PadAddr::from_flat(3));
    }

    #[test]
    fn json_overrides_and_conflicts() {
        let sfz = "<group> key=48 loop_mode=loop_continuous sync_beats=4\n<region> sample=l.wav";
        let parsed = sfz::parse(sfz).unwrap();
        let mut j = KitJson::new(24);
        let mut pj = PadJson::new(48);
        pj.bank = Some("B".into());
        pj.index = Some(3);
        pj.launch = Some(Launch {
            mode: LaunchMode::Toggle,
            quantize: Quantize::TwoBars,
            retrigger: Retrigger::Continue,
        });
        pj.color = Some(PadColor::Role(ColorRole::Green));
        j.pads.push(pj);
        let (doc, w) = kit_from_parts(None, &parsed.file, Some(&j), "", &ReadOptions::default());
        assert!(w.iter().any(|w| w.code == "kit.quantize_conflict"));
        let p = &doc.pads[0];
        assert_eq!(p.addr, PadAddr { bank: 1, index: 3 });
        assert_eq!(p.launch.quantize, Quantize::Bar);
        assert_eq!(p.launch.retrigger, Retrigger::Continue);
        assert_eq!(p.color, PadColor::Role(ColorRole::Green));
    }

    #[test]
    fn rejects_unsafe_paths() {
        assert!(UpkitPackage::from_files([("../x", vec![])]).is_err());
        let sfz = "<region> key=36 sample=../../etc/passwd";
        let pkg = UpkitPackage::from_files([("kit.sfz", sfz.as_bytes().to_vec())]).unwrap();
        let loaded = pkg.read(&ReadOptions::default()).unwrap();
        assert!(
            loaded
                .warnings
                .iter()
                .any(|w| w.code == "sfz.unsafe_sample_path")
        );
        assert!(loaded.doc.pads[0].layers.is_empty());
    }

    #[test]
    fn unique_paths() {
        let mut taken = BTreeSet::new();
        assert_eq!(
            unique_sample_path("/x/Kick 1.WAV", &mut taken),
            "samples/Kick 1.wav"
        );
        assert_eq!(
            unique_sample_path("y/Kick 1.wav", &mut taken),
            "samples/Kick 1-2.wav"
        );
        assert_eq!(
            unique_sample_path("a:b?.wav", &mut taken),
            "samples/a_b_.wav"
        );
    }
}
