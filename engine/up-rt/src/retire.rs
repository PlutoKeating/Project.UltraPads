//! Deferred deallocation ("retire") for the audio thread.
//!
//! The audio thread must never free heap memory. Anything it wants to get rid
//! of (an `Arc<Sample>` that was replaced, a finished voice's buffer
//! reference, …) is moved into a [`Retirer`], which pushes it through a SPSC
//! ring to a [`Collector`] that the control thread drains and drops.

use crate::spsc::{self, Consumer, Producer};
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};

/// Audio-thread side.
pub struct Retirer<T: Send> {
    tx: Producer<T>,
    /// Pre-allocated overflow stash used when the ring is momentarily full.
    stash: Vec<T>,
    leaked: Arc<AtomicU64>,
}

/// Control-thread side.
pub struct Collector<T: Send> {
    rx: Consumer<T>,
    leaked: Arc<AtomicU64>,
}

/// Create a retire channel. `capacity` bounds the ring; an overflow stash of
/// the same capacity is pre-allocated.
pub fn retire_channel<T: Send>(capacity: usize) -> (Retirer<T>, Collector<T>) {
    let (tx, rx) = spsc::channel(capacity);
    let leaked = Arc::new(AtomicU64::new(0));
    (
        Retirer {
            tx,
            stash: Vec::with_capacity(capacity),
            leaked: Arc::clone(&leaked),
        },
        Collector { rx, leaked },
    )
}

impl<T: Send> Retirer<T> {
    /// Hand `value` to the control thread. Never allocates or frees.
    ///
    /// If both the ring and the stash are full, the value is leaked
    /// (`mem::forget`) and counted — leaking is preferable to freeing on the
    /// audio thread, and indicates a mis-sized channel.
    #[inline]
    pub fn retire(&mut self, value: T) {
        self.flush();
        if let Err(rtrb::PushError::Full(v)) = self.tx.push(value) {
            if self.stash.len() < self.stash.capacity() {
                self.stash.push(v);
            } else {
                std::mem::forget(v);
                self.leaked.fetch_add(1, Ordering::Relaxed);
            }
        }
    }

    /// Retry pushing stashed values (call once per block).
    #[inline]
    pub fn flush(&mut self) {
        while !self.stash.is_empty() && self.tx.slots() > 0 {
            if let Some(v) = self.stash.pop() {
                let _ = self.tx.push(v);
            }
        }
    }
}

impl<T: Send> Collector<T> {
    /// Drop everything that was retired so far. Returns the number dropped.
    pub fn collect(&mut self) -> usize {
        let mut n = 0;
        while let Ok(v) = self.rx.pop() {
            drop(v);
            n += 1;
        }
        n
    }

    /// Number of values leaked because the channel overflowed.
    pub fn leaked(&self) -> u64 {
        self.leaked.load(Ordering::Relaxed)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn retire_and_collect() {
        let (mut r, mut c) = retire_channel::<Arc<Vec<f32>>>(2);
        let a = Arc::new(vec![1.0; 16]);
        let weak = Arc::downgrade(&a);
        r.retire(a);
        assert!(
            weak.upgrade().is_some(),
            "must not be freed on audio thread"
        );
        assert_eq!(c.collect(), 1);
        assert!(weak.upgrade().is_none());
    }

    #[test]
    fn overflow_uses_stash_then_leaks() {
        let (mut r, mut c) = retire_channel::<Box<u32>>(1);
        r.retire(Box::new(1)); // ring
        r.retire(Box::new(2)); // stash
        r.retire(Box::new(3)); // leaked
        assert_eq!(c.leaked(), 1);
        assert_eq!(c.collect(), 1);
        r.flush();
        assert_eq!(c.collect(), 1);
    }
}
