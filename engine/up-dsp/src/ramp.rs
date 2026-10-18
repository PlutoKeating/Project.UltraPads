//! Linear fades and parameter smoothing (de-click).

/// State of a [`Fade`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FadeState {
    /// Gain is 1 and stays there.
    Steady,
    FadingIn,
    FadingOut,
    /// Fade-out finished; gain is 0.
    Silent,
}

/// Short linear fade used to avoid clicks when starting/stopping voices.
#[derive(Debug, Clone, Copy)]
pub struct Fade {
    gain: f32,
    step: f32,
    state: FadeState,
}

impl Default for Fade {
    fn default() -> Self {
        Self::steady()
    }
}

impl Fade {
    /// Gain 1, no fade.
    pub const fn steady() -> Self {
        Self {
            gain: 1.0,
            step: 0.0,
            state: FadeState::Steady,
        }
    }

    /// Start from silence and fade in over `frames` frames.
    pub fn fade_in(frames: u32) -> Self {
        if frames == 0 {
            return Self::steady();
        }
        Self {
            gain: 0.0,
            step: 1.0 / frames as f32,
            state: FadeState::FadingIn,
        }
    }

    /// Fade from the current gain down to zero over `frames` frames.
    pub fn start_fade_out(&mut self, frames: u32) {
        if matches!(self.state, FadeState::Silent) {
            return;
        }
        if frames == 0 || self.gain <= 0.0 {
            self.gain = 0.0;
            self.state = FadeState::Silent;
            return;
        }
        // Keep the same absolute duration from full scale.
        self.step = 1.0 / frames as f32;
        self.state = FadeState::FadingOut;
    }

    #[inline]
    pub fn state(&self) -> FadeState {
        self.state
    }

    #[inline]
    pub fn is_silent(&self) -> bool {
        self.state == FadeState::Silent
    }

    #[inline]
    pub fn is_fading_out(&self) -> bool {
        self.state == FadeState::FadingOut
    }

    #[inline]
    pub fn gain(&self) -> f32 {
        self.gain
    }

    /// Advance one frame and return the gain to apply to it.
    #[inline]
    pub fn next_gain(&mut self) -> f32 {
        match self.state {
            FadeState::Steady => 1.0,
            FadeState::Silent => 0.0,
            FadeState::FadingIn => {
                let g = self.gain;
                self.gain += self.step;
                if self.gain >= 1.0 {
                    self.gain = 1.0;
                    self.state = FadeState::Steady;
                }
                g
            }
            FadeState::FadingOut => {
                let g = self.gain;
                self.gain -= self.step;
                if self.gain <= 0.0 {
                    self.gain = 0.0;
                    self.state = FadeState::Silent;
                }
                g
            }
        }
    }
}

/// Linearly smoothed parameter (avoids zipper noise on gain changes).
#[derive(Debug, Clone, Copy)]
pub struct SmoothedValue {
    current: f32,
    target: f32,
    step: f32,
    remaining: u32,
    ramp_frames: u32,
}

impl SmoothedValue {
    pub fn new(value: f32, ramp_frames: u32) -> Self {
        Self {
            current: value,
            target: value,
            step: 0.0,
            remaining: 0,
            ramp_frames: ramp_frames.max(1),
        }
    }

    pub fn set_target(&mut self, target: f32) {
        if (target - self.target).abs() < f32::EPSILON && self.remaining == 0 {
            return;
        }
        self.target = target;
        self.remaining = self.ramp_frames;
        self.step = (target - self.current) / self.ramp_frames as f32;
    }

    /// Jump immediately.
    pub fn set_immediate(&mut self, value: f32) {
        self.current = value;
        self.target = value;
        self.remaining = 0;
    }

    #[inline]
    pub fn target(&self) -> f32 {
        self.target
    }

    #[inline]
    pub fn is_smoothing(&self) -> bool {
        self.remaining > 0
    }

    #[inline]
    pub fn next_value(&mut self) -> f32 {
        if self.remaining > 0 {
            self.remaining -= 1;
            self.current = if self.remaining == 0 {
                self.target
            } else {
                self.current + self.step
            };
        }
        self.current
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fade_in_then_out() {
        let mut f = Fade::fade_in(4);
        let g: Vec<f32> = (0..5).map(|_| f.next_gain()).collect();
        assert_eq!(g, vec![0.0, 0.25, 0.5, 0.75, 1.0]);
        assert_eq!(f.state(), FadeState::Steady);
        f.start_fade_out(2);
        assert_eq!(f.next_gain(), 1.0);
        assert_eq!(f.next_gain(), 0.5);
        assert_eq!(f.next_gain(), 0.0);
        assert!(f.is_silent());
    }

    #[test]
    fn fade_out_is_monotonic() {
        let mut f = Fade::steady();
        f.start_fade_out(240);
        let mut prev = f32::MAX;
        for _ in 0..300 {
            let g = f.next_gain();
            assert!(g <= prev);
            prev = g;
        }
        assert!(f.is_silent());
    }

    #[test]
    fn smoothed_reaches_target() {
        let mut s = SmoothedValue::new(0.0, 10);
        s.set_target(1.0);
        let mut last = 0.0;
        for _ in 0..10 {
            last = s.next_value();
        }
        assert_eq!(last, 1.0);
        assert!(!s.is_smoothing());
    }
}
