//! 原 App 素材：旧版 Android APK 3.x 与新版 iOS IPA 4.x。
//!
//! 两个版本的 Kit 结构相同：`Sounds/pad{N}_{preset}.{wav|ogg}` + `Sounds/<Kit 名>.txt`（JSON）：
//! - `behaviour.padN`：100 = Loop（按一下开、再按关）、200 = One-shot（重触发从头播）、300 = Gate（按住播放）
//! - `colors.padN`：`azul`/`azul_loop` → blue、`amarelo` → orange、`rosa` → pink、`verde` → green
//! - `groups.padN`：互斥组：按下一个 pad 时同组其它 pad 立即停止 → SFZ `group=N off_by=N`
//! - `preset`：wav 文件名后缀
//!
//! 目录：旧版 `list.json`，新版 `fetch.json` + `fetch_next.json`（同结构：kits / categories /
//! kitCategories / groupCategories）。教程：旧版 `kit.sequence`（按顺序、不计时，音符码映射见
//! [`android_code_to_pad`]）；新版 `tutorial.json`（计时事件）与 `<id>_lesson.json`（分课）。

use std::collections::{BTreeMap, BTreeSet};

use serde_json::Value;
use up_format::kit::{
    ColorRole, KitDoc, KitSource, LaunchMode, MAX_PADS, PadAddr, PadColor, PadDoc, PadKind,
    SampleLayer, TutorialRef,
};
use up_format::smf::{Chart, Marker, NoteEvent};
use up_format::tutorial::{TutorialDoc, TutorialMode, TutorialStep};
use up_format::upkit;
use up_format::{Warning, wav};

use super::{CompatKit, CompatScan, CompatSource};
use crate::archive::{ImportLimits, MemFs, SourceFs, read_zip};
use crate::error::Result;
use crate::fsutil;
use crate::index::{Catalog, CatalogCategory, CatalogEntry, CatalogStatus};

/// 原 App 素材的内容许可证标记（私有研究，禁止分发）。
pub const PRIVATE_LICENSE: &str = "LicenseRef-Private-Assets";

const MAX_CONFIG_BYTES: u64 = 256 * 1024;
const MAX_CATALOG_BYTES: u64 = 64 * 1024 * 1024;

/// 旧版 APK 3.x。
pub struct AndroidSource;
/// 新版 IPA 4.x。
pub struct IosSource;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Flavor {
    Android,
    Ios,
}

impl Flavor {
    fn id(self) -> &'static str {
        match self {
            Self::Android => "compat-android",
            Self::Ios => "compat-ios",
        }
    }
    fn audio_exts(self) -> &'static [&'static str] {
        match self {
            Self::Android => &["wav"],
            // 新版远程包是 Sounds_OGG.zip；`isMP3` 的 Kit 是 MP3
            Self::Ios => &["ogg", "mp3"],
        }
    }
    fn catalog_files(self) -> &'static [&'static str] {
        match self {
            Self::Android => &["list.json"],
            Self::Ios => &["fetch.json", "fetch_next.json"],
        }
    }
    fn is_kit_zip(self, path: &str) -> bool {
        let name = up_format::path::file_name(path).to_ascii_lowercase();
        if !name.ends_with(".zip") {
            return false;
        }
        match self {
            Self::Android => name == "initialpack.zip" || name == "sounds.zip",
            Self::Ios => {
                let stem = &name[..name.len() - 4];
                (path.contains("initial/sp/")
                    && (stem == "kit" || stem.bytes().all(|b| b.is_ascii_digit())))
                    || name == "sounds.zip"
                    || name == "sounds_ogg.zip"
            }
        }
    }
}

impl CompatSource for AndroidSource {
    fn id(&self) -> &'static str {
        Flavor::Android.id()
    }
    fn detect(&self, fs: &dyn SourceFs) -> bool {
        detect(Flavor::Android, fs)
    }
    fn import(
        &self,
        fs: &dyn SourceFs,
        limits: &ImportLimits,
        emit: &mut dyn FnMut(CompatKit) -> Result<()>,
    ) -> Result<CompatScan> {
        run(Flavor::Android, fs, limits, emit)
    }
}

impl CompatSource for IosSource {
    fn id(&self) -> &'static str {
        Flavor::Ios.id()
    }
    fn detect(&self, fs: &dyn SourceFs) -> bool {
        detect(Flavor::Ios, fs)
    }
    fn import(
        &self,
        fs: &dyn SourceFs,
        limits: &ImportLimits,
        emit: &mut dyn FnMut(CompatKit) -> Result<()>,
    ) -> Result<CompatScan> {
        run(Flavor::Ios, fs, limits, emit)
    }
}

/// `pad12_sunset.wav` → `(12, "wav")`。
pub fn pad_file_number(path: &str) -> Option<(u8, String)> {
    let name = up_format::path::file_name(path).to_ascii_lowercase();
    let rest = name.strip_prefix("pad")?;
    let digits: String = rest.chars().take_while(char::is_ascii_digit).collect();
    let after = &rest[digits.len()..];
    if !after.starts_with('_') {
        return None;
    }
    let n: u8 = digits.parse().ok()?;
    let ext = up_format::path::extension_lower(&name)?;
    (1..=MAX_PADS).contains(&n).then_some((n, ext))
}

