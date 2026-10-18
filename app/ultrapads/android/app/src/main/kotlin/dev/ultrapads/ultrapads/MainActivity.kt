package dev.ultrapads.ultrapads

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts Flutter and prepares the Rust audio engine.
 *
 * Dart loads `libup_ffi.so` with `dlopen`, which never runs `JNI_OnLoad`, so
 * cpal's AAudio backend would not find the JavaVM / Context. We load the
 * library through the JVM first and hand both over via [nativeInit]
 * (implemented in `bridge/up-ffi/src/android.rs`). Dart's later `dlopen`
 * returns the same, already-initialised library instance.
 *
 * The hub's Wi-Fi multicast lock (mDNS, ADR-0004 §Android) is managed in
 * Rust: `hub_discover` / `hub_start_server` acquire it through JNI before
 * starting mDNS and release it when discovery / the server stops. This
 * activity only reports foreground/background via [nativeSetForeground]
 * ([onStart] / [onStop]) so the lock is never held in the background.
 *
 * RECORD_AUDIO is requested through the `dev.ultrapads/permissions`
 * MethodChannel (see docs/API.md §3):
 *  - `recordAudioStatus` → `"granted"` | `"denied"`
 *  - `requestRecordAudio` → `true` when granted
 */
class MainActivity : FlutterActivity() {
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var nativeLoaded = false

    override fun onCreate(savedInstanceState: Bundle?) {
        initNativeAudio(applicationContext)
        super.onCreate(savedInstanceState)
    }

    override fun onStart() {
        super.onStart()
        setNativeForeground(true)
    }

    override fun onStop() {
        setNativeForeground(false)
        super.onStop()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "recordAudioStatus" -> result.success(if (hasRecordAudio()) "granted" else "denied")
                    "requestRecordAudio" -> requestRecordAudio(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasRecordAudio(): Boolean =
        checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    private fun requestRecordAudio(result: MethodChannel.Result) {
        if (hasRecordAudio()) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("busy", "a permission request is already in progress", null)
            return
        }
        pendingPermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_RECORD_AUDIO)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_RECORD_AUDIO) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    /** Implemented in Rust: `Java_dev_ultrapads_ultrapads_MainActivity_nativeInit`. */
    private external fun nativeInit(context: Context): Boolean

    /** Implemented in Rust: releases the multicast lock while in the background. */
    private external fun nativeSetForeground(foreground: Boolean)

    private fun setNativeForeground(foreground: Boolean) {
        if (!nativeLoaded) return
        try {
            nativeSetForeground(foreground)
        } catch (e: UnsatisfiedLinkError) {
            Log.e(TAG, "nativeSetForeground missing in libup_ffi.so", e)
        }
    }

    private fun initNativeAudio(context: Context) {
        try {
            System.loadLibrary("up_ffi")
            nativeLoaded = true
            if (!nativeInit(context)) {
                Log.i(TAG, "native audio context was already initialised")
            }
        } catch (e: UnsatisfiedLinkError) {
            Log.e(TAG, "failed to load libup_ffi.so", e)
        }
    }

    companion object {
        private const val TAG = "UltraPads"
        private const val PERMISSION_CHANNEL = "dev.ultrapads/permissions"
        private const val REQUEST_RECORD_AUDIO = 4201
    }
}
