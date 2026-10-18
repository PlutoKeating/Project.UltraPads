//! SFZ 解析与序列化。
//!
//! 流程：预处理（去注释、`#define $VAR`、`#include "file"`）→ 词法（header / `opcode=value`）
//! → [`SfzFile`]（保留原始顺序和未知 opcode，可无损回写）→ [`SfzFile::regions`] 按
//! `<control>` / `<global>` / `<master>` / `<group>` / `<region>` 层级继承展开成 [`Region`]。
//!
//! `#include` 的文件内容由调用方通过 [`IncludeResolver`] 提供，本模块不做 I/O。

pub mod note;
pub mod opcodes;

use std::collections::BTreeMap;
use std::fmt::Write as _;

use crate::{FormatError, Result, Warning};

pub use note::{note_name, parse_note};

/// 最大 `#include` 嵌套深度。
pub const MAX_INCLUDE_DEPTH: usize = 16;
/// 预处理后文本的最大字节数（防止 include 炸弹）。
pub const MAX_EXPANDED_LEN: usize = 16 * 1024 * 1024;

/// `#include` 解析回调。参数是 SFZ 中写的路径（未规范化），返回文件文本。
pub trait IncludeResolver {
    fn resolve(&mut self, path: &str) -> std::result::Result<String, String>;
}

impl<F> IncludeResolver for F
where
    F: FnMut(&str) -> std::result::Result<String, String>,
{
    fn resolve(&mut self, path: &str) -> std::result::Result<String, String> {
        self(path)
    }
}

/// 不允许任何 `#include` 的解析器。
pub struct NoIncludes;

impl IncludeResolver for NoIncludes {
    fn resolve(&mut self, path: &str) -> std::result::Result<String, String> {
        Err(format!("不允许 #include（{path}）"))
    }
}

/// SFZ header 类型。
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Header {
    /// 第一个 header 之前出现的 opcode。
    None,
    Control,
    Global,
    Master,
    Group,
    Region,
    /// 白名单之外的 header（如 `<curve>`、`<effect>`），原样保留。
    Other(String),
}

impl Header {
    pub fn parse(name: &str) -> Self {
        match name {
            "control" => Self::Control,
            "global" => Self::Global,
            "master" => Self::Master,
            "group" => Self::Group,
            "region" => Self::Region,
            other => Self::Other(other.to_string()),
        }
    }

    pub fn name(&self) -> &str {
        match self {
            Self::None => "",
            Self::Control => "control",
            Self::Global => "global",
            Self::Master => "master",
            Self::Group => "group",
            Self::Region => "region",
            Self::Other(s) => s,
        }
    }
}

/// 一个 `opcode=value`。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Opcode {
    pub name: String,
    pub value: String,
}

impl Opcode {
    pub fn new(name: impl Into<String>, value: impl ToString) -> Self {
        Self {
            name: name.into(),
            value: value.to_string(),
        }
    }
}

/// 一个 header 及其 opcode。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Section {
    pub header: Header,
    pub opcodes: Vec<Opcode>,
    /// 序列化时写在 header 前的注释（解析时不回填）。
    pub comment: Option<String>,
}

impl Section {
    pub fn new(header: Header) -> Self {
        Self {
            header,
            opcodes: Vec::new(),
            comment: None,
        }
    }

    pub fn with_comment(mut self, comment: impl Into<String>) -> Self {
        self.comment = Some(comment.into());
        self
    }

    pub fn push(&mut self, name: &str, value: impl ToString) -> &mut Self {
        self.opcodes.push(Opcode::new(name, value));
        self
    }

    pub fn get(&self, name: &str) -> Option<&str> {
        self.opcodes
            .iter()
            .rev()
            .find(|o| opcodes::canonical(&o.name) == name)
            .map(|o| o.value.as_str())
    }
}

/// 解析后的 SFZ 文档（保留顺序与未知 opcode）。
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct SfzFile {
    pub sections: Vec<Section>,
    /// 文件头注释（序列化时写在最前）。
    pub header_comment: Option<String>,
}

