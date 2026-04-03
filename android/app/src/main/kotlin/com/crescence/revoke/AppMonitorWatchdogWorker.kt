package com.crescence.revoke

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

class AppMonitorWatchdogWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {
    override fun doWork(): Result {
        return try {
            AppMonitorCoordinator.enqueueWatchdog(applicationContext)
            AppMonitorCoordinator.checkAndReviveService(
                context = applicationContext,
                trigger = "workmanager_watchdog",
            )
            Result.success()
        } catch (error: Exception) {
            AppMonitorCoordinator.recordNonFatal(
                context = applicationContext,
                source = "AppMonitorWatchdogWorker",
                message = "Unexpected watchdog worker failure.",
                error = error,
            )
            Result.retry()
        }
    }
}
