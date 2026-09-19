package com.grs.dictionary

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Word of the day on the launcher. This runs in the launcher's process, so it
 * reads only the 30-day schedule Flutter wrote to shared preferences and never
 * opens a database. The schedule is keyed by date, so the word rolls over on
 * the daily update without the app having been opened, and the system's
 * post-boot APPWIDGET_UPDATE redraws it after a restart.
 */
class WordOfDayWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) draw(context, manager, id, manager.getAppWidgetOptions(id))
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, newOptions: Bundle) {
        draw(context, manager, id, newOptions)
    }

    private fun draw(context: Context, manager: AppWidgetManager, id: Int, options: Bundle?) {
        val schedule = schedule(context)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.UK).format(Date())
        val index = schedule.indexOfFirst { it.optString("date") == today }
        val word = if (index >= 0) schedule[index] else null

        val width = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 160
        val height = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 160
        val views = when {
            width >= 280 && height >= 240 -> large(context, schedule, index)
            width >= 240 -> medium(context, word, today)
            else -> small(context, word)
        }

        val open = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra("word_key", word?.optString("key"))
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        views.setOnClickPendingIntent(
            R.id.widget_root,
            PendingIntent.getActivity(context, id, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        )
        manager.updateAppWidget(id, views)
    }

    private fun small(context: Context, word: JSONObject?) =
        RemoteViews(context.packageName, R.layout.word_of_day_widget_small).apply {
            setTextViewText(R.id.widget_word, word?.optString("word") ?: "Mull")
            setTextViewText(R.id.widget_pos, word?.optString("pos") ?: PRE_FETCH)
        }

    private fun medium(context: Context, word: JSONObject?, today: String) =
        RemoteViews(context.packageName, R.layout.word_of_day_widget_medium).apply {
            setTextViewText(R.id.widget_label, if (word == null) "MULL" else "MULL · $today")
            setTextViewText(R.id.widget_word, word?.optString("word") ?: "Mull")
            val ipa = word?.optString("ipa") ?: ""
            val pos = word?.optString("pos") ?: ""
            setTextViewText(R.id.widget_ipa_pos, if (ipa.isEmpty()) pos else "$ipa · $pos")
            setTextViewText(R.id.widget_detail, word?.optString("detail") ?: PRE_FETCH)
        }

    private fun large(context: Context, schedule: List<JSONObject>, index: Int) =
        RemoteViews(context.packageName, R.layout.word_of_day_widget_large).apply {
            val slots = listOf(
                R.id.widget_word1 to R.id.widget_detail1,
                R.id.widget_word2 to R.id.widget_detail2,
                R.id.widget_word3 to R.id.widget_detail3,
            )
            slots.forEachIndexed { offset, (wordId, detailId) ->
                val entry = if (index >= 0) schedule.getOrNull(index + offset) else null
                setTextViewText(wordId, entry?.optString("word") ?: if (offset == 0) "Mull" else "")
                setTextViewText(detailId, entry?.let { "${it.optString("pos")} · ${it.optString("detail")}" }
                    ?: if (offset == 0) PRE_FETCH else "")
            }
        }

    private fun schedule(context: Context): List<JSONObject> {
        val json = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.widget.schedule", null) ?: return emptyList()
        return try {
            val array = JSONArray(json)
            List(array.length()) { array.getJSONObject(it) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private companion object {
        const val PRE_FETCH = "the first word arrives when you open Mull"
    }
}
