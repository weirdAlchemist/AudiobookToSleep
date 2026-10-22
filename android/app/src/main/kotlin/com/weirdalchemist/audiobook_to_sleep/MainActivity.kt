package com.weirdalchemist.audiobook_to_sleep

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity shares its Flutter engine with the background audio
// service, so playback keeps going when the screen is off.
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MediaBridge.CHANNEL)
            .setMethodCallHandler(MediaBridge(applicationContext))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DeviceBridge.CHANNEL)
            .setMethodCallHandler(DeviceBridge(this))
    }
}
