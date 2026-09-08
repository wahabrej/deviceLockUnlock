package com.example.devicelocunlock

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class SyncForegroundService : Service() {
    private val executor = Executors.newSingleThreadExecutor()
    private val handler = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null
    
    private val pollingTask = object : Runnable {
        override fun run() {
            executor.execute {
                try {
                    checkLockStatus()
                } catch (e: Exception) {
                    Log.e("SyncService", "Polling error: ${e.message}")
                }
            }
            // ১৫-২০ সেকেন্ড পর পর চেক করবে
            handler.postDelayed(this, 20000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i("SyncService", "Service onStartCommand called")
        startForegroundWithNotification()
        handler.removeCallbacks(pollingTask)
        handler.post(pollingTask)
        return START_STICKY // সিস্টেম কিল করলেও আবার রিস্টার্ট হবে
    }

    private fun startForegroundWithNotification() {
        val channelId = "sync_service_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Protection Monitoring", NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Security Active")
            .setContentText("Device is under EMI protection")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(1, notification)
        }
    }

    private fun checkLockStatus() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val imei = prefs.getString("flutter.device_imei", "") ?: ""
        
        if (imei.isEmpty()) {
            Log.w("SyncService", "IMEI not found in SharedPreferences")
            return
        }

        // WakeLock নেওয়া হচ্ছে যাতে ব্যাকগ্রাউন্ডে নেটওয়ার্ক সচল থাকে
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SyncService:WakeLock")
        wakeLock?.acquire(10000)

        try {
            Log.i("SyncService", "Checking status for IMEI: $imei")
            val url = URL("${BuildConfig.SMART_PAY_APK_API_BASE_URL}/devices/$imei/lock-status")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = 10000
            conn.readTimeout = 10000
            conn.useCaches = false
            val deviceTrackKey = prefs.getString("flutter.device_track_key", BuildConfig.DEVICE_TRACK_KEY)
                ?: BuildConfig.DEVICE_TRACK_KEY
            if (deviceTrackKey.isNotBlank()) {
                conn.setRequestProperty("x-device-key", deviceTrackKey)
            }

            if (conn.responseCode == 200) {
                val response = conn.inputStream.bufferedReader().readText()
                val json = JSONObject(response)
                if (json.getBoolean("success")) {
                    val data = json.getJSONObject("data")
                    
                    val isLockedServer = when(val raw = data.opt("isLocked")) {
                        is Boolean -> raw
                        is Int -> raw == 1
                        is String -> raw.lowercase() == "true" || raw == "1"
                        else -> false
                    }
                    
                    val currentLocalLock = prefs.getBoolean("flutter.device_locked", false)

                    if (isLockedServer != currentLocalLock) {
                        Log.i("SyncService", "Mismatch detected! Server: $isLockedServer, Local: $currentLocalLock")
                        // সরাসরি স্ট্যাটিক মেথড কল যা অ্যাপকে Dead অবস্থা থেকে জাগিয়ে তুলবে
                        MainActivity.applyEMIHardLockStatic(this, isLockedServer)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("SyncService", "Network call failed: ${e.message}")
        } finally {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        }
    }

    // অ্যাপ সোয়াইপ করে বন্ধ করলে এটি কল হয়
    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.i("SyncService", "Task removed (App Swiped). Scheduling restart...")
        val restartIntent = Intent(this, SyncForegroundService::class.java).apply {
            setPackage(packageName)
        }
        val pendingIntent = PendingIntent.getService(
            this, 1, restartIntent, 
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.set(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + 1500, pendingIntent)
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        Log.i("SyncService", "Service destroyed")
        handler.removeCallbacks(pollingTask)
        executor.shutdown()
        super.onDestroy()
    }
}
