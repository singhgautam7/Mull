package com.grs.dictionary

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
    }

    override fun onDestroy() {
        tts?.shutdown()
        super.onDestroy()
    }
}
