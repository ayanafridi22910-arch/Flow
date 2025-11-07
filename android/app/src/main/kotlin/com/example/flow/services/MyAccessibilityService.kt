package com.example.flow.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Notification
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.example.flow.R

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
        if (!isBlocking || event == null) {
            return
        }

        val packageName = when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> event.packageName?.toString()
            AccessibilityEvent.TYPE_WINDOWS_CHANGED -> {
                // For some apps, the package name is not directly available in the event
                // but can be retrieved from the source node.
                event.source?.packageName?.toString()
            }
            else -> null
        }

        if (packageName != null) {
            handleAppBlock(packageName)
        }
    }

    private fun handleAppBlock(packageName: String) {
        if (blockedApps.contains(packageName)) {
            if (isAppLauncher(packageName) || packageName == "com.example.flow") {
                return
            }

            performGlobalAction(GLOBAL_ACTION_HOME)

            val intent = Intent(this, OverlayService::class.java).apply {
                action = OverlayService.ACTION_SHOW_OVERLAY
            }
            startService(intent)
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
            .setSmallIcon(R.mipmap.ic_launcher)
            .build()

        startForeground(1, notification)
    }

    override fun onUnbind(intent: Intent?): Boolean {
        isServiceEnabled = false
        Log.d("MyAccessibilityService", "Service disconnected")
        hideOverlay()
        return super.onUnbind(intent)
    }

    private fun hideOverlay() {
        val intent = Intent(this, OverlayService::class.java).apply {
            action = OverlayService.ACTION_HIDE_OVERLAY
        }
        startService(intent)
    }
}