fn parent(path: &str) -> &str {
    path.rfind('/').map(|i| &path[..i]).unwrap_or("")
}

fn contains_bytes(hay: &[u8], needle: &[u8]) -> bool {
    hay.windows(needle.len()).any(|w| w == needle)
}

fn detect(flavor: Flavor, fs: &dyn SourceFs) -> bool {
    let files = fs.files();
    let exts = flavor.audio_exts();
    let dirs_with_txt: BTreeSet<&str> = files
        .iter()
        .filter(|f| f.to_ascii_lowercase().ends_with(".txt"))
        .map(|f| parent(f))
        .collect();
    if files.iter().any(|f| {
        pad_file_number(f).is_some_and(|(_, e)| exts.contains(&e.as_str()))
            && dirs_with_txt.contains(parent(f))
    }) {
        return true;
    }
    if files.iter().any(|f| flavor.is_kit_zip(f)) {
        return true;
    }
    files.iter().any(|f| {
        flavor
            .catalog_files()
            .contains(&up_format::path::file_name(f))
            && fs.size(f).is_some_and(|s| s <= MAX_CATALOG_BYTES)
            && fs
                .read(f)
                .is_ok_and(|b| contains_bytes(&b, b"kitCategories"))
    })
}

/// 解析后的 `<Kit>.txt`。
#[derive(Debug, Clone, PartialEq)]
pub struct KitConfig {
    /// pad 编号（1 起）→ (behaviour, color, group)
    pub pads: BTreeMap<u8, (i64, Option<String>, Option<i64>)>,
    pub preset: String,
}

/// 解析配置 JSON（扩展名是 .txt）。缺少 behaviour/colors/groups 时返回 `None`。
pub fn parse_config(bytes: &[u8]) -> Option<KitConfig> {
    let v: Value = serde_json::from_slice(bytes).ok()?;
    let b = v.get("behaviour")?.as_object()?;
    let c = v.get("colors")?.as_object()?;
    let g = v.get("groups")?.as_object()?;
    let preset = v
        .get("preset")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    let mut pads = BTreeMap::new();
    for n in 1..=MAX_PADS {
        let key = format!("pad{n}");
        let Some(beh) = b.get(&key).and_then(Value::as_i64) else {
            continue;
        };
        pads.insert(
            n,
            (
                beh,
                c.get(&key).and_then(Value::as_str).map(str::to_string),
                g.get(&key).and_then(Value::as_i64),
            ),
        );
    }
    Some(KitConfig { pads, preset })
}

/// 原 App 颜色名 → 调色板角色。
pub fn color_role(name: &str) -> Option<ColorRole> {
    match name.trim().to_ascii_lowercase().as_str() {
        "azul" | "azul_loop" | "blue" => Some(ColorRole::Blue),
        "amarelo" | "orange" | "laranja" => Some(ColorRole::Orange),
        "rosa" | "pink" => Some(ColorRole::Pink),
        "verde" | "green" => Some(ColorRole::Green),
        "roxo" | "purple" => Some(ColorRole::Purple),
        "vermelho" | "red" => Some(ColorRole::Red),
        _ => None,
    }
}

/// 旧版教程音符码 → pad 编号（1 起）；100/101 是切页（返回 `None`）。
pub fn android_code_to_pad(code: i64) -> Option<u8> {
    const A: [i64; 12] = [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19];
    if let Some(i) = A.iter().position(|c| *c == code) {
        return Some(i as u8 + 1);
    }
    (23..=34).contains(&code).then(|| (code - 23) as u8 + 13)
}

fn pad_note(n: u8) -> u8 {
    PadAddr::from_flat(n - 1).default_note()
}

fn rgb_to_hex(s: &str) -> Option<String> {
    let parts: Vec<u8> = s
        .split(';')
        .map(|p| p.trim().parse::<u8>())
        .collect::<std::result::Result<_, _>>()
        .ok()?;
    (parts.len() == 3).then(|| format!("#{:02X}{:02X}{:02X}", parts[0], parts[1], parts[2]))
}

fn id_string(v: &Value) -> Option<String> {
    match v {
        Value::Number(n) => Some(n.to_string()),
        Value::String(s) => Some(s.clone()),
        _ => None,
    }
}

/// 目录中一个 Kit 的原始信息。
#[derive(Debug, Clone)]
struct CatalogKit {
    name: String,
    raw: Value,
    genres: Vec<String>,
    tags: Vec<String>,
}

