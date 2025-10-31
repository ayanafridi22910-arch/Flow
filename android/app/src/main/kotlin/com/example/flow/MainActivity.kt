package com.example.flow

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle 
import android.os.Handler 
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ComponentName

class MainActivity: FlutterActivity() {

    // YEH PURA HISSA SAME HAI
    companion object {
        private const val CHANNEL = "app.blocker/channel"
        private var channel: MethodChannel? = null

        fun sendUrlToFlutter(url: String) {
            Handler(Looper.getMainLooper()).post {
                channel?.invokeMethod("onUrlVisited", url)
            }
        }
    }

    // YEH PURA HISSA BHI SAME HAI
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        channel?.setMethodCallHandler {
            call, result ->
            when (call.method) {
                "checkAccessibilityServiceEnabled" -> {
                    // Hum yahan se updated function ko call karenge
                    val isEnabled = isAccessibilityServiceEnabled(this)
                    Log.d("AccessibilityCheck", "Service enabled check returned: $isEnabled")
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

    // #################### SIRF IS FUNCTION ME BADLAV KIYA GAYA HAI ####################
    private fun isAccessibilityServiceEnabled(context: Context): Boolean {
        try {
            val settingValue = Settings.Secure.getString(
                context.applicationContext.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
            if (settingValue != null) {
                Log.d("AccessibilityCheck", "System's enabled services list: '$settingValue'")
                // A less strict check. This might be prone to false positives if another
                // service has a similar name, but it's more robust against package name issues.
                if (settingValue.contains(com.example.flow.services.AppDetectAccessibilityService::class.java.simpleName, ignoreCase = true)) {
                    Log.d("AccessibilityCheck", "MATCH FOUND with simple name! Returning true.")
                    return true
                }
            }
        } catch (e: Settings.SettingNotFoundException) {
            Log.e("AccessibilityCheck", "Setting not found", e)
        }
        
        Log.d("AccessibilityCheck", "No match found or accessibility is disabled. Returning false.")
        return false
    }
    // #################################################################################
}