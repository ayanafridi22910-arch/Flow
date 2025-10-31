package com.example.flow

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ComponentName
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityManager
import androidx.annotation.NonNull // Yeh import add karein
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import com.example.flow.services.MyAccessibilityService

class MainActivity: FlutterActivity() {

    companion object {
        private const val CHANNEL = "app.blocker/channel"
        private var channel: MethodChannel? = null

        // Yeh function MyAccessibilityService se call hoga (agar URL tracking use kar rahe ho)
        fun sendUrlToFlutter(url: String) {
            Handler(Looper.getMainLooper()).post {
                channel?.invokeMethod("onUrlVisited", url)
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("channel_id", "Flow Blocker", NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        // BlockManager.initialize(this) // Is line ki zaroorat nahi hai

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        channel?.setMethodCallHandler {
            call, result ->
            when (call.method) {
                "checkAccessibilityServiceEnabled" -> {
                    val isEnabled = isAccessibilityServiceEnabled(this)
                    result.success(isEnabled)
                }

                "isOverlayPermissionGranted" -> {
                    result.success(Settings.canDrawOverlays(this))
                }

                "requestOverlayPermission" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName"))
                        startActivity(intent)
                    }
                    result.success(null)
                }
                
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(null)
                }

                "setBlockedApps" -> {
                    val apps = call.argument<List<String>>("apps")
                    if (apps != null) {
                        // Yahan MyAccessibilityService ko call karna hai
                        MyAccessibilityService.updateBlockedApps(apps)
                        Log.d("MainActivity", "Updated MyAccessibilityService with apps: $apps")
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "App list cannot be null.", null)
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isAccessibilityServiceEnabled(context: Context): Boolean {
        val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        
        // Yahan MyAccessibilityService ko check karna hai
        val expectedComponentName = ComponentName(context, com.example.flow.services.MyAccessibilityService::class.java)

        for (serviceInfo in enabledServices) {
            val componentName = ComponentName(
                serviceInfo.resolveInfo.serviceInfo.packageName,
                serviceInfo.resolveInfo.serviceInfo.name
            )
            if (componentName == expectedComponentName) {
                Log.d("AccessibilityCheck", "SUCCESS (Manager): Service is enabled and matches component name.")
                return true
            }
        }
        Log.d("AccessibilityCheck", "FAILURE (Manager): Service is NOT enabled. Looking for ${expectedComponentName.flattenToString()}")
        return false
    }
}