fn parse_catalogs(
    flavor: Flavor,
    docs: &[Value],
    warnings: &mut Vec<Warning>,
) -> (Catalog, BTreeMap<String, CatalogKit>) {
    let src = flavor.id();
    let mut catalog = Catalog::default();
    let mut kits: BTreeMap<String, Value> = BTreeMap::new();
    let mut cats: BTreeMap<String, Value> = BTreeMap::new();
    let mut kit_cats: Vec<Value> = Vec::new();
    let mut group_cats: Vec<Value> = Vec::new();
    for d in docs {
        for k in d
            .get("kits")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
        {
            if let Some(id) = k.get("id").and_then(id_string) {
                if k.get("deleted").and_then(Value::as_bool) == Some(true) {
                    continue;
                }
                kits.insert(id, k.clone());
            }
        }
        for c in d
            .get("categories")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
        {
            if let Some(id) = c.get("id").and_then(id_string) {
                cats.insert(id, c.clone());
            }
        }
        kit_cats.extend(
            d.get("kitCategories")
                .and_then(Value::as_array)
                .into_iter()
                .flatten()
                .cloned(),
        );
        group_cats.extend(
            d.get("groupCategories")
                .and_then(Value::as_array)
                .into_iter()
                .flatten()
                .cloned(),
        );
    }
    // 分组：categoryId 属于 groupId；名字含 GENRE 的分组下的分类就是曲风
    let mut group_of: BTreeMap<String, String> = BTreeMap::new();
    for g in &group_cats {
        if let (Some(c), Some(gr)) = (
            g.get("categoryId").and_then(id_string),
            g.get("groupId").and_then(id_string),
        ) {
            group_of.insert(c, gr);
        }
    }
    let name_of = |id: &str| -> String {
        cats.get(id)
            .and_then(|c| c.get("name"))
            .and_then(Value::as_str)
            .unwrap_or("")
            .trim()
            .to_string()
    };
    let is_genre_cat = |id: &str| -> bool {
        [Some(id.to_string()), group_of.get(id).cloned()]
            .into_iter()
            .flatten()
            .any(|g| name_of(&g).to_ascii_uppercase().contains("GENRE") && g != id)
    };
    for (id, c) in &cats {
        catalog.categories.insert(
            format!("{src}:{id}"),
            CatalogCategory {
                id: format!("{src}:{id}"),
                source: src.into(),
                name: name_of(id),
                order: c.get("order").and_then(Value::as_i64).unwrap_or(0),
                kind: c.get("type").and_then(Value::as_i64).unwrap_or(0),
                group_id: group_of.get(id).map(|g| format!("{src}:{g}")),
                entries: Vec::new(),
            },
        );
    }
    let mut per_kit: BTreeMap<String, Vec<(i64, String)>> = BTreeMap::new();
    for kc in &kit_cats {
        let (Some(k), Some(c)) = (
            kc.get("kitId").and_then(id_string),
            kc.get("categoryId").and_then(id_string),
        ) else {
            continue;
        };
        let order = kc.get("order").and_then(Value::as_i64).unwrap_or(0);
        per_kit
            .entry(k.clone())
            .or_default()
            .push((order, c.clone()));
        if let Some(cat) = catalog.categories.get_mut(&format!("{src}:{c}")) {
            cat.entries.push(format!("{src}:{k}"));
        }
    }
    let mut out = BTreeMap::new();
    for (id, k) in &kits {
        let name = k
            .get("name")
            .and_then(Value::as_str)
            .unwrap_or("")
            .trim()
            .to_string();
        if name.is_empty() {
            continue;
        }
        let mut genres = Vec::new();
        let mut tags = Vec::new();
        let mut cat_ids = Vec::new();
        for (_, c) in per_kit.get(id).map(Vec::as_slice).unwrap_or_default() {
            cat_ids.push(format!("{src}:{c}"));
            let n = name_of(c);
            let kind = cats
                .get(c)
                .and_then(|x| x.get("type"))
                .and_then(Value::as_i64)
                .unwrap_or(0);
            if n.is_empty() || kind >= 100 {
                continue;
            }
            let pretty = title_case(&n);
            if is_genre_cat(c) {
                if !genres.contains(&pretty) {
                    genres.push(pretty);
                }
            } else if !tags.contains(&pretty) {
                tags.push(pretty);
            }
        }
        let show_real = k
            .get("shouldShowRealNames")
            .and_then(Value::as_bool)
            .unwrap_or(false);
        let inspired = match (
            k.get("authorName").and_then(Value::as_str),
            k.get("musicName").and_then(Value::as_str),
        ) {
            (Some(a), Some(m)) if show_real && !a.is_empty() => Some(format!("{a} — {m}")),
            _ => None,
        };
        let has_seq = k
            .get("sequence")
            .and_then(Value::as_array)
            .is_some_and(|s| !s.is_empty());
        let has_tut = has_seq
            || k.get("tutorialUpdateTime")
                .and_then(Value::as_i64)
                .unwrap_or(0)
                > 0
            || k.get("lessonsUpdateTime")
                .and_then(Value::as_i64)
                .unwrap_or(0)
                > 0;
        let video = k
            .get("url")
            .and_then(Value::as_str)
            .filter(|s| !s.is_empty())
            .map(str::to_string);
        let mut extra = serde_json::Map::new();
        for key in [
            "isMP3",
            "tutorialUpdateTime",
            "lessonsUpdateTime",
            "isAuthorial",
            "youkuUrl",
            "orderNew",
        ] {
            if let Some(x) = k.get(key) {
                extra.insert(key.to_string(), x.clone());
            }
        }
        catalog.entries.insert(
            format!("{src}:{id}"),
            CatalogEntry {
                id: format!("{src}:{id}"),
                source: src.into(),
                original_id: id.clone(),
                name: name.clone(),
                inspired_by: inspired,
                genres: genres.clone(),
                tags: tags.clone(),
                category_ids: cat_ids,
                theme_color: k
                    .get("colorBackground")
                    .and_then(Value::as_str)
                    .and_then(rgb_to_hex),
                video_url: video,
                has_tutorial: has_tut,
                is_new: k.get("isNew").and_then(Value::as_bool).unwrap_or(false),
                is_top: k.get("isTop").and_then(Value::as_bool).unwrap_or(false),
                order: k
                    .get("orderTop")
                    .and_then(Value::as_i64)
                    .unwrap_or(i64::MAX / 2),
                difficulty: k
                    .get("difficulty")
                    .and_then(Value::as_str)
                    .map(|d| d.trim().to_lowercase())
                    .filter(|d| !d.is_empty()),
                created_at: k
                    .get("createdAt")
                    .and_then(Value::as_str)
                    .map(str::to_string),
                extra,
                status: CatalogStatus::NotDownloaded,
            },
        );
        out.insert(
            id.clone(),
            CatalogKit {
                name,
                raw: k.clone(),
                genres,
                tags,
            },
        );
    }
    if docs.is_empty() {
        warnings.push(Warning::new(
            "compat.no_catalog",
            "没有找到目录文件，Kit 将不带曲风/教程元数据",
        ));
    }
    (catalog, out)
}

