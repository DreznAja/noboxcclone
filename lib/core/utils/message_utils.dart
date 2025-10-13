import 'dart:convert';
import '../models/chat_models.dart';
import '../app_config.dart';

class MessageUtils {
  static String formatMessage(String text) {
    // Convert WhatsApp-style formatting to Flutter rich text
    String result = text;
    
    // Bold text (*text*)
    result = result.replaceAllMapped(
      RegExp(r'\*([^*]+)\*'),
      (match) => '**${match.group(1)}**',
    );
    
    // Italic text (_text_)
    result = result.replaceAllMapped(
      RegExp(r'_([^_]+)_'),
      (match) => '*${match.group(1)}*',
    );
    
    // Strikethrough (~text~)
    result = result.replaceAllMapped(
      RegExp(r'~([^~]+)~'),
      (match) => '~~${match.group(1)}~~',
    );
    
    return result;
  }

  static String getMessageTypeDescription(int type) {
    switch (type) {
      case 1:
        return 'Text';
      case 2:
        return '🔊 Voice Note';
      case 3:
        return '🖼 Photo';
      case 4:
        return '🎬 Video';
      case 5:
        return '📁 Document';
      case 6:
        return 'System';
      case 7:
        return '🌟 Sticker';
      case 9:
        return '📍 Location';
      case 10:
        return '🛒 Order';
      case 11:
        return '📦 Catalog';
      case 12:
        return '👤 Contact';
      case 13:
        return '👥 Contacts';
      case 14:
        return '📋 Interactive Order';
      case 15:
        return '📊 Polling';
      case 16:
        return '❌ Unsupported Message';
      case 17:
        return '❌ Storage Limit';
      case 18:
        return '❌ Channel Limit';
      case 19:
        return '📝 Interactive List';
      case 21:
        return '📟 Interactive Button';
      case 24:
        return '🖼 Post';
      case 25:
        return '👤 Profile';
      case 26:
        return '🌟 Sticker not Support';
      case 27:
        return '📃 Template Message';
      default:
        return 'Message';
    }
  }

  static bool isLocationMessage(String? messageText) {
    if (messageText == null) return false;
    return messageText.contains('Location:') && 
           messageText.contains('https://maps.google.com/maps?q=');
  }

  static Map<String, double>? parseLocationFromMessage(String messageText) {
    final locationRegex = RegExp(r'Location: (-?\d+\.\d+), (-?\d+\.\d+)');
    final match = locationRegex.firstMatch(messageText);
    
    if (match != null) {
      final latitude = double.tryParse(match.group(1)!);
      final longitude = double.tryParse(match.group(2)!);
      
      if (latitude != null && longitude != null) {
        return {
          'latitude': latitude,
          'longitude': longitude,
        };
      }
    }
    
    return null;
  }
  static String getChannelName(int channelId) {
    switch (channelId) {
      case 1:
        return 'WhatsApp';
      case 1557:
      case 1561:
        return 'WhatsApp Business';
      case 2:
        return 'Telegram';
      case 3:
        return 'Instagram';
      case 4:
        return 'Messenger';
      case 6:
        return 'TikTok';
      case 19:
        return 'Email';
      case 1492:
        return 'Bukalapak';
      case 1502:
        return 'Blibli';
      case 1503:
        return 'Lazada';
      case 1504:
        return 'Shopee';
      case 1505:
      case 1562:
        return 'Tokopedia';
      case 1532:
        return 'OLX';
      case 1569:
        return 'Nobox Chat';
      default:
        return 'Unknown Channel';
    }
  }

  static bool isValidUrl(String url) {
    try {
      Uri.parse(url);
      return url.startsWith('http://') || url.startsWith('https://');
    } catch (e) {
      return false;
    }
  }

  static String generateMessageId() {
    // FIXED: Generate message ID that matches backend JavaScript format exactly
    // Based on backend: timestampPart (9 digits) + randomPart (6 digits) = 15 digits total
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final timestampStr = timestamp.toString();
    final timestampPart = timestampStr.substring(0, 9); // First 9 digits
    
    // Generate 6-digit random number (100000-999999)
    final random = DateTime.now().microsecond % 900000 + 100000;
    final randomPart = random.toString();
    
    final messageId = timestampPart + randomPart;
    
    // Ensure it's exactly 15 digits
    if (messageId.length != 15) {
      print('⚠️ Generated message ID length mismatch: ${messageId.length}, expected 15');
      // Fallback: use current timestamp + padding
      final fallbackId = timestamp.toString().substring(0, 15).padRight(15, '0');
      print('🔄 Using fallback message ID: $fallbackId');
      return fallbackId;
    }
    
    print('✅ Generated message ID: $messageId (length: ${messageId.length})');
    return messageId;
  }

  static Map<String, dynamic> parseVCard(String vcard) {
    final Map<String, dynamic> fields = {};
    final lines = vcard.split(RegExp(r'\r\n|\r|\n'));
    
    for (final line in lines) {
      if (line.toLowerCase().startsWith('fn:')) {
        fields['fn'] = line.substring(3);
      } else if (line.toLowerCase().startsWith('tel:')) {
        fields['tel'] = line.substring(4);
      }
      // Add more vCard parsing as needed
    }
    
    return fields;
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}