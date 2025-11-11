package com.example.flow.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import com.example.flow.BlockManager

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

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                if (packageName != currentForegroundPackage) {
                    currentForegroundPackage = packageName
                    handleAppChange(packageName)
                }
            }
            AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                if (packageName == "com.instagram.android") {
                    handleInstagramClick(event)
                }
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

    private fun handleInstagramClick(event: AccessibilityEvent) {
        // First, check if Reels blocking is enabled.
        // We'll get this preference from the BlockManager.
        if (!BlockManager.isInstagramReelsBlocked()) {
            return
        }

        var nodeInfo: AccessibilityNodeInfo? = event.source
        while (nodeInfo != null) {
            // The Reels tab can be identified by its content description.
            // We check for "Reels" case-insensitively.
            if (nodeInfo.contentDescription?.toString().equals("Reels", ignoreCase = true)) {
                Log.d("AccessibilityService", "Instagram Reels tab clicked. Blocking.")

                // Show the overlay immediately.
                val showOverlayIntent = Intent(this, OverlayService::class.java).apply {
                    action = OverlayService.ACTION_SHOW_OVERLAY
                }
                startService(showOverlayIntent)

                // Perform the global action to go to the Home Screen, effectively
                // closing the app from the user's perspective.
                performGlobalAction(GLOBAL_ACTION_HOME)

                break // Exit the loop once the Reels tab is found and handled.
            }
            nodeInfo = nodeInfo.parent
        }
    }


    override fun onInterrupt() {
        Log.d("AccessibilityService", "onInterrupt: Service interrupted.")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d("AccessibilityService", "Service Connected.")
        BlockManager.initialize(this)

        // We need to configure the service to listen for the events we care about.
        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or AccessibilityEvent.TYPE_VIEW_CLICKED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            // We need FLAG_REPORT_VIEW_IDS to get the resource names of views.
            // FLAG_INCLUDE_NOT_IMPORTANT_VIEWS is also helpful for broader detection.
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
        }
    }

    override fun onDestroy() {
        Log.d("AccessibilityService", "Service Destroyed.")
        val stopOverlayServiceIntent = Intent(this, OverlayService::class.java)
        stopService(stopOverlayServiceIntent)
        super.onDestroy()
    }
}
