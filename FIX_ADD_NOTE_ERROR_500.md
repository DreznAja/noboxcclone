# Fix: Error 500 pada Add Note - "Could not find field 'CtId'"

## 🔍 Problem
Error 500 muncul saat mencoba add note dari Contact Detail Screen:

```
Could not find field 'CtId' on row of type 'ChatnotesRow'
```

## 🎯 Root Cause
**Backend table `Chatnotes` TIDAK MEMILIKI field `CtId`!**

Table Chatnotes hanya memiliki field:
- `Id`
- `RoomId` ← Yang ini yang benar!
- `Cnt` (content)
- `In`, `InBy`, `Up`, `UpBy` (timestamps & user IDs)

Kesalahan awal: kita mencoba kirim `CtId` (ContactId), padahal backend hanya accept `RoomId`.

## ✅ Solusi

### Perubahan 1: ContactDetailService (`contact_detail_service.dart`)

**BEFORE (SALAH):**
```dart
Future<bool> addContactNote(String contactId, String content) async {
  final requestData = {
    'Entity': {
      'CtId': contactId,  // ❌ Field ini tidak ada!
      'Cnt': content,
    },
  };
  // ...
}
```

**AFTER (BENAR):**
```dart
Future<bool> addContactNote(String roomId, String content) async {
  final roomIdInt = int.tryParse(roomId);
  
  final requestData = {
    'Entity': {
      'RoomId': roomIdInt,  // ✅ Gunakan RoomId!
      'Cnt': content,
    },
  };
  // ...
}
```

### Perubahan 2: ContactDetailProvider (`contact_detail_provider.dart`)

**BEFORE:**
```dart
Future<void> addNote(String contactId, String content) async {
  final success = await _service.addContactNote(contactId, content);
  await loadContactNotes(contactId);
}
```

**AFTER:**
```dart
Future<void> addNote(String roomId, String content) async {
  // Pass roomId instead of contactId
  final success = await _service.addContactNote(roomId, content);
  await loadContactNotes(roomId);
}
```

### Perubahan 3: ContactDetailScreen UI (`contact_detail_screen.dart`)

**BEFORE:**
```dart
void _addNote(String contactId) {
  showDialog(
    context: context,
    builder: (context) => AddNoteDialog(
      onSave: (content) {
        ref.read(contactDetailProvider.notifier)
           .addNote(contactId, content);  // ❌ Kirim contactId
      },
    ),
  );
}
```

**AFTER:**
```dart
void _addNote(String contactId) {
  // Check if roomId available
  if (_currentRoomId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Room ID not found. Cannot add note.'),
      ),
    );
    return;
  }
  
  showDialog(
    context: context,
    builder: (context) => AddNoteDialog(
      onSave: (content) {
        ref.read(contactDetailProvider.notifier)
           .addNote(_currentRoomId!, content);  // ✅ Kirim roomId
      },
    ),
  );
}
```

## 📊 Format Request yang Benar

### Chat Note (dari Chat Screen):
```json
{
  "Entity": {
    "RoomId": 728385619223301,
    "Cnt": "Note dari chat screen"
  }
}
```

### Contact Note (dari Contact Detail):
```json
{
  "Entity": {
    "RoomId": 728385619223301,
    "Cnt": "Note dari contact detail"
  }
}
```

**KEDUA FUNGSI MENGGUNAKAN RoomId!** Tidak ada yang menggunakan CtId!

## 🧪 Testing

### Test Contact Note:
1. Buka Contact Detail Screen
2. Pastikan `_currentRoomId` tidak null (ada conversation dengan contact ini)
3. Klik Add Note
4. Input: "Test note dari contact detail"
5. Save
6. Cek log:
```
📝 [Add Contact Note] Starting - RoomId: 728385619223301
📝 [Add Contact Note] Request data: {Entity: {RoomId: 728385619223301, Cnt: Test note dari contact detail}}
📝 [Add Contact Note] Response: 200 - {EntityId: 729714935149573, Error: null}
✅ [Add Contact Note] Success
```

### Test Chat Note:
1. Buka Chat Screen
2. Klik ⋮ → Add Note
3. Input: "Test note dari chat"
4. Save
5. Cek SnackBar success & log

## 📝 Response Success dari Backend

```json
{
  "EntityId": 729714935149573,
  "Error": null,
  "CustomData": null
}
```

Note akan muncul di list dengan format:
```json
{
  "Id": 729714935149573,
  "RoomId": 728385619223301,
  "Cnt": "Test note",
  "In": "2025-10-12T16:40:16.270",
  "InBy": 1645,
  "Up": "2025-10-12T16:40:16.270",
  "UpBy": 1645
}
```

## ⚠️ Important Notes

1. **RoomId is Required**: Contact Note hanya bisa dibuat jika ada RoomId (conversation exists)
2. **Both Use Same Endpoint**: Contact Note dan Chat Note pakai endpoint yang sama: `/Services/Chat/Chatnotes/Create`
3. **No CtId Field**: Backend table Chatnotes tidak punya field `CtId` sama sekali
4. **Integer Type**: RoomId harus dikirim sebagai integer, bukan string

## 🎉 Summary

✅ Error 500 fixed dengan menggunakan `RoomId` instead of `CtId`  
✅ Contact Note sekarang berfungsi dengan benar  
✅ Chat Note sudah berfungsi dari awal (sudah pakai RoomId)  
✅ Format request konsisten dengan web interface  
✅ Kedua fungsi (Contact & Chat Note) menggunakan endpoint dan format yang sama
