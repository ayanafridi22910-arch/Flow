package com.example.flow.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Notification
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.example.flow.BlockActivity
import com.example.flow.MainActivity

class MyAccessibilityService : AccessibilityService() {

    companion object {
        private var instance: MyAccessibilityService? = null

        private val blockedApps = mutableSetOf<String>()
        private var isServiceEnabled = false
        private var isBlocking = false

        fun updateBlockedApps(apps: List<String>) {
            blockedApps.clear()
            blockedApps.addAll(apps)
            isBlocking = apps.isNotEmpty()
            Log.d("MyAccessibilityService", "Updated blocked apps: $blockedApps, isBlocking: $isBlocking")
            instance?.updateServiceInfo(apps)
        }

        fun isEnabled(): Boolean {
            return isServiceEnabled
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    fun updateServiceInfo(apps: List<String>) {
        val info = serviceInfo
        info.packageNames = if (apps.isEmpty()) null else apps.toTypedArray()
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        Log.d("MyAccessibilityService", "onAccessibilityEvent: ${event?.eventType}, pkg: ${event?.packageName}")
        if (!isBlocking) {
            // Log.d("MyAccessibilityService", "Not blocking.")
            return
        }

        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName = event.packageName?.toString()
            Log.d("MyAccessibilityService", "Window state changed for pkg: $packageName")

            if (packageName != null && blockedApps.contains(packageName)) {
                Log.d("MyAccessibilityService", "Blocking app: $packageName")
                // Prevent blocking the launcher and the app itself
                if (isAppLauncher(packageName) || packageName == "com.example.flow") {
                    Log.d("MyAccessibilityService", "Not blocking launcher or self.")
                    return
                }

                performGlobalAction(GLOBAL_ACTION_BACK)

                val intent = Intent(this, BlockActivity::class.java)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                intent.putExtra("blocked_app_package", packageName)
                startActivity(intent)
                Log.d("MyAccessibilityService", "Started BlockActivity for $packageName")
            }
        }
    }

    private fun isAppLauncher(packageName: String): Boolean {
        val intent = Intent(Intent.ACTION_MAIN)
        intent.addCategory(Intent.CATEGORY_HOME)
        val resolveInfo = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            packageManager.resolveActivity(intent, PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong()))
        } else {
            @Suppress("DEPRECATION")
            packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        }
        return resolveInfo?.activityInfo?.packageName == packageName
    }

    override fun onInterrupt() {
        Log.d("MyAccessibilityService", "Service interrupted")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isServiceEnabled = true
        Log.d("MyAccessibilityService", "Service connected")

        val notification = Notification.Builder(this, "channel_id")
            .setContentTitle("Flow App Blocker")
            .setContentText("Accessibility service is running.")
            .setSmallIcon(com.example.flow.R.mipmap.ic_launcher)
            .build()

        startForeground(1, notification)
    }

    override fun onUnbind(intent: Intent?): Boolean {
        isServiceEnabled = false
        Log.d("MyAccessibilityService", "Service disconnected")
        return super.onUnbind(intent)
    }
}