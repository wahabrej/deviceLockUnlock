package com.example.devicelocunlock

import android.app.ActivityManager
import android.app.KeyguardManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.BatteryManager
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import android.os.UserManager
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.devicelocunlock/controls"
    private val DEVICE_CHANNEL = "com.example.devicelocunlock/device"
    private val lockTaskHandler = Handler(Looper.getMainLooper())

    companion object {
        var isHardLocked = false

        fun applyEMIHardLockStatic(context: Context, enable: Boolean): Boolean {
            Log.d("MainActivity", "applyEMIHardLockStatic called: enable=$enable")
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = ComponentName(context, DeviceAdminReceiver::class.java)

            if (!dpm.isDeviceOwnerApp(context.packageName)) {
                Log.e("MainActivity", "Lock rejected: app is not Device Owner")
                return false
            }

            // স্ট্যাটাসটি SharedPreferences এ সেভ করা যাতে অ্যাপ বন্ধ থাকলেও মনে থাকে
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            return try {
                if (enable) {
                    dpm.setLockTaskPackages(adminComponent, arrayOf(context.packageName))
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        dpm.setStatusBarDisabled(adminComponent, true)
                        dpm.setKeyguardDisabled(adminComponent, true)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        dpm.setLockTaskFeatures(adminComponent, DevicePolicyManager.LOCK_TASK_FEATURE_NONE)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        dpm.setUninstallBlocked(adminComponent, context.packageName, true)
                        dpm.addUserRestriction(adminComponent, UserManager.DISALLOW_FACTORY_RESET)
                    }

                    // Wake the screen so the managed LockScreen can be displayed.
                    val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                    @Suppress("DEPRECATION")
                    val wl = pm.newWakeLock(PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE, "Lock:Wake")
                    wl.acquire(10000)
                    if (wl.isHeld) wl.release()

                    prefs.edit().putBoolean("flutter.device_locked", true).apply()
                    isHardLocked = true

                    // Bring the managed LockScreen to the foreground. onResume() enters kiosk mode.
                    val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or 
                                   Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or 
                                   Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                   Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    context.startActivity(intent)
                } else {
                    dpm.setLockTaskPackages(adminComponent, emptyArray())
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        dpm.setStatusBarDisabled(adminComponent, false)
                        dpm.setKeyguardDisabled(adminComponent, false)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        dpm.setUninstallBlocked(adminComponent, context.packageName, false)
                        dpm.clearUserRestriction(adminComponent, UserManager.DISALLOW_FACTORY_RESET)
                    }
                    prefs.edit().putBoolean("flutter.device_locked", false).apply()
                    isHardLocked = false
                }
                Log.i("MainActivity", if (enable) "Managed lock policy applied" else "Managed lock policy cleared")
                true
            } catch (e: Exception) {
                Log.e("MainActivity", "Hard lock error", e)
                false
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        turnScreenOnAndKeyguardOff()
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        isHardLocked = prefs.getBoolean("flutter.device_locked", false)
        startNativeSyncService()
        requestIgnoreBatteryOptimizations()
        if (isHardLocked) {
            scheduleLockTaskRetry()
        }
    }

    private fun startNativeSyncService() {
        val serviceIntent = Intent(this, SyncForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun turnScreenOnAndKeyguardOff() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                          WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                          WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                          WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    override fun onResume() {
        super.onResume()
        if (isHardLocked) {
            scheduleLockTaskRetry()
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && isHardLocked) {
            scheduleLockTaskRetry()
        }
    }

    override fun onDestroy() {
        lockTaskHandler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun scheduleLockTaskRetry() {
        lockTaskHandler.removeCallbacksAndMessages(null)
        val retryDelays = longArrayOf(0L, 300L, 1000L, 2500L)
        retryDelays.forEach { delay ->
            lockTaskHandler.postDelayed({
                if (isHardLocked && !isFinishing) {
                    startLockTaskIfAllowed()
                }
            }, delay)
        }
    }

    private fun startLockTaskIfAllowed() {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        if (!dpm.isDeviceOwnerApp(packageName)) {
            Log.e("MainActivity", "Cannot start lock task: app is not Device Owner")
            return
        }
        try {
            startLockTask()
            Log.i("MainActivity", "Lock task started")
        } catch (e: Exception) {
            Log.e("MainActivity", "Unable to start lock task", e)
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "lockDevice" -> result.success(applyEMIHardLockStatic(this, true))
                    "unlockDevice" -> {
                        try { stopLockTask() } catch (e: Exception) {}
                        result.success(applyEMIHardLockStatic(this, false))
                    }
                    "isAdminActive" -> result.success(isDeviceAdminActive())
                    "isDeviceOwner" -> result.success(isDeviceOwner())
                    "activateAdmin" -> { activateDeviceAdmin(); result.success(true) }
                    "requestIgnoreBatteryOptimizations" -> { checkAndRequestPermissions(); result.success(true) }
                    "removeManagement" -> { 
                        removeManagement() 
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getDeviceInfo") result.success(getDeviceInfo())
                else result.notImplemented()
            }
    }

    // ✅ এই মেথডটি ডিভাইস ওনার স্ট্যাটাস রিমুভ করে সরাসরি আনইনস্টল পেজ ওপেন করবে
    private fun removeManagement() {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        try {
            // ১. লক টাস্ক মোড (কিয়স্ক) বন্ধ করা
            try { stopLockTask() } catch (e: Exception) {}
            
            // ২. হার্ড লক মেকানিজম অফ করা
            applyEMIHardLockStatic(this, false)

            // ৩. ডিভাইস ওনার ক্লিয়ার করা
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                if (dpm.isDeviceOwnerApp(packageName)) {
                    dpm.clearDeviceOwnerApp(packageName)
                    Log.d("MainActivity", "Device Owner status removed.")
                }
            }
            
            // ৪. অ্যাডমিন রিমুভ করা
            val adminComponent = ComponentName(this, DeviceAdminReceiver::class.java)
            dpm.removeActiveAdmin(adminComponent)

            // ৫. সরাসরি আনইনস্টল স্ক্রিন ওপেন করা
            val intent = Intent(Intent.ACTION_DELETE)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)

        } catch (e: Exception) {
            Log.e("MainActivity", "Error removing management: ${e.message}")
        }
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                } catch (e: Exception) {
                    val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    startActivity(intent)
                }
            }
        }
    }

    private fun checkAndRequestPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                startActivity(intent)
            }
        }
    }

    override fun onBackPressed() {
        if (isHardLocked) return
        super.onBackPressed()
    }

    private fun isDeviceAdminActive(): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(this, DeviceAdminReceiver::class.java)
        return dpm.isAdminActive(adminComponent)
    }

    private fun isDeviceOwner(): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return dpm.isDeviceOwnerApp(packageName)
    }

    private fun activateDeviceAdmin() {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(this, DeviceAdminReceiver::class.java)
        if (!dpm.isAdminActive(adminComponent)) {
            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
            intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
            startActivity(intent)
        }
    }

    private fun getAndroidDeviceId(): String = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "UNKNOWN"

    private fun getGeneratedIMEI(): String {
        val androidId = getAndroidDeviceId().filter { it.isDigit() }
        return if (androidId.length >= 15) androidId.substring(0, 15) else androidId.padEnd(15, '0')
    }

    private fun getDeviceInfo(): Map<String, String> {
        val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        return mapOf(
            "model" to "${Build.MANUFACTURER} ${Build.MODEL}",
            "imei" to getGeneratedIMEI(),
            "androidVersion" to Build.VERSION.RELEASE,
            "batteryLevel" to "$level%",
            "deviceId" to getAndroidDeviceId()
        )
    }
}
