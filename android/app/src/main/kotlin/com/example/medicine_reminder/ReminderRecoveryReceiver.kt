package com.example.medicine_reminder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.BackoffPolicy
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import dev.fluttercommunity.workmanager.BackgroundWorker
import dev.fluttercommunity.workmanager.SharedPreferenceHelper
import java.util.concurrent.TimeUnit
import android.util.Log

/** Rebuild from encrypted plans instead of replaying a stale cached alarm list. */
class ReminderRecoveryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in actions) return
        val pending = goAsync()
        val appContext = context.applicationContext
        Thread {
            try { enqueue(appContext, intent.action ?: "system", awaitPersist = true) }
            catch (error: Exception) { Log.w("MedicineRecovery", "Recovery will retry on app open", error) }
            finally { pending.finish() }
        }.start()
    }

    companion object {
        const val WORK_NAME = "medicine-system-recovery"
        const val PREFS = "medicine_recovery"
        val actions = setOf(
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED,
            "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED"
        )

        @Synchronized
        fun enqueue(context: Context, reason: String, awaitPersist: Boolean = false): Boolean {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            prefs.edit().putLong("generation", prefs.getLong("generation", 0) + 1)
                .putString("reason", reason).apply()
            // Uses the public worker/constants of the lockfile's workmanager_android.
            // The callback is installed by initializeReminderBackground on first open.
            if (SharedPreferenceHelper.getCallbackHandle(context) == -1L) return false
            val request = OneTimeWorkRequest.Builder(BackgroundWorker::class.java)
                .setInputData(Data.Builder()
                    .putString(BackgroundWorker.DART_TASK_KEY, WORK_NAME)
                    .putString("reason", reason).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .addTag(WORK_NAME).build()
            val operation = WorkManager.getInstance(context).enqueueUniqueWork(WORK_NAME, ExistingWorkPolicy.KEEP, request)
            if (awaitPersist) operation.result.get(8, TimeUnit.SECONDS)
            return true
        }
    }
}