fn title_case(s: &str) -> String {
    let lower = s.to_lowercase();
    let mut out = String::with_capacity(s.len());
    let mut up = true;
    for c in lower.chars() {
        if up {
            out.extend(c.to_uppercase());
        } else {
            out.push(c);
        }
        up = !c.is_alphanumeric();
    }
    out
}

/// 一个待导入的 Kit 位置。
struct Candidate {
    /// 所在文件源（0 = 顶层，其余为嵌套 ZIP 的序号）
    fs: usize,
    dir: String,
    config: KitConfig,
    name: String,
    /// 从目录名（`21_Sunset`）或 ZIP 名（`2947.zip`）推出的原 ID
    hint_id: Option<String>,
    /// 该 Kit 来自的 ZIP 所在目录（用于关联同目录的 tutorial.json）
    zip_dir: Option<String>,
    zip_stem: Option<String>,
}

fn discover(
    flavor: Flavor,
    fs: &dyn SourceFs,
    fs_index: usize,
    zip_info: Option<(&str, &str)>,
    warnings: &mut Vec<Warning>,
) -> Vec<Candidate> {
    let files = fs.files();
    let exts = flavor.audio_exts();
    let mut dirs: BTreeSet<&str> = BTreeSet::new();
    for f in &files {
        if pad_file_number(f).is_some_and(|(_, e)| exts.contains(&e.as_str())) {
            dirs.insert(parent(f));
        }
    }
    let mut out = Vec::new();
    for dir in dirs {
        let config = files.iter().filter(|f| parent(f) == dir).find_map(|f| {
            if !f.to_ascii_lowercase().ends_with(".txt")
                || fs.size(f).is_none_or(|s| s > MAX_CONFIG_BYTES)
            {
                return None;
            }
            let bytes = fs.read(f).ok()?;
            parse_config(&bytes).map(|c| (f.clone(), c))
        });
        let Some((cfg_path, config)) = config else {
            warnings.push(Warning::new(
                "compat.no_config",
                format!("{dir}：有 pad 音频但没有配置 .txt，已跳过"),
            ));
            continue;
        };
        let name = up_format::path::file_stem(&cfg_path).trim().to_string();
        // 目录名 `21_Sunset/Sounds` → 21
        let hint_id = zip_info
            .map(|(_, stem)| stem.to_string())
            .filter(|s| s.bytes().all(|b| b.is_ascii_digit()))
            .or_else(|| {
                dir.split('/').rev().find_map(|c| {
                    let digits: String = c.chars().take_while(char::is_ascii_digit).collect();
                    (!digits.is_empty() && c[digits.len()..].starts_with('_')).then_some(digits)
                })
            });
        out.push(Candidate {
            fs: fs_index,
            dir: dir.to_string(),
            config,
            name,
            hint_id,
            zip_dir: zip_info.map(|(d, _)| d.to_string()),
            zip_stem: zip_info.map(|(_, s)| s.to_string()),
        });
    }
    out
}

