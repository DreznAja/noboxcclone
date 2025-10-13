# Fitur Add Note di Chat Screen

## Deskripsi
Fitur ini memungkinkan user untuk menambahkan note/catatan untuk conversation/room tertentu dari dalam chat screen.

## Endpoint API
```
POST https://id.nobox.ai/Services/Chat/Chatnotes/Create
```

### Request Body
```json
{
  "Entity": {
    "RoomId": "728385619223301",
    "Cnt": "oi"
  }
}
```

### Response
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

## Perubahan Kode

### 1. ApiService (`lib/core/services/api_service.dart`)
Ditambahkan method baru `createNote`:

```dart
static Future<ApiResponse<Map<String, dynamic>>> createNote({
  required String roomId,
  required String content,
}) async {
  try {
    final requestData = {
      'Entity': {
        'RoomId': roomId,
        'Cnt': content,
      },
    };

    final response = await dio.post(
      'Services/Chat/Chatnotes/Create',
      data: requestData,
    );

    if (response.statusCode == 200) {
      final isError = response.data['Error'] != null;
      
      if (!isError) {
        return ApiResponse(
          isError: false,
          data: response.data,
          statusCode: response.statusCode!,
        );
      } else {
        return ApiResponse(
          isError: true,
          error: response.data['Error'] ?? 'Failed to create note',
          statusCode: response.statusCode!,
        );
      }
    } else {
      return ApiResponse(
        isError: true,
        error: 'HTTP ${response.statusCode}: ${response.statusMessage}',
        statusCode: response.statusCode!,
      );
    }
  } catch (e) {
    return ApiResponse(
      isError: true,
      error: e.toString(),
      statusCode: 500,
    );
  }
}
```

### 2. ChatProvider (`lib/core/providers/chat_provider.dart`)
Ditambahkan method `createNote`:

```dart
Future<bool> createNote(String content) async {
  final activeRoom = state.activeRoom;
  if (activeRoom == null) {
    state = state.copyWith(error: 'No active room');
    return false;
  }

  final roomId = activeRoom.id;
  print('📝 [Create Note] Creating note for room: $roomId');

  try {
    final response = await ApiService.createNote(
      roomId: roomId,
      content: content,
    );

    if (response.isError) {
      print('❌ [Create Note] Failed: ${response.error}');
      state = state.copyWith(error: response.error);
      return false;
    }

    print('✅ [Create Note] Note created successfully');
    print('📝 [Create Note] Response: ${response.data}');
    
    state = state.copyWith(error: null);
    return true;
  } catch (e) {
    print('❌ [Create Note] Exception: $e');
    state = state.copyWith(error: e.toString());
    return false;
  }
}
```

### 3. ChatScreen (`lib/presentation/screens/chat/chat_screen.dart`)

#### a. Import AddNoteDialog
```dart
import '../../widgets/add_note_dialog.dart';
```

#### b. Tambah Menu "Add Note" di PopupMenu AppBar
```dart
PopupMenuButton<String>(
  icon: const Icon(Icons.more_vert, color: Colors.white),
  onSelected: (String value) {
    switch (value) {
      case 'add_note':
        _handleAddNote();
        break;
      case 'resolve':
        _handleResolve();
        break;
      case 'archive':
        _handleArchive();
        break;
    }
  },
  itemBuilder: (BuildContext context) => [
    const PopupMenuItem(
      value: 'add_note',
      child: Row(
        children: [
          Icon(Icons.note_add_outlined, size: 20),
          SizedBox(width: 12),
          Text('Add Note'),
        ],
      ),
    ),
    // ... menu lainnya
  ],
)
```

#### c. Method Handler `_handleAddNote()`
```dart
void _handleAddNote() {
  showDialog(
    context: context,
    builder: (context) => AddNoteDialog(
      onSave: (content) async {
        final success = await ref.read(chatProvider.notifier).createNote(content);
        
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Note berhasil ditambahkan'),
                backgroundColor: AppTheme.successColor,
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gagal menambahkan note'),
                backgroundColor: AppTheme.errorColor,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      },
    ),
  );
}
```

## Cara Menggunakan

1. **Buka Chat Screen** untuk conversation yang ingin ditambahkan note
2. **Klik icon titik tiga (⋮)** di AppBar bagian kanan atas
3. **Pilih "Add Note"** dari menu dropdown
4. **Isi konten note** di dialog yang muncul
5. **Klik "Save"** untuk menyimpan note

## Flow Data

```
User Action (Klik Add Note)
    ↓
AddNoteDialog ditampilkan
    ↓
User input note content
    ↓
User klik Save
    ↓
ChatProvider.createNote(content) dipanggil
    ↓
ApiService.createNote(roomId, content) dipanggil
    ↓
POST ke /Services/Chat/Chatnotes/Create
    ↓
Response dari API
    ↓
Success/Error feedback via SnackBar
```

## Testing

### Manual Test
1. Login ke aplikasi
2. Buka conversation
3. Klik ⋮ di AppBar
4. Pilih "Add Note"
5. Isi note: "Test note untuk room ini"
6. Klik Save
7. Verifikasi SnackBar success muncul
8. Cek di backend/web apakah note tersimpan

### Expected Behavior
- ✅ Dialog muncul saat klik "Add Note"
- ✅ Input field auto-focus
- ✅ Tombol Cancel menutup dialog tanpa save
- ✅ Tombol Save memanggil API
- ✅ SnackBar success/error muncul sesuai hasil API
- ✅ Note tersimpan di backend dengan RoomId yang benar

## Notes
- Note ini untuk **conversation/room**, bukan untuk contact
- Note di-attach ke RoomId, bukan ContactId
- Dialog menggunakan widget `AddNoteDialog` yang sudah ada
- API endpoint sama dengan yang digunakan di web interface
