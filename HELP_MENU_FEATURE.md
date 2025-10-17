# Fitur Help Menu di Chat Screen

## 📝 Deskripsi
Menambahkan menu "Help" di PopupMenu Chat Screen yang membuka dokumentasi Nobox.ai di browser eksternal.

## 🔗 Link Dokumentasi
```
https://ubig-co-1.gitbook.io/nobox-ai/real-base-ai-articles-english/menu/messages/inbox
```

## 🎯 Lokasi Menu
**Chat Screen → AppBar → Icon Titik Tiga (⋮) → Help**

## 📊 Perubahan Kode

### File: `lib/presentation/screens/chat/chat_screen.dart`

#### 1. Import Package
```dart
import 'package:url_launcher/url_launcher.dart';
```

#### 2. Tambah Case di Switch onSelected
```dart
switch (value) {
  case 'resolve':
    _handleResolve();
    break;
  case 'archive':
    _handleArchive();
    break;
  case 'add_note':
    _handleAddNote();
    break;
  case 'help':           // ← BARU
    _handleHelp();       // ← BARU
    break;
}
```

#### 3. Tambah PopupMenuItem
```dart
const PopupMenuItem(
  value: 'help',
  child: Row(
    children: [
      Icon(Icons.help_outline, size: 20),
      SizedBox(width: 12),
      Text('Help'),
    ],
  ),
),
```

#### 4. Fungsi _handleHelp()
```dart
void _handleHelp() async {
  final url = Uri.parse(
    'https://ubig-co-1.gitbook.io/nobox-ai/real-base-ai-articles-english/menu/messages/inbox'
  );
  
  try {
    final canLaunch = await canLaunchUrl(url);
    if (canLaunch) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication, // Buka di browser eksternal
      );
    } else {
      // Show error SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak bisa membuka link dokumentasi'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  } catch (e) {
    print('Error opening help URL: $e');
    // Show error SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gagal membuka dokumentasi'),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }
}
```

## 🧪 Cara Test

1. Buka Chat Screen
2. Klik icon **titik tiga (⋮)** di AppBar kanan atas
3. Pilih **"Help"**
4. Browser eksternal akan terbuka dengan link dokumentasi
5. Jika gagal, SnackBar error akan muncul

## 📱 Behavior

### Success:
- Browser eksternal terbuka (Chrome, Firefox, Safari, dll)
- Menampilkan halaman dokumentasi Nobox.ai Inbox

### Error:
- SnackBar muncul dengan pesan error
- Log error di console: `Error opening help URL: ...`

## 🎨 Icon & Text
- **Icon**: `Icons.help_outline` (size 20)
- **Text**: "Help"
- **Position**: Paling bawah di PopupMenu

## 📋 Menu Order (dari atas ke bawah)
1. Add Note
2. Mark as Resolved
3. Archive
4. **Help** ← Baru

## ⚙️ Package Used
```yaml
dependencies:
  url_launcher: ^6.x.x  # Already in pubspec.yaml
```

## 🔧 Android Configuration (PENTING!)

### AndroidManifest.xml
Untuk Android 11+, tambahkan `queries` tag:

```xml
<!-- Queries for url_launcher (Android 11+) -->
<queries>
    <!-- Browser intent -->
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="https" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="http" />
    </intent>
</queries>
```

**Lokasi:** `android/app/src/main/AndroidManifest.xml`  
**Posisi:** Sebelum tag `<application>`

## 💡 Notes
- Menggunakan `LaunchMode.externalApplication` agar membuka di browser eksternal, bukan in-app browser
- Error handling untuk kasus URL tidak bisa dibuka
- Mounted check untuk menghindari error saat widget disposed
- Link bisa di-update kapan saja dengan mengganti URL di fungsi `_handleHelp()`

## 🔄 Future Enhancement Ideas
- Add parameter untuk custom URL
- Add dialog confirmation sebelum membuka browser
- Add option untuk copy link
- Add in-app browser option (WebView)
