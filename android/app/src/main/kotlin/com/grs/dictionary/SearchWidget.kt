package com.grs.dictionary

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews

/**
 * The search widget: one row, three taps. A search-shaped box that opens the
 * Search tab with the keyboard up, and two round buttons for the Mull and
 * Shelves tabs. Pure navigation: no data, no database, no configuration. Its
 * colours are the app's theme, pushed by the app (see [WidgetTheme]); before
 * the app has run once it draws in Mull's default resources.
 */
class SearchWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, build(context))
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, newOptions: Bundle) {
        manager.updateAppWidget(id, build(context))
    }

    private fun build(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.search_widget)
        // Three targets, three request codes and three actions: a PendingIntent
        // is matched on its intent without extras, so identical ones collapse.
        views.setOnClickPendingIntent(R.id.widget_search_box, open(context, 1, "/search?focus=1"))
        views.setOnClickPendingIntent(R.id.widget_mull_button, open(context, 2, "/mull"))
        views.setOnClickPendingIntent(R.id.widget_shelves_button, open(context, 3, "/collections"))

        val theme = WidgetTheme.load(context) ?: return views
        theme.apply(context, views, R.id.widget_search_box_fill, "setColorFilter", "panel")
        theme.apply(context, views, R.id.widget_search_icon, "setColorFilter", "muted")
        theme.apply(context, views, R.id.widget_search_hint, "setTextColor", "muted")
        for (id in intArrayOf(R.id.widget_mull_fill, R.id.widget_shelves_fill)) {
            theme.apply(context, views, id, "setColorFilter", "primary")
        }
        for (id in intArrayOf(R.id.widget_mull_icon, R.id.widget_shelves_icon)) {
            theme.apply(context, views, id, "setColorFilter", "onPrimary")
        }
        return views
    }

    private fun open(context: Context, code: Int, route: String): PendingIntent = PendingIntent.getActivity(
        context,
        code,
        Intent(context, MainActivity::class.java).apply {
            action = "com.grs.dictionary.OPEN_$code"
            putExtra("route", route)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