fn run(
    flavor: Flavor,
    fs: &dyn SourceFs,
    limits: &ImportLimits,
    emit: &mut dyn FnMut(CompatKit) -> Result<()>,
) -> Result<CompatScan> {
    let mut warnings = Vec::new();
    let files = fs.files();

    // 1. 目录
    let mut docs = Vec::new();
    for want in flavor.catalog_files() {
        for f in files
            .iter()
            .filter(|f| up_format::path::file_name(f) == *want)
        {
            if fs.size(f).is_none_or(|s| s > MAX_CATALOG_BYTES) {
                continue;
            }
            match fs.read(f).map(|b| serde_json::from_slice::<Value>(&b)) {
                Ok(Ok(v)) if v.get("kits").is_some() => {
                    docs.push(v);
                    break;
                }
                _ => warnings.push(Warning::new(
                    "compat.bad_catalog",
                    format!("{f} 无法解析"),
                )),
            }
        }
    }
    let (catalog, catalog_kits) = parse_catalogs(flavor, &docs, &mut warnings);
    let by_name: BTreeMap<String, String> = catalog_kits
        .iter()
        .map(|(id, k)| (k.name.to_lowercase(), id.clone()))
        .collect();

    // 2. 嵌套 ZIP（先处理，使 kit.zip 能关联同目录的 tutorial.json）+ 顶层
    let mut sources: Vec<MemFs> = Vec::new();
    let mut candidates = Vec::new();
    for f in files.iter().filter(|f| flavor.is_kit_zip(f)) {
        let bytes = match fs.read(f) {
            Ok(b) => b,
            Err(e) => {
                warnings.push(Warning::new("compat.zip", format!("{f}：{e}")));
                continue;
            }
        };
        match read_zip(
            std::io::Cursor::new(bytes),
            up_format::path::file_stem(f),
            limits,
        ) {
            Ok(mem) => {
                let idx = sources.len() + 1;
                let stem = up_format::path::file_stem(f).to_string();
                candidates.extend(discover(
                    flavor,
                    &mem,
                    idx,
                    Some((parent(f), &stem)),
                    &mut warnings,
                ));
                sources.push(mem);
            }
            Err(e) => warnings.push(Warning::new("compat.zip", format!("{f}：{e}"))),
        }
    }
    candidates.extend(discover(flavor, fs, 0, None, &mut warnings));

    // 3. 逐个构建
    let mut seen = BTreeSet::new();
    for c in candidates {
        if !seen.insert(c.name.to_lowercase()) {
            continue;
        }
        let cfs: &dyn SourceFs = if c.fs == 0 { fs } else { &sources[c.fs - 1] };
        let orig_id = c
            .hint_id
            .clone()
            .filter(|id| catalog_kits.contains_key(id))
            .or_else(|| by_name.get(&c.name.to_lowercase()).cloned())
            .or_else(|| c.hint_id.clone());
        let info = orig_id.as_ref().and_then(|id| catalog_kits.get(id));
        let (mut doc, mut assets) = match build_kit(flavor, cfs, &c, limits, &mut warnings) {
            Some(x) => x,
            None => continue,
        };
        // 确定性 ID：同一原 App Kit 在不同设备上导入得到同一个 ID（多设备同步不重复）。
        doc.id = fsutil::stable_id(&format!(
            "{}:{}",
            flavor.id(),
            orig_id.as_deref().unwrap_or(&c.name.to_lowercase())
        ));
        if let Some(info) = info {
            doc.genres = info.genres.clone();
            doc.tags = info.tags.clone();
            doc.theme_color = info
                .raw
                .get("colorBackground")
                .and_then(Value::as_str)
                .and_then(rgb_to_hex);
        }
        doc.source = Some(KitSource {
            kind: flavor.id().into(),
            original_id: orig_id.clone(),
            original_name: Some(c.name.clone()),
            inspired_by: catalog
                .entries
                .get(&format!(
                    "{}:{}",
                    flavor.id(),
                    orig_id.clone().unwrap_or_default()
                ))
                .and_then(|e| e.inspired_by.clone()),
        });
        // 教程
        match flavor {
            Flavor::Android => {
                if let Some(seq) = info
                    .and_then(|i| i.raw.get("sequence"))
                    .and_then(Value::as_array)
                {
                    let video = info.and_then(|i| i.raw.get("url")).and_then(Value::as_str);
                    add_sequence_tutorial(&mut doc, &mut assets, seq, video, &mut warnings);
                }
            }
            Flavor::Ios => {
                let tutorial = c
                    .zip_dir
                    .as_ref()
                    .filter(|_| c.zip_stem.as_deref() == Some("kit"))
                    .map(|d| {
                        if d.is_empty() {
                            "tutorial.json".to_string()
                        } else {
                            format!("{d}/tutorial.json")
                        }
                    })
                    .filter(|p| fs.exists(p))
                    .or_else(|| {
                        // 解包后的素材：tutorial.json 是默认 Kit（Sunset，id 21）的教程
                        (orig_id.as_deref() == Some("21"))
                            .then(|| {
                                files
                                    .iter()
                                    .find(|f| up_format::path::file_name(f) == "tutorial.json")
                                    .cloned()
                            })
                            .flatten()
                    });
                if let Some(t) = tutorial {
                    if let Ok(bytes) = fs.read(&t) {
                        add_timed_tutorial(&mut doc, &mut assets, &bytes, &mut warnings);
                    }
                }
                if let Some(id) = &orig_id {
                    let lesson_name = format!("{id}_lesson.json");
                    if let Some(l) = files
                        .iter()
                        .find(|f| up_format::path::file_name(f) == lesson_name)
                    {
                        if let Ok(bytes) = fs.read(l) {
                            add_lessons(&mut doc, &mut assets, &bytes, &mut warnings);
                        }
                    }
                }
            }
        }
        let catalog_id = orig_id.map(|id| format!("{}:{id}", flavor.id()));
        emit(CompatKit {
            doc,
            assets,
            catalog_id,
        })?;
    }
    Ok(CompatScan {
        catalog: (!catalog.entries.is_empty()).then_some(catalog),
        warnings,
    })
}

