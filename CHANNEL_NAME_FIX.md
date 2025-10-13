# Channel Name Display Fix

## Problem
The home screen was showing inconsistent or outdated bot/channel names compared to the chat screen AppBar. For example:
- Home screen: "Not Found" or "Bot WA"
- Chat screen AppBar: "Bot" or "Bot W"

## Root Cause
The home screen API endpoint (`/Services/Chat/Chatrooms/List`) returns the bot/account name in the `ChAcc` field:

```json
{
  "Id": 728385619223301,
  "ChAcc": "Bot",
  "ChId": 1,
  "ChAccId": 706026840646405,
  ...
}
```

However, the Room model was only using `ChAcc` for the `channelName` property, not for `accountName`. The `_getBotName()` method in `room_list_widget.dart` prioritizes `accountName` and `botName` over `channelName`, so it would fall back to AccountService or generic names.

## Solution

### 1. Updated Room Model Parsing (`chat_models.dart`)
Modified `Room.fromJson()` to map `ChAcc` to `accountName` when `AccNm` is not available:

```dart
// Priority: AccNm > ChAcc (if not "Not Found") > null
final accountName = json['AccNm'] ?? 
                   json['AccountName'] ?? 
                   (channelNameRaw != null && 
                    channelNameRaw.toString().isNotEmpty && 
                    channelNameRaw.toString() != 'Not Found' 
                    ? channelNameRaw.toString() 
                    : null);
```

**Result:** The home screen now directly uses the bot name from the API response as `accountName`.

### 2. Added AccountService Refresh on Pull-to-Refresh (`home_screen.dart`)
Added refresh of AccountService cache when user pulls to refresh:

```dart
Future<void> _handleRefresh() async {
  try {
    // Refresh AccountService to get latest account names
    try {
      await AccountService().refreshAccountMappings();
      print('✅ Account mappings refreshed on pull-to-refresh');
    } catch (e) {
      print('⚠️ Failed to refresh account mappings: $e');
    }
    
    // ... continue with room loading
  }
}
```

**Result:** Users can manually sync latest account names from backend by pulling to refresh.

### 3. Name Display Priority (already implemented in `room_list_widget.dart`)
The `_getBotName()` method follows this priority:
1. `accountName` (from `AccNm` or `ChAcc`)
2. `botName` (from `BotNm`)
3. AccountService lookup
4. `channelName` (if not "Not Found")
5. Generic fallback based on `channelId`

## Testing
1. **Home Screen API Response:**
   - `ChAcc: "Bot"` → `room.accountName = "Bot"`
   - `_getBotName()` returns `"Bot"` (priority 1)

2. **Chat Screen API Response:**
   - `AccNm: "Bot"` → `room.accountName = "Bot"`
   - AppBar displays `"Bot"`

3. **Pull to Refresh:**
   - Changes made on web interface
   - Pull to refresh on mobile
   - AccountService cache updates
   - Room names update to match backend

## Result
✅ Home screen and chat screen now show consistent bot/channel names  
✅ Names dynamically reflect backend changes after refresh  
✅ No more "Not Found" placeholders  
✅ No more stale cache issues
