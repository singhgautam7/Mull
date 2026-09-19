package com.grs.dictionary

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Pronunciation through the platform's own TextToSpeech engine.
 *
 * A method channel rather than a plugin: it is one call, it stays on the
 * device, and it keeps the build free of third-party Gradle plugins.
 */
class MainActivity : FlutterActivity() {
    private var tts: TextToSpeech? = null
    private var ready = false
    private var platformChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        tts = TextToSpeech(this) { status ->
            ready = status == TextToSpeech.SUCCESS
            if (ready) tts?.language = Locale.UK
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.grs.dictionary/tts")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val text = call.argument<String>("text") ?: ""
                        val rate = call.argument<Double>("rate") ?: 1.0
                        tts?.setSpeechRate(rate.toFloat())
                        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "mull")
                        result.success(ready)
                    }
                    else -> result.notImplemented()
                }
            }
        // Widget refresh and arrival (PROCESS_TEXT, SEND, widget tap). Flutter
        // pulls the launch intent once it is ready; a later intent is pushed.
        // Either way the extras are taken off the intent, so one arrival is
        // handled once.
        platformChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.grs.dictionary/platform")
        platformChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "refreshWidget" -> {
                    val manager = AppWidgetManager.getInstance(this)
                    val ids = manager.getAppWidgetIds(ComponentName(this, WordOfDayWidget::class.java))
                    WordOfDayWidget().onUpdate(this, manager, ids)
                    result.success(null)
                }
                "incomingText" -> result.success(takeArrival(intent))
                else -> result.notImplemented()
            }
        }
    }

    // singleTop: an arrival while Mull is already open lands here.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        takeArrival(intent)?.let { platformChannel?.invokeMethod("onIntentReceived", it) }
    }

    /** The arrival carried by [intent], if any, removed from it in the same step. */
    private fun takeArrival(intent: Intent): Map<String, String?>? {
        val text = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
            ?: intent.getStringExtra(Intent.EXTRA_TEXT)
        val wordKey = intent.getStringExtra("word_key")
        if (text == null && wordKey == null) return null
        intent.removeExtra(Intent.EXTRA_PROCESS_TEXT)
        intent.removeExtra(Intent.EXTRA_TEXT)
        intent.removeExtra("word_key")
        return mapOf("text" to text, "wordKey" to wordKey, "sourceHint" to callingActivity?.packageName)
    }

    override fun onDestroy() {
        tts?.shutdown()
        super.onDestroy()
    }
}