fn build_kit(
    flavor: Flavor,
    fs: &dyn SourceFs,
    c: &Candidate,
    limits: &ImportLimits,
    warnings: &mut Vec<Warning>,
) -> Option<(KitDoc, BTreeMap<String, Vec<u8>>)> {
    let exts = flavor.audio_exts();
    let files = fs.files();
    let mut doc = KitDoc::new(fsutil::new_id(), c.name.clone());
    doc.license = Some(PRIVATE_LICENSE.into());
    doc.authors = vec!["Unknown".into()];
    doc.description = Some(format!(
        "从 {} 素材包导入；原 App 素材仅限私有研究，禁止分发。",
        match flavor {
            Flavor::Android => "Android 3.x ",
            Flavor::Ios => "iOS 4.x ",
        }
    ));
    let mut assets = BTreeMap::new();
    let mut taken = BTreeSet::new();
    for (&n, (behaviour, color, group)) in &c.config.pads {
        let (kind, mode) = match behaviour {
            100 => (PadKind::Loop, LaunchMode::Toggle),
            200 => (PadKind::OneShot, LaunchMode::Trigger),
            300 => (PadKind::OneShot, LaunchMode::Gate),
            -1 => continue,
            other => {
                warnings.push(Warning::new(
                    "compat.behaviour",
                    format!("{}：pad{n} 的 behaviour={other} 未知，已跳过", c.name),
                ));
                continue;
            }
        };
        let sep = if c.dir.is_empty() { "" } else { "/" };
        let path = exts
            .iter()
            .find_map(|ext| fs.find_ci(&format!("{}{sep}pad{n}_{}.{ext}", c.dir, c.config.preset)))
            .or_else(|| {
                files
                    .iter()
                    .find(|f| {
                        parent(f) == c.dir
                            && pad_file_number(f)
                                .is_some_and(|(m, e)| m == n && exts.contains(&e.as_str()))
                    })
                    .cloned()
            });
        let Some(path) = path else {
            warnings.push(Warning::new(
                "compat.missing_audio",
                format!("{}：缺少 pad{n} 的音频，显示为空 pad", c.name),
            ));
            continue;
        };
        let raw = match fs.read(&path) {
            Ok(b) => b,
            Err(e) => {
                warnings.push(Warning::new("compat.read", format!("{path}：{e}")));
                continue;
            }
        };
        let ext = up_format::path::extension_lower(&path).unwrap_or_default();
        let wav_bytes = match crate::transcode::ensure_wav(raw, &ext, limits.max_entry_bytes / 4) {
            Ok(w) => w,
            Err(e) => {
                warnings.push(Warning::new("compat.decode", format!("{path}：{e}")));
                continue;
            }
        };
        if let Err(e) = wav::info(&wav_bytes) {
            warnings.push(Warning::new("compat.bad_wav", format!("{path}：{e}")));
            continue;
        }
        let file_name = format!("{}.wav", up_format::path::file_stem(&path));
        let dest = upkit::unique_sample_path(&file_name, &mut taken);
        let mut pad = PadDoc::new(PadAddr::from_flat(n - 1));
        pad.kind = kind;
        pad.launch.mode = mode;
        pad.self_choke = kind == PadKind::OneShot;
        if let Some(g) = group.filter(|g| *g > 0).and_then(|g| u32::try_from(g).ok()) {
            pad.choke_group = Some(g);
            pad.choked_by = Some(g);
        }
        pad.color = match color.as_deref().map(|s| (s, color_role(s))) {
            Some((_, Some(role))) => PadColor::Role(role),
            Some((s, None)) => {
                warnings.push(Warning::new(
                    "compat.color",
                    format!("{}：pad{n} 的颜色 `{s}` 未知，使用默认色", c.name),
                ));
                upkit::default_color(&pad)
            }
            None => upkit::default_color(&pad),
        };
        pad.layers.push(SampleLayer::new(dest.clone()));
        assets.insert(dest, wav_bytes);
        doc.pads.push(pad);
    }
    if doc.pads.is_empty() {
        warnings.push(Warning::new(
            "compat.empty",
            format!("{}：没有可用的 pad，已跳过", c.name),
        ));
        return None;
    }
    doc.pad_count = if c.config.pads.keys().any(|n| *n > 12) {
        24
    } else {
        12
    };
    Some((doc, assets))
}

