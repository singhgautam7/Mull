package com.grs.dictionary

import android.app.Application
import io.flutter.embedding.engine.FlutterEngineGroup

/**
 * One engine group for the process. The app and the define sheet each run
 * their own engine and entrypoint; spawning them from one group shares the
 * VM and code, so a second engine costs milliseconds and little memory
 * rather than a whole second runtime.
 */
class MullApplication : Application() {
    val engines: FlutterEngineGroup by lazy { FlutterEngineGroup(this) }
}