/// 解析结果：文档 + 非致命警告。
#[derive(Debug, Clone)]
pub struct ParsedSfz {
    pub file: SfzFile,
    pub warnings: Vec<Warning>,
}

/// 解析选项。
#[derive(Debug, Clone, Default)]
pub struct ParseOptions {
    /// 遇到未知 opcode 时报错而不是警告。
    pub strict: bool,
}

/// 解析 SFZ 文本（不允许 `#include`）。
pub fn parse(text: &str) -> Result<ParsedSfz> {
    parse_with(text, &mut NoIncludes, &ParseOptions::default())
}

/// 解析 SFZ 文本，`#include` 通过 `resolver` 解析。
pub fn parse_with(
    text: &str,
    resolver: &mut dyn IncludeResolver,
    options: &ParseOptions,
) -> Result<ParsedSfz> {
    let mut defines: Vec<(String, String)> = Vec::new();
    let mut expanded = String::with_capacity(text.len());
    preprocess(text, resolver, &mut defines, 0, &mut expanded)?;
    let mut warnings = Vec::new();
    let file = lex(&expanded, &mut warnings)?;
    for section in &file.sections {
        if let Header::Other(name) = &section.header {
            warnings.push(Warning::new(
                "sfz.unknown_header",
                format!("不支持的 header <{name}>，已保留但不参与发声"),
            ));
        }
        for op in &section.opcodes {
            match opcodes::lookup(&op.name) {
                None => {
                    if options.strict {
                        return Err(FormatError::Sfz {
                            line: 0,
                            message: format!("未知 opcode `{}`", op.name),
                        });
                    }
                    warnings.push(Warning::new(
                        "sfz.unknown_opcode",
                        format!("未知 opcode `{}={}`，已保留原文", op.name, op.value),
                    ));
                }
                Some(spec) => {
                    if let Err(msg) = opcodes::validate_value(spec, &op.value) {
                        if options.strict {
                            return Err(FormatError::Sfz {
                                line: 0,
                                message: msg,
                            });
                        }
                        warnings.push(Warning::new("sfz.invalid_value", msg));
                    }
                }
            }
        }
    }
    Ok(ParsedSfz { file, warnings })
}

fn strip_comments(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let bytes = text.as_bytes();
    let mut i = 0;
    let mut start = 0;
    while i < bytes.len() {
        if bytes[i] == b'/' && i + 1 < bytes.len() {
            if bytes[i + 1] == b'/' {
                out.push_str(&text[start..i]);
                while i < bytes.len() && bytes[i] != b'\n' {
                    i += 1;
                }
                start = i;
                continue;
            }
            if bytes[i + 1] == b'*' {
                out.push_str(&text[start..i]);
                i += 2;
                while i + 1 < bytes.len() && !(bytes[i] == b'*' && bytes[i + 1] == b'/') {
                    if bytes[i] == b'\n' {
                        out.push('\n');
                    }
                    i += 1;
                }
                i = (i + 2).min(bytes.len());
                start = i;
                out.push(' ');
                continue;
            }
        }
        i += 1;
    }
    out.push_str(&text[start.min(text.len())..]);
    out
}

fn substitute(line: &str, defines: &[(String, String)]) -> String {
    if !line.contains('$') || defines.is_empty() {
        return line.to_string();
    }
    let mut out = String::with_capacity(line.len());
    let mut rest = line;
    while let Some(pos) = rest.find('$') {
        out.push_str(&rest[..pos]);
        let tail = &rest[pos..];
        // 最长匹配
        let best = defines
            .iter()
            .filter(|(name, _)| tail.starts_with(name.as_str()))
            .max_by_key(|(name, _)| name.len());
        match best {
            Some((name, value)) => {
                out.push_str(value);
                rest = &tail[name.len()..];
            }
            None => {
                out.push('$');
                rest = &tail[1..];
            }
        }
    }
    out.push_str(rest);
    out
}

