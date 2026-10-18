//! Lock-free bounded multi-producer queue (audio thread is the consumer).

use crossbeam_queue::ArrayQueue;
use std::sync::Arc;

/// Bounded, lock-free, allocation-free (after construction) MPMC queue used as
/// MPSC: any thread may push, only the audio thread pops.
///
/// `rtrb` is strictly SPSC; commands however originate from several threads
/// (Flutter UI via sync FFI, Hub controller thread, control thread), so the
/// command path uses `crossbeam_queue::ArrayQueue`, which is lock-free for both
/// push and pop and never allocates after construction.
pub struct CommandQueue<T> {
    inner: Arc<ArrayQueue<T>>,
}

impl<T> Clone for CommandQueue<T> {
    fn clone(&self) -> Self {
        Self {
            inner: Arc::clone(&self.inner),
        }
    }
}

impl<T> CommandQueue<T> {
    pub fn new(capacity: usize) -> Self {
        Self {
            inner: Arc::new(ArrayQueue::new(capacity.max(1))),
        }
    }

    /// Push a value; returns it back if the queue is full. Lock-free.
    #[inline]
    pub fn push(&self, value: T) -> Result<(), T> {
        self.inner.push(value)
    }

    /// Pop the oldest value. Lock-free, wait-free in the uncontended case.
    #[inline]
    pub fn pop(&self) -> Option<T> {
        self.inner.pop()
    }

    pub fn len(&self) -> usize {
        self.inner.len()
    }

    pub fn is_empty(&self) -> bool {
        self.inner.is_empty()
    }

    pub fn capacity(&self) -> usize {
        self.inner.capacity()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn multi_producer() {
        let q = CommandQueue::<u32>::new(4096);
        let handles: Vec<_> = (0..4)
            .map(|t| {
                let q = q.clone();
                std::thread::spawn(move || {
                    for i in 0..1000 {
                        q.push(t * 1000 + i).unwrap();
                    }
                })
            })
            .collect();
        for h in handles {
            h.join().unwrap();
        }
        let mut n = 0;
        while q.pop().is_some() {
            n += 1;
        }
        assert_eq!(n, 4000);
    }

    #[test]
    fn full_returns_value() {
        let q = CommandQueue::new(1);
        q.push(1).unwrap();
        assert_eq!(q.push(2), Err(2));
    }
}
