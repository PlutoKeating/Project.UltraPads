//! Realtime-safety toolkit used by the audio thread.
//!
//! * [`spsc`] — wait-free single-producer/single-consumer ring buffers (`rtrb`),
//!   used for audio → control traffic (events, retired resources, recorded audio).
//! * [`mpsc::CommandQueue`] — bounded lock-free multi-producer queue for
//!   control/UI → audio commands. The UI thread, hub thread and control thread
//!   can all push without locks; the audio thread is the single consumer.
//! * [`retire`] — deferred deallocation: the audio thread never drops heap
//!   resources, it hands them back to the control thread.
//! * [`param`] — atomic `f32`/`f64`/`bool` parameters.
//! * [`alloc_check`] — a counting global allocator wrapper that tests use to
//!   prove a code path performs zero heap allocations.

pub mod alloc_check;
pub mod mpsc;
pub mod param;
pub mod retire;

/// Re-export of `rtrb` SPSC ring buffers.
pub mod spsc {
    pub use rtrb::{Consumer, PopError, Producer, PushError, RingBuffer};

    /// Create a SPSC ring buffer with the given capacity.
    pub fn channel<T>(capacity: usize) -> (Producer<T>, Consumer<T>) {
        RingBuffer::new(capacity)
    }
}