fn preprocess(
    text: &str,
    resolver: &mut dyn IncludeResolver,
    defines: &mut Vec<(String, String)>,
    depth: usize,
    out: &mut String,
) -> Result<()> {
    if depth > MAX_INCLUDE_DEPTH {
        return Err(FormatError::Include(format!(
            "#include 嵌套超过 {MAX_INCLUDE_DEPTH} 层"
        )));
    }
    let text = text.strip_prefix('\u{feff}').unwrap_or(text);
    let clean = strip_comments(text);
    for line in clean.lines() {
        let trimmed = line.trim();
        if let Some(rest) = trimmed.strip_prefix("#define") {
            let rest = rest.trim();
            let (name, value) = match rest.find(char::is_whitespace) {
                Some(i) => (&rest[..i], rest[i..].trim()),
                None => (rest, ""),
            };
            if !name.starts_with('$') || name.len() < 2 {
                return Err(FormatError::Sfz {
                    line: 0,
                    message: format!("#define 变量名必须以 $ 开头：`{name}`"),
                });
            }
            let value = substitute(value, defines);
            defines.retain(|(n, _)| n != name);
            defines.push((name.to_string(), value));
            out.push('\n');
            continue;
        }
        if let Some(rest) = trimmed.strip_prefix("#include") {
            let target = substitute(rest.trim(), defines);
            let target = target.trim().trim_matches('"').trim();
            if target.is_empty() {
                return Err(FormatError::Include("#include 缺少路径".into()));
            }
            let included = resolver
                .resolve(target)
                .map_err(|e| FormatError::Include(format!("{target}: {e}")))?;
            preprocess(&included, resolver, defines, depth + 1, out)?;
            out.push('\n');
            continue;
        }
        out.push_str(&substitute(line, defines));
        out.push('\n');
        if out.len() > MAX_EXPANDED_LEN {
            return Err(FormatError::Include("预处理后的 SFZ 过大".into()));
        }
    }
    Ok(())
}

fn is_ident_byte(b: u8) -> bool {
    b.is_ascii_alphanumeric() || b == b'_'
}

/// 从 `start` 开始，若是 `ident=` 则返回 (ident 结束, `=` 位置)。
fn opcode_at(bytes: &[u8], start: usize) -> Option<usize> {
    let mut i = start;
    while i < bytes.len() && is_ident_byte(bytes[i]) {
        i += 1;
    }
    if i > start && i < bytes.len() && bytes[i] == b'=' {
        Some(i)
    } else {
        None
    }
}

fn lex(text: &str, warnings: &mut Vec<Warning>) -> Result<SfzFile> {
    let bytes = text.as_bytes();
    let mut file = SfzFile::default();
    let mut current = Section::new(Header::None);
    let mut line = 1usize;
    let mut i = 0usize;
    while i < bytes.len() {
        let b = bytes[i];
        if b == b'\n' {
            line += 1;
            i += 1;
            continue;
        }
        if b.is_ascii_whitespace() {
            i += 1;
            continue;
        }
        if b == b'<' {
            let close = text[i..].find('>').ok_or_else(|| FormatError::Sfz {
                line,
                message: "header 缺少 `>`".into(),
            })?;
            let name = text[i + 1..i + close].trim();
            if name.is_empty() || !name.bytes().all(is_ident_byte) {
                return Err(FormatError::Sfz {
                    line,
                    message: format!("非法 header `<{name}>`"),
                });
            }
            if current.header != Header::None || !current.opcodes.is_empty() {
                file.sections.push(std::mem::replace(
                    &mut current,
                    Section::new(Header::parse(name)),
                ));
            } else {
                current = Section::new(Header::parse(name));
            }
            i += close + 1;
            continue;
        }
        if let Some(eq) = opcode_at(bytes, i) {
            let name = &text[i..eq];
            let value_start = eq + 1;
            let mut j = value_start;
            while j < bytes.len() {
                let c = bytes[j];
                if c == b'\n' || c == b'\r' || c == b'<' {
                    break;
                }
                if c.is_ascii_whitespace() {
                    let mut k = j;
                    while k < bytes.len() && (bytes[k] == b' ' || bytes[k] == b'\t') {
                        k += 1;
                    }
                    if k < bytes.len() && opcode_at(bytes, k).is_some() {
                        break;
                    }
                    j = k;
                    continue;
                }
                j += 1;
            }
            let value = text[value_start..j].trim();
            if current.header == Header::None && file.sections.is_empty() {
                warnings.push(Warning::new(
                    "sfz.opcode_before_header",
                    format!("第 {line} 行：`{name}` 出现在任何 header 之前"),
                ));
            }
            current.opcodes.push(Opcode::new(name, value));
            i = j;
            continue;
        }
        // 无法识别的 token：跳到下一个空白
        let mut j = i;
        while j < bytes.len() && !bytes[j].is_ascii_whitespace() {
            j += 1;
        }
        warnings.push(Warning::new(
            "sfz.garbage",
            format!("第 {line} 行：忽略无法识别的内容 `{}`", &text[i..j]),
        ));
        i = j;
    }
    if current.header != Header::None || !current.opcodes.is_empty() {
        file.sections.push(current);
    }
    Ok(file)
}

