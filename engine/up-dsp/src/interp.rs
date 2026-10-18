//! Interpolation kernels for varispeed sample playback.

/// 4-point, 3rd-order Hermite (Catmull-Rom) interpolation.
/// `x` = fractional position in `[0, 1)` between `y0` and `y1`;
/// `ym1`, `y2` are the neighbours.
#[inline]
pub fn hermite4(x: f32, ym1: f32, y0: f32, y1: f32, y2: f32) -> f32 {
    let c0 = y0;
    let c1 = 0.5 * (y1 - ym1);
    let c2 = ym1 - 2.5 * y0 + 2.0 * y1 - 0.5 * y2;
    let c3 = 0.5 * (y2 - ym1) + 1.5 * (y0 - y1);
    ((c3 * x + c2) * x + c1) * x + c0
}

/// Read `data` at fractional position `pos` with Hermite interpolation.
/// Out-of-range neighbours read as zero (or wrap when `wrap` is a valid
/// loop range `start..end`).
#[inline]
pub fn read_hermite(data: &[f32], pos: f64, wrap: Option<(usize, usize)>) -> f32 {
    let i = pos.floor() as isize;
    let frac = (pos - i as f64) as f32;
    let at = |k: isize| -> f32 {
        match wrap {
            Some((s, e)) if e > s => {
                let len = (e - s) as isize;
                let mut j = k;
                if j >= e as isize {
                    j = s as isize + (j - s as isize).rem_euclid(len);
                }
                if j < 0 {
                    return 0.0;
                }
                data.get(j as usize).copied().unwrap_or(0.0)
            }
            _ => {
                if k < 0 {
                    0.0
                } else {
                    data.get(k as usize).copied().unwrap_or(0.0)
                }
            }
        }
    };
    if frac == 0.0 {
        return at(i);
    }
    hermite4(frac, at(i - 1), at(i), at(i + 1), at(i + 2))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn passes_through_samples() {
        assert_eq!(hermite4(0.0, 1.0, 2.0, 3.0, 4.0), 2.0);
        assert!(
            (hermite4(0.5, 1.0, 2.0, 3.0, 4.0) - 2.5).abs() < 1e-6,
            "linear data stays linear"
        );
    }

    #[test]
    fn read_with_wrap() {
        let d = [0.0, 1.0, 2.0, 3.0];
        assert_eq!(read_hermite(&d, 2.0, None), 2.0);
        assert_eq!(read_hermite(&d, 5.0, Some((0, 4))), 1.0);
        assert_eq!(read_hermite(&d, 10.0, None), 0.0);
    }
}
