package com.example.flow.services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import com.example.flow.R

// This service is responsible for displaying and hiding the app block overlay.
class OverlayService : Service() {

    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null

    companion object {
        const val ACTION_SHOW_OVERLAY = "com.example.flow.ACTION_SHOW_OVERLAY"
        const val ACTION_HIDE_OVERLAY = "com.example.flow.ACTION_HIDE_OVERLAY"
        private const val NOTIFICATION_CHANNEL_ID = "FlowAppBlockerChannel"
        private const val NOTIFICATION_ID = 101
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null // This is not a bound service.
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())

        // Inflate the overlay view once and add it to the WindowManager.
        // Its visibility will be toggled later.
        val inflater = getSystemService(LAYOUT_INFLATER_SERVICE) as LayoutInflater
        overlayView = inflater.inflate(R.layout.overlay_layout, null)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_FULLSCREEN,
            PixelFormat.OPAQUE
        )

        windowManager.addView(overlayView, params)

        // Find the close button and set its listener
        val closeButton: View = overlayView!!.findViewById(R.id.closeOverlayButton)
        closeButton.setOnClickListener {
            // When the user clicks close, hide the overlay, but keep the service running.
            hideOverlay()
        }

        // Initially hide the overlay
        overlayView?.visibility = View.GONE
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW_OVERLAY -> showOverlay()
            ACTION_HIDE_OVERLAY -> hideOverlay()
        }
        return START_STICKY
    }

    private fun showOverlay() {
        overlayView?.visibility = View.VISIBLE
    }

    private fun hideOverlay() {
        overlayView?.visibility = View.GONE
    }

    override fun onDestroy() {
        super.onDestroy()
        // Remove the view from the window manager when the service is destroyed.
        overlayView?.let {
            windowManager.removeView(it)
            overlayView = null
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Flow App Blocker Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    private fun createNotification() = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
        .setContentTitle("Flow App Blocker")
        .setContentText("Blocking distracting apps.")
        .setSmallIcon(R.mipmap.ic_launcher) // Use your app's launcher icon
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setOngoing(true)
        .build()
}
