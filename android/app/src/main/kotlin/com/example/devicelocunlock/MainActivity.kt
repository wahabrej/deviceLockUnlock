package com.example.devicelocunlock

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTROLS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "lockDevice" -> result.success(applyLockState(this, true, true))
                    "unlockDevice" -> result.success(applyLockState(this, false, false))
                    "isDeviceOwner" -> result.success(isDeviceOwner())
                    "getDeviceId" -> result.success(readDeviceId())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getDeviceInfo") {
                    result.success(
                        mapOf(
                            "deviceId" to readDeviceId(),
                            "manufacturer" to Build.MANUFACTURER,
                            "model" to Build.MODEL,
                            "androidVersion" to Build.VERSION.RELEASE,
                            "sdkInt" to Build.VERSION.SDK_INT,
                        ),
                    )
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun isDeviceOwner(): Boolean =
        getSystemService(DevicePolicyManager::class.java).isDeviceOwnerApp(packageName)

    private fun readDeviceId(): String =
        Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID).orEmpty()

    companion object {
        private const val CONTROLS_CHANNEL = "com.example.devicelocunlock/controls"
        private const val DEVICE_CHANNEL = "com.example.devicelocunlock/device"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val LOCKED_KEY = "flutter.device_locked"

        private var instance: MainActivity? = null

        fun applyEMIHardLockStatic(context: Context, locked: Boolean): Boolean =
            applyLockState(context, locked, locked)

        private fun applyLockState(
            context: Context,
            locked: Boolean,
            lockScreen: Boolean,
        ): Boolean {
            val devicePolicyManager = context.getSystemService(DevicePolicyManager::class.java)
            val adminComponent = ComponentName(context, DeviceAdminReceiver::class.java)
            val isAdmin = devicePolicyManager.isAdminActive(adminComponent)
            val isOwner = devicePolicyManager.isDeviceOwnerApp(context.packageName)

            if (locked && lockScreen && !isAdmin && !isOwner) return false

            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(LOCKED_KEY, locked)
                .apply()

            if (locked && lockScreen && (isAdmin || isOwner)) {
                devicePolicyManager.lockNow()
            }

            instance?.notifyFlutterOfLockState(locked)
            return true
        }
    }

    private fun notifyFlutterOfLockState(locked: Boolean) {
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CONTROLS_CHANNEL).invokeMethod(
                "lockStateChanged",
                mapOf("isLocked" to locked),
            )
        }
    }
}