/// 展开后的 region：已合并 global/master/group 继承的 opcode（规范名 → 值）。
#[derive(Debug, Clone, Default, PartialEq)]
pub struct Region {
    pub opcodes: BTreeMap<String, String>,
    /// `<control>` 的 `default_path`（已拼到 [`Region::sample_path`] 中）。
    pub default_path: String,
    /// `<control>` 的 `note_offset + 12 * octave_offset`。
    pub note_shift: i32,
    /// region 在文件中的序号（从 0 开始）。
    pub index: usize,
}

impl Region {
    pub fn get(&self, name: &str) -> Option<&str> {
        self.opcodes.get(name).map(String::as_str)
    }

    fn num<T: std::str::FromStr>(&self, name: &str) -> Option<T> {
        self.get(name).and_then(|v| v.trim().parse().ok())
    }

    fn note(&self, name: &str) -> Option<u8> {
        let n = parse_note(self.get(name)?)?;
        u8::try_from(i32::from(n) + self.note_shift)
            .ok()
            .filter(|n| *n <= 127)
    }

    /// 原始 `sample=` 值（未拼接 `default_path`）。
    pub fn sample(&self) -> Option<&str> {
        self.get("sample")
    }

    /// `default_path` + `sample`，反斜杠已转换为 `/`；未做安全校验（见 [`crate::path::join`]）。
    pub fn sample_path(&self) -> Option<String> {
        let sample = self.sample()?.replace('\\', "/");
        if self.default_path.is_empty() {
            Some(sample)
        } else {
            let base = self.default_path.replace('\\', "/");
            Some(format!("{}/{}", base.trim_end_matches('/'), sample))
        }
    }

    /// 键位范围 `(lokey, hikey)`；`key=` 同时设定两端。
    pub fn key_range(&self) -> Option<(u8, u8)> {
        let key = self.note("key");
        let lo = self.note("lokey").or(key);
        let hi = self.note("hikey").or(key);
        match (lo, hi) {
            (Some(l), Some(h)) => Some((l.min(h), l.max(h))),
            (Some(l), None) => Some((l, 127)),
            (None, Some(h)) => Some((0, h)),
            (None, None) => None,
        }
    }

    pub fn pitch_keycenter(&self) -> Option<u8> {
        self.note("pitch_keycenter").or_else(|| self.note("key"))
    }

    pub fn vel_range(&self) -> (u8, u8) {
        let lo = self.num::<f64>("lovel").unwrap_or(0.0).clamp(0.0, 127.0) as u8;
        let hi = self.num::<f64>("hivel").unwrap_or(127.0).clamp(0.0, 127.0) as u8;
        (lo, hi)
    }

    pub fn loop_mode(&self) -> Option<&str> {
        self.get("loop_mode")
    }

