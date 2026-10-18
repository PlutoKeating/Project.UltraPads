//! Gain, pan and velocity helpers.

/// Decibels → linear amplitude.
#[inline]
pub fn db_to_linear(db: f32) -> f32 {
    10f32.powf(db / 20.0)
}

/// Linear amplitude → decibels (`-inf` clamps to -120 dB).
#[inline]
pub fn linear_to_db(lin: f32) -> f32 {
    if lin <= 1e-6 {
        -120.0
    } else {
        20.0 * lin.log10()
    }
}

/// Constant-power pan law (−3 dB at centre). `pan` ∈ `[-1, 1]`.
/// Returns `(left, right)` gains.
#[inline]
pub fn pan_gains(pan: f32) -> (f32, f32) {
    let p = pan.clamp(-1.0, 1.0);
    let angle = (p + 1.0) * std::f32::consts::FRAC_PI_4; // 0..pi/2
    (angle.cos(), angle.sin())
}

/// Constant-power pan normalised so that centre is unity (0 dB) on both
/// channels; hard left/right gives √2 on one side and 0 on the other.
/// Used for pads so that the default (centre) does not attenuate samples.
#[inline]
pub fn pan_gains_unity_centre(pan: f32) -> (f32, f32) {
    let (l, r) = pan_gains(pan);
    (l * std::f32::consts::SQRT_2, r * std::f32::consts::SQRT_2)
}

/// Velocity (0..=1) → linear gain using a square-law curve (≈ 40 dB range),
/// which feels natural on touch screens and MIDI pads.
#[inline]
pub fn velocity_to_gain(velocity: f32) -> f32 {
    let v = velocity.clamp(0.0, 1.0);
    v * v
}

/// Apply a constant gain in-place.
#[inline]
pub fn apply_gain(buf: &mut [f32], gain: f32) {
    if gain == 1.0 {
        return;
    }
    for s in buf {
        *s *= gain;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pan_law() {
        let (l, r) = pan_gains(0.0);
        assert!((l - r).abs() < 1e-6);
        assert!((l * l + r * r - 1.0).abs() < 1e-5, "constant power");
        let (l, r) = pan_gains(-1.0);
        assert!((l - 1.0).abs() < 1e-6 && r.abs() < 1e-6);
        let (l, r) = pan_gains_unity_centre(0.0);
        assert!((l - 1.0).abs() < 1e-5 && (r - 1.0).abs() < 1e-5);
    }

    #[test]
    fn db_conversions() {
        assert!((db_to_linear(-6.0206) - 0.5).abs() < 1e-3);
        assert!((linear_to_db(1.0)).abs() < 1e-6);
        assert_eq!(linear_to_db(0.0), -120.0);
        assert_eq!(velocity_to_gain(1.0), 1.0);
        assert_eq!(velocity_to_gain(2.0), 1.0);
        assert!((velocity_to_gain(0.5) - 0.25).abs() < 1e-6);
    }
}
