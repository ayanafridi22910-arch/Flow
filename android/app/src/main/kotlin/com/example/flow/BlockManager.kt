package com.example.flow

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

// Manages the list of blocked apps using SharedPreferences.
// This object is a singleton, ensuring a single source of truth for the blocked apps list.
object BlockManager {

    private const val PREFS_NAME = "AppBlockerPrefs"
    private const val BLOCKED_APPS_KEY = "blockedApps"

    private lateinit var sharedPreferences: SharedPreferences

    // Initializes the BlockManager with the application context.
    // Must be called once, typically in MainActivity or Application class.
    fun initialize(context: Context) {
        sharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    // Updates the set of blocked app package names.
    fun setBlockedApps(packageNames: Set<String>) {
        sharedPreferences.edit().putStringSet(BLOCKED_APPS_KEY, packageNames).apply()
    }

    // Retrieves the set of blocked app package names.
    fun getBlockedApps(): Set<String> {
        return sharedPreferences.getStringSet(BLOCKED_APPS_KEY, emptySet()) ?: emptySet()
    }

    // Checks if a specific app is marked as blocked.
    fun isAppBlocked(packageName: String): Boolean {
        val isBlocked = getBlockedApps().contains(packageName)
        Log.d("BlockManager", "isAppBlocked: $packageName -> $isBlocked")
        return isBlocked
    }
}
