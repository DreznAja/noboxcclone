# Fitur New Conversation untuk Resolved Contacts

## 📝 Deskripsi
Ketika user create new conversation dengan contact yang:
1. **Belum pernah di-chat** (no existing room), ATAU
2. **Conversation sebelumnya sudah resolved** (status = 3)

Maka sistem akan membuat **conversation baru dengan status Unassigned (1)**.

## 🎯 Business Logic

### Skenario 1: Contact Belum Pernah Di-Chat
```
User pilih contact yang belum pernah di-chat
    ↓
Click "Create"
    ↓
System tidak menemukan existing room
    ↓
✅ Create NEW conversation (status = 1 Unassigned)
    ↓
Navigate ke ChatScreen dengan conversation baru
```

### Skenario 2: Contact Dengan Resolved Conversation
```
User pilih contact dengan resolved conversation (status = 3)
    ↓
Click "Create"
    ↓
System menemukan existing room dengan status = 3
    ↓
✅ Ignore existing resolved room
    ↓
✅ Create NEW conversation (status = 1 Unassigned)
    ↓
Navigate ke ChatScreen dengan conversation baru
```

### Skenario 3: Contact Dengan Active Conversation
```
User pilih contact dengan active conversation (status = 1 atau 2)
    ↓
Click "Create"
    ↓
System menemukan existing active room
    ↓
✅ Open existing conversation (NO create new)
    ↓
Navigate ke ChatScreen dengan existing conversation
```

## 📊 Status Flow

| Existing Status | Action | Result |
|-----------------|--------|--------|
| No Room | Create New | ✅ New conversation (status = 1) |
| Unassigned (1) | Open Existing | ✅ Open existing conversation |
| Assigned (2) | Open Existing | ✅ Open existing conversation |
| **Resolved (3)** | **Create New** | **✅ New conversation (status = 1)** |
| Archived (4) | Create New | ✅ New conversation (status = 1) |

## 🔧 Perubahan Kode

### File: `lib/presentation/widgets/new_conversation_dialog.dart`

#### Before:
```dart
// Check for existing room
existingRoom = chatState.rooms.firstWhere(
  (room) => room.ctId == targetId || room.ctRealId == targetId,
  orElse: () => null,
);

if (existingRoom != null) {
  // Always open existing room
  Navigator.push(ChatScreen(room: existingRoom));
}
```

#### After:
```dart
// Check for existing room
existingRoom = chatState.rooms.firstWhere(
  (room) => room.ctId == targetId || room.ctRealId == targetId,
  orElse: () => Room(id: '', ...),
);

// FIXED: If room exists but is resolved (status = 3), treat as new conversation
if (existingRoom.id.isNotEmpty) {
  if (existingRoom.status == 3) {
    print('Found resolved room: ${existingRoom.id} - Creating new conversation instead');
    existingRoom = null; // Force create new conversation
  } else {
    print('Found existing active room: ${existingRoom.id} (status: ${existingRoom.status})');
  }
}

// If existingRoom is null, create new conversation
if (existingRoom == null) {
  existingRoom = Room(
    id: targetId,
    ctId: targetId,
    name: targetName,
    status: 1, // ← Unassigned
    channelId: selectedChannelId,
    // ...
  );
}

Navigator.push(ChatScreen(room: existingRoom));
```

## 🧪 Testing

### Test 1: Contact Belum Pernah Chat
**Steps:**
1. Buka New Conversation dialog
2. Pilih Contact yang **belum pernah di-chat**
3. Pilih Channel & Account
4. Click **"Create"**

**Expected:**
- ✅ Navigate ke ChatScreen
- ✅ Room status = **Unassigned (1)**
- ✅ Input enabled (bisa kirim pesan)
- ✅ Empty messages (no previous messages)

### Test 2: Contact Dengan Resolved Conversation
**Steps:**
1. Buka conversation dengan contact A
2. Mark as Resolved (status = 3)
3. Back ke home screen
4. Buka New Conversation dialog
5. Pilih **contact A yang sama**
6. Click **"Create"**

**Expected:**
- ✅ Navigate ke ChatScreen dengan **conversation baru**
- ✅ Room status = **Unassigned (1)** (bukan 3!)
- ✅ Input enabled (bisa kirim pesan)
- ✅ Messages kosong (fresh start)
- ✅ Old resolved conversation tetap ada di backend

### Test 3: Contact Dengan Active Conversation
**Steps:**
1. Buka conversation dengan contact B (status Assigned/Unassigned)
2. Back ke home screen
3. Buka New Conversation dialog
4. Pilih **contact B yang sama**
5. Click **"Create"**

**Expected:**
- ✅ Navigate ke ChatScreen
- ✅ Open **existing conversation** (bukan buat baru)
- ✅ Room status = sama dengan sebelumnya
- ✅ Input enabled
- ✅ All previous messages tetap ada

## 💡 Why This Feature?

### Problem:
Sebelumnya, jika conversation sudah resolved:
- ❌ User tidak bisa chat lagi (input disabled)
- ❌ Tidak ada cara mudah untuk reopen conversation
- ❌ User stuck - mau kirim pesan tapi conversation resolved

### Solution:
Dengan fitur ini:
- ✅ User bisa create new conversation dengan contact yang sama
- ✅ Old resolved conversation tetap archived/preserved
- ✅ New conversation start fresh dengan status Unassigned
- ✅ Clear separation antara old resolved vs new active conversation

## 📝 Notes

### 1. New Room ID
Saat create new conversation:
- `roomId` = `targetId` (contactId)
- Backend akan generate room ID yang unique
- Multiple rooms bisa exist untuk contact yang sama (old resolved + new active)

### 2. History Preservation
- Old resolved conversation **TIDAK DIHAPUS**
- Old conversation masih bisa diakses dari archived/resolved list
- New conversation adalah conversation terpisah

### 3. Status Unassigned
New conversation selalu dimulai dengan status **Unassigned (1)**:
- Belum di-assign ke agent manapun
- Bisa auto-assign based on rules/bot
- Manual assign juga bisa

### 4. Duplicate Prevention
System hanya prevent duplicate untuk **active conversations** (status 1, 2):
- Status 1 (Unassigned): Open existing
- Status 2 (Assigned): Open existing
- Status 3 (Resolved): Create new ✅
- Status 4 (Archived): Create new ✅

## 🔄 Use Cases

### Use Case 1: Follow-up setelah Resolved
```
Customer: "Masalah saya sudah selesai, terima kasih"
Agent: Mark as Resolved
--- Next day ---
Customer: "Ada pertanyaan baru"
Agent: Create New Conversation
✅ Fresh conversation, tidak mix dengan old issue
```

### Use Case 2: Seasonal Customer
```
Customer orders in January → Resolved
Customer orders in June → Create New
✅ Setiap order = separate conversation
✅ Easy tracking per transaction/issue
```

### Use Case 3: Different Issue
```
Issue 1: "Refund request" → Resolved
Issue 2: "New order inquiry" → Create New
✅ Clear separation per issue
✅ Better organization and reporting
```

## 🎯 Summary

✅ Contact yang belum pernah chat → Create new conversation (status = 1)  
✅ Contact dengan resolved conversation → Create new conversation (status = 1)  
✅ Contact dengan active conversation → Open existing conversation  
✅ Old resolved conversations preserved (tidak hilang)  
✅ User bisa chat lagi setelah conversation resolved
