# Fix: Error 500 Ketika Filter Account

## Problem
Ketika memfilter conversation berdasarkan Account, aplikasi menampilkan error 500:
```
DioException [bad response]: This exception was thrown because the response has a status code of 500
The status code of 500 has the following meaning: "Server error - the server failed to fulfil an apparently valid request"
```

## Root Cause Analysis

### 1. Field Mismatch
Backend chatroom list API menggunakan field `ChAcc` (Channel Account) yang berisi **nama account** (string), bukan ID account (integer).

Contoh data dari API:
```json
{
  "Id": "123",
  "ChAcc": "WhatsApp Business",  // Nama account (string)
  "CtRealNm": "John Doe",
  // ...
}
```

### 2. Previous Implementation (WRONG)
**FilterOptions.toMap()** (line 115 di filter_models.dart):
```dart
if (accountId != null) filters['AccountId'] = [int.parse(accountId!)];
```

Masalah:
- ❌ Mengirim field `AccountId` yang tidak dikenali backend
- ❌ Mengkonversi ke integer, padahal backend expect string nama account
- ❌ Backend tidak bisa memproses field ini → error 500

**FilterDialog** (line 478 sebelumnya):
```dart
value: item.id,  // Menyimpan ID account (angka)
```

Masalah:
- ❌ Menyimpan ID account, bukan nama account
- ❌ Saat di-convert di FilterOptions, tetap salah karena field dan tipenya salah

## Solution

### 1. Fix FilterOptions.toMap() - Use Client-Side Filtering
**File**: `lib/core/models/filter_models.dart` (line 115-121)

```dart
// FIXED: Account filter using client-side filtering
// Backend ChAcc/AccNm filter causes error 500
// Similar to FunnelId and TagId, we filter on client side
if (accountId != null) {
  filters['AccountFilter'] = accountId; // Temporary flag for client-side filtering
  print('📝 [FilterOptions] Account filter: $accountId (will filter client-side)');
}
```

Perbaikan:
- ✅ Menggunakan client-side filtering seperti Funnel dan Tag
- ✅ Tidak mengirim ke backend (menghindari error 500)
- ✅ Menyimpan nama account untuk filtering di client

### 2. Fix FilterDialog - Store Account Name Instead of ID
**File**: `lib/presentation/widgets/filter_dialog.dart`

#### a. Update Account Dropdown (line 276-282)
```dart
// Account - SPECIAL: Uses account name for ChAcc filter
_buildAccountDropdownField(
  'Account',
  _filters.accountId,
  _accounts,
  (value) => setState(() => _filters.accountId = value),
),
```

#### b. Add Special Dropdown Method (line 499-572)
```dart
// Special dropdown for Account filter - uses NAME as value instead of ID
// because backend ChAcc field expects account name, not ID
Widget _buildAccountDropdownField(
  String label,
  String? value,
  List<FilterDataItem> options,
  Function(String?) onChanged,
) {
  // ... same structure as _buildApiDropdownField ...
  items: options.map((FilterDataItem item) {
    return DropdownMenuItem<String>(
      // CRITICAL: Use NAME as value for ChAcc filter
      value: item.name,  // ← KEY CHANGE: name instead of id
      child: Text(
        item.name.isNotEmpty ? item.name : 'ID: ${item.id}',
        // ...
      ),
    );
  }).toList(),
  // ...
}
```

Perbaikan:
- ✅ Menyimpan **nama account** (bukan ID) di `_filters.accountId`
- ✅ Nilai yang disimpan sesuai dengan yang di-expect backend di field `ChAcc`

### 3. Add Client-Side Filtering in ChatProvider
**File**: `lib/core/providers/chat_provider.dart`

#### a. Remove AccountFilter before API call (line 365-385)
```dart
final accountFilter = finalFilters.remove('AccountFilter');
if (accountFilter != null) {
  print('🔍 [CHAT PROVIDER] Removed AccountFilter (client-side only): $accountFilter');
}
```

#### b. Apply client-side filtering (line 473-495)
```dart
// IMPORTANT: Client-side filtering for Account
// Backend ChAcc/AccNm filter causes error 500
if (filters != null && filters.containsKey('AccountFilter')) {
  final accountFilterValue = filters['AccountFilter'];
  print('🔍 [CHAT PROVIDER] Applying client-side Account filter');
  
  rooms = rooms.where((room) {
    // Check if room's channelName or accountName matches the filter
    final matchesChannelName = room.channelName == accountFilterValue;
    final matchesAccountName = room.accountName == accountFilterValue;
    return matchesChannelName || matchesAccountName;
  }).toList();
}
```

#### c. Also in loadMoreRooms (line 561-623)
Same filtering logic applied for pagination.

