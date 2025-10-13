package com.example.nbx0

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.loader.FlutterLoader

class SignalRBackgroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "signalr_service"
        private const val NOTIFICATION_ID = 1001
        private const val METHOD_CHANNEL = "com.example.nbx0/signalr_background"
        private const val ACTION_START = "START_SIGNALR_SERVICE"
        private const val ACTION_STOP = "STOP_SIGNALR_SERVICE"

        private var isRunning = false

        fun startService(context: Context) {
            val intent = Intent(context, SignalRBackgroundService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, SignalRBackgroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var flutterEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate() {
        super.onCreate()

        // Create notification channel
        createNotificationChannel()

        // Acquire wake lock to keep service running
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "NoboxChat::SignalRWakeLock"
        )
        wakeLock?.acquire(10 * 60 * 1000L) // 10 minutes
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                if (!isRunning) {
                    startForeground(NOTIFICATION_ID, createNotification())
                    isRunning = true
                    initializeFlutterEngine()
                }
            }

            ACTION_STOP -> {
                stopForeground(true)
                stopSelf()
                isRunning = false
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SignalR Connection Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps chat connection active in background"
                setShowBadge(false)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Nobox Chat")
            .setContentText("Connected - Ready to receive messages")
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun initializeFlutterEngine() {
        try {
            // Init Flutter Loader (pengganti FlutterMain)
            val flutterLoader = FlutterLoader()
            flutterLoader.startInitialization(applicationContext)
            flutterLoader.ensureInitializationComplete(applicationContext, null)

            flutterEngine = FlutterEngine(applicationContext)

            // Jalankan entrypoint Dart
            val dartEntrypoint = DartExecutor.DartEntrypoint(
                flutterLoader.findAppBundlePath(),
                "signalrBackgroundEntry" // <- pastikan entrypoint ini ada di Dart side
            )

            flutterEngine?.dartExecutor?.executeDartEntrypoint(dartEntrypoint)

            // Setup method channel
            methodChannel = MethodChannel(
                flutterEngine!!.dartExecutor.binaryMessenger,
                METHOD_CHANNEL
            )

            methodChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateNotification" -> {
                        val status = call.argument<String>("status") ?: "Connected"
                        updateNotification(status)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }

        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun updateNotification(status: String) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Nobox Chat")
            .setContentText(status)
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, notification)
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        wakeLock?.release()
        flutterEngine?.destroy()
        flutterEngine = null
        methodChannel = null
    }
}