fn localized(en: String, zh: String) -> BTreeMap<String, String> {
    BTreeMap::from([("en".to_string(), en), ("zh-CN".to_string(), zh)])
}

/// 旧版 `sequence`（每步同时要按的音符码）→ `tutorials/compat/`（sequence 模式 + chart.mid）。
fn add_sequence_tutorial(
    doc: &mut KitDoc,
    assets: &mut BTreeMap<String, Vec<u8>>,
    seq: &[Value],
    video: Option<&str>,
    warnings: &mut Vec<Warning>,
) {
    let mut steps = Vec::new();
    let mut chart = Chart {
        bpm: 120.0,
        track_name: Some(format!("{} tutorial", doc.name)),
        ..Chart::default()
    };
    let tpq = u32::from(chart.ticks_per_quarter);
    let mut unknown = BTreeSet::new();
    for (i, step) in seq.iter().enumerate() {
        let Some(codes) = step.as_array() else {
            continue;
        };
        let mut pads = Vec::new();
        let mut bank = None;
        for code in codes.iter().filter_map(Value::as_i64) {
            match code {
                100 => bank = Some("A".to_string()),
                101 => bank = Some("B".to_string()),
                c => match android_code_to_pad(c) {
                    Some(p) => pads.push(pad_note(p)),
                    None => {
                        unknown.insert(c);
                    }
                },
            }
        }
        let tick = i as u32 * tpq;
        if let Some(b) = &bank {
            chart.markers.push(Marker {
                tick,
                text: format!("Page {b}"),
            });
        }
        for &key in &pads {
            chart.notes.push(NoteEvent {
                tick,
                duration: tpq / 2,
                channel: 0,
                key,
                velocity: 100,
            });
        }
        steps.push(TutorialStep {
            from_bar: None,
            to_bar: None,
            hint: BTreeMap::new(),
            pads,
            bank,
            loop_: false,
        });
    }
    if !unknown.is_empty() {
        warnings.push(Warning::new(
            "compat.tutorial_code",
            format!("{}：教程中有未知音符码 {unknown:?}，已忽略", doc.name),
        ));
    }
    if steps.is_empty() {
        return;
    }
    let t = TutorialDoc {
        id: "compat".into(),
        title: localized(
            format!("{} tutorial", doc.name),
            format!("{} 教程", doc.name),
        ),
        mode: TutorialMode::Sequence,
        chart: Some("chart.mid".into()),
        tempo: None,
        judge: None,
        video_url: video.map(str::to_string),
        steps,
        extra: Default::default(),
    };
    push_tutorial(doc, assets, "compat", t, chart);
}

fn push_tutorial(
    doc: &mut KitDoc,
    assets: &mut BTreeMap<String, Vec<u8>>,
    id: &str,
    t: TutorialDoc,
    chart: Chart,
) {
    let dir = format!("tutorials/{id}");
    assets.insert(format!("{dir}/tutorial.json"), t.to_vec_pretty());
    assets.insert(format!("{dir}/chart.mid"), chart.to_smf());
    doc.tutorials.push(TutorialRef {
        id: id.into(),
        path: format!("{dir}/tutorial.json"),
    });
}

/// 计时事件 `[{time(秒), pad(1 起, 100/101 切页), ...}]` → Chart。
fn events_to_chart(name: &str, bpm: f64, events: &[Value], offset_secs: f64) -> Chart {
    let mut chart = Chart {
        bpm,
        track_name: Some(name.to_string()),
        ..Chart::default()
    };
    let tpq = f64::from(chart.ticks_per_quarter);
    for e in events {
        let (Some(t), Some(pad)) = (
            e.get("time").and_then(Value::as_f64),
            e.get("pad").and_then(Value::as_i64),
        ) else {
            continue;
        };
        let tick = (((t - offset_secs).max(0.0)) * bpm / 60.0 * tpq).round() as u32;
        match pad {
            100 => chart.markers.push(Marker {
                tick,
                text: "Page A".into(),
            }),
            101 => chart.markers.push(Marker {
                tick,
                text: "Page B".into(),
            }),
            p if (1..=i64::from(MAX_PADS)).contains(&p) => {
                let state = e.get("state").and_then(Value::as_i64).unwrap_or(1);
                chart.notes.push(NoteEvent {
                    tick,
                    duration: (tpq / 4.0) as u32,
                    channel: 0,
                    key: pad_note(p as u8),
                    velocity: if state == 0 { 64 } else { 100 },
                });
            }
            _ => {}
        }
    }
    chart.notes.sort_by_key(|n| (n.tick, n.key));
    chart
}

