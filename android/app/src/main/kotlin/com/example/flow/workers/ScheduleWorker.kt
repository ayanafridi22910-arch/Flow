package com.example.flow.workers

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.flow.services.MyAccessibilityService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

class ScheduleWorker(appContext: Context, workerParams: WorkerParameters) :
    CoroutineWorker(appContext, workerParams) {

    companion object {
        const val TAG = "ScheduleWorker"
        const val KEY_APPS_TO_BLOCK = "appsToBlock"
        const val KEY_SCHEDULE_ACTION = "scheduleAction"
        const val ACTION_START_BLOCKING = "startBlocking"
        const val ACTION_STOP_BLOCKING = "stopBlocking"
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val appsToBlock = inputData.getStringArray(KEY_APPS_TO_BLOCK)?.toList() ?: emptyList()
        val action = inputData.getString(KEY_SCHEDULE_ACTION)

        Log.d(TAG, "doWork: action=$action, appsToBlock=$appsToBlock")

        when (action) {
            ACTION_START_BLOCKING -> {
                MyAccessibilityService.updateBlockedApps(appsToBlock)
                Log.d(TAG, "Blocking started for apps: $appsToBlock")
            }
            ACTION_STOP_BLOCKING -> {
                MyAccessibilityService.updateBlockedApps(emptyList()) // Clear blocked apps
                Log.d(TAG, "Blocking stopped.")
            }
        }
        Result.success()
    }
}