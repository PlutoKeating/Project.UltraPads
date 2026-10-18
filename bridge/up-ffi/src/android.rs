//! Android JNI glue.
//!
//! * `nativeInit(context)`: Dart loads `libup_ffi.so` with `dlopen`, which
//!   never calls `JNI_OnLoad`. `MainActivity` therefore does
//!   `System.loadLibrary("up_ffi")` and calls `nativeInit(context)` so that
//!   cpal's AAudio backend can reach the JavaVM and an Android `Context`
//!   through `ndk_context`. The JavaVM and context are also kept here for
//!   the multicast lock.
//! * [`MulticastGuard`]: Android drops Wi-Fi multicast (mDNS) unless the app
//!   holds a `WifiManager.MulticastLock`. `hub_discover` / `hub_start_server`
//!   take a guard *before* starting mDNS and drop it when discovery / the
//!   server stops. The real lock (created here through JNI on framework
//!   classes only, so R8 shrinking cannot break it) is held while at least
//!   one guard exists **and** the activity is in the foreground:
//!   `MainActivity.onStart/onStop` call `nativeSetForeground(bool)`, which
//!   releases the lock in the background and re-acquires it on return.
//!   Off Android the guard is a no-op.

/// RAII holder of one multicast-lock reason (see module docs).
#[derive(Debug)]
pub(crate) struct MulticastGuard {
    #[cfg_attr(not(target_os = "android"), allow(dead_code))]
    tag: String,
}

impl MulticastGuard {
    pub(crate) fn acquire(tag: &str) -> Self {
        #[cfg(target_os = "android")]
        jni_entry::set_holder(tag, true);
        Self { tag: tag.into() }
    }
}

impl Drop for MulticastGuard {
    fn drop(&mut self) {
        #[cfg(target_os = "android")]
        jni_entry::set_holder(&self.tag, false);
    }
}

#[cfg(target_os = "android")]
mod jni_entry {
    use jni_sys::{
        JNI_EDETACHED, JNI_FALSE, JNI_OK, JNI_TRUE, JNI_VERSION_1_6, JNIEnv, JavaVM, jboolean,
        jobject, jvalue,
    };
    use std::collections::BTreeSet;
    use std::ffi::CStr;
    use std::sync::{Mutex, OnceLock};

    /// JavaVM + application context (global ref), stored as integers so the
    /// statics are `Send + Sync`.
    struct Jvm {
        vm: usize,
        context: usize,
    }

    static JVM: OnceLock<Jvm> = OnceLock::new();

    struct LockState {
        holders: BTreeSet<String>,
        foreground: bool,
        /// Global ref to the `WifiManager.MulticastLock` (0 = not created).
        lock: usize,
        held: bool,
    }