## Data Flow After Fix

1. **User selects account** from dropdown
   - Selected value = Account Name (string), e.g., "Bot BEAIR"
   
2. **FilterOptions.accountId** stores the name
   - accountId = "Bot BEAIR"

3. **FilterOptions.toMap()** creates client-side flag
   ```dart
   filters['AccountFilter'] = "Bot BEAIR"
   ```

4. **ChatProvider removes flag before API call**
   ```dart
   final accountFilter = finalFilters.remove('AccountFilter'); // Not sent to backend
   ```

5. **API Request** to `Services/Chat/Chatrooms/List` (NO ACCOUNT FILTER)
   ```json
   {
     "Take": 20,
     "Skip": 0,
     "EqualityFilter": {
       "St": [1, 2, 3]
       // AccountFilter NOT included
     }
   }
   ```

6. **Backend returns ALL rooms** (no error 500)
   - ✅ Returns all rooms with status 1, 2, 3
   - ✅ No error because no ChAcc/AccNm filter sent

7. **Client-side filtering applied**
   ```dart
   rooms = rooms.where((room) {
     return room.channelName == "Bot BEAIR" || 
            room.accountName == "Bot BEAIR";
   }).toList();
   ```

8. **Final result**
   - ✅ Only rooms matching "Bot BEAIR" displayed
   - ✅ No error 500

## Testing Steps

1. **Build dan jalankan aplikasi**
   ```bash
   flutter run
   ```

2. **Open filter dialog** dari home screen

3. **Select Account** dari dropdown
   - Pilih salah satu account, misal "WhatsApp Business"

4. **Click Apply**

5. **Verify results**:
   - ✅ Tidak ada error 500
   - ✅ List hanya menampilkan conversation dari account yang dipilih
   - ✅ Check console log untuk konfirmasi filter:
     ```
     📝 [FilterOptions] Account filter added: ChAcc = WhatsApp Business
     ```

6. **Test dengan account lain**
   - Pastikan filter bekerja untuk semua account

7. **Test kombinasi filter**
   - Account + Status
   - Account + Channel
   - Account + Chat Type
   - dll.

## Related Files Modified

1. **`lib/core/models/filter_models.dart`**
   - Line 115-121: Changed to use `AccountFilter` for client-side filtering

2. **`lib/presentation/widgets/filter_dialog.dart`**
   - Line 276-282: Changed to use `_buildAccountDropdownField`
   - Line 499-572: Added new `_buildAccountDropdownField` method that stores account name

3. **`lib/core/providers/chat_provider.dart`**
   - Line 370: Added `accountFilter` removal before API call
   - Line 383-385: Added logging for AccountFilter removal
   - Line 473-495: Added client-side Account filtering in `loadRooms`
   - Line 566: Added AccountFilter removal in `loadMoreRooms`
   - Line 617-623: Added client-side Account filtering in `loadMoreRooms`

## Notes

### Why ChAcc Uses Account Name, Not ID?
Berdasarkan Room model (`lib/core/models/chat_models.dart` line 76-96):
```dart
final channelNameRaw = json['ChAcc'];  // This is account name from API
final accountName = json['AccNm'] ?? 
                   (channelNameRaw != null && 
                    channelNameRaw.toString() != 'Not Found' 
                    ? channelNameRaw.toString() 
                    : null);
```

Field `ChAcc` di backend adalah string nama account, bukan foreign key ID. Ini berbeda dengan field lain seperti:
- `ChId` = Channel ID (integer)
- `CtRealId` = Contact ID (integer)
- `GrpId` = Group ID (integer)

### Other Filters Using Client-Side Filtering
Beberapa filter lain juga menggunakan client-side filtering karena backend limitation:
- **ReadStatus**: Backend filter trigger "mark as read" action
- **ChatType (Private)**: Backend tidak support `IsGrp=[0]` dengan baik
- **FunnelId**: Backend filter menyebabkan error 500
- **TagId**: Backend filter menyebabkan error 500
- **Account** (NEW): Backend `ChAcc`/`AccNm` filter menyebabkan error 500

## Conclusion
Error 500 saat filter Account disebabkan oleh:
1. Backend tidak support `ChAcc` atau `AccNm` filter di EqualityFilter
2. Mencoba mengirim field yang tidak di-support backend
3. Backend mengembalikan error 500 saat menerima filter tersebut

**Solusi Final**: Menggunakan **client-side filtering** seperti Funnel dan Tag:
- ✅ Tidak mengirim filter Account ke backend (menghindari error 500)
- ✅ Memfilter hasil di client berdasarkan `room.channelName` atau `room.accountName`
- ✅ Filter Account kini bekerja dengan benar tanpa error
