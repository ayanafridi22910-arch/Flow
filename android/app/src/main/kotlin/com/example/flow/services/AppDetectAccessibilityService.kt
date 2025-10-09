package com.example.flow.services

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.util.Log
import android.content.Context
import android.content.pm.PackageManager
import com.example.flow.BlockManager

// This AccessibilityService detects which app is currently in the foreground.
class AppDetectAccessibilityService : AccessibilityService() {

    private var currentForegroundPackage: String? = null

    // A list of common system UI packages that should not dismiss the overlay.
    // This is a heuristic and might need updates for specific device manufacturers.
    private val systemUiPackages = setOf(
        "com.android.systemui", // Notification shade, status bar, navigation bar
        "com.google.android.apps.nexuslauncher", // Pixel Launcher
        "com.android.launcher3", // Generic Android Launcher
        "com.sec.android.app.launcher", // Samsung Launcher
        "com.huawei.android.launcher", // Huawei Launcher
        "com.miui.home", // Xiaomi Launcher
        "com.oneplus.launcher", // OnePlus Launcher
        "com.oppo.launcher", // Oppo Launcher
        "com.vivo.launcher", // Vivo Launcher
        "com.google.android.apps.wellbeing", // Digital Wellbeing
        "com.google.android.packageinstaller", // Package installer
        "com.android.settings", // Settings app
        "android" // The Android system itself (for some dialogs)
    )

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val packageName = event?.packageName?.toString()

        // Filter out events from our own package to reduce log spam and unnecessary processing.
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
    }

    private fun handleAppChange(packageName: String) {
        Log.d("AccessibilityService", "handleAppChange: $packageName")

        // Ignore our own app's package name, as it's the overlay itself.
        // This check is now redundant due to the filter in onAccessibilityEvent, but kept for safety.
        if (packageName == getPackageName()) {
            Log.d("AccessibilityService", "Ignoring our own package: $packageName")
            return
        }

        val isAppBlocked = BlockManager.isAppBlocked(packageName)

        if (isAppBlocked) {
            // If the new app is blocked, immediately launch the home screen
            // to send the blocked app to the background.
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(homeIntent)
            Log.d("AccessibilityService", "Blocked app ($packageName) detected. Launching home screen.")

            // Send command to OverlayService to show the overlay.
            val showOverlayIntent = Intent(this, OverlayService::class.java).apply {
                action = OverlayService.ACTION_SHOW_OVERLAY
            }
            startService(showOverlayIntent)
            Log.d("AccessibilityService", "Sending SHOW_OVERLAY command.")
        } else {
            // If the new app is NOT blocked:
            // We need to decide if it's a genuine switch to a non-blocked app
            // or a temporary system UI element (like notification shade, recent apps, etc.).

            if (!systemUiPackages.contains(packageName)) {
                // It's a non-blocked, non-system app. Send command to OverlayService to hide the overlay.
                val hideOverlayIntent = Intent(this, OverlayService::class.java).apply {
                    action = OverlayService.ACTION_HIDE_OVERLAY
                }
                startService(hideOverlayIntent)
                Log.d("AccessibilityService", "Sending HIDE_OVERLAY command for $packageName.")
            } else {
                // It's a system UI package. Do nothing, the overlay should remain if active.
                Log.d("AccessibilityService", "System UI ($packageName) detected. Keeping OverlayService active if it was.")
            }
        }
    }

    override fun onInterrupt() {
        Log.d("AccessibilityService", "onInterrupt: Service interrupted.")
        // Send command to OverlayService to hide the overlay if the service is interrupted.
        val hideOverlayIntent = Intent(this, OverlayService::class.java).apply {
            action = OverlayService.ACTION_HIDE_OVERLAY
        }
        startService(hideOverlayIntent)
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d("AccessibilityService", "Service Connected.")
        BlockManager.initialize(this)

        // Start OverlayService once and keep it running.
        // val startOverlayServiceIntent = Intent(this, OverlayService::class.java)
        // startService(startOverlayServiceIntent)
        // Log.d("AccessibilityService", "OverlayService started persistently.")
    }

    override fun onDestroy() {
        Log.d("AccessibilityService", "Service Destroyed.")
        // Stop the persistently running OverlayService when AccessibilityService is destroyed.
        val stopOverlayServiceIntent = Intent(this, OverlayService::class.java)
        stopService(stopOverlayServiceIntent)
        super.onDestroy()
    }
}