    static STATE: Mutex<LockState> = Mutex::new(LockState {
        holders: BTreeSet::new(),
        foreground: true,
        lock: 0,
        held: false,
    });

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
            } else {
                let _ = JVM.set(Jvm {
                    vm: vm as usize,
                    context: global as usize,
                });
            }
        }
        JNI_TRUE
    }

    /// `dev.ultrapads.ultrapads.MainActivity.nativeSetForeground(Boolean)`
    ///
    /// # Safety
    /// Called by the JVM.
    #[unsafe(no_mangle)]
    pub unsafe extern "system" fn Java_dev_ultrapads_ultrapads_MainActivity_nativeSetForeground(
        _env: *mut JNIEnv,
        _this: jobject,
        foreground: jboolean,
    ) {
        if let Ok(mut st) = STATE.lock() {
            st.foreground = foreground == JNI_TRUE;
            update(&mut st);
        }
    }

    pub(super) fn set_holder(tag: &str, hold: bool) {
        if let Ok(mut st) = STATE.lock() {
            if hold {
                st.holders.insert(tag.to_owned());
            } else {
                st.holders.remove(tag);
            }
            update(&mut st);
        }
    }

    fn update(st: &mut LockState) {
        let want = st.foreground && !st.holders.is_empty();
        if want == st.held {
            return;
        }
        let ok = with_env(|env| unsafe {
            if st.lock == 0 {
                st.lock = create_lock(env)? as usize;
            }
            let lock = st.lock as jobject;
            let method = if want { c"acquire" } else { c"release" };
            call_void(env, lock, method, c"()V", &[])
        });
        match ok {
            Some(()) => {
                st.held = want;
                log::info!(
                    "multicast lock {} ({:?})",
                    if want { "acquired" } else { "released" },
                    st.holders
                );
            }
            None => log::warn!("multicast lock update failed; mDNS may not work"),
        }
    }

    /// `ctx.getSystemService("wifi").createMulticastLock("ultrapads-mdns")`,
    /// not reference-counted, as a global ref.
    unsafe fn create_lock(env: *mut JNIEnv) -> Option<jobject> {
        let jvm = JVM.get()?;
        unsafe {
            let iface = &**env;
            let ctx = jvm.context as jobject;
            let wifi_name = new_string(env, c"wifi")?;
            let wifi = call_object(
                env,
                ctx,
                c"getSystemService",
                c"(Ljava/lang/String;)Ljava/lang/Object;",
                &[jvalue { l: wifi_name }],
            );
            (iface.v1_1.DeleteLocalRef)(env, wifi_name);
            let wifi = wifi?;
            let tag = new_string(env, c"ultrapads-mdns")?;
            let lock = call_object(
                env,
                wifi,
                c"createMulticastLock",
                c"(Ljava/lang/String;)Landroid/net/wifi/WifiManager$MulticastLock;",
                &[jvalue { l: tag }],
            );
            (iface.v1_1.DeleteLocalRef)(env, tag);
            (iface.v1_1.DeleteLocalRef)(env, wifi);
            let lock = lock?;
            call_void(
                env,
                lock,
                c"setReferenceCounted",
                c"(Z)V",
                &[jvalue { z: JNI_FALSE }],
            )?;
            let global = (iface.v1_1.NewGlobalRef)(env, lock);
            (iface.v1_1.DeleteLocalRef)(env, lock);
            (!global.is_null()).then_some(global)
        }
    }

    unsafe fn clear_exception(env: *mut JNIEnv) -> bool {
        unsafe {
            let iface = &**env;
            if (iface.v1_2.ExceptionCheck)(env) == JNI_TRUE {
                (iface.v1_1.ExceptionDescribe)(env);
                (iface.v1_1.ExceptionClear)(env);
                true
            } else {
                false
            }
        }
    }

    unsafe fn new_string(env: *mut JNIEnv, s: &CStr) -> Option<jobject> {
        unsafe {
            let j = ((**env).v1_1.NewStringUTF)(env, s.as_ptr());
            (!clear_exception(env) && !j.is_null()).then_some(j)
        }
    }

    unsafe fn call_object(
        env: *mut JNIEnv,
        obj: jobject,
        name: &CStr,
        sig: &CStr,
        args: &[jvalue],
    ) -> Option<jobject> {
        unsafe {
            let iface = &**env;
            let cls = (iface.v1_1.GetObjectClass)(env, obj);
            let mid = (iface.v1_1.GetMethodID)(env, cls, name.as_ptr(), sig.as_ptr());
            (iface.v1_1.DeleteLocalRef)(env, cls);
            if clear_exception(env) || mid.is_null() {
                return None;
            }
            let r = (iface.v1_1.CallObjectMethodA)(env, obj, mid, args.as_ptr());
            (!clear_exception(env) && !r.is_null()).then_some(r)
        }
    }

    unsafe fn call_void(
        env: *mut JNIEnv,
        obj: jobject,
        name: &CStr,
        sig: &CStr,
        args: &[jvalue],
    ) -> Option<()> {
        unsafe {
            let iface = &**env;
            let cls = (iface.v1_1.GetObjectClass)(env, obj);
            let mid = (iface.v1_1.GetMethodID)(env, cls, name.as_ptr(), sig.as_ptr());
            (iface.v1_1.DeleteLocalRef)(env, cls);
            if clear_exception(env) || mid.is_null() {
                return None;
            }
            (iface.v1_1.CallVoidMethodA)(env, obj, mid, args.as_ptr());
            (!clear_exception(env)).then_some(())
        }
    }

    /// Run `f` with a JNIEnv for the current thread (attaching it as a
    /// daemon for the duration of the call if needed).
    fn with_env<T>(f: impl FnOnce(*mut JNIEnv) -> Option<T>) -> Option<T> {
        let jvm = JVM.get()?;
        unsafe {
            let vm = jvm.vm as *mut JavaVM;
            let vmi = &**vm;
            let mut env: *mut JNIEnv = std::ptr::null_mut();
            let penv = (&mut env as *mut *mut JNIEnv).cast();
            let mut attached = false;
            match (vmi.v1_2.GetEnv)(vm, penv, JNI_VERSION_1_6) {
                JNI_OK => {}
                JNI_EDETACHED => {
                    if (vmi.v1_4.AttachCurrentThreadAsDaemon)(vm, penv, std::ptr::null_mut())
                        != JNI_OK
                    {
                        return None;
                    }
                    attached = true;
                }
                _ => return None,
            }
            let r = if env.is_null() { None } else { f(env) };
            if attached {
                (vmi.v1_1.DetachCurrentThread)(vm);
            }
            r
        }
    }
}
