//! Android glue.
//!
//! cpal's AAudio backend (device enumeration, stream setup) reads the
//! JavaVM and an Android `Context` from `ndk_context`. Dart FFI loads
//! `libup_ffi.so` via `dlopen`, which does not run `JNI_OnLoad`, so the
//! Android `MainActivity` calls `System.loadLibrary("up_ffi")` and then a
//! JNI export in `up-ffi` that forwards here.

use std::sync::atomic::{AtomicBool, Ordering};

static INITIALIZED: AtomicBool = AtomicBool::new(false);

/// Whether the Android context has been provided (always `true` elsewhere).
pub fn context_ready() -> bool {
    !cfg!(target_os = "android") || INITIALIZED.load(Ordering::Acquire)
}

/// Initialise `ndk_context` once.
///
/// # Safety
/// `vm` must be a valid `JavaVM*` and `context` a JNI **global** reference
/// to an `android.content.Context` that stays valid for the process
/// lifetime.
#[allow(unused_variables)]
pub unsafe fn init_android_context(
    vm: *mut std::ffi::c_void,
    context: *mut std::ffi::c_void,
) -> bool {
    if INITIALIZED.swap(true, Ordering::AcqRel) {
        return false;
    }
    #[cfg(target_os = "android")]
    unsafe {
        ndk_context::initialize_android_context(vm, context);
    }
    true
}
