package com.grs.dictionary

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.speech.tts.TextToSpeech
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * The two method channels Mull's Dart side talks to, shared by [MainActivity]
 * and [DefineActivity]: pronunciation through the platform TextToSpeech
 * engine, and the platform surface (arrivals, the launcher widget, handing a
 * route to the full app, finishing the host).
 */
class PlatformChannels(private val activity: Activity) {
    private var tts: TextToSpeech? = null
    private var ready = false
    // The utterance asked for while the engine was still starting.
    private var pending: Pair<String, Double>? = null
    private var platform: MethodChannel? = null
    private var permissionResult: MethodChannel.Result? = null

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "com.grs.dictionary/tts")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        speak(call.argument<String>("text") ?: "", call.argument<Double>("rate") ?: 1.0)
                        result.success(ready)
                    }
                    else -> result.notImplemented()
                }
            }
        // Flutter pulls the launch intent once it is ready; a later intent is
        // pushed through [pushArrival]. Either way the extras are taken off
        // the intent, so one arrival is handled once.
        platform = MethodChannel(engine.dartExecutor.binaryMessenger, "com.grs.dictionary/platform")
        platform?.setMethodCallHandler { call, result ->
            when (call.method) {
                // Both launcher widgets, after the schedule or the theme changed.
                "refreshWidget" -> {
                    WidgetTheme.refreshAll(activity)
                    result.success(null)
                }
                "incomingText" -> result.success(takeArrival(activity.intent))
                // The define sheet handing off to the full app: open it on a
                // route, in its own task, and leave the caller's task.
                "openInApp" -> {
                    activity.startActivity(
                        Intent(activity, MainActivity::class.java).apply {
                            action = Intent.ACTION_MAIN
                            putExtra("route", call.argument<String>("route"))
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        }
                    )
                    activity.finish()
                    result.success(null)
                }
                "finish" -> {
                    activity.finish()
                    result.success(null)
                }
                // About: the installed version, and links that leave the app
                // for the browser or Play. Mull itself still has no network.
                "appVersion" -> result.success(
                    activity.packageManager.getPackageInfo(activity.packageName, 0).versionName,
                )
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    try {
                        activity.startActivity(
                            Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(true)
                    } catch (_: android.content.ActivityNotFoundException) {
                        result.success(false)
                    }
                }
                // Word of the day: the alarm is armed from the saved setting,
                // so the receiver and the app never disagree about the time.
                "scheduleReminder" -> {
                    WordOfDayReminder.sync(activity)
                    result.success(null)
                }
                "requestNotifications" -> {
                    if (WordOfDayReminder.canPost(activity)) {
                        result.success(true)
                    } else if (Build.VERSION.SDK_INT >= 33) {
                        permissionResult?.success(false)
                        permissionResult = result
                        activity.requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), NOTIFICATIONS_REQUEST)
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** The answer to [requestNotifications], from the activity's callback. */
    fun onPermissionResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != NOTIFICATIONS_REQUEST) return false
        permissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == android.content.pm.PackageManager.PERMISSION_GRANTED)
        permissionResult = null
        return true
    }

    /** An arrival while the activity is already open. */
    fun pushArrival(intent: Intent) {
        takeArrival(intent)?.let { platform?.invokeMethod("onIntentReceived", it) }
    }

    /**
     * The engine is bound on the first tap, not at launch: binding and
     * setLanguage run on this (the platform main) thread and a slow engine
     * there during a cold start is an ANR, not a dropped frame. The first
     * word is spoken once the engine reports ready.
     */
    private fun speak(text: String, rate: Double) {
        val engine = tts ?: TextToSpeech(activity) { status ->
            ready = status == TextToSpeech.SUCCESS
            if (ready) {
                tts?.language = Locale.UK
                pending?.let { (t, r) -> speak(t, r) }
            }
            pending = null
        }.also { tts = it }
        if (!ready) {
            pending = text to rate
            return
        }
        engine.setSpeechRate(rate.toFloat())
        engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "mull")
    }

    fun shutdown() {
        tts?.shutdown()
        tts = null
    }

    companion object {
        /**
         * The arrival carried by [intent], if any, removed from it in the same
         * step: text from PROCESS_TEXT, DEFINE or SEND, a word key from a widget
         * tap, or a route from the define sheet.
         */
        fun takeArrival(intent: Intent): Map<String, String?>? {
            val text = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
                ?: intent.getStringExtra(Intent.EXTRA_TEXT)
            val wordKey = intent.getStringExtra("word_key")
            val route = intent.getStringExtra("route")
            if (text == null && wordKey == null && route == null) return null
            intent.removeExtra(Intent.EXTRA_PROCESS_TEXT)
            intent.removeExtra(Intent.EXTRA_TEXT)
            intent.removeExtra("word_key")
            intent.removeExtra("route")
            return mapOf("text" to text, "wordKey" to wordKey, "route" to route, "sourceHint" to intent.getStringExtra(EXTRA_SOURCE))
        }

        const val EXTRA_SOURCE = "com.grs.dictionary.source"
        private const val NOTIFICATIONS_REQUEST = 4102
    }
}
