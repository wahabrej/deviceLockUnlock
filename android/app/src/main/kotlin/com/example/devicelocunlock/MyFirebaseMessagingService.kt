package com.example.devicelocunlock

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // টোকেনটি SharedPreferences এ সেভ করা (ফ্লাটার যাতে পায়)
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().putString("flutter.fcm_token", token).apply()
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val data = message.data
        if (data.isNotEmpty()) {
            val command = data["command"]
            Log.d("FCM", "Received Command: $command")

            when (command) {
                "LOCK" -> {
                    updateLockStatus(true)
                    MainActivity.applyEMIHardLockStatic(this, true)
                    showNotification("Device Locked", "Administrator has locked this device due to EMI overdue.")
                }
                "UNLOCK" -> {
                    updateLockStatus(false)
                    MainActivity.applyEMIHardLockStatic(this, false)
                    showNotification("Device Unlocked", "Administrator has unlocked your device.")
                }
            }
        }
    }

    private fun updateLockStatus(isLocked: Boolean) {
        // ফ্লাটারের SharedPreferences এ স্ট্যাটাস সেভ করা
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("flutter.device_locked", isLocked).apply()
    }

    private fun showNotification(title: String, body: String) {
        val channelId = "device_lock_channel"
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Device Status", NotificationManager.IMPORTANCE_HIGH)
            notificationManager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(100, notification)
    }
}