    pub fn group(&self) -> Option<i64> {
        self.num("group")
    }
    pub fn off_by(&self) -> Option<i64> {
        self.num("off_by")
    }
    pub fn off_mode(&self) -> Option<&str> {
        self.get("off_mode")
    }
    pub fn off_time(&self) -> Option<f64> {
        self.num("off_time")
    }
    pub fn seq_length(&self) -> Option<u32> {
        self.num("seq_length")
    }
    pub fn seq_position(&self) -> Option<u32> {
        self.num("seq_position")
    }
    pub fn trigger(&self) -> &str {
        self.get("trigger").unwrap_or("attack")
    }
    pub fn volume_db(&self) -> f64 {
        self.num("volume").unwrap_or(0.0)
    }
    /// -100..=100
    pub fn pan(&self) -> f64 {
        self.num("pan").unwrap_or(0.0)
    }
    pub fn tune_cents(&self) -> i64 {
        self.num("tune").unwrap_or(0)
    }
    pub fn transpose(&self) -> i64 {
        self.num("transpose").unwrap_or(0)
    }
    pub fn offset(&self) -> Option<u64> {
        self.num("offset")
    }
    pub fn end(&self) -> Option<i64> {
        self.num("end")
    }
    pub fn loop_start(&self) -> Option<u64> {
        self.num("loop_start")
    }
    pub fn loop_end(&self) -> Option<u64> {
        self.num("loop_end")
    }
    pub fn sync_beats(&self) -> Option<f64> {
        self.num("sync_beats")
    }
    pub fn lorand(&self) -> Option<f64> {
        self.num("lorand")
    }
    pub fn hirand(&self) -> Option<f64> {
        self.num("hirand")
    }
    pub fn note_selfmask(&self) -> Option<bool> {
        self.get("note_selfmask").map(|v| v == "on")
    }
    pub fn label(&self) -> Option<&str> {
        self.get("region_label")
            .or_else(|| self.get("group_label"))
            .or_else(|| self.get("master_label"))
            .or_else(|| self.get("global_label"))
    }
}

/// `<control>` 汇总信息。
#[derive(Debug, Clone, Default, PartialEq)]
pub struct Control {
    pub default_path: String,
    pub note_offset: i32,
    pub octave_offset: i32,
    /// `label_keyN`：音符 → 名称。
    pub key_labels: BTreeMap<u8, String>,
    /// `label_ccN`：CC → 名称。
    pub cc_labels: BTreeMap<u8, String>,
    /// `set_ccN`
    pub cc_defaults: BTreeMap<u8, f64>,
}

impl SfzFile {
    /// 汇总所有 `<control>`（后出现的覆盖先出现的）。
    pub fn control(&self) -> Control {
        let mut c = Control::default();
        for s in self.sections.iter().filter(|s| s.header == Header::Control) {
            for op in &s.opcodes {
                let name = opcodes::canonical(&op.name);
                let v = op.value.trim();
                if name == "default_path" {
                    c.default_path = v.to_string();
                } else if name == "note_offset" {
                    c.note_offset = v.parse().unwrap_or(0);
                } else if name == "octave_offset" {
                    c.octave_offset = v.parse().unwrap_or(0);
                } else if let Some(n) = name.strip_prefix("label_key") {
                    if let Ok(k) = n.parse() {
                        c.key_labels.insert(k, v.to_string());
                    }
                } else if let Some(n) = name.strip_prefix("label_cc") {
                    if let Ok(k) = n.parse() {
                        c.cc_labels.insert(k, v.to_string());
                    }
                } else if let Some(n) = name.strip_prefix("set_cc") {
                    if let (Ok(k), Ok(val)) = (n.parse(), v.parse()) {
                        c.cc_defaults.insert(k, val);
                    }
                }
            }
        }
        c
    }

