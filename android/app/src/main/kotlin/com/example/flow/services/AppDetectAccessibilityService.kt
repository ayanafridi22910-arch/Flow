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

        if (packageName == getPackageName()) {
            return
        }

        Log.d("AccessibilityService", "onAccessibilityEvent: ${event?.eventType} - $packageName")

        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            if (packageName != null && packageName != currentForegroundPackage) {
                currentForegroundPackage = packageName
                handleAppChange(packageName)
            }
        }

        // For Chrome, we need to listen for more event types to capture URL changes
        if (packageName == "com.android.chrome" && (
                    event?.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED ||
                    event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
                    )) {
            val source = event.source
            source?.let {
                val url = findUrlInNode(it)
                if (url != null) {
                    Log.d("AccessibilityService", "Chrome URL detected: $url")
                    MainActivity.sendUrlToFlutter(url)
                }
                it.recycle()
            }
        }
    }

    private fun findUrlInNode(node: AccessibilityNodeInfo): String? {
        // Chrome's URL bar has a resource ID "com.android.chrome:id/url_bar"
        val urlBarNodes = node.findAccessibilityNodeInfosByViewId("com.android.chrome:id/url_bar")
        if (urlBarNodes.isNotEmpty()) {
            val urlBar = urlBarNodes[0]
            val url = urlBar.text?.toString()
            urlBar.recycle()
            if (!url.isNullOrEmpty()) {
                return url
            }
        }

        // Fallback: iterate through children if the above fails
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            child?.let {
                val url = findUrlInNode(it)
                if (url != null) {
                    return url
                }
                it.recycle()
            }
        }
        return null
    }

    private fun handleAppChange(packageName: String) {
        Log.d("AccessibilityService", "handleAppChange: $packageName")

        if (packageName == getPackageName()) {
            Log.d("AccessibilityService", "Ignoring our own package: $packageName")
            return
        }

        val isAppBlocked = BlockManager.isAppBlocked(packageName)

        if (isAppBlocked) {
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(homeIntent)
            Log.d("AccessibilityService", "Blocked app ($packageName) detected. Launching home screen.")

            val showOverlayIntent = Intent(this, OverlayService::class.java).apply {
                action = OverlayService.ACTION_SHOW_OVERLAY
            }
            startService(showOverlayIntent)
            Log.d("AccessibilityService", "Sending SHOW_OVERLAY command.")
        } else {
            if (!systemUiPackages.contains(packageName)) {
                val hideOverlayIntent = Intent(this, OverlayService::class.java).apply {
                    action = OverlayService.ACTION_HIDE_OVERLAY
                }
                startService(hideOverlayIntent)
                Log.d("AccessibilityService", "Sending HIDE_OVERLAY command for $packageName.")
            } else {
                Log.d("AccessibilityService", "System UI ($packageName) detected. Keeping OverlayService active if it was.")
            }
        }
    }

    override fun onInterrupt() {
        Log.d("AccessibilityService", "onInterrupt: Service interrupted.")
        val hideOverlayIntent = Intent(this, OverlayService::class.java).apply {
            action = OverlayService.ACTION_HIDE_OVERLAY
        }
        startService(hideOverlayIntent)
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
