//! Atomic parameters shared between control and audio threads.

use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, Ordering};

/// Atomic `f32` stored as bits.
#[derive(Debug, Default)]
pub struct AtomicF32(AtomicU32);

impl AtomicF32 {
    pub const fn new(v: f32) -> Self {
        Self(AtomicU32::new(v.to_bits()))
    }
    #[inline]
    pub fn get(&self) -> f32 {
        f32::from_bits(self.0.load(Ordering::Relaxed))
    }
    #[inline]
    pub fn set(&self, v: f32) {
        self.0.store(v.to_bits(), Ordering::Relaxed)
    }
}

/// Atomic `f64` stored as bits.
#[derive(Debug, Default)]
pub struct AtomicF64(AtomicU64);

impl AtomicF64 {
    pub const fn new(v: f64) -> Self {
        Self(AtomicU64::new(v.to_bits()))
    }
    #[inline]
    pub fn get(&self) -> f64 {
        f64::from_bits(self.0.load(Ordering::Relaxed))
    }
    #[inline]
    pub fn set(&self, v: f64) {
        self.0.store(v.to_bits(), Ordering::Relaxed)
    }
}

/// Atomic flag with relaxed semantics plus an explicit `take`.
#[derive(Debug, Default)]
pub struct AtomicFlag(AtomicBool);

impl AtomicFlag {
    pub const fn new(v: bool) -> Self {
        Self(AtomicBool::new(v))
    }
    #[inline]
    pub fn get(&self) -> bool {
        self.0.load(Ordering::Acquire)
    }
    #[inline]
    pub fn set(&self, v: bool) {
        self.0.store(v, Ordering::Release)
    }
    /// Returns the current value and clears it.
    #[inline]
    pub fn take(&self) -> bool {
        self.0.swap(false, Ordering::AcqRel)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn roundtrip() {
        let a = AtomicF32::new(0.5);
        assert_eq!(a.get(), 0.5);
        a.set(-1.25);
        assert_eq!(a.get(), -1.25);
        let b = AtomicF64::new(120.0);
        b.set(93.5);
        assert_eq!(b.get(), 93.5);
        let f = AtomicFlag::new(true);
        assert!(f.take());
        assert!(!f.get());
    }
}