    /// 按层级继承展开所有 region。
    pub fn regions(&self) -> Vec<Region> {
        let mut out = Vec::new();
        let mut global: BTreeMap<String, String> = BTreeMap::new();
        let mut master: BTreeMap<String, String> = BTreeMap::new();
        let mut group: BTreeMap<String, String> = BTreeMap::new();
        let mut default_path = String::new();
        let mut note_offset = 0i32;
        let mut octave_offset = 0i32;
        let put = |map: &mut BTreeMap<String, String>, s: &Section| {
            for op in &s.opcodes {
                map.insert(
                    opcodes::canonical(&op.name).to_string(),
                    op.value.trim().to_string(),
                );
            }
        };
        for s in &self.sections {
            match &s.header {
                Header::Control => {
                    if let Some(p) = s.get("default_path") {
                        default_path = p.trim().to_string();
                    }
                    if let Some(v) = s.get("note_offset") {
                        note_offset = v.trim().parse().unwrap_or(0);
                    }
                    if let Some(v) = s.get("octave_offset") {
                        octave_offset = v.trim().parse().unwrap_or(0);
                    }
                }
                Header::None | Header::Global => {
                    global.clear();
                    master.clear();
                    group.clear();
                    put(&mut global, s);
                }
                Header::Master => {
                    master.clear();
                    group.clear();
                    put(&mut master, s);
                }
                Header::Group => {
                    group.clear();
                    put(&mut group, s);
                }
                Header::Region => {
                    let mut merged = global.clone();
                    merged.extend(master.iter().map(|(k, v)| (k.clone(), v.clone())));
                    merged.extend(group.iter().map(|(k, v)| (k.clone(), v.clone())));
                    put(&mut merged, s);
                    out.push(Region {
                        opcodes: merged,
                        default_path: default_path.clone(),
                        note_shift: note_offset + 12 * octave_offset,
                        index: out.len(),
                    });
                }
                Header::Other(_) => {}
            }
        }
        out
    }

    /// 序列化为 SFZ 文本：每个 header 独占一行，每个 opcode 独占一行（值可含空格）。
    pub fn to_sfz_string(&self) -> String {
        let mut out = String::new();
        if let Some(c) = &self.header_comment {
            for l in c.lines() {
                let _ = writeln!(out, "// {l}");
            }
            out.push('\n');
        }
        for (i, s) in self.sections.iter().enumerate() {
            if i > 0 && s.header != Header::Region {
                out.push('\n');
            }
            if let Some(c) = &s.comment {
                for l in c.lines() {
                    let _ = writeln!(out, "// {l}");
                }
            }
            if s.header != Header::None {
                let _ = writeln!(out, "<{}>", s.header.name());
            }
            for op in &s.opcodes {
                let value = op.value.replace(['\n', '\r'], " ");
                let _ = writeln!(out, "{}={}", op.name, value.trim());
            }
        }
        out
    }

    /// 去掉白名单之外的 opcode 与 header（导出“纯 Profile” SFZ 时使用）。
    pub fn retain_whitelisted(&mut self) {
        self.sections
            .retain(|s| !matches!(s.header, Header::Other(_)));
        for s in &mut self.sections {
            s.opcodes.retain(|o| opcodes::lookup(&o.name).is_some());
        }
    }
}

impl std::fmt::Display for SfzFile {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.to_sfz_string())
    }
}

