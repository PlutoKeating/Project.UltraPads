//! Android JNI entry point.
//!
//! Dart loads `libup_ffi.so` with `dlopen`, which never calls
//! `JNI_OnLoad`. `MainActivity` therefore does
//! `System.loadLibrary("up_ffi")` and calls `nativeInit(context)` so that
//! cpal's AAudio backend can reach the JavaVM and an Android `Context`
//! through `ndk_context`.

#[cfg(target_os = "android")]
mod jni_entry {
    use jni_sys::{JNI_FALSE, JNI_OK, JNI_TRUE, JNIEnv, JavaVM, jboolean, jobject};

    /// `dev.ultrapads.ultrapads.MainActivity.nativeInit(Context): Boolean`
    ///
    /// # Safety
    /// Called by the JVM with a valid `env` and a live `context` reference.
    #[unsafe(no_mangle)]
    pub unsafe extern "system" fn Java_dev_ultrapads_ultrapads_MainActivity_nativeInit(
        env: *mut JNIEnv,
        _this: jobject,
        context: jobject,
    ) -> jboolean {
        if env.is_null() || context.is_null() {
            return JNI_FALSE;
        }
        unsafe {
            let iface = &**env;
            let mut vm: *mut JavaVM = std::ptr::null_mut();
            if (iface.v1_1.GetJavaVM)(env, &mut vm) != JNI_OK || vm.is_null() {
                return JNI_FALSE;
            }
            // The context must outlive this call: promote to a global ref
            // that is intentionally never released.
            let global = (iface.v1_1.NewGlobalRef)(env, context);
            if global.is_null() {
                return JNI_FALSE;
            }
            if !up_host::android::init_android_context(vm.cast(), global.cast()) {
                // Already initialised (activity re-created): drop the extra ref.
                (iface.v1_1.DeleteGlobalRef)(env, global);
            }
        }
        JNI_TRUE
    }
}
