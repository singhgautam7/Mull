package com.grs.dictionary

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * The colours the app's theme resolved, for the launcher widgets.
 *
 * A RemoteViews widget draws from values baked in at its last update, so the
 * app writes its current palette (light and dark, and which of the two, or
 * the system's choice, applies) to shared preferences under `widget.theme`
 * whenever the theme changes, then asks for a redraw. On Android 12 and later
 * both tones are handed to the launcher and it picks at inflate time, so a
 * system dark-mode switch is right without the app; earlier launchers get
 * the tone that applied when the app last ran. Nothing here opens a
 * database or the Flutter engine.
 */
class WidgetTheme private constructor(
    private val mode: String,
    private val light: JSONObject,
    private val dark: JSONObject,
) {
    /** A role's colour for the tone in force right now. */
    fun color(context: Context, role: String): Int = tone(context).getLong(role).toInt()

    private fun tone(context: Context): JSONObject = when (mode) {
        "light" -> light
        "dark" -> dark
        else -> if (isNight(context)) dark else light
    }

    /** Whether the launcher, not the app, should pick the tone per inflate. */
    private val followsSystem get() = mode != "light" && mode != "dark"

    /**
     * Applies [role] to a view through [method] (`setColorFilter` for an
     * ImageView, `setTextColor` for a TextView): with both tones on API 31+
     * when the theme follows the system, otherwise the resolved one.
     */
    fun apply(context: Context, views: RemoteViews, viewId: Int, method: String, role: String) {
        if (followsSystem && Build.VERSION.SDK_INT >= 31) {
            views.setColorInt(viewId, method, light.getLong(role).toInt(), dark.getLong(role).toInt())
        } else {
            views.setInt(viewId, method, color(context, role))
        }
    }

    companion object {
        const val PREF = "flutter.widget.theme"

        fun isNight(context: Context): Boolean =
            context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES

        /** The saved theme, or null before the app has run once. */
        fun load(context: Context): WidgetTheme? {
            val json = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString(PREF, null) ?: return null
            return try {
                val o = JSONObject(json)
                WidgetTheme(o.optString("mode", "system"), o.getJSONObject("light"), o.getJSONObject("dark"))
            } catch (_: Exception) {
                null
            }
        }

        /** Redraws every Mull widget on the launcher. */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            for (provider in listOf(WordOfDayWidget::class.java, SearchWidget::class.java)) {
                val ids = manager.getAppWidgetIds(ComponentName(context, provider))
                if (ids.isEmpty()) continue
                when (provider) {
                    WordOfDayWidget::class.java -> WordOfDayWidget().onUpdate(context, manager, ids)
                    SearchWidget::class.java -> SearchWidget().onUpdate(context, manager, ids)
                }
            }
        }
    }
}
