package com.example.nbx0

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        private const val CHANNEL_ID = "chat_notifications"
        private const val CHANNEL_NAME = "Chat Notifications"
        private const val CHANNEL_DESCRIPTION = "Notifications for new chat messages"
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        android.util.Log.d("FCM", "Message received: ${remoteMessage.messageId}")
        android.util.Log.d("FCM", "Data: ${remoteMessage.data}")

        // ALWAYS handle data payload (this is what's sent from backend)
        if (remoteMessage.data.isNotEmpty()) {
            handleDataMessage(remoteMessage.data)
        } else if (remoteMessage.notification != null) {
            // Only handle notification payload if no data payload
            remoteMessage.notification?.let {
                showNotification(
                    title = it.title ?: "New Message",
                    body = it.body ?: "You have a new message",
                    data = remoteMessage.data
                )
            }
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        sendTokenToServer(token)
    }

    private fun handleDataMessage(data: Map<String, String>) {
        val message = data["message"] ?: "New message"
        val senderName = data["senderName"] ?: "Someone"
        val roomName = data["roomName"] ?: "Chat"

        // Use roomName if senderName is generic/not useful
        val displayName = if (senderName == "Customer" || senderName == "Someone") {
            roomName
        } else {
            senderName
        }

        showNotification(
            title = displayName,
            body = message,
            data = data
        )
    }

    private fun showNotification(title: String, body: String, data: Map<String, String>) {
        val roomId = data["roomId"]
        val roomName = data["roomName"] ?: "Chat"

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("roomId", roomId)
            putExtra("roomName", roomName)
            putExtra("openChat", true)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            roomId?.hashCode() ?: 0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setColor(getColor(R.color.notification_color))
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Pastikan channel dibuat untuk Android 8.0+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = CHANNEL_DESCRIPTION
                enableLights(true)
                enableVibration(true)
            }
            manager.createNotificationChannel(channel)
        }

        manager.notify(roomId?.hashCode() ?: 0, builder.build())
    }

    private fun sendTokenToServer(token: String) {
        // TODO: Kirim token ke backend server
        println("FCM Token: $token")
    }
}
