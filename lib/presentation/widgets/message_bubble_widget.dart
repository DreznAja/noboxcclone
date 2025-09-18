import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'audio_player_widget.dart';
import '../../core/models/chat_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/app_config.dart';
import '../../core/utils/message_detection_utils.dart';
import '../../core/utils/message_utils.dart';
import '../screens/media/image_viewer_screen.dart';
import '../screens/media/video_player_screen.dart';

class MessageBubbleWidget extends StatelessWidget {
  final ChatMessage message;
  final bool showSenderInfo;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  const MessageBubbleWidget({
    super.key,
    required this.message,
    this.showSenderInfo = true,
    this.isSelected = false,
    this.onLongPress,
    this.onTap,
    this.onReply,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = MessageDetectionUtils.isAgentMessage(message);
    
    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Message container
            Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Message bubble - now takes full width without avatars
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.85, // Increased from 0.75 to 0.85
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        // Reply preview
                        if (message.replyId != null) _buildReplyPreview(context, isMe),
                        
                        // Message content
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? (isMe ? AppTheme.primaryColor.withOpacity(0.8) : AppTheme.otherMessageColor.withOpacity(0.8))
                                : (isMe ? AppTheme.primaryColor : Colors.white),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isMe ? 18 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMessageContent(context, isMe),
                              const SizedBox(height: 4),
                              _buildTimestampRow(isMe),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to convert UTC timestamp to local Indonesian time
  DateTime _getLocalTime(DateTime utcTime) {
    // Assuming the server sends UTC time and we need to convert to WIB (UTC+7)
    // Adjust the offset based on your location:
    // WIB (Jakarta, Java): UTC+7
    // WITA (Central Indonesia): UTC+8  
    // WIT (Eastern Indonesia): UTC+9
    
    const int timezoneOffsetHours = 7; // Change this based on your timezone
    return utcTime.add(Duration(hours: timezoneOffsetHours));
  }

  Widget _buildTimestampRow(bool isMe) {
    // Convert to local time before formatting
    final localTime = _getLocalTime(message.timestamp);
    
    // Format timestamp in Indonesian format
    final dateFormat = DateFormat('dd MMM, HH:mm', 'id_ID');
    final formattedTime = dateFormat.format(localTime);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          formattedTime,
          style: TextStyle(
            fontSize: 11,
            color: isMe ? Colors.white70 : AppTheme.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          _buildAckIcon(),
        ],
      ],
    );
  }

