//! Allocation accounting for realtime tests.
//!
//! Install [`CountingAlloc`] as the global allocator in a test binary and wrap
//! the code under test in [`count_allocs`]: the returned count is the number
//! of allocations, reallocations and deallocations performed **on the
//! current thread** while the closure ran.
//!
//! ```ignore
//! #[global_allocator]
//! static A: up_rt::alloc_check::CountingAlloc = up_rt::alloc_check::CountingAlloc;
//! let (_, n) = up_rt::alloc_check::count_allocs(|| process_block());
//! assert_eq!(n, 0);
//! ```

use std::alloc::{GlobalAlloc, Layout, System};
use std::cell::Cell;

thread_local! {
    static TRACKING: Cell<bool> = const { Cell::new(false) };
    static COUNT: Cell<u64> = const { Cell::new(0) };
}

/// Global allocator wrapper around [`System`] that counts heap operations on
/// threads that opted in via [`count_allocs`].
pub struct CountingAlloc;

#[inline]
fn bump() {
    // `try_with` so that allocations during TLS teardown don't panic.
    let _ = TRACKING.try_with(|t| {
        if t.get() {
            let _ = COUNT.try_with(|c| c.set(c.get() + 1));
        }
    });
}

// SAFETY: forwards to the system allocator; bookkeeping uses const-initialized
// thread locals which never allocate.
unsafe impl GlobalAlloc for CountingAlloc {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        bump();
        unsafe { System.alloc(layout) }
    }
    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        bump();
        unsafe { System.dealloc(ptr, layout) }
    }
    unsafe fn alloc_zeroed(&self, layout: Layout) -> *mut u8 {
        bump();
        unsafe { System.alloc_zeroed(layout) }
    }
    unsafe fn realloc(&self, ptr: *mut u8, layout: Layout, new_size: usize) -> *mut u8 {
        bump();
        unsafe { System.realloc(ptr, layout, new_size) }
    }
}

/// Run `f` and return its result together with the number of heap operations
/// performed on this thread meanwhile. Only meaningful when
/// [`CountingAlloc`] is the global allocator.
pub fn count_allocs<R>(f: impl FnOnce() -> R) -> (R, u64) {
    let before = COUNT.with(|c| c.get());
    let was = TRACKING.with(|t| t.replace(true));
    let r = f();
    TRACKING.with(|t| t.set(was));
    let after = COUNT.with(|c| c.get());
    (r, after - before)
}

/// Assert (in debug builds) that `f` does not touch the heap.
#[track_caller]
pub fn assert_no_alloc<R>(f: impl FnOnce() -> R) -> R {
    let (r, n) = count_allocs(f);
    debug_assert_eq!(n, 0, "realtime section performed {n} heap operations");
    r
}
