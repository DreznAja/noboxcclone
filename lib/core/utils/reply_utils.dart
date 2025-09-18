import 'dart:convert';

import 'package:nobox_chat/core/utils/message_detection_utils.dart';
import 'package:nobox_chat/core/utils/message_utils.dart';

import '../models/chat_models.dart';
import '../app_config.dart';

class ReplyUtils {
  /// Generate reply preview text based on message type (matching JavaScript logic)
  static String getReplyPreviewText(ChatMessage message) {
    switch (message.type) {
      case 1: // Text
        return message.message ?? 'Text message';
      case 2: // Audio
        return '🔊 Audio';
      case 3: // Image
        return message.message?.isNotEmpty == true 
            ? '🖼 ${message.message}' 
            : '🖼 Photo';
      case 4: // Video
        return message.message?.isNotEmpty == true 
            ? '🎬 ${message.message}' 
            : '🎬 Video';
      case 5: // Document
        return message.message?.isNotEmpty == true 
            ? '📁 ${message.message}' 
            : '📁 Document';
      case 7: // Sticker
        return '🌟 Sticker';
      case 9: // Location
        return message.message?.isNotEmpty == true 
            ? '📍 ${message.message}' 
            : '📍 Location';
      case 10: // Order
        return '🛒 Order';
      case 11: // Catalog
        return '📦 Catalog';
      case 12: // Contact
        return '👤 Contact';
      case 13: // Contacts
        return '👥 Contacts';
      case 14: // Interactive Order
        return '📋 Interactive Order';
      case 15: // Polling
        return '📊 Polling';
      case 16: // Unsupported
        return '❌ Unsupported Message';
      case 17: // Storage Limit
        return '❌ Storage Limit';
      case 18: // Channel Limit
        return '❌ Channel Limit';
      case 19: // Interactive List
        return '📝 Interactive List';
      case 21: // Interactive Button
        return '📟 Interactive Button';
      case 24: // Post
        return '🖼 Post';
      case 25: // Profile
        return '👤 Profile';
      case 26: // Sticker not supported
        return '🌟 Sticker not supported';
      case 27: // Template
        return '📃 Template Message';
      default:
        return message.message ?? 'Message';
    }
  }

  /// Get sender name for reply (matching JavaScript logic)
  static String getReplySenderName(ChatMessage originalMessage, ChatMessage? replyMessage) {
    if (replyMessage == null) return 'Unknown';
    
    // Check if reply is from agent or customer
    final isFromAgent = MessageDetectionUtils.isAgentMessage(replyMessage);
    
    if (isFromAgent) {
      return 'Me'; // Agent message
    } else {
      // Customer message - use contact name or default
      return 'Customer';
    }
  }

  /// Check if reply has media content (for preview)
  static bool hasReplyMedia(ChatMessage message) {
    if (message.replyType == null) return false;
    
    // Types that can have media
    final mediaTypes = [3, 7, 10, 24, 25]; // Image, Sticker, Order, Post, Profile
    return mediaTypes.contains(message.replyType) && 
           (message.replyFiles?.isNotEmpty == true);
  }

  /// Get media URL for reply preview
  static String? getReplyMediaUrl(ChatMessage message) {
    if (!hasReplyMedia(message)) return null;
    
    try {
      if (message.replyFiles != null) {
        final dynamic parsed = jsonDecode(message.replyFiles!);
        
        if (parsed is List && parsed.isNotEmpty) {
          final fileInfo = parsed[0];
          if (fileInfo is Map<String, dynamic>) {
            final filename = fileInfo['Filename'] ?? fileInfo['filename'];
            if (filename != null) {
              return filename.toString().startsWith('http') 
                  ? filename.toString()
                  : '${AppConfig.baseUrl}upload/$filename';
            }
          }
        }
      }
    } catch (e) {
      print('Error parsing reply media: $e');
    }
    
    return null;
  }

  /// Format reply data for sending (matching JavaScript structure)
  static Map<String, dynamic> formatReplyData(ChatMessage replyMessage) {
    return {
      'ReplyId': replyMessage.id,
      'ReplyType': replyMessage.type,
      'ReplyFrom': replyMessage.from,
      'ReplyMsg': replyMessage.message ?? '',
      'ReplyFiles': replyMessage.files ?? replyMessage.file ?? '',
      if (replyMessage.replyGrpMember != null) 
        'ReplyGrpMember': replyMessage.replyGrpMember,
    };
  }
}