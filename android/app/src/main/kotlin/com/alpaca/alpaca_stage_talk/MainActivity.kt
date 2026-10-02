package com.alpaca.alpaca_stage_talk

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "alpaca_stage_talk/net")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquireMulticast" -> {
                        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        val lock = wifi.createMulticastLock("stage-talk")
                        lock.setReferenceCounted(false)
                        lock.acquire()
                        multicastLock = lock
                        result.success(true)
                    }
                    "releaseMulticast" -> {
                        multicastLock?.let { if (it.isHeld) it.release() }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
