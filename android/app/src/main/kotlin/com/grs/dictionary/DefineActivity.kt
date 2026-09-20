package com.grs.dictionary

import android.content.Context
import android.os.Bundle
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * "Define in Mull": PROCESS_TEXT, DEFINE and SEND land here, not in the app.
 *
 * A translucent activity in the caller's task that runs the `defineMain`
 * entrypoint, which draws only the word sheet over whatever the user was
 * reading, and finishes when the sheet is dismissed. Each arrival is its own
 * instance and its own engine, spawned from the process's engine group and
 * destroyed with the activity, so nothing accumulates. It never joins the
 * app's task and never shows in recents.
 *
 * Before this, arrivals started a second `MainActivity` (a whole second app
 * instance and engine) inside the caller's task; the launch transition waited
 * five seconds for a first frame that never came, freezing the display for
 * every app on it.
 */
class DefineActivity : FlutterActivity() {
    private val channels = PlatformChannels(this)

    override fun onCreate(savedInstanceState: Bundle?) {
        // Who sent us: read before the engine asks for the arrival.
        intent.putExtra(PlatformChannels.EXTRA_SOURCE, callingActivity?.packageName ?: referrer?.host)
        super.onCreate(savedInstanceState)
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine =
        (application as MullApplication).engines.createAndRunEngine(
            this,
            // The function lives in its own library; without the URI the engine looks in main.dart.
            DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "package:mull/define_main.dart",
                "defineMain",
            ),
        )

    override fun shouldDestroyEngineWithHost(): Boolean = true

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channels.attach(flutterEngine)
    }

    override fun onDestroy() {
        channels.shutdown()
        super.onDestroy()
    }
}
