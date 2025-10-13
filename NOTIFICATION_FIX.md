# Fix: Notifikasi Menampilkan Nama Contact yang Salah

## Masalah
Ketika notifikasi diklik, aplikasi membuka chat screen dengan nama contact yang salah/ngawur. Dari log terlihat bahwa join conversation berhasil (`✅ Joined room 710968507805701 for real-time updates`), tetapi nama yang ditampilkan tidak sesuai dengan contact yang sebenarnya.

## Root Cause
Di file `lib/main.dart`, fungsi `_navigateToRoom()` hanya membuat objek `Room` sederhana dengan data minimal dari notifikasi:

```dart
final room = Room(
  id: roomId,
  name: roomName,  // roomName dari notifikasi mungkin salah
  status: 1,
  channelId: 1,
  channelName: 'Chat',
);
```

Masalahnya adalah:
1. **roomName** yang dikirim dari notifikasi (baik dari FCM maupun SignalR) mungkin tidak akurat atau tidak sesuai dengan data room yang sebenarnya di database
2. Objek `Room` hanya memiliki data minimal tanpa informasi lengkap seperti `ctRealId`, `contactImage`, `accountName`, `botName`, dll.

## Solusi
Mengubah fungsi `_navigateToRoom()` untuk **fetch data room yang lengkap dari API** sebelum navigasi ke ChatScreen:

### Perubahan di `lib/main.dart`:

1. **Fetch complete room data dari API** menggunakan endpoint `Services/Chat/Chatrooms/DetailRoom`
2. **Parse response** dan buat objek `Room` yang lengkap dengan `Room.fromJson()`
3. **Fallback mechanism** jika API gagal, tetap gunakan data minimal dari notifikasi

```dart
Future<void> _navigateToRoom(String roomId, String roomName) async {
  // ... navigate to home screen first ...
  
  Future.delayed(const Duration(milliseconds: 300), () async {
    try {
      print('🔍 Fetching complete room data for roomId: $roomId');
      
      // Fetch data room yang lengkap dari API
      final response = await ApiService.dio.post(
        'Services/Chat/Chatrooms/DetailRoom',
        data: {'EntityId': roomId},
      );
      
      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final roomData = response.data['Data']['Room'];
        final room = Room.fromJson(roomData);  // ✅ Data lengkap!
        
        // Navigate with complete room data
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
        );
      } else {
        // Fallback to notification data
      }
    } catch (e) {
      // Fallback to notification data
    }
  });
}
```

## Keuntungan
1. ✅ **Nama contact yang benar** - mendapat data dari API yang akurat
2. ✅ **Data room lengkap** - termasuk `ctRealId`, `contactImage`, `accountName`, `botName`, tags, funnel, dll
3. ✅ **Fallback mechanism** - tetap bisa buka chat meski API gagal
4. ✅ **Konsisten dengan flow normal** - sama seperti ketika user klik room dari list

## Testing
Untuk test fix ini:
1. Build dan install aplikasi
2. Kirim pesan dari contact lain
3. Tekan notifikasi yang muncul
4. Verifikasi nama contact yang ditampilkan sudah benar

## Log yang Diharapkan
```
📱 Notification tapped globally: 710968507805701
🔍 Fetching complete room data for roomId: 710968507805701
✅ Got complete room data: [Nama Contact yang Benar]
👋 Joined conversation: 710968507805701
✅ Joined room 710968507805701 for real-time updates
```

## File yang Diubah
- `lib/main.dart` - fungsi `_navigateToRoom()` - Fetch complete room data sebelum navigasi
- `lib/core/services/push_notification_service.dart` - Added API call to fetch actual contact name
- `android/app/src/main/kotlin/com/example/nbx0/MyFirebaseMessagingService.kt` - Fallback logic untuk native notifications

## Catatan Penting tentang Notifikasi Background

### Masalah
Notifikasi menampilkan "Customer" bukan nama contact sebenarnya karena:
1. **Backend mengirim data yang tidak akurat** - Field `senderName` di FCM payload berisi "Customer" (generic) bukan nama contact
2. **Notifikasi background ditangani native Android** - Tidak bisa easily fetch data dari API

### Solusi yang Diterapkan

#### 1. Flutter (Foreground Notifications)
Ketika app di foreground, notifikasi sekarang akan:
- **Fetch data room dari API** menggunakan `DetailRoom` endpoint
- **Menggunakan nama contact sebenarnya** dari response API (CtRealNm/Ct/Grp)
- **Fallback ke senderName** jika API call gagal

```dart
static Future<String?> _getRoomDetailForNotification(String roomId) async {
  final response = await ApiService.dio.post(
    'Services/Chat/Chatrooms/DetailRoom',
    data: {'EntityId': roomId},
  );
  
  if (response.statusCode == 200) {
    final roomData = response.data['Data']['Room'];
    return roomData['CtRealNm'] ?? roomData['Ct'] ?? roomData['Grp'];
  }
  return null;
}
```

#### 2. Native Android (Background Notifications)
Di native side, ditambahkan logic sederhana:
- Check jika `senderName` adalah "Customer" atau "Someone" (generic)
- Jika ya, gunakan `roomName` sebagai fallback
- Ini partial fix karena `roomName` dari backend mungkin juga tidak akurat

```kotlin
val displayName = if (senderName == "Customer" || senderName == "Someone") {
    roomName
} else {
    senderName
}
```

### Rekomendasi untuk Fix Permanent

**RECOMMENDED**: Perbaiki di backend server yang mengirim FCM notification.

Backend seharusnya:
1. Query data contact/room dari database sebelum mengirim notification
2. Set field `senderName` dengan nama contact yang benar (bukan "Customer")
3. Set field `roomName` dengan nama contact yang benar

Contoh payload FCM yang benar:
```json
{
  "data": {
    "roomId": "710968507805701",
    "roomName": "dhani bilek",  // ← Nama contact yang benar
    "senderName": "dhani bilek", // ← Nama contact yang benar
    "message": "ww"
  }
}
```

Dengan fix ini:
- ✅ Notifikasi foreground akan menampilkan nama yang benar (via API call)
- ⚠️ Notifikasi background masih tergantung pada data dari backend
- 💡 Solusi terbaik: Perbaiki backend untuk mengirim nama yang akurat
