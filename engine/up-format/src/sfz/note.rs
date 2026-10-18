//! MIDI 音符名解析（SFZ 约定：`c4` = 60，`c-1` = 0）。

/// 解析数字（`36`）或音名（`c4`、`C#4`、`db3`、`c-1`）。
pub fn parse_note(s: &str) -> Option<u8> {
    let s = s.trim();
    if let Ok(n) = s.parse::<i32>() {
        return u8::try_from(n).ok().filter(|n| *n <= 127);
    }
    let mut chars = s.chars();
    let letter = chars.next()?.to_ascii_lowercase();
    let base: i32 = match letter {
        'c' => 0,
        'd' => 2,
        'e' => 4,
        'f' => 5,
        'g' => 7,
        'a' => 9,
        'b' => 11,
        _ => return None,
    };
    let rest: &str = chars.as_str();
    let (accidental, octave_str) = match rest.chars().next() {
        Some('#') | Some('♯') => (1, &rest[rest.chars().next()?.len_utf8()..]),
        Some('b') | Some('♭') if rest.len() > 1 => (-1, &rest[rest.chars().next()?.len_utf8()..]),
        _ => (0, rest),
    };
    let octave: i32 = octave_str.parse().ok()?;
    let n = (octave + 1) * 12 + base + accidental;
    u8::try_from(n).ok().filter(|n| *n <= 127)
}

/// 音符号转音名（升号写法），如 60 → `c4`。
pub fn note_name(n: u8) -> String {
    const NAMES: [&str; 12] = [
        "c", "c#", "d", "d#", "e", "f", "f#", "g", "g#", "a", "a#", "b",
    ];
    let octave = i32::from(n) / 12 - 1;
    format!("{}{}", NAMES[usize::from(n % 12)], octave)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names() {
        assert_eq!(parse_note("c4"), Some(60));
        assert_eq!(parse_note("C#4"), Some(61));
        assert_eq!(parse_note("db4"), Some(61));
        assert_eq!(parse_note("c-1"), Some(0));
        assert_eq!(parse_note("g9"), Some(127));
        assert_eq!(parse_note("36"), Some(36));
        assert_eq!(parse_note("128"), None);
        assert_eq!(parse_note("h2"), None);
        assert_eq!(note_name(36), "c2");
        for n in 0..=127u8 {
            assert_eq!(parse_note(&note_name(n)), Some(n));
        }
    }
}