/// 把秒数/数值格式化为 SFZ 友好的十进制字符串（去掉多余的 0）。
pub fn fmt_num(v: f64) -> String {
    if v.fract() == 0.0 && v.abs() < 1e15 {
        format!("{}", v as i64)
    } else {
        let s = format!("{v:.6}");
        s.trim_end_matches('0').trim_end_matches('.').to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const DRUMS: &str = r#"
// UltraPads Kit: 808 Street
<control>
default_path=samples/
label_cc1=Tone
label_key36=Kick
set_cc1=64
note_offset=0

<global>
loop_mode=one_shot
off_mode=normal
amp_veltrack=100
ampeg_release=0.05

/* block
   comment */
<group> key=36 note_selfmask=on group_label=Kick
<region> sample=kick 01.wav lovel=0 hivel=100 volume=-3
<region> sample=kick_hard.wav lovel=101 hivel=127

<group> key=c#2 group=3 seq_length=2 polyphony=4 note_polyphony=2
<region> sample=hh_closed_rr1.wav seq_position=1
<region> sample=hh_closed_rr2.wav seq_position=2

<group> lokey=46 hikey=46 pitch_keycenter=46 group=4 off_by=3 off_mode=time off_time=0.03
<region> sample=hh\open.wav trigger=attack lorand=0 hirand=0.5 pan=-20 tune=-5 transpose=1
<region> sample=hh_open2.wav lorand=0.5 hirand=1

<master> master_label=Loops
<group> key=48 loop_mode=loop_continuous sync_beats=4 sync_offset=0 group=10 off_by=10
<region> sample=loop_drums_92bpm_4bar.wav loop_start=0 loop_end=88199 offset=10 end=88199 amplitude=80 width=100
<region> sample=loop_rel.wav trigger=release lobpm=60 hibpm=200 delay_beats=1 stop_beats=16 ampeg_attack=0.001 ampeg_hold=0 ampeg_decay=0.1 ampeg_sustain=100 ampeg_delay=0 xfin_lovel=0 xfin_hivel=64 xfout_lovel=64 xfout_hivel=127 pitch_keytrack=0 pitch_veltrack=0 amp_velcurve_127=1 count=1 loop_count=2 delay=0 image=cover.png region_label=Rel
"#;

    #[test]
    fn parses_whitelisted_drum_kit_without_warnings() {
        let parsed = parse(DRUMS).unwrap();
        assert!(parsed.warnings.is_empty(), "{:?}", parsed.warnings);
        let regions = parsed.file.regions();
        assert_eq!(regions.len(), 8);

        let kick = &regions[0];
        assert_eq!(kick.sample(), Some("kick 01.wav"));
        assert_eq!(kick.sample_path().unwrap(), "samples/kick 01.wav");
        assert_eq!(kick.key_range(), Some((36, 36)));
        assert_eq!(kick.loop_mode(), Some("one_shot"));
        assert_eq!(kick.vel_range(), (0, 100));
        assert_eq!(kick.volume_db(), -3.0);
        assert_eq!(kick.note_selfmask(), Some(true));
        assert_eq!(kick.label(), Some("Kick"));
        assert_eq!(regions[1].vel_range(), (101, 127));

        let hh = &regions[2];
        assert_eq!(hh.key_range(), Some((37, 37)));
        assert_eq!(hh.group(), Some(3));
        assert_eq!(hh.seq_length(), Some(2));
        assert_eq!(hh.seq_position(), Some(1));
        assert_eq!(regions[3].seq_position(), Some(2));

        let open = &regions[4];
        assert_eq!(open.sample_path().unwrap(), "samples/hh/open.wav");
        assert_eq!(open.off_by(), Some(3));
        assert_eq!(open.off_mode(), Some("time"));
        assert_eq!(open.off_time(), Some(0.03));
        assert_eq!(open.pitch_keycenter(), Some(46));
        assert_eq!(open.pan(), -20.0);
        assert_eq!(open.tune_cents(), -5);
        assert_eq!(open.transpose(), 1);
        assert_eq!(open.hirand(), Some(0.5));

        let lp = &regions[6];
        assert_eq!(lp.loop_mode(), Some("loop_continuous"));
        assert_eq!(lp.sync_beats(), Some(4.0));
        assert_eq!(lp.loop_end(), Some(88199));
        assert_eq!(lp.offset(), Some(10));
        assert_eq!(lp.label(), Some("Loops"));
        assert_eq!(regions[7].trigger(), "release");

        let control = parsed.file.control();
        assert_eq!(control.default_path, "samples/");
        assert_eq!(control.key_labels.get(&36).unwrap(), "Kick");
        assert_eq!(control.cc_labels.get(&1).unwrap(), "Tone");
        assert_eq!(control.cc_defaults.get(&1), Some(&64.0));
    }

    #[test]
    fn unknown_opcodes_are_preserved_and_warned() {
        let parsed = parse("<region> sample=a.wav cutoff=500 key=36\n<curve> v000=0").unwrap();
        let codes: Vec<_> = parsed.warnings.iter().map(|w| w.code.as_str()).collect();
        assert!(codes.contains(&"sfz.unknown_opcode"));
        assert!(codes.contains(&"sfz.unknown_header"));
        let text = parsed.file.to_sfz_string();
        assert!(text.contains("cutoff=500"));
        let mut f = parsed.file.clone();
        f.retain_whitelisted();
        assert!(!f.to_sfz_string().contains("cutoff"));
        assert!(!f.to_sfz_string().contains("curve"));
        assert!(
            parse_with(
                "<region> cutoff=1",
                &mut NoIncludes,
                &ParseOptions { strict: true }
            )
            .is_err()
        );
    }

    #[test]
    fn invalid_values_warn() {
        let parsed = parse("<region> sample=a.wav loop_mode=forever lovel=300").unwrap();
        assert_eq!(
            parsed
                .warnings
                .iter()
                .filter(|w| w.code == "sfz.invalid_value")
                .count(),
            2
        );
    }

    #[test]
    fn defines_and_includes_via_callback() {
        let main = "#define $KICK 36\n#define $KICKVEL $KICK\n#include \"common.sfz\"\n<region> key=$KICK sample=$NAME.wav\n";
        let mut calls = Vec::new();
        let mut resolver = |p: &str| -> std::result::Result<String, String> {
            calls.push(p.to_string());
            match p {
                "common.sfz" => Ok("#define $NAME kick\n<global> loop_mode=one_shot\n".into()),
                _ => Err("missing".into()),
            }
        };
        let parsed = parse_with(main, &mut resolver, &ParseOptions::default()).unwrap();
        let r = &parsed.file.regions()[0];
        assert_eq!(r.key_range(), Some((36, 36)));
        assert_eq!(r.sample(), Some("kick.wav"));
        assert_eq!(r.loop_mode(), Some("one_shot"));
        assert_eq!(calls, vec!["common.sfz".to_string()]);
        assert!(parse("#include \"x.sfz\"").is_err());
    }

    #[test]
    fn longest_define_wins_and_recursion_is_bounded() {
        let parsed = parse("#define $A 1\n#define $AB 2\n<region> key=$AB sample=x.wav").unwrap();
        assert_eq!(parsed.file.regions()[0].get("key"), Some("2"));
        let mut looping =
            |_: &str| -> std::result::Result<String, String> { Ok("#include \"self.sfz\"".into()) };
        let err = parse_with(
            "#include \"self.sfz\"",
            &mut looping,
            &ParseOptions::default(),
        )
        .unwrap_err();
        assert!(matches!(err, FormatError::Include(_)));
    }

    #[test]
    fn inheritance_resets_per_level() {
        let src = "<global> volume=-6\n<group> key=36 pan=10\n<region> sample=a.wav\n<group> key=37\n<region> sample=b.wav\n<global>\n<region> sample=c.wav key=38";
        let regions = parse(src).unwrap().file.regions();
        assert_eq!(regions[0].pan(), 10.0);
        assert_eq!(regions[1].pan(), 0.0);
        assert_eq!(regions[1].volume_db(), -6.0);
        assert_eq!(regions[2].volume_db(), 0.0);
    }

    #[test]
    fn note_offset_applies() {
        let src = "<control> note_offset=2 octave_offset=-1\n<region> key=48 sample=a.wav";
        assert_eq!(
            parse(src).unwrap().file.regions()[0].key_range(),
            Some((38, 38))
        );
    }

    #[test]
    fn roundtrip_serialization() {
        let parsed = parse(DRUMS).unwrap();
        let text = parsed.file.to_sfz_string();
        let again = parse(&text).unwrap();
        assert_eq!(parsed.file.sections, again.file.sections);
        assert_eq!(parsed.file.regions(), again.file.regions());
    }

    #[test]
    fn rejects_broken_headers() {
        assert!(parse("<region sample=a.wav").is_err());
        assert!(parse("<re gion> sample=a.wav").is_err());
    }

    #[test]
    fn num_formatting() {
        assert_eq!(fmt_num(4.0), "4");
        assert_eq!(fmt_num(0.03), "0.03");
        assert_eq!(fmt_num(-3.5), "-3.5");
    }
}
