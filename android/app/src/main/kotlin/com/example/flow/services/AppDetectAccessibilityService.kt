package com.example.flow.services

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.util.Log
import com.example.flow.BlockManager
import com.example.flow.MainActivity
import android.view.accessibility.AccessibilityNodeInfo

class AppDetectAccessibilityService : AccessibilityService() {

    private var currentForegroundPackage: String? = null

    private val systemUiPackages = setOf(
        "com.android.systemui",
        "com.google.android.apps.nexuslauncher",
        "com.android.launcher3",
        "com.sec.android.app.launcher",
        "com.huawei.android.launcher",
        "com.miui.home",
        "com.oneplus.launcher",
        "com.oppo.launcher",
        "com.vivo.launcher",
        "com.google.android.apps.wellbeing",
        "com.google.android.packageinstaller",
        "com.android.settings",
        "android"
    )

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val packageName = event?.packageName?.toString()

        if (packageName == null || packageName == getPackageName()) {
            return
        }

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            if (packageName != currentForegroundPackage) {
                currentForegroundPackage = packageName
                handleAppChange(packageName)
            }
        }
    }

    private fun handleAppChange(packageName: String) {
        Log.d("AccessibilityService", "handleAppChange: $packageName")

        val isAppBlocked = BlockManager.isAppBlocked(packageName)

        if (isAppBlocked) {
            Log.d("AccessibilityService", "Blocked app ($packageName) detected. Showing overlay.")
            val showOverlayIntent = Intent(this, OverlayService::class.java).apply {
                action = OverlayService.ACTION_SHOW_OVERLAY
            }
            startService(showOverlayIntent)
        } else {
            if (!systemUiPackages.contains(packageName)) {
                val hideOverlayIntent = Intent(this, OverlayService::class.java).apply {
                    action = OverlayService.ACTION_HIDE_OVERLAY
                }
                startService(hideOverlayIntent)
                Log.d("AccessibilityService", "Sending HIDE_OVERLAY command for $packageName.")
            }
        }
    }

    override fun onInterrupt() {
        Log.d("AccessibilityService", "onInterrupt: Service interrupted.")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d("AccessibilityService", "Service Connected.")
        BlockManager.initialize(this)
    }

    override fun onDestroy() {
        Log.d("AccessibilityService", "Service Destroyed.")
        val stopOverlayServiceIntent = Intent(this, OverlayService::class.java)
        stopService(stopOverlayServiceIntent)
        super.onDestroy()
    }
}