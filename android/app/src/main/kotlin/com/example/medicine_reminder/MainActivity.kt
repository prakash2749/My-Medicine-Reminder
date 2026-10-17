package com.example.medicine_reminder

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings
import android.os.Build
import android.net.Uri
import android.os.SystemClock
import androidx.work.WorkManager
import androidx.core.content.ContextCompat

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "medicine_reminder/settings")
            .setMethodCallHandler { call, result ->
                if (call.method == "openNotificationSettings") {
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    }
                    startActivity(intent)
                    result.success(null)
                } else if (call.method == "getRecoveryContext") {
                    val prefs = getSharedPreferences(ReminderRecoveryReceiver.PREFS, MODE_PRIVATE)
                    result.success(mapOf(
                        "elapsedMillis" to SystemClock.elapsedRealtime(),
                        "bootCount" to if (Build.VERSION.SDK_INT >= 24) Settings.Global.getInt(contentResolver, Settings.Global.BOOT_COUNT, 0) else 0,
                        "generation" to prefs.getLong("generation", 0),
                        "reason" to prefs.getString("reason", "startup")
                    ))
                } else if (call.method == "enqueueReminderRecovery") {
                    result.success(ReminderRecoveryReceiver.enqueue(this, "app-retry"))
                } else if (call.method == "getRecoveryWorkState") {
                    val work = WorkManager.getInstance(this).getWorkInfosForUniqueWork(ReminderRecoveryReceiver.WORK_NAME)
                    work.addListener({
                        try { result.success(work.get().map { it.state.name }) }
                        catch (error: Exception) { result.error("recovery-state", error.message, null) }
                    }, ContextCompat.getMainExecutor(this))
                } else result.notImplemented()
            }
    }
}
