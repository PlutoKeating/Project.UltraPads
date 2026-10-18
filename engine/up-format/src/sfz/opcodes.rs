//! UltraPads SFZ Profile：受支持的 opcode 白名单。
//!
//! 只覆盖鼓组/打击垫所需的 SFZ v1/v2 标准 opcode（以及少量 ARIA/sfizz 广泛支持的扩展）。
//! 白名单之外的 opcode 会被保留原文（无损回写），但加载时给出 `sfz.unknown_opcode` 警告，
//! 导出时由调用方决定是否剔除。

/// opcode 值的类型，用于校验。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ValueKind {
    /// 任意字符串（路径、标签）。
    Text,
    /// 整数（可为负）。
    Int,
    /// 非负整数（帧偏移等）。
    UInt,
    /// 浮点数。
    Float,
    /// MIDI 音符：数字 0..=127 或音名（`c4` = 60）。
    Note,
    /// 0..=127 的 MIDI 值。
    Midi7,
    /// 枚举值之一。
    Enum(&'static [&'static str]),
}

/// 白名单条目。名字以 `N` 结尾的条目表示带数字后缀的 opcode 族（如 `label_ccN`）。
#[derive(Debug, Clone, Copy)]
pub struct OpcodeSpec {
    pub name: &'static str,
    pub kind: ValueKind,
    /// 规范来源：`v1`、`v2`、`aria`、`sfizz`。
    pub version: &'static str,
}

const fn op(name: &'static str, kind: ValueKind, version: &'static str) -> OpcodeSpec {
    OpcodeSpec {
        name,
        kind,
        version,
    }
}

pub const LOOP_MODES: &[&str] = &["no_loop", "one_shot", "loop_continuous", "loop_sustain"];
pub const TRIGGERS: &[&str] = &["attack", "release", "first", "legato", "release_key"];
pub const OFF_MODES: &[&str] = &["fast", "normal", "time"];
pub const ON_OFF: &[&str] = &["on", "off"];

/// UltraPads SFZ Profile 白名单。
pub const WHITELIST: &[OpcodeSpec] = &[
    // ---- <control> ----
    op("default_path", ValueKind::Text, "v2"),
    op("note_offset", ValueKind::Int, "v2"),
    op("octave_offset", ValueKind::Int, "v2"),
    op("set_ccN", ValueKind::Midi7, "v2"),
    op("label_ccN", ValueKind::Text, "aria"),
    op("label_keyN", ValueKind::Text, "sfizz"),
    // ---- 采样 ----
    op("sample", ValueKind::Text, "v1"),
    op("offset", ValueKind::UInt, "v1"),
    op("end", ValueKind::Int, "v1"),
    op("count", ValueKind::UInt, "v1"),
    op("image", ValueKind::Text, "v2"),
    // ---- 键位/力度/随机/轮替 ----
    op("key", ValueKind::Note, "v1"),
    op("lokey", ValueKind::Note, "v1"),
    op("hikey", ValueKind::Note, "v1"),
    op("pitch_keycenter", ValueKind::Note, "v1"),
    op("lovel", ValueKind::Midi7, "v1"),
    op("hivel", ValueKind::Midi7, "v1"),
    op("lorand", ValueKind::Float, "v1"),
    op("hirand", ValueKind::Float, "v1"),
    op("seq_length", ValueKind::UInt, "v1"),
    op("seq_position", ValueKind::UInt, "v1"),
    op("lobpm", ValueKind::Float, "v1"),
    op("hibpm", ValueKind::Float, "v1"),
    op("trigger", ValueKind::Enum(TRIGGERS), "v1"),
    // ---- choke / 复音 ----
    op("group", ValueKind::Int, "v1"),
    op("off_by", ValueKind::Int, "v1"),
    op("off_mode", ValueKind::Enum(OFF_MODES), "v1"),
    op("off_time", ValueKind::Float, "aria"),
    op("polyphony", ValueKind::UInt, "v2"),
    op("note_polyphony", ValueKind::UInt, "v2"),
    op("note_selfmask", ValueKind::Enum(ON_OFF), "v2"),
    // ---- loop ----
    op("loop_mode", ValueKind::Enum(LOOP_MODES), "v1"),
    op("loop_start", ValueKind::UInt, "v1"),
    op("loop_end", ValueKind::UInt, "v1"),
    op("loop_count", ValueKind::UInt, "v2"),
    // ---- 拍同步 ----
    op("sync_beats", ValueKind::Float, "v1"),
    op("sync_offset", ValueKind::Float, "v1"),
    op("delay", ValueKind::Float, "v1"),
    op("delay_beats", ValueKind::Float, "v2"),
    op("stop_beats", ValueKind::Float, "v2"),
    // ---- 音量/声像/音高 ----
    op("volume", ValueKind::Float, "v1"),
    op("amplitude", ValueKind::Float, "aria"),
    op("pan", ValueKind::Float, "v1"),
    op("width", ValueKind::Float, "v1"),
    op("amp_veltrack", ValueKind::Float, "v1"),
    op("amp_velcurve_N", ValueKind::Float, "v1"),
    op("tune", ValueKind::Int, "v1"),
    op("transpose", ValueKind::Int, "v1"),
    op("pitch_keytrack", ValueKind::Int, "v1"),
    op("pitch_veltrack", ValueKind::Int, "v1"),
    // ---- 包络 ----
    op("ampeg_delay", ValueKind::Float, "v1"),
    op("ampeg_attack", ValueKind::Float, "v1"),
    op("ampeg_hold", ValueKind::Float, "v1"),
    op("ampeg_decay", ValueKind::Float, "v1"),
    op("ampeg_sustain", ValueKind::Float, "v1"),
    op("ampeg_release", ValueKind::Float, "v1"),
    // ---- 力度交叉淡变 ----
    op("xfin_lovel", ValueKind::Midi7, "v1"),
    op("xfin_hivel", ValueKind::Midi7, "v1"),
    op("xfout_lovel", ValueKind::Midi7, "v1"),
    op("xfout_hivel", ValueKind::Midi7, "v1"),
    // ---- 标签 ----
    op("global_label", ValueKind::Text, "aria"),
    op("master_label", ValueKind::Text, "aria"),
    op("group_label", ValueKind::Text, "aria"),
    op("region_label", ValueKind::Text, "aria"),
];

