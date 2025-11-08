# Fix: Notifications Not Working When App is Terminated

## Problem
✅ Notifications work when app is foreground
✅ Notifications work when app is background
❌ Notifications NOT working when app is terminated (closed)

## Root Cause
Saat app terminated, Android tidak bisa run Dart code untuk display notification. FCM harus menampilkan notification secara otomatis via **notification payload**, bukan hanya data payload.

## Solution

### Backend MUST Send BOTH Notification AND Data Payload

#### WRONG (Tidak muncul saat app terminated):
```json
{
  "to": "FCM_TOKEN",
  "data": {
    "roomId": "728385619223301",
    "message": "Hello"
  }
}
```

#### CORRECT (Muncul di semua kondisi):
```json
{
  "to": "FCM_TOKEN",
  "notification": {
    "title": "Contact Name",
    "body": "Message preview",
    "sound": "default",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  },
  "data": {
    "roomId": "728385619223301",
    "roomName": "Contact Name",
    "senderName": "Contact Name",
    "message": "Full message text"
  },
  "priority": "high",
  "content_available": true
}
```

## Key Points

### 1. **notification** Object (REQUIRED untuk terminated state)
```json
"notification": {
  "title": "Contact Name",     // Nama contact/room
  "body": "Message preview",   // Preview isi pesan
  "sound": "default",          // Notification sound
  "android_channel_id": "chat_notifications"
}
```

### 2. **data** Object (REQUIRED untuk navigation)
```json
"data": {
  "roomId": "728385619223301",      // REQUIRED - untuk buka room
  "roomName": "Contact Name",       // REQUIRED - untuk navigation
  "senderName": "Contact Name",     // Optional - untuk display
  "message": "Full message text",   // Optional - untuk content
  "type": "chat"                    // Optional - untuk categorize
}
```

### 3. **priority** (REQUIRED)
```json
"priority": "high"  // Pastikan notification priority high
```

## How It Works

### App Foreground (OPEN)
1. FCM delivers message
2. Dart code runs `onMessage` listener
3. FlutterLocalNotifications displays notification
4. Uses `data` payload for content

### App Background (MINIMIZED)
1. FCM delivers message
2. Android displays notification from `notification` payload
3. Tap → App resumes
4. Dart code runs `onMessageOpenedApp` listener
5. Uses `data` payload for navigation

### App Terminated (CLOSED)
1. FCM delivers message
2. **Android AUTOMATICALLY displays notification from `notification` payload**
3. Tap → App launches
4. Dart code runs `getInitialMessage()`
5. Uses `data` payload for navigation

## Backend Implementation Example

### Node.js (Admin SDK)
```javascript
const admin = require('firebase-admin');

async function sendChatNotification(userToken, roomId, roomName, message) {
  const payload = {
    token: userToken,
    notification: {
      title: roomName,
      body: message.substring(0, 100), // Limit preview
    },
    data: {
      roomId: roomId.toString(),
      roomName: roomName,
      senderName: roomName,
      message: message,
      type: 'chat',
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'chat_notifications',
        sound: 'default',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
    },
    apns: {
      headers: {
        'apns-priority': '10',
      },
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
    },
  };

  await admin.messaging().send(payload);
}
```

### PHP
```php
$message = [
    'token' => $userToken,
    'notification' => [
        'title' => $roomName,
        'body' => substr($message, 0, 100),
    ],
    'data' => [
        'roomId' => (string)$roomId,
        'roomName' => $roomName,
        'senderName' => $roomName,
        'message' => $message,
    ],
    'android' => [
        'priority' => 'high',
    ],
];

$response = $firebase->send($message);
```

### C# (.NET)
```csharp
var message = new Message()
{
    Token = userToken,
    Notification = new Notification
    {
        Title = roomName,
        Body = messagePreview,
    },
    Data = new Dictionary<string, string>()
    {
        { "roomId", roomId.ToString() },
        { "roomName", roomName },
        { "senderName", roomName },
        { "message", fullMessage },
    },
    Android = new AndroidConfig
    {
        Priority = Priority.High,
        Notification = new AndroidNotification
        {
            ChannelId = "chat_notifications",
        },
    },
};

await FirebaseMessaging.DefaultInstance.SendAsync(message);
```

## Testing

### 1. Test via Firebase Console
1. Go to Firebase Console → Cloud Messaging
2. Click "Send test message"
3. Input FCM token (dari log app)
4. **IMPORTANT**: Fill both "Notification" AND "Additional options → Custom data"
5. Close app completely
6. Send message
7. Should see notification!

### 2. Test Backend Payload
Print backend FCM payload sebelum send, pastikan ada `notification` object.

### 3. Verify Token
```dart
// Di login success, print token
final token = PushNotificationService.getFCMToken();
print('🔑 FCM Token: $token');
```

Copy token ini dan test manual via Firebase Console.

## Common Issues

### Issue 1: Notification tidak muncul sama sekali
**Solution**: 
- Cek permission di device settings
- Cek battery optimization settings
- Pastikan app tidak di-force stop

### Issue 2: Notification muncul tapi tidak bisa di-tap
**Solution**:
- Pastikan `data` payload ada `roomId` dan `roomName`
- Cek MainActivity intent filter
- Test getInitialMessage di main.dart

### Issue 3: Token tidak terkirim ke backend
**Solution**:
- Cek network connection
- Verify backend endpoint exists
- Check logs untuk error

## Verification Checklist

✅ AndroidManifest.xml has FirebaseMessagingService
✅ MyFirebaseMessagingService.kt handles onMessageReceived
✅ MainActivity handles intent from notification tap
✅ PushNotificationService sends token to backend
✅ Background handler registered in main.dart
✅ Notification channel created
✅ Icons and colors defined

⏳ Backend sends notification payload (NOT JUST data)
⏳ Test with Firebase Console
⏳ Verify with real backend integration

## Next Steps

1. **Share FCM token dengan backend team**
   ```dart
   // Log akan muncul saat app start:
   // 📱 FCM Token: xxxxxxx...
   ```

2. **Backend team implement FCM sending dengan notification payload**

3. **Test dengan sequence:**
   - Foreground ✅
   - Background ✅
   - Terminated ❌ ← Focus di sini

4. **Kalau masih tidak work, minta backend team share:**
   - FCM request payload yang dikirim
   - FCM response dari Google
   - Error logs jika ada

## Quick Debug

Run this after login:
```dart
print('🔑 FCM Token: ${PushNotificationService.getFCMToken()}');
```

Share token dengan backend untuk test manual via Firebase Console!
