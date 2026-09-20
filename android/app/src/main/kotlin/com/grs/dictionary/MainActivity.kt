package com.grs.dictionary

import android.content.Context
import android.content.Intent
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/** The app. Arrivals from outside (text selection, share sheet) go to [DefineActivity]. */
class MainActivity : FlutterActivity() {
    private val channels = PlatformChannels(this)

    override fun provideFlutterEngine(context: Context): FlutterEngine =
        (application as MullApplication).engines.createAndRunEngine(
            this,
            DartExecutor.DartEntrypoint(FlutterInjector.instance().flutterLoader().findAppBundlePath(), "main"),
        )

    // A host-provided engine is kept alive by default; this one belongs to the activity.
    override fun shouldDestroyEngineWithHost(): Boolean = true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channels.attach(flutterEngine)
    }

    // singleTop: a widget tap or a hand-off from the define sheet while Mull
    // is already open lands here.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        channels.pushArrival(intent)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (!channels.onPermissionResult(requestCode, grantResults)) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    override fun onDestroy() {
        channels.shutdown()
        super.onDestroy()
    }
}
