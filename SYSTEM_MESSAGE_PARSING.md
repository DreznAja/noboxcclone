# System Message Parsing - Archived Conversations

## Problem
Messages dari archived conversations muncul sebagai JSON mentah:
```
{"msg":"Site.Inbox.HasResolveBy","user":null,"userHandle":1}
{"msg":"Site.Inbox.HasArchiveBy","user":null,"userHandle":1645}
```

## Solution
Menambahkan parser untuk system messages agar tampil human-readable.

## Implementation

### File Modified: `lib/core/utils/message_detection_utils.dart`

#### 1. **Added JSON Parsing Function**

```dart
static String parseSystemMessage(String jsonString) {
  try {
    final json = _tryParseJson(jsonString);
    if (json == null) return jsonString;
    
    final msg = json['msg'] as String?;
    final user = json['user'];
    
    if (msg == null) return jsonString;
    
    // Parse different system messages
    if (msg == 'Site.Inbox.HasResolveBy') {
      final userName = user ?? 'Agent';
      return '🟢 Conversation resolved by $userName';
    } else if (msg == 'Site.Inbox.HasArchiveBy') {
      final userName = user ?? 'Agent';
      return '📦 Conversation archived by $userName';
    }
    // ... more cases
    
  } catch (e) {
    return jsonString;
  }
}
```

#### 2. **Updated cleanMessageContent()**

```dart
static String cleanMessageContent(String content) {
  // Check if it's a system message (JSON format)
  if (content.trim().startsWith('{') && content.trim().endsWith('}')) {
    final parsed = parseSystemMessage(content);
    if (parsed != content) {
      return parsed; // Return parsed system message
    }
  }
  
  // Regular message cleaning
  return content
      .replaceAll('\n\nSent from NoBox.Ai trial account', '')
      .replaceAll('\n\nSent by NoBox.Ai', '')
      .replaceAll('\n\nDikirim pakai NoBox.Ai', '')
      .trim();
}
```

## Supported System Messages

| JSON Message | Display Format |
|-------------|----------------|
| `Site.Inbox.HasResolveBy` | 🟢 Conversation resolved by {user} |
| `Site.Inbox.HasArchiveBy` | 📦 Conversation archived by {user} |
| `Site.Inbox.HasRestoreBy` | 🔄 Conversation restored by {user} |
| `Site.Inbox.HasAssignBySystem` | 🤖 Conversation assigned by system |
| `HasAsign/HasAssign` | 👤 Conversation assigned to {user} |
| `MuteBot` | 🔇 Bot muted for this conversation |
| `UnmuteBot` | 🔊 Bot unmuted for this conversation |

## Before & After

### Before:
```
{"msg":"Site.Inbox.HasResolveBy","user":null,"userHandle":1}
{"msg":"Site.Inbox.HasArchiveBy","user":null,"userHandle":1645}
```

### After:
```
🟢 Conversation resolved by Agent
📦 Conversation archived by Agent
```

## How It Works

1. **Detection**: `cleanMessageContent()` checks if message starts with `{` and ends with `}`
2. **Parsing**: Uses `jsonDecode()` to parse the JSON string
3. **Mapping**: Maps system message codes to human-readable text with emojis
4. **Fallback**: If parsing fails, returns original message

## Edge Cases Handled

- ✅ Invalid JSON → returns original message
- ✅ Unknown message types → cleans the code and returns readable text
- ✅ Null user → uses "Agent" as default
- ✅ Non-JSON messages → processes normally

## Testing

Test with archived conversations containing system messages:
1. Open archived conversation
2. Check for system messages (resolve, archive, assign, etc.)
3. Verify they display as human-readable text with icons

## UI Implementation

### System Message Widget

System messages ditampilkan dengan styling khusus:

```dart
Widget _buildSystemMessage(BuildContext context) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    child: Row(
      children: [
        // Left line
        Expanded(
          child: Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
        ),
        
        // Message content with timestamp
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            cleanMessage + ' - ' + formattedTime,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        
        // Right line
        Expanded(
          child: Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
        ),
      ],
    ),
  );
}
```

### Display Format:
```
━━━━━━  🟢 Conversation resolved by Agent - 09 Okt 2025 14:04  ━━━━━━
━━━━━━  📦 Conversation archived by Agent - 09 Okt 2025 14:04  ━━━━━━
```

## Future Enhancements

- [x] Custom styling for system messages (DONE)
- [ ] Add more system message types as they're discovered
- [ ] Localization for different languages
- [ ] Click actions on system messages (e.g., see who resolved)

---
**Created**: 2025-10-09
**Author**: AI Assistant (Claude)
**Related**: ARCHIVED_CONVERSATION_BUG_FIX.md
