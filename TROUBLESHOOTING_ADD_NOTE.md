# Troubleshooting: Error 500 pada Add Note

## Problem
Error 500 (Internal Server Error) muncul saat mencoba add note baik dari Contact Detail atau Chat Screen.

```
❌ Error adding contact note: DioException [bad response]: 
This exception was thrown because the response has a status code of 500
```

## Root Cause Analysis

### Kemungkinan Penyebab:

#### 1. **Format Request Salah**
Backend mengharapkan format tertentu yang berbeda dari yang kita kirim.

**Sebelum Fix:**
```dart
// Contact Note - format lama (SALAH)
{
  'CtId': contactId,      // String
  'Cnt': content,
  'RoomId': null
}

// Chat Note - format lama
{
  'Entity': {
    'RoomId': roomId,     // String
    'Cnt': content
  }
}
```

**Setelah Fix:**
```dart
// Contact Note - format baru (BENAR)
{
  'Entity': {
    'CtId': ctIdInt,      // Integer
    'Cnt': content
  }
}

// Chat Note - format baru
{
  'Entity': {
    'RoomId': roomIdValue,  // Integer (jika bisa diparse)
    'Cnt': content
  }
}
```

#### 2. **Tipe Data Parameter**
Backend mengharapkan ID sebagai **integer**, bukan string.

- ✅ `CtId: 123456` (integer)
- ❌ `CtId: "123456"` (string)

#### 3. **Missing Entity Wrapper**
API endpoint `/Services/Chat/Chatnotes/Create` mengharapkan data dibungkus dengan key `Entity`.

#### 4. **Invalid ID**
ID yang dikirim tidak valid atau tidak ada di database backend.

## Solusi yang Diterapkan

### 1. Contact Note (`contact_detail_service.dart`)
```dart
Future<bool> addContactNote(String contactId, String content) async {
  try {
    // Convert to integer
    final ctIdInt = int.tryParse(contactId);
    if (ctIdInt == null) {
      print('❌ Invalid contactId format: $contactId');
      return false;
    }
    
    // Wrap with Entity
    final requestData = {
      'Entity': {
        'CtId': ctIdInt,  // ← Integer
        'Cnt': content,
      },
    };
    
    final response = await _dio.post(
      'Services/Chat/Chatnotes/Create',
      data: requestData,
    );
    // ...
  }
}
```

### 2. Chat Note (`api_service.dart`)
```dart
static Future<ApiResponse<Map<String, dynamic>>> createNote({
  required String roomId,
  required String content,
}) async {
  try {
    // Convert to integer if possible
    final roomIdValue = int.tryParse(roomId) ?? roomId;
    
    final requestData = {
      'Entity': {
        'RoomId': roomIdValue,  // ← Integer/String
        'Cnt': content,
      },
    };
    
    final response = await dio.post(
      'Services/Chat/Chatnotes/Create',
      data: requestData,
    );
    // ...
  }
}
```

## Cara Debug

### 1. Lihat Request yang Dikirim
Log sudah ditambahkan untuk melihat detail request:

```dart
print('📝 [Add Contact Note] Starting - ContactId: $contactId');
print('📝 [Add Contact Note] Content: $content');
print('📝 [Add Contact Note] Request data: $requestData');
```

### 2. Test di Postman/Insomnia
Coba hit endpoint langsung dengan format yang benar:

```bash
POST https://id.nobox.ai/Services/Chat/Chatnotes/Create
Headers:
  Authorization: Bearer YOUR_TOKEN
  Content-Type: application/json

Body:
{
  "Entity": {
    "RoomId": 728385619223301,
    "Cnt": "Test note"
  }
}
```

### 3. Cek Response Backend
Jika masih error 500, minta backend developer untuk:
- Cek server logs
- Verifikasi format request yang diharapkan
- Cek apakah ada validation error
- Pastikan database connection OK

## Testing Steps

### Test Contact Note:
1. Buka Contact Detail Screen
2. Klik Add Note
3. Input: "Test contact note"
4. Lihat log:
```
📝 [Add Contact Note] Starting - ContactId: 710968507789317
📝 [Add Contact Note] Content: Test contact note
📝 [Add Contact Note] Request data: {Entity: {CtId: 710968507789317, Cnt: Test contact note}}
```

### Test Chat Note:
1. Buka Chat Screen
2. Klik ⋮ → Add Note
3. Input: "Test chat note"
4. Lihat log:
```
📝 [Create Note] Request - RoomId: 728385619223301 (sent as: 728385619223301), Content: Test chat note
📝 [Create Note] Full request: {Entity: {RoomId: 728385619223301, Cnt: Test chat note}}
```

## Expected Behavior

### Success (200 OK):
```json
{
  "EntityId": 729482300212229,
  "Error": null,
  "CustomData": null,
  "Entity": {
    "RoomId": "728385619223301",
    "Cnt": "oi"
  }
}
```

### Error (500):
```
DioException [bad response]: status code 500
```

## Next Steps Jika Masih Error

1. **Verify Backend**
   - Pastikan endpoint bekerja di web interface
   - Test dengan user yang sama
   - Cek permission user

2. **Check Database**
   - Pastikan RoomId/CtId valid
   - Cek referential integrity

3. **Contact Backend Team**
   - Share full error log
   - Share request payload yang dikirim
   - Minta backend logs untuk melihat error detail

## Alternative Workaround

Jika masih error, coba format request alternatif:

```dart
// Alternatif 1: Tanpa Entity wrapper (untuk testing)
final requestData = {
  'RoomId': roomIdValue,
  'Cnt': content,
};

// Alternatif 2: Dengan field tambahan
final requestData = {
  'Entity': {
    'RoomId': roomIdValue,
    'Cnt': content,
    'Type': 1,  // Mungkin backend butuh type
  },
};
```

## Summary

- ✅ Format request sudah diperbaiki dengan Entity wrapper
- ✅ ID sudah diconvert ke integer
- ✅ Logging sudah ditambahkan untuk debugging
- ⚠️ Jika masih error 500, kemungkinan besar masalah di backend