  Widget _buildReplyPreview(BuildContext context, bool isMe) {
    if (message.replyId == null) return const SizedBox.shrink();
    
    // Get reply content and sender info
    final replyContent = _getReplyContent();
    final replySender = _getReplySender();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.15) : const Color(0xFFE8F5E8),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white : const Color(0xFF25D366), 
            width: 4
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sender name with proper styling
          Text(
            replySender,
            style: TextStyle(
              fontSize: 13,
              color: isMe ? Colors.white.withOpacity(0.9) : const Color(0xFF25D366),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 1),
          // Reply content
          _buildReplyContentWidget(isMe),
        ],
      ),
    );
  }
  
  String _getReplyContent() {
    // If we have reply message text, use it (with type prefix for media)
    final replyText = message.replyMessage?.trim() ?? '';
    
    if (message.replyType == null) {
      return replyText.isNotEmpty ? replyText : 'Message';
    }
    
    switch (message.replyType!) {
      case 1: // Text
        return replyText.isNotEmpty ? replyText : 'Text message';
      case 2: // Audio
        return replyText.isNotEmpty ? '🔊 $replyText' : '🔊 Audio';
      case 3: // Image
        return replyText.isNotEmpty ? replyText : '📷 Photo';
      case 4: // Video
        return replyText.isNotEmpty ? replyText : '🎥 Video';
      case 5: // Document
        return replyText.isNotEmpty ? '📄 $replyText' : '📄 Document';
      case 7: // Sticker
        return '🌟 Sticker';
      case 9: // Location
        return replyText.isNotEmpty ? replyText : '📍 Location';
      default:
        return replyText.isNotEmpty ? replyText : 'Message';
    }
  }
  
  String _getReplySender() {
    // Check if reply is from agent or customer
    if (message.replyFrom != null) {
      // Create a temporary message to check if it's from agent
      final tempMessage = ChatMessage(
        id: 'temp_reply_check',
        roomId: message.roomId,
        from: message.replyFrom!,
        agentId: 0, // Will be determined by detection logic
        type: 1,
        timestamp: DateTime.now(),
      );
      
      final isFromAgent = MessageDetectionUtils.isAgentMessage(tempMessage);
      return isFromAgent ? 'You' : message.replyGrpMember ?? 'Customer';
    }
    
    return 'Unknown';
  }
  
  Widget _buildReplyContentWidget(bool isMe) {
    final replyContent = _getReplyContent();
    
    // Handle media replies with thumbnails
    if ((message.replyType == 3 || message.replyType == 7 || message.replyType == 4) && 
        message.replyFiles != null && message.replyFiles!.isNotEmpty) {
      try {
        final dynamic parsed = jsonDecode(message.replyFiles!);
        String? imageUrl;
        
        if (parsed is List && parsed.isNotEmpty) {
          final fileInfo = parsed[0];
          if (fileInfo is Map<String, dynamic>) {
            final filename = fileInfo['Filename'] ?? fileInfo['filename'];
            if (filename != null) {
              imageUrl = filename.toString().startsWith('http') 
                  ? filename.toString()
                  : '${AppConfig.baseUrl}upload/$filename';
            }
          }
        }
        
        if (imageUrl != null) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Media thumbnail
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.grey.shade300,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: 36,
                    height: 36,
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade200,
                      child: Icon(
                        message.replyType == 4 ? Icons.videocam : Icons.image,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade200,
                      child: Icon(
                        message.replyType == 4 ? Icons.videocam : Icons.image,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Reply text content
              Expanded(
                child: Text(
                  replyContent,
                  style: TextStyle(
                    fontSize: 14,
                    color: isMe ? Colors.white.withOpacity(0.85) : const Color(0xFF4A4A4A),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }
      } catch (e) {
        print('Error parsing reply files: $e');
      }
    }
    
    // Text-only reply or fallback
    return Text(
      replyContent,
      style: TextStyle(
        fontSize: 14,
        color: isMe ? Colors.white.withOpacity(0.85) : const Color(0xFF4A4A4A),
        height: 1.2,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isMe) {
    // Check if this is a location message (text message with location data)
    if (message.type == 1 && MessageUtils.isLocationMessage(message.message)) {
      return _buildLocationMessage(isMe);
    }
    
    switch (message.type) {
      case 1: // Text
        return _buildTextMessage(isMe);
      case 2: // Audio
        return _buildAudioMessage(isMe);
      case 3: // Image
        return _buildImageMessage(context, isMe);
      case 4: // Video
        return _buildVideoMessage(context, isMe);
      case 5: // Document
        return _buildDocumentMessage(isMe);
      case 7: // Sticker
        return _buildStickerMessage(context);
      case 9: // Location
        return _buildLocationMessage(isMe);
      default:
        return _buildTextMessage(isMe);
    }
  }

  Widget _buildTextMessage(bool isMe) {
    // Clean the message text using utility function
    final cleanMessage = MessageDetectionUtils.cleanMessageContent(message.message ?? '');
     
    return Text(
      cleanMessage,
      style: TextStyle(
        color: isMe ? Colors.white : AppTheme.textPrimary,
        fontSize: 16,
        height: 1.3,
      ),
    );
  }

  Widget _buildImageMessage(BuildContext context, bool isMe) {
    final imageUrl = _getFileUrl();
    // For media messages, caption is in the message field
    String? caption = message.message?.trim();
    final hasCaption = caption != null && caption.isNotEmpty;
    
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image, 
              size: 48, 
              color: isMe ? Colors.white70 : Colors.grey
            ),
            const SizedBox(height: 8),
            Text(
              'Image not available', 
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey, 
                fontSize: 12
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    print('Loading image from URL: $imageUrl'); // Debug log

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: GestureDetector(
            onTap: () {
              // Navigate to full-screen image viewer
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ImageViewerScreen(
                    imageUrl: imageUrl,
                    caption: hasCaption ? caption : null,
                  ),
                ),
              );
            },
            child: Hero(
              tag: imageUrl,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                httpHeaders: const {
                  'User-Agent': 'NoboxChat/1.0',
                },
                placeholder: (context, url) => Container(
                  width: 200,
                  height: 200,
                  color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 200,
                  height: 200,
                  color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey.shade200,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image, 
                        size: 48, 
                        color: isMe ? Colors.white70 : Colors.grey
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load image\n${error.toString()}', 
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.grey, 
                          fontSize: 12
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Caption (if exists)
        if (hasCaption) ...[
          const SizedBox(height: 8),
          Text(
            MessageDetectionUtils.cleanMessageContent(caption!),
            style: TextStyle(
              color: isMe ? Colors.white : AppTheme.textPrimary,
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVideoMessage(BuildContext context, bool isMe) {
    final videoUrl = _getFileUrl();
    
    // Caption is in message field for video messages
    String? caption = message.message?.trim();
    final hasCaption = caption != null && caption.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Video player
        GestureDetector(
          onTap: () {
            if (videoUrl != null && videoUrl.isNotEmpty) {
              // Navigate to fullscreen video player
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(
                    videoUrl: videoUrl,
                    caption: hasCaption ? caption : null,
                  ),
                ),
              );
            }
          },
          child: Container(
            width: 200,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isMe ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Play button with subtle animation
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                
                // Video icon indicator
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.videocam,
                          color: Colors.white,
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Video',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Tap to play hint
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Tap to play',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Caption (if exists)
        if (hasCaption) ...[
          const SizedBox(height: 8),
          Text(
            MessageDetectionUtils.cleanMessageContent(caption!),
            style: TextStyle(
              color: isMe ? Colors.white : AppTheme.textPrimary,
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAudioMessage(bool isMe) {
    final audioUrl = _getFileUrl();
    
    if (audioUrl == null || audioUrl.isEmpty) {
      return Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 24,
              color: isMe ? Colors.white70 : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Voice note not available',
                style: TextStyle(
                  fontSize: 14,
                  color: isMe ? Colors.white70 : Colors.red,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Use the new AudioPlayerWidget
    return AudioPlayerWidget(
      audioUrl: audioUrl,
      isMe: isMe,
      caption: message.message?.trim().isNotEmpty == true ? message.message : null,
    );
  }

  Widget _buildDocumentMessage(bool isMe) {
    String fileName = 'Document';
    final documentUrl = _getFileUrl();
    
    // Caption is in message field for document messages
    String? caption = message.message?.trim();
    final hasCaption = caption != null && caption.isNotEmpty;
    
    // Try to extract filename from file data
    if (message.file != null) {
      try {
        final fileData = message.file!;
        if (fileData.startsWith('[') || fileData.startsWith('{')) {
          final dynamic parsed = jsonDecode(fileData);
          if (parsed is List && parsed.isNotEmpty) {
            final fileInfo = parsed[0];
            if (fileInfo is Map<String, dynamic>) {
              fileName = fileInfo['OriginalName'] ?? fileInfo['originalName'] ?? fileName;
            }
          } else if (parsed is Map<String, dynamic>) {
            fileName = parsed['OriginalName'] ?? parsed['originalName'] ?? fileName;
          }
        }
      } catch (e) {
        print('Error parsing document data: $e');
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Document preview
        GestureDetector(
          onTap: () {
            if (documentUrl != null) {
              // TODO: Open document
              print('Open document: $documentUrl');
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.insert_drive_file, 
                  size: 32,
                  color: isMe ? Colors.white : AppTheme.primaryColor,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isMe ? Colors.white : AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Document',
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe ? Colors.white70 : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Caption/message (if exists)
        if (hasCaption) ...[
          const SizedBox(height: 8),
          Text(
            MessageDetectionUtils.cleanMessageContent(caption!),
            style: TextStyle(
              color: isMe ? Colors.white : AppTheme.textPrimary,
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStickerMessage(BuildContext context) {
    final stickerUrl = _getFileUrl();
    if (stickerUrl == null || stickerUrl.isEmpty) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_emotions, size: 32, color: Colors.grey),
            SizedBox(height: 4),
            Text('Sticker', style: TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      );
    }

    print('Loading sticker from URL: $stickerUrl'); // Debug log

    return GestureDetector(
      onTap: () {
        // Navigate to full-screen image viewer for stickers too
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ImageViewerScreen(
              imageUrl: stickerUrl,
            ),
          ),
        );
      },
      child: Hero(
        tag: stickerUrl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: stickerUrl,
            width: 120,
            height: 120,
            fit: BoxFit.contain,
            httpHeaders: const {
              'User-Agent': 'NoboxChat/1.0',
            },
            errorWidget: (context, url, error) => Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_emotions, size: 32, color: Colors.grey),
                  SizedBox(height: 4),
                  Text('Failed to load sticker', style: TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationMessage(bool isMe) {
    final messageText = message.message ?? '';
    
    // Extract coordinates from message text
    double? latitude;
    double? longitude;
    String? mapsUrl;
    
    // Parse location from message text
    final locationRegex = RegExp(r'Location: (-?\d+\.\d+), (-?\d+\.\d+)');
    final match = locationRegex.firstMatch(messageText);
    
    if (match != null) {
      latitude = double.tryParse(match.group(1)!);
      longitude = double.tryParse(match.group(2)!);
    }
    
    // Extract Google Maps URL if present
    final urlRegex = RegExp(r'https://maps\.google\.com/maps\?q=(-?\d+\.\d+),(-?\d+\.\d+)');
    final urlMatch = urlRegex.firstMatch(messageText);
    if (urlMatch != null) {
      mapsUrl = urlMatch.group(0);
    }
    
    return GestureDetector(
      onTap: () {
        if (mapsUrl != null) {
          // Open in maps app
          _openInMaps(mapsUrl);
        } else if (latitude != null && longitude != null) {
          // Create maps URL and open
          final url = 'https://maps.google.com/maps?q=$latitude,$longitude';
          _openInMaps(url);
        }
      },
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location header
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 20,
                  color: isMe ? Colors.white : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Location',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isMe ? Colors.white : AppTheme.textPrimary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Map preview placeholder
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: isMe ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.map,
                    size: 48,
                    color: isMe ? Colors.white70 : AppTheme.textSecondary,
                  ),
                  Positioned(
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Tap to open in Maps',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Coordinates display
            if (latitude != null && longitude != null)
              Text(
                'Lat: ${latitude!.toStringAsFixed(6)}, Lng: ${longitude!.toStringAsFixed(6)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isMe ? Colors.white70 : AppTheme.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
            
            // Open in maps button
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? Colors.white.withOpacity(0.2) : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isMe ? Colors.white.withOpacity(0.3) : AppTheme.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: isMe ? Colors.white : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Open in Maps',
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe ? Colors.white : AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _openInMaps(String url) {
    // Open the location in the default maps app
    print('Opening maps URL: $url');
    
    try {
      launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      print('Failed to open maps: $e');
      // Fallback: show URL in a dialog
      // This would need context, so we'll just print for now
    }
  }

  String? _getFileUrl() {
    if (message.file != null) {
      try {
        final fileData = message.file!;
        
        // Check if it's a JSON string
        if (fileData.startsWith('[') || fileData.startsWith('{')) {
          final dynamic parsed = jsonDecode(fileData);
          if (parsed is List && parsed.isNotEmpty) {
            final fileInfo = parsed[0];
            if (fileInfo is Map<String, dynamic>) {
              final filename = fileInfo['Filename'] ?? fileInfo['filename'];
              if (filename != null) {
                // Check if filename is already a full URL
                if (filename.toString().startsWith('http://') || filename.toString().startsWith('https://')) {
                  return filename.toString();
                }
                // Construct proper URL for uploaded files
                return '${AppConfig.baseUrl}upload/$filename';
              }
            }
          } else if (parsed is Map<String, dynamic>) {
            final filename = parsed['Filename'] ?? parsed['filename'];
            if (filename != null) {
              // Check if filename is already a full URL
              if (filename.toString().startsWith('http://') || filename.toString().startsWith('https://')) {
                return filename.toString();
              }
              // Construct proper URL for uploaded files
              return '${AppConfig.baseUrl}upload/$filename';
            }
          }
        }
        
        // If it's already a URL, validate it
        if (fileData.startsWith('http://') || fileData.startsWith('https://')) {
          return fileData;
        }
        
        // If it's just a filename, construct URL
        if (!fileData.contains('://') && !fileData.startsWith('file:///')) {
          return '${AppConfig.baseUrl}upload/$fileData';
        }
        
        return null;
      } catch (e) {
        print('Error parsing file data: $e');
        return null;
      }
    }
    
    // Also check the files field as fallback
    if (message.files != null) {
      try {
        final filesData = message.files!;
        if (filesData.startsWith('[') || filesData.startsWith('{')) {
          final dynamic parsed = jsonDecode(filesData);
          if (parsed is List && parsed.isNotEmpty) {
            final fileInfo = parsed[0];
            if (fileInfo is Map<String, dynamic>) {
              final filename = fileInfo['Filename'] ?? fileInfo['filename'];
              if (filename != null) {
                // Check if filename is already a full URL
                if (filename.toString().startsWith('http://') || filename.toString().startsWith('https://')) {
                  return filename.toString();
                }
                // Construct proper URL for uploaded files
                return '${AppConfig.baseUrl}upload/$filename';
              }
            }
          }
        }
      } catch (e) {
        print('Error parsing files data: $e');
      }
    }
    
    return null;
  }

  Widget _buildAckIcon() {
    IconData icon;
    Color color;

    switch (message.ack) {
      case 1: // Pending
        icon = Icons.access_time;
        color = AppTheme.textSecondary;
        break;
      case 2: // Sent
        icon = Icons.check;
        color = AppTheme.textSecondary;
        break;
      case 3: // Delivered
        icon = Icons.done_all;
        color = AppTheme.textSecondary;
        break;
      case 4: // Failed
        icon = Icons.error_outline;
        color = AppTheme.errorColor;
        break;
      case 5: // Read
        icon = Icons.done_all;
        color = AppTheme.primaryColor;
        break;
      default:
        icon = Icons.access_time;
        color = AppTheme.textSecondary;
        break;
    }

    return Icon(
      icon,
      size: 14,
      color: color,
    );
  }
}