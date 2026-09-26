package com.example.devicelocunlock

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

// সরাসরি android.app.admin.DeviceAdminReceiver ইনহেরিট করা হয়েছে
class DeviceAdminReceiver : android.app.admin.DeviceAdminReceiver() {

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d(TAG, "✅ Device Admin enabled successfully")
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d(TAG, "❌ Device Admin disabled")
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence? {
        return "This device is managed by EMI Lock Protection. Disabling this will restrict phone usage."
    }

    companion object {
        private const val TAG = "DeviceAdminReceiver"
    }
}
