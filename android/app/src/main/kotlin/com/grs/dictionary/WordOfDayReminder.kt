package com.grs.dictionary

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * One quiet notification a day, at the minute the user chose. An
 * AlarmManager alarm (inexact: within a few minutes is fine for a word) fires
 * [ReminderReceiver], which reads today's entry from the 30-day schedule
 * Flutter keeps in shared preferences for the launcher widget, posts it, and
 * arms tomorrow's alarm. Nothing here opens a database or the Flutter engine.
 * Settings are read from the same preferences the app writes (`wotd.*`).
 */
object WordOfDayReminder {
    const val CHANNEL = "word_of_day"
    const val ACTION_FIRE = "com.grs.dictionary.WORD_OF_DAY"
    private const val REQUEST = 4101
    private const val NOTIFICATION_ID = 41

    private fun prefs(context: Context) =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    /** Arms the next alarm from the saved setting, or clears it. */
    fun sync(context: Context) {
        val p = prefs(context)
        if (!p.getBoolean("flutter.wotd.enabled", false)) return cancel(context)
        schedule(context, p.getLong("flutter.wotd.minutes", 8 * 60 + 30L).toInt())
    }

    fun schedule(context: Context, minutes: Int) {
        val at = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, minutes / 60)
            set(Calendar.MINUTE, minutes % 60)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // A ten-minute window: inexact enough to need no SCHEDULE_EXACT_ALARM
        // permission, tight enough that "morning" means morning.
        alarms.setWindow(AlarmManager.RTC_WAKEUP, at.timeInMillis, 10 * 60 * 1000L, pending(context))
    }

    fun cancel(context: Context) {
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pending(context))
    }

    private fun pending(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        REQUEST,
        Intent(context, ReminderReceiver::class.java).setAction(ACTION_FIRE),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun canPost(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    /** Today's word from the widget schedule, or a nudge to open the app. */
    fun post(context: Context) {
        if (!canPost(context)) return
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.UK).format(Date())
        val entry = try {
            val array = JSONArray(prefs(context).getString("flutter.widget.schedule", null) ?: "[]")
            (0 until array.length()).map { array.getJSONObject(it) }.firstOrNull { it.optString("date") == today }
        } catch (_: Exception) {
            null
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL, "Word of the day", NotificationManager.IMPORTANCE_LOW).apply {
                description = "One word a day, at the time you chose. Nothing else."
            },
        )
        val open = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra("word_key", entry?.optString("key"))
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val tap = PendingIntent.getActivity(
            context, NOTIFICATION_ID, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val title = entry?.optString("word") ?: "Your word of the day"
        val body = entry?.let { "${it.optString("pos")} · ${it.optString("detail")}" }
            ?: "Open Mull to see it."
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(tap)
            .setAutoCancel(true)
            .setSilent(true)
            .build()
        manager.notify(NOTIFICATION_ID, notification)
    }
}

/** The alarm, and the reboot that would otherwise have cleared it. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            WordOfDayReminder.ACTION_FIRE -> {
                WordOfDayReminder.post(context)
                WordOfDayReminder.sync(context)
            }
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> WordOfDayReminder.sync(context)
        }
    }
}
