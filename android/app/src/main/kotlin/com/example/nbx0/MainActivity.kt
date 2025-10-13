package com.example.nbx0

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    
    private val CHANNEL = "com.example.nbx0/background_service"
    private val REQUEST_BATTERY_OPTIMIZATION = 1001
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Handle notification tap intent
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        android.util.Log.d("MainActivity", "handleIntent called with openChat: ${intent?.getBooleanExtra("openChat", false)}")

        if (intent?.getBooleanExtra("openChat", false) == true) {
            val roomId = intent.getStringExtra("roomId")
            val roomName = intent.getStringExtra("roomName")

            android.util.Log.d("MainActivity", "Opening chat from notification: roomId=$roomId, roomName=$roomName")

            // Pass data to Flutter via method channel
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, "com.example.nbx0/notification").invokeMethod(
                    "openChat",
                    mapOf(
                        "roomId" to roomId,
                        "roomName" to roomName
                    )
                )
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Setup method channel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "startBackgroundService" -> {
                        SignalRBackgroundService.startService(this)
                        result.success(true)
                    }
                    "stopBackgroundService" -> {
                        SignalRBackgroundService.stopService(this)
                        result.success(true)
                    }
                    "requestBatteryOptimization" -> {
                        val requested = requestBatteryOptimization()
                        result.success(requested)
                    }
                    "isBatteryOptimizationDisabled" -> {
                        val isDisabled = isBatteryOptimizationDisabled()
                        result.success(isDisabled)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            } catch (e: Exception) {
                result.error("ERROR", e.message, null)
            }
        }
    }

    private fun requestBatteryOptimization(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                
                if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                    val intent = Intent().apply {
                        action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                        data = Uri.parse("package:$packageName")
                    }
                    startActivityForResult(intent, REQUEST_BATTERY_OPTIMIZATION)
                    true
                } else {
                    true // Already exempted
                }
            } else {
                true // Not needed for older Android versions
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun isBatteryOptimizationDisabled(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                powerManager.isIgnoringBatteryOptimizations(packageName)
            } else {
                true // Not applicable for older versions
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Don't stop the background service when activity is destroyed
        // This allows SignalR to stay connected in background
    }
    
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
    }
}