/// opcode 别名（旧写法 → 规范名）。
pub const ALIASES: &[(&str, &str)] = &[
    ("loopmode", "loop_mode"),
    ("loopstart", "loop_start"),
    ("loopend", "loop_end"),
    ("offby", "off_by"),
    ("polyphony_group", "group"),
    ("gain", "volume"),
    ("velocity_curve", "amp_veltrack"),
];

/// 返回规范 opcode 名（处理别名）。
pub fn canonical(name: &str) -> &str {
    ALIASES
        .iter()
        .find(|(alias, _)| *alias == name)
        .map(|(_, canon)| *canon)
        .unwrap_or(name)
}

/// 查找白名单条目；支持 `label_cc12` → `label_ccN`、`amp_velcurve_64` → `amp_velcurve_N`。
pub fn lookup(name: &str) -> Option<&'static OpcodeSpec> {
    let name = canonical(name);
    if let Some(spec) = WHITELIST.iter().find(|s| s.name == name) {
        return Some(spec);
    }
    let digits = name
        .bytes()
        .rev()
        .take_while(|b| b.is_ascii_digit())
        .count();
    if digits == 0 || digits == name.len() {
        return None;
    }
    let stem = &name[..name.len() - digits];
    WHITELIST.iter().find(|s| {
        s.name
            .strip_suffix('N')
            .is_some_and(|family| family == stem)
    })
}

/// 校验值是否符合类型。返回错误描述。
pub fn validate_value(spec: &OpcodeSpec, value: &str) -> Result<(), String> {
    let v = value.trim();
    match spec.kind {
        ValueKind::Text => Ok(()),
        ValueKind::Int => v
            .parse::<i64>()
            .map(|_| ())
            .map_err(|_| format!("`{}` 需要整数，得到 `{v}`", spec.name)),
        ValueKind::UInt => v
            .parse::<u64>()
            .map(|_| ())
            .map_err(|_| format!("`{}` 需要非负整数，得到 `{v}`", spec.name)),
        ValueKind::Float => v
            .parse::<f64>()
            .ok()
            .filter(|f| f.is_finite())
            .map(|_| ())
            .ok_or_else(|| format!("`{}` 需要数字，得到 `{v}`", spec.name)),
        ValueKind::Midi7 => v
            .parse::<f64>()
            .ok()
            .filter(|f| (0.0..=127.0).contains(f))
            .map(|_| ())
            .ok_or_else(|| format!("`{}` 需要 0..=127，得到 `{v}`", spec.name)),
        ValueKind::Note => super::note::parse_note(v)
            .map(|_| ())
            .ok_or_else(|| format!("`{}` 需要 MIDI 音符，得到 `{v}`", spec.name)),
        ValueKind::Enum(values) => {
            if values.contains(&v) {
                Ok(())
            } else {
                Err(format!(
                    "`{}` 只能取 {}，得到 `{v}`",
                    spec.name,
                    values.join("/")
                ))
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn families_and_aliases() {
        assert_eq!(lookup("label_cc7").unwrap().name, "label_ccN");
        assert_eq!(lookup("label_key36").unwrap().name, "label_keyN");
        assert_eq!(lookup("amp_velcurve_127").unwrap().name, "amp_velcurve_N");
        assert_eq!(lookup("loopmode").unwrap().name, "loop_mode");
        assert!(lookup("cutoff").is_none());
        assert!(lookup("label_cc").is_none());
    }

    #[test]
    fn value_validation() {
        let lm = lookup("loop_mode").unwrap();
        assert!(validate_value(lm, "one_shot").is_ok());
        assert!(validate_value(lm, "forever").is_err());
        assert!(validate_value(lookup("key").unwrap(), "c#4").is_ok());
        assert!(validate_value(lookup("lovel").unwrap(), "200").is_err());
        assert!(validate_value(lookup("offset").unwrap(), "-1").is_err());
    }
}
