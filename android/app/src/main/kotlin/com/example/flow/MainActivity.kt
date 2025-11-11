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
import androidx.annotation.NonNull
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import com.example.flow.services.MyAccessibilityService

class MainActivity: FlutterActivity() {

    companion object {
        private const val CHANNEL = "app.blocker/channel"
        private var channel: MethodChannel? = null

        fun sendUrlToFlutter(url: String) {
            Handler(Looper.getMainLooper()).post {
                channel?.invokeMethod("onUrlVisited", url)
            }
        }

        // Function for the accessibility service to send debug logs to Flutter
        fun sendDebugLogToFlutter(log: String) {
            Handler(Looper.getMainLooper()).post {
                channel?.invokeMethod("onDebugLog", log)
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationChannel = NotificationChannel("channel_id", "Flow Blocker", NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(notificationChannel)
        }

        BlockManager.initialize(this)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        channel?.setMethodCallHandler {
            call, result ->
            when (call.method) {
                "checkAccessibilityServiceEnabled" -> result.success(isAccessibilityServiceEnabled(this))
                "isOverlayPermissionGranted" -> result.success(Settings.canDrawOverlays(this))
                "requestOverlayPermission" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "setBlockedApps" -> {
                    val apps = call.argument<List<String>>("apps")
                    if (apps != null) {
                        MyAccessibilityService.updateBlockedApps(apps)
                        Log.d("MainActivity", "Updated MyAccessibilityService with apps: $apps")
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "App list cannot be null.", null)
                    }
                }
                "isReelsBlocked" -> result.success(BlockManager.isInstagramReelsBlocked())
                "setReelsBlocked" -> {
                    val blocked = call.argument<Boolean>("blocked")
                    if (blocked != null) {
                        BlockManager.setInstagramReelsBlocked(blocked)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Blocked status cannot be null.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(context: Context): Boolean {
        val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        val expectedComponentName = ComponentName(context, MyAccessibilityService::class.java)

        return enabledServices.any {
            val componentName = ComponentName(it.resolveInfo.serviceInfo.packageName, it.resolveInfo.serviceInfo.name)
            componentName == expectedComponentName
        }
    }
}
