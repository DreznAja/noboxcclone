# Push Notification Setup Guide

## Status Implementasi
✅ Firebase Cloud Messaging (FCM) sudah disetup
✅ Background message handler sudah ada
✅ Foreground notification sudah berfungsi
✅ Local notifications sudah terintegrasi
✅ Notification tap handler sudah ada

## Yang Sudah Berfungsi

### 1. Foreground Notifications
Ketika aplikasi sedang terbuka, notifikasi akan muncul melalui local notifications dengan:
- Messaging style (seperti WhatsApp)
- Grouped notifications per room
- Tidak muncul jika user sedang di room tersebut

### 2. Background/Terminated Notifications
Ketika aplikasi tertutup atau di background:
- Android native service menangani notifikasi
- Notifikasi muncul otomatis dari FCM
- Tap notification akan membuka aplikasi ke room yang sesuai

### 3. FCM Token Management
- Token otomatis di-generate saat aplikasi start
- Token disimpan di local storage
- Token auto-refresh ketika ada perubahan

## Setup Backend Integration

### 1. Kirim FCM Token ke Backend
Tambahkan API endpoint di backend untuk menerima FCM token:

```dart
// Di lib/core/services/push_notification_service.dart
static Future<void> sendTokenToBackend(String token) async {
  try {
    final userData = StorageService.getUserData();
    final userId = userData?['UserId'];
    
    if (userId == null) return;
    
    await ApiService.dio.post(
      'Services/User/RegisterFCMToken',
      data: {
        'UserId': userId,
        'FCMToken': token,
        'Platform': Platform.isAndroid ? 'android' : 'ios',
      },
    );
    
    print('✅ FCM Token sent to backend');
  } catch (e) {
    print('❌ Failed to send FCM token: $e');
  }
}
```

Panggil saat token didapat:
```dart
String? token = await _firebaseMessaging.getToken();
if (token != null) {
  await sendTokenToBackend(token);
}
```

### 2. Backend Push Notification Format
Backend harus mengirim notifikasi dengan format:

```json
{
  "to": "FCM_TOKEN_USER",
  "notification": {
    "title": "Contact Name",
    "body": "Message preview",
    "sound": "default",
    "badge": "1"
  },
  "data": {
    "roomId": "728385619223301",
    "roomName": "Contact Name",
    "senderName": "Contact Name",
    "message": "Full message text",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  },
  "priority": "high",
  "content_available": true
}
```

## Android Native Configuration

### File: android/app/src/main/AndroidManifest.xml
```xml
<manifest>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    
    <application>
        <!-- FCM Service -->
        <service
            android:name=".MyFirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT"/>
            </intent-filter>
        </service>
        
        <!-- Default notification icon -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/nobox2" />
            
        <!-- Default notification color -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_color"
            android:resource="@color/colorPrimary" />
            
        <!-- Notification channel -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="chat_notifications" />
    </application>
</manifest>
```

### File: android/app/src/main/kotlin/.../MyFirebaseMessagingService.kt
Buat custom service untuk handle background notifications dengan better display.

## iOS Configuration

### File: ios/Runner/AppDelegate.swift
```swift
import UIKit
import Flutter
import firebase_messaging

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## Testing Notifications

### 1. Test Token Generation
```dart
final token = PushNotificationService.getFCMToken();
print('FCM Token: $token');
```

### 2. Test Manual Notification (via Firebase Console)
1. Buka Firebase Console
2. Go to Cloud Messaging
3. Send test message dengan token dari console log
4. Test dengan app di foreground, background, dan terminated

### 3. Test dari Backend
Backend kirim notification ke FCM token user tertentu

## Troubleshooting

### Notifikasi tidak muncul saat app ditutup
1. ✅ Cek apakah FCM token sudah di-generate
2. ✅ Cek permission notifikasi di settings device
3. ✅ Pastikan background handler sudah di-register
4. ✅ Cek format payload dari backend

### Notifikasi muncul tapi tidak bisa di-tap
1. ✅ Pastikan data payload ada `roomId` dan `roomName`
2. ✅ Cek method channel handler di MainActivity
3. ✅ Test onMessageOpenedApp listener

### Token tidak terkirim ke backend
1. ✅ Cek network connection
2. ✅ Cek backend API endpoint
3. ✅ Implement retry mechanism

## Best Practices

### 1. Clear notifications saat masuk room
```dart
// Di chat_screen.dart initState
@override
void initState() {
  super.initState();
  PushNotificationService.setCurrentRoom(widget.room.id);
  PushNotificationService.cancelNotificationsForRoom(widget.room.id);
}

@override
void dispose() {
  PushNotificationService.clearCurrentRoom();
  super.dispose();
}
```

### 2. Update badge count
Implementasi badge counter untuk iOS

### 3. Notification grouping
Sudah diimplementasi dengan groupKey per room

### 4. Rich notifications
Bisa tambahkan:
- Reply dari notification (Android)
- Mark as read action
- Quick reply input

## Next Steps

1. ✅ Test notifikasi di berbagai kondisi (foreground, background, terminated)
2. ⏳ Kirim FCM token ke backend saat login/register
3. ⏳ Backend implement push notification sending
4. ⏳ Test dengan real messages dari backend
5. ⏳ Implement notification actions (reply, mark read)
6. ⏳ Add notification settings (mute, customize)

## Known Issues

1. **iOS simulator tidak support push notification** - Test di real device
2. **Token might change** - Handle token refresh with backend sync
3. **Battery optimization** - User mungkin perlu disable battery optimization untuk app

## Support

Jika masih ada masalah:
1. Check logs untuk error messages
2. Verify Firebase configuration
3. Test dengan Firebase Console test message
4. Check backend payload format