/// 新版 `tutorial.json`（计时事件）→ `tutorials/compat/`。
fn add_timed_tutorial(
    doc: &mut KitDoc,
    assets: &mut BTreeMap<String, Vec<u8>>,
    bytes: &[u8],
    warnings: &mut Vec<Warning>,
) {
    let Ok(Value::Array(events)) = serde_json::from_slice::<Value>(bytes) else {
        warnings.push(Warning::new("compat.tutorial", "tutorial.json 无法解析"));
        return;
    };
    // 原数据只有秒；chart 用 120 BPM（1 拍 = 0.5 秒）保存，秒级时刻不失真
    let chart = events_to_chart(&format!("{} tutorial", doc.name), 120.0, &events, 0.0);
    let mut extra = serde_json::Map::new();
    extra.insert("compatEvents".into(), Value::Array(events));
    let t = TutorialDoc {
        id: "compat".into(),
        title: localized(
            format!("{} tutorial", doc.name),
            format!("{} 教程", doc.name),
        ),
        mode: TutorialMode::Timed,
        chart: Some("chart.mid".into()),
        tempo: Some(up_format::tutorial::TutorialTempo {
            start: 120.0,
            target: 120.0,
        }),
        judge: None,
        video_url: None,
        steps: Vec::new(),
        extra,
    };
    push_tutorial(doc, assets, "compat", t, chart);
}

/// 新版 `<id>_lesson.json`（`{bpm, lessons:[{steps:[{pad,time}], duration, midStartTime}]}`）
/// → `tutorials/lesson-<n>/`。
fn add_lessons(
    doc: &mut KitDoc,
    assets: &mut BTreeMap<String, Vec<u8>>,
    bytes: &[u8],
    warnings: &mut Vec<Warning>,
) {
    let Ok(v) = serde_json::from_slice::<Value>(bytes) else {
        warnings.push(Warning::new("compat.lesson", "lesson.json 无法解析"));
        return;
    };
    let bpm = v
        .get("bpm")
        .and_then(Value::as_f64)
        .filter(|b| *b > 0.0)
        .unwrap_or(120.0);
    let lessons = v
        .get("lessons")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    for (i, lesson) in lessons.iter().enumerate() {
        let steps = lesson
            .get("steps")
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default();
        let n = i + 1;
        let chart = events_to_chart(&format!("{} lesson {n}", doc.name), bpm, &steps, 0.0);
        let mut extra = serde_json::Map::new();
        for k in ["duration", "midStartTime"] {
            if let Some(x) = lesson.get(k) {
                extra.insert(k.into(), x.clone());
            }
        }
        extra.insert("lesson".into(), Value::from(n));
        extra.insert("lessonCount".into(), Value::from(lessons.len()));
        let t = TutorialDoc {
            id: format!("lesson-{n}"),
            title: localized(
                format!("{} — lesson {n}", doc.name),
                format!("{} 第 {n} 课", doc.name),
            ),
            mode: TutorialMode::Timed,
            chart: Some("chart.mid".into()),
            tempo: Some(up_format::tutorial::TutorialTempo {
                start: bpm,
                target: bpm,
            }),
            judge: None,
            video_url: None,
            steps: Vec::new(),
            extra,
        };
        push_tutorial(doc, assets, &format!("lesson-{n}"), t, chart);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn helpers() {
        assert_eq!(
            pad_file_number("Sounds/pad12_sunset.wav"),
            Some((12, "wav".into()))
        );
        assert_eq!(
            pad_file_number("Sounds/pad3_apart easy.ogg"),
            Some((3, "ogg".into()))
        );
        assert_eq!(pad_file_number("Sounds/pads.wav"), None);
        assert_eq!(pad_file_number("pad25_x.wav"), None);
        assert_eq!(android_code_to_pad(0), Some(1));
        assert_eq!(android_code_to_pad(19), Some(12));
        assert_eq!(android_code_to_pad(23), Some(13));
        assert_eq!(android_code_to_pad(34), Some(24));
        assert_eq!(android_code_to_pad(1), None);
        assert_eq!(android_code_to_pad(100), None);
        assert_eq!(color_role("azul_loop"), Some(ColorRole::Blue));
        assert_eq!(color_role("amarelo"), Some(ColorRole::Orange));
        assert_eq!(rgb_to_hex("248;69;62").as_deref(), Some("#F8453E"));
        assert_eq!(title_case("HIP HOP"), "Hip Hop");
    }

    #[test]
    fn config_parsing() {
        let c = parse_config(br#"{"behaviour":{"pad1":200,"pad2":100,"pad13":300},"colors":{"pad1":"rosa"},"groups":{"pad1":1},"preset":"x"}"#).unwrap();
        assert_eq!(c.pads.len(), 3);
        assert_eq!(c.pads[&1], (200, Some("rosa".into()), Some(1)));
        assert!(parse_config(br#"{"behaviour":{}}"#).is_none());
    }
}
