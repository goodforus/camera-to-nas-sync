package com.pandasf.nas_sync

import android.content.ContextWrapper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        // Register the Keystore-backed secure storage channel with the main
        // Flutter engine so the UI can read/write passwords securely.
        SecureStorageChannelHandler.register(flutterEngine.dartExecutor.binaryMessenger, this.applicationContext)
    }
}
