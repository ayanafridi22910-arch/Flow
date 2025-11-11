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
import android.view.accessibility.AccessibilityNodeInfo
import com.example.flow.BlockManager
import com.example.flow.MainActivity
import com.example.flow.R
import java.util.LinkedList
import java.util.Queue

class MyAccessibilityService : AccessibilityService() {

    private var lastBlockTime: Long = 0

    companion object {
        private const val TAG = "FlowService"
        private var instance: MyAccessibilityService? = null
        private val blockedApps = mutableSetOf<String>()
        private var isServiceEnabled = false
        private var isBlocking = false

        fun updateBlockedApps(apps: List<String>) {
            blockedApps.clear()
            blockedApps.addAll(apps)
            isBlocking = apps.isNotEmpty()
            Log.d(TAG, "Updated blocked apps: $blockedApps, isBlocking: $isBlocking")
            instance?.updateServiceInfo(apps)
        }

        fun isEnabled(): Boolean = isServiceEnabled
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
        val info = serviceInfo ?: return
        info.packageNames = if (apps.isEmpty()) null else apps.toTypedArray()
        serviceInfo = info
        Log.d(TAG, "Service info updated with packages: ${apps.joinToString()}")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val packageName = event.packageName?.toString()

        if (packageName == "com.instagram.android") {
            if (BlockManager.isInstagramReelsBlocked()) {
                
                // --- YEH HAI ASLI FIX ---
                // Maine 'eventType' ko 'event.eventType' se badal diya hai
                if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED || event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                    Handler(Looper.getMainLooper()).postDelayed({
                        val rootNode = rootInActiveWindow ?: return@postDelayed
                        
                        if (isReelsPageActive(rootNode)) {
                            triggerReelsBlock()
                        } else {
                            hideOverlay()
                        }
                        rootNode.recycle()
                    }, 150)
                    return
                }
            }
        }

        if (isBlocking && packageName != null) {
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED || event.eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED) {
                if (blockedApps.contains(packageName) && !isAppLauncher(packageName) && packageName != "com.example.flow") {
                    handleAppBlock(packageName)
                }
            }
        }
    }

    private fun isReelsPageActive(rootNode: AccessibilityNodeInfo): Boolean {
        Log.d(TAG, "=== Starting Screen Node Search ===")
        val queue: Queue<AccessibilityNodeInfo> = LinkedList()
        queue.add(rootNode)
        var foundSelectedReels = false

        while (queue.isNotEmpty()) {
            val node = queue.poll() ?: continue
            if (node.windowId == -1) continue

            val viewId = node.viewIdResourceName ?: "null"
            val contentDesc = node.contentDescription?.toString() ?: "null"
            val text = node.text?.toString() ?: "null"
            val isSelected = node.isSelected

            if (contentDesc.contains("Reels", ignoreCase = true) || viewId.contains("reels", ignoreCase = true)) {
                Log.d(TAG, 
                    "Found Node: ID=[$viewId] | Desc=[$contentDesc] | Text=[$text] | Selected=[$isSelected]"
                )
            }

            val isReelsIdentifier = (viewId == "com.instagram.android:id/reels_tab" || 
                                     contentDesc.equals("Reels", ignoreCase = true) ||
                                     contentDesc.contains("Reels, Selected", ignoreCase = true) ||
                                     contentDesc.contains("Reels, tab", ignoreCase = true)
                                    )
            
            if (isSelected && isReelsIdentifier) {
                Log.d(TAG, "!!! REELS TAB DETECTED AS ACTIVE (Selected) !!!")
                foundSelectedReels = true
                break
            }

            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { queue.add(it) }
            }
        }
        
        Log.d(TAG, "=== Search Finished. Result: $foundSelectedReels ===")
        return foundSelectedReels
    }

    private fun triggerReelsBlock() {
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastBlockTime < 1000) return
        lastBlockTime = currentTime
        Log.d(TAG, "Instagram Reels detected. Blocking.")
        val intent = Intent(this, OverlayService::class.java).apply { action = OverlayService.ACTION_SHOW_OVERLAY }
        startService(intent)
    }

    private fun handleAppBlock(packageName: String) {
        if (blockedApps.contains(packageName) && !isAppLauncher(packageName) && packageName != "com.example.flow") {
            performGlobalAction(GLOBAL_ACTION_HOME)
            val intent = Intent(this, OverlayService::class.java).apply { action = OverlayService.ACTION_SHOW_OVERLAY }
            startService(intent)
        }
    }

    private fun isAppLauncher(packageName: String): Boolean {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val resolveInfo = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            packageManager.resolveActivity(intent, PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong()))
        } else {
            @Suppress("DEPRECATION")
            packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        }
        return resolveInfo?.activityInfo?.packageName == packageName
    }

    override fun onInterrupt() {
        Log.d(TAG, "Service interrupted")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isServiceEnabled = true
        
        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        info.packageNames = if (blockedApps.isEmpty()) null else blockedApps.toTypedArray()
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS

        this.serviceInfo = info
        
        Log.d(TAG, "Service connected AND CONFIGURED!")
        startForeground(1, createNotification())
    }

    private fun createNotification(): Notification {
         return Notification.Builder(this, "channel_id")
            .setContentTitle("Flow App Blocker")
            .setContentText("Accessibility service is running.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .build()
    }

    override fun onUnbind(intent: Intent?): Boolean {
        isServiceEnabled = false
        Log.d(TAG, "Service disconnected")
        hideOverlay()
        return super.onUnbind(intent)
    }

    private fun hideOverlay() {
        val intent = Intent(this, OverlayService::class.java).apply { action = OverlayService.ACTION_HIDE_OVERLAY }
        startService(intent)
    }
}