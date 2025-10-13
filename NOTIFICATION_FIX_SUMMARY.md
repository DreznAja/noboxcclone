# Ringkasan Fix Notifikasi - Nama Contact yang Salah

## 🎯 Masalah
Notifikasi menampilkan **"Customer"** (generic) bukan nama contact sebenarnya seperti "dhani bilek", "mambar?", dll.

## 🔍 Root Cause
**Dua masalah:**
1. **Backend FCM mengirim data yang salah:**
```json
{
  "senderName": "Customer",  // ❌ Salah - harusnya nama contact
  "roomName": "Customer",    // ❌ Salah - harusnya nama contact
  "message": "ww"
}
```

2. **SignalR notification hardcoded "Customer":**
```dart
// Di signalr_service.dart line 264
PushNotificationService.showChatNotification(
  senderName: 'Customer',  // ❌ Hardcoded!
  ...
);
```

## ✅ Solusi yang Diterapkan

### 1. Notifikasi Tap - Buka Chat dengan Data Lengkap
**File:** `lib/main.dart`
- Fetch data room lengkap dari API sebelum navigasi
- Gunakan nama contact yang benar dari database

### 2. Notifikasi Foreground (FCM) - Tampilkan Nama yang Benar
**File:** `lib/core/services/push_notification_service.dart`
- Ketika app aktif dan terima FCM, fetch nama contact dari API
- Tampilkan nama sebenarnya di notifikasi
- Fallback ke data FCM jika API gagal

### 3. Notifikasi SignalR - Fetch Nama dari API
**File:** `lib/core/services/signalr_service.dart`
- **CRITICAL FIX:** Tidak lagi hardcode "Customer"
- Fetch nama contact dari API sebelum show notification
- Gunakan nama sebenarnya dari database
- Ini adalah fix utama karena SignalR adalah sumber notifikasi utama

### 4. Notifikasi Background - Partial Fix
**File:** `android/.../MyFirebaseMessagingService.kt`
- Deteksi jika `senderName` adalah "Customer" (generic)
- Gunakan `roomName` sebagai fallback
- **LIMITATION:** Tetap bergantung pada data dari backend

## 📊 Hasil

| Skenario | Sebelum | Sesudah |
|----------|---------|---------|------|
| **Klik notifikasi** | Nama salah | ✅ **Nama benar** (dari API) |
| **SignalR notif** | "Customer" | ✅ **Nama benar** (dari API) |
| **FCM foreground** | "Customer" | ✅ **Nama benar** (dari API) |
| **FCM background** | "Customer" | ⚠️ Bergantung backend |

## 🚀 Testing
1. Build app: `flutter run` atau build APK
2. Buka app (foreground)
3. Kirim pesan dari contact lain
4. Cek notifikasi → seharusnya tampil nama yang benar
5. Klik notifikasi → seharusnya buka chat dengan nama yang benar

## 💡 Rekomendasi PENTING

### ⭐ Solusi Terbaik: Perbaiki Backend
Backend FCM server harus:
1. Query database untuk nama contact sebelum send notification
2. Kirim nama contact yang benar di FCM payload

**Contoh kode backend (pseudo):**
```javascript
// ❌ JANGAN seperti ini
const notification = {
  senderName: "Customer",  // Generic!
  roomName: "Customer"
}

// ✅ HARUS seperti ini
const room = await db.getRoomById(roomId);
const notification = {
  senderName: room.contactName,  // Nama sebenarnya!
  roomName: room.contactName
}
```

## 📝 Files Changed
- ✅ `lib/main.dart` - Navigation fix (fetch complete room data)
- ✅ `lib/core/services/push_notification_service.dart` - FCM foreground notification fix
- ✅ `lib/core/services/signalr_service.dart` - **SignalR notification fix (CRITICAL)**
- ✅ `android/app/src/main/kotlin/com/example/nbx0/MyFirebaseMessagingService.kt` - Background fallback
- 📄 `NOTIFICATION_FIX.md` - Detailed documentation
- 📄 `NOTIFICATION_FIX_SUMMARY.md` - This file

## ⚠️ Known Limitations
- Background notifications masih tergantung pada data dari backend
- Jika backend tetap kirim "Customer", background notification tetap salah
- **FIX PERMANENT MEMERLUKAN PERUBAHAN DI BACKEND**
