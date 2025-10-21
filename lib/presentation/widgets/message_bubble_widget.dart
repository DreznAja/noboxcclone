import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_player_widget.dart';
import '../../core/models/chat_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/app_config.dart';
import '../../core/utils/message_detection_utils.dart';
import '../../core/utils/message_utils.dart';
import '../screens/media/image_viewer_screen.dart';
import '../screens/media/image_gallery_viewer_screen.dart';
import '../screens/media/video_player_screen.dart';
import 'forward_dialog.dart';

class MessageBubbleWidget extends ConsumerWidget {
  final ChatMessage message;
  final List<ChatMessage>? allMessages; // All messages untuk gallery
  final bool showSenderInfo;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;

  const MessageBubbleWidget({
    super.key,
    required this.message,
    this.allMessages,
    this.showSenderInfo = true,
    this.isSelected = false,
    this.onLongPress,
    this.onTap,
    this.onReply,
    this.onForward,
    this.onCopy,
    this.onDelete,
  });

@override
Widget build(BuildContext context, WidgetRef ref) {
  final isDarkMode = ref.watch(themeProvider).isDarkMode;

    // Check if this is a system message
   if (MessageDetectionUtils.isSystemMessage(message)) {
    return _buildSystemMessage(context, isDarkMode); // TAMBAHKAN isDarkMode
  }
  
  final isMe = MessageDetectionUtils.isAgentMessage(message);
  
  return GestureDetector(
    onLongPress: onLongPress,
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.85,
                  ),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // Reply preview
                      if (message.replyId != null) _buildReplyPreview(context, isMe, isDarkMode), // TAMBAHKAN isDarkMode
                      
                      // Message content
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isMe 
                                  ? AppTheme.primaryColor.withOpacity(0.8) 
                                  : (isDarkMode 
                                      ? AppTheme.darkSurface.withOpacity(0.8) 
                                      : AppTheme.otherMessageColor.withOpacity(0.8))) // UPDATE INI
                              : (isMe 
                                  ? AppTheme.primaryColor 
                                  : (isDarkMode ? AppTheme.darkSurface : Colors.white)), // UPDATE INI
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: Radius.circular(isMe ? 12 : 2),
                            bottomRight: Radius.circular(isMe ? 2 : 12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08), // UPDATE INI
                              blurRadius: 1,
                              offset: const Offset(0, 0.5),
                            ),
                          ],
                        ),
                        child: _buildMessageContent(context, isMe, isDarkMode), // TAMBAHKAN isDarkMode
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

Widget _buildSystemMessage(BuildContext context, bool isDarkMode) {
  final cleanMessage = MessageDetectionUtils.cleanMessageContent(message.message ?? '');
  final localTime = message.timestamp.toLocal();
  final dateFormat = DateFormat('dd MMM yyyy HH:mm', 'id_ID');
  final formattedTime = dateFormat.format(localTime);
  
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    child: Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            height: 1,
            color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.shade300, // UPDATE
          ),
        ),
        
        Flexible(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cleanMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey.shade600, // UPDATE
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode 
                      ? AppTheme.darkTextSecondary.withOpacity(0.7) 
                      : Colors.grey.shade400, // UPDATE
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        
        Expanded(
          flex: 1,
          child: Container(
            height: 1,
            color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.shade300, // UPDATE
          ),
        ),
      ],
    ),
  );
}
  
  Widget _buildTimestampRow(bool isMe) {
    final localTime = message.timestamp.toLocal();
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

Widget _buildReplyPreview(BuildContext context, bool isMe, bool isDarkMode) {
  if (message.replyId == null || message.replyId!.isEmpty) return const SizedBox.shrink();
  
  if (message.replyId!.startsWith('temp_')) {
    print('🔍 Skipping reply preview for temporary message ID: ${message.replyId}');
    return const SizedBox.shrink();
  }
  
  final replyContent = _getReplyContent();
  final replySender = _getReplySender();
  
  if (replyContent.isEmpty && replySender == 'Unknown') {
    return const SizedBox.shrink();
  }
  
  return Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: isMe 
        ? Colors.blue.withOpacity(0.1) 
        : (isDarkMode 
            ? Colors.green[900]!.withOpacity(0.3) 
            : const Color(0xFFE8F5E8)), // UPDATE
      borderRadius: BorderRadius.circular(6),
      border: Border(
        left: BorderSide(
          color: isMe ? Colors.blue.withOpacity(0.8) : const Color(0xFF25D366), 
          width: 3
        ),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.reply,
              size: 12,
              color: isMe ? Colors.blue.withOpacity(0.9) : const Color(0xFF25D366),
            ),
            const SizedBox(width: 4),
            Text(
              'Reply to:',
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.blue.withOpacity(0.7) : const Color(0xFF25D366).withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          replySender,
          style: TextStyle(
            fontSize: 12,
            color: isMe ? Colors.blue.withOpacity(0.9) : const Color(0xFF25D366),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        _buildReplyContentWidget(isMe, isDarkMode), // TAMBAHKAN isDarkMode
      ],
    ),
  );
}
  
  String _getReplyContent() {
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
    if (message.replyFrom != null) {
      final tempMessage = ChatMessage(
        id: 'temp_reply_check',
        roomId: message.roomId,
        from: message.replyFrom!,
        agentId: 0,
        type: 1,
        timestamp: DateTime.now(),
      );
      
      final isFromAgent = MessageDetectionUtils.isAgentMessage(tempMessage);
      return isFromAgent ? 'You' : message.replyGrpMember ?? 'Customer';
    }
    
    return 'Unknown';
  }
  
Widget _buildReplyContentWidget(bool isMe, bool isDarkMode) {
  final replyContent = _getReplyContent();
  
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
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: isDarkMode ? Colors.grey[700] : Colors.grey.shade300, // UPDATE
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: 32,
                  height: 32,
                  placeholder: (context, url) => Container(
                    color: isDarkMode ? Colors.grey[800] : (isDarkMode ? Colors.grey[800] : Colors.grey.shade200), // UPDATE
                    child: Icon(
                      message.replyType == 4 ? Icons.videocam : Icons.image,
                      size: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey, // UPDATE
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: isDarkMode ? Colors.grey[800] : (isDarkMode ? Colors.grey[800] : Colors.grey.shade200), // UPDATE
                    child: Icon(
                      message.replyType == 4 ? Icons.videocam : Icons.image,
                      size: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey, // UPDATE
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                replyContent,
                style: TextStyle(
                  fontSize: 13,
                  color: isMe 
                    ? Colors.white.withOpacity(0.85) 
                    : (isDarkMode ? AppTheme.darkTextPrimary : const Color(0xFF4A4A4A)), // UPDATE
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
  
  return Text(
    replyContent,
    style: TextStyle(
      fontSize: 13,
      color: isMe 
        ? Colors.blue.withOpacity(0.85) 
        : (isDarkMode ? AppTheme.darkTextPrimary : const Color(0xFF4A4A4A)), // UPDATE
      height: 1.2,
    ),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );
}


Widget _buildMessageContent(BuildContext context, bool isMe, bool isDarkMode) {
  if (message.type == 1 && MessageUtils.isLocationMessage(message.message)) {
    return _buildLocationMessage(isMe, isDarkMode);
  }
  
  switch (message.type) {
    case 1: return _buildTextMessage(isMe, isDarkMode);
    case 2: return _buildAudioMessage(isMe, isDarkMode);
    case 3: return _buildImageMessage(context, isMe, isDarkMode);
    case 4: return _buildVideoMessage(context, isMe, isDarkMode);
    case 5: return _buildDocumentMessage(isMe, isDarkMode);
    case 7: return _buildStickerMessage(context, isMe, isDarkMode);
    case 9: return _buildLocationMessage(isMe, isDarkMode);
    default: return _buildTextMessage(isMe, isDarkMode);
  }
}

Widget _buildTextMessage(bool isMe, bool isDarkMode) {
  final cleanMessage = MessageDetectionUtils.cleanMessageContent(message.message ?? '');
   
  return Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Flexible(
        child: _buildTextWithLinks(cleanMessage, isMe, isDarkMode), // TAMBAHKAN isDarkMode
      ),
      const SizedBox(width: 8),
      _buildTimestampRow(isMe),
    ],
  );
}
  
Widget _buildTextWithLinks(String text, bool isMe, bool isDarkMode) {
  final urlRegex = RegExp(r'https?://[^\s]+|www\.[^\s]+', caseSensitive: false);
  final matches = urlRegex.allMatches(text);
  
  if (matches.isEmpty) {
    return Text(
      text,
      style: TextStyle(
        color: isMe 
          ? Colors.white 
          : (isDarkMode ? AppTheme.darkTextPrimary : (isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary)), // UPDATE
        fontSize: 16,
        height: 1.3,
      ),
    );
  }
  
  final List<TextSpan> spans = [];
  int currentIndex = 0;
  
  for (final match in matches) {
    if (match.start > currentIndex) {
      spans.add(TextSpan(
        text: text.substring(currentIndex, match.start),
        style: TextStyle(
          color: isMe 
            ? Colors.white 
            : (isDarkMode ? AppTheme.darkTextPrimary : (isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary)), // UPDATE
          fontSize: 16,
          height: 1.3,
        ),
      ));
    }
    
    final url = match.group(0)!;
    spans.add(TextSpan(
      text: url,
      style: const TextStyle(
        color: Colors.blue, // LINK TETAP BIRU
        fontSize: 16,
        height: 1.3,
        decoration: TextDecoration.underline,
      ),
      recognizer: TapGestureRecognizer()..onTap = () => _launchURL(url),
    ));
    
    currentIndex = match.end;
  }
  
  if (currentIndex < text.length) {
    spans.add(TextSpan(
      text: text.substring(currentIndex),
      style: TextStyle(
        color: isMe 
          ? Colors.white 
          : (isDarkMode ? AppTheme.darkTextPrimary : (isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary)), // UPDATE
        fontSize: 16,
        height: 1.3,
      ),
    ));
  }
  
  return RichText(text: TextSpan(children: spans));
}
  
  Future<void> _launchURL(String url) async {
    // Add https:// if missing
    String finalUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      finalUrl = 'https://$url';
    }
    
    final uri = Uri.parse(finalUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      print('Could not launch $finalUrl');
    }
  }

  Widget _buildImageMessage(BuildContext context, bool isMe, bool isDarkMode) {
  final imageUrl = _getFileUrl();
  String? caption = message.message?.trim();
  // Fallback: try to get caption from file info if Msg is empty
  if (caption == null || caption.isEmpty) {
    caption = _getMediaCaption();
  }
  final hasCaption = caption != null && caption.isNotEmpty;
  final maxWidth = MediaQuery.of(context).size.width * 0.7;

  if (imageUrl == null || imageUrl.isEmpty) {
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withOpacity(0.2) : (isDarkMode ? Colors.grey[800] : (isDarkMode ? Colors.grey[800] : Colors.grey.shade200)),
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
        ),
        const SizedBox(height: 4),
        _buildTimestampRow(isMe),
      ],
    );
  }

  return Column(
    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          onTap: () {
            // Jika ada allMessages, buka gallery viewer dengan swipe
            if (allMessages != null && allMessages!.isNotEmpty) {
              // Filter hanya image messages (type == 3)
              final imageMessages = allMessages!.where((m) => m.type == 3).toList();
              
              print('🖼️ Found ${imageMessages.length} image messages in chat');
              
              if (imageMessages.length > 1) {
                // Convert to ImageGalleryItem dan find current index
                final galleryItems = <ImageGalleryItem>[];
                
                for (final m in imageMessages) {
                  String? imgUrl = _extractImageUrl(m);
                  
                  if (imgUrl != null && imgUrl.isNotEmpty) {
                    galleryItems.add(ImageGalleryItem(
                      imageUrl: imgUrl,
                      caption: m.message?.trim(),
                      timestamp: m.timestamp,
                    ));
                  }
                }
                
                print('📸 Gallery items found: ${galleryItems.length}');
                
                // Validasi gallery items tidak kosong
                if (galleryItems.isEmpty) {
                  print('⚠️ No valid gallery items found, opening single image viewer');
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ImageViewerScreen(
                        imageUrl: imageUrl,
                        caption: hasCaption ? caption : null,
                      ),
                    ),
                  );
                  return;
                }
                
                // Find current image index
                final currentIndex = galleryItems.indexWhere((item) => item.imageUrl == imageUrl);
                
                print('🎯 Current image index: $currentIndex, total: ${galleryItems.length}');
                
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ImageGalleryViewerScreen(
                      images: galleryItems,
                      initialIndex: currentIndex >= 0 ? currentIndex : 0,
                    ),
                  ),
                );
              } else {
                // Hanya satu gambar, buka viewer biasa
                print('📷 Only one image, opening single viewer');
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ImageViewerScreen(
                      imageUrl: imageUrl,
                      caption: hasCaption ? caption : null,
                    ),
                  ),
                );
              }
            } else {
              // Fallback ke viewer biasa jika tidak ada allMessages
              print('⚠️ No allMessages provided, opening single viewer');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ImageViewerScreen(
                    imageUrl: imageUrl,
                    caption: hasCaption ? caption : null,
                  ),
                ),
              );
            }
          },
          child: Hero(
            tag: imageUrl,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: 400,
              ),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                httpHeaders: const {
                  'User-Agent': 'NoboxChat/1.0',
                },
                placeholder: (context, url) => Container(
                  width: maxWidth,
                  height: 200,
                  color: isMe ? Colors.white.withOpacity(0.2) : (isDarkMode ? Colors.grey[800] : Colors.grey.shade200),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 200,
                  height: 200,
                  color: isMe ? Colors.white.withOpacity(0.2) : (isDarkMode ? Colors.grey[800] : Colors.grey.shade200),
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
                        'Failed to load image',
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
      ),

      if (hasCaption) ...[
        const SizedBox(height: 8),
        Container(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
          ),
          child: Text(
            MessageDetectionUtils.cleanMessageContent(caption!),
            style: TextStyle(
              color: isMe ? Colors.white : (isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ),
      ],

      const SizedBox(height: 4),
      _buildTimestampRow(isMe),
    ],
  );
}

 Widget _buildVideoMessage(BuildContext context, bool isMe, bool isDarkMode) {
  final videoUrl = _getFileUrl();
  String? caption = message.message?.trim();
  // Fallback: try to get caption from file info if Msg is empty
  if (caption == null || caption.isEmpty) {
    caption = _getMediaCaption();
  }
  final hasCaption = caption != null && caption.isNotEmpty;
  final maxWidth = MediaQuery.of(context).size.width * 0.7;

  return Column(
    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: () {
          if (videoUrl != null && videoUrl.isNotEmpty) {
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: 400,
            ),
            decoration: BoxDecoration(
              color: Colors.black,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (videoUrl != null && videoUrl.isNotEmpty)
                    FutureBuilder<String?>(
                      future: _generateThumbnail(videoUrl),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.hasData &&
                            snapshot.data != null) {
                          return Image.file(
                            File(snapshot.data!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade800,
                                child: const Icon(
                                  Icons.videocam,
                                  size: 48,
                                  color: Colors.white54,
                                ),
                              );
                            },
                          );
                        }
                        return Container(
                          color: Colors.grey.shade800,
                          child: snapshot.connectionState == ConnectionState.waiting
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                                  ),
                                )
                              : const Icon(
                                  Icons.videocam,
                                  size: 48,
                                  color: Colors.white54,
                                ),
                        );
                      },
                    ),

                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),

                  Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
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

                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
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
        ),
      ),

      if (hasCaption) ...[
        const SizedBox(height: 8),
        Container(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
          ),
          child: Text(
            MessageDetectionUtils.cleanMessageContent(caption!),
            style: TextStyle(
              color: isMe ? Colors.white : (isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ),
      ],

      const SizedBox(height: 4),
      _buildTimestampRow(isMe),
    ],
  );
}

Future<String?> _generateThumbnail(String videoUrl) async {
  try {
    final thumbnailPath = await VideoThumbnail.thumbnailFile(
      video: videoUrl,
      thumbnailPath: (await getTemporaryDirectory()).path,
      imageFormat: ImageFormat.PNG,
      maxHeight: 150,
      quality: 75,
    );
    return thumbnailPath;
  } catch (e) {
    print('Error generating thumbnail: $e');
    return null;
  }
}

  Widget _buildAudioMessage(bool isMe, bool isDarkMode) {
  final audioUrl = _getFileUrl();
  
  if (audioUrl == null || audioUrl.isEmpty) {
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withOpacity(0.2) : (isDarkMode ? Colors.grey[800] : Colors.grey.shade100),
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
        ),
        const SizedBox(height: 4),
        _buildTimestampRow(isMe),
      ],
    );
  }
  
  return Column(
    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      AudioPlayerWidget(
        audioUrl: audioUrl,
        isMe: isMe,
        caption: message.message?.trim().isNotEmpty == true ? message.message : null,
      ),
      const SizedBox(height: 4),
      _buildTimestampRow(isMe),
    ],
  );
}

  Widget _buildDocumentMessage(bool isMe, bool isDarkMode) {
  String fileName = 'Document';
  final documentUrl = _getFileUrl();
  String? caption = message.message?.trim();
  final hasCaption = caption != null && caption.isNotEmpty;
  
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
    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: () {
          if (documentUrl != null) {
            print('Open document: $documentUrl');
          }
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withOpacity(0.2) : (isDarkMode ? Colors.grey[800] : Colors.grey.shade100),
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
                        color: isMe ? Colors.white : (isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
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
      
      if (hasCaption) ...[
        const SizedBox(height: 8),
        Text(
          MessageDetectionUtils.cleanMessageContent(caption!),
          style: TextStyle(
            color: isMe ? Colors.white : (isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
            fontSize: 14,
            height: 1.3,
          ),
        ),
      ],
      
      const SizedBox(height: 4),
      _buildTimestampRow(isMe),
    ],
  );
}

 Widget _buildStickerMessage(BuildContext context, bool isMe, bool isDarkMode) {
  final stickerUrl = _getFileUrl();
  if (stickerUrl == null || stickerUrl.isEmpty) {
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: (isDarkMode ? Colors.grey[800] : Colors.grey.shade200),
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
        ),
        const SizedBox(height: 2),
        _buildTimestampRow(isMe),
      ],
    );
  }

  return Column(
    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: () {
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
                  color: (isDarkMode ? Colors.grey[800] : Colors.grey.shade200),
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
      ),
      const SizedBox(height: 2),
      _buildTimestampRow(isMe),
    ],
  );
}

 Widget _buildLocationMessage(bool isMe, bool isDarkMode) {
  final messageText = message.message ?? '';
  
  double? latitude;
  double? longitude;
  String? mapsUrl;
  
  final locationRegex = RegExp(r'Location: (-?\d+\.\d+), (-?\d+\.\d+)');
  final match = locationRegex.firstMatch(messageText);
  
  if (match != null) {
    latitude = double.tryParse(match.group(1)!);
    longitude = double.tryParse(match.group(2)!);
  }
  
  final urlRegex = RegExp(r'https://maps\.google\.com/maps\?q=(-?\d+\.\d+),(-?\d+\.\d+)');
  final urlMatch = urlRegex.firstMatch(messageText);
  if (urlMatch != null) {
    mapsUrl = urlMatch.group(0);
  }
  
  return Column(
    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: () {
          if (mapsUrl != null) {
            _openInMaps(mapsUrl);
          } else if (latitude != null && longitude != null) {
            final url = 'https://maps.google.com/maps?q=$latitude,$longitude';
            _openInMaps(url);
          }
        },
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withOpacity(0.2) : (isDarkMode ? Colors.grey[800] : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMe ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      color: isMe ? Colors.white : (isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: isMe ? Colors.white.withOpacity(0.1) : (isDarkMode ? Colors.grey[800] : Colors.grey.shade200),
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
              
              if (latitude != null && longitude != null)
                Text(
                  'Lat: ${latitude!.toStringAsFixed(6)}, Lng: ${longitude!.toStringAsFixed(6)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isMe ? Colors.white70 : AppTheme.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              
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
      ),
      const SizedBox(height: 2),
      _buildTimestampRow(isMe),
    ],
  );
}
  
  void _openInMaps(String url) {
    print('Opening maps URL: $url');
    
    try {
      launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      print('Failed to open maps: $e');
    }
  }

  // Helper untuk extract image URL dari message lain
  String? _extractImageUrl(ChatMessage msg) {
    if (msg.file != null) {
      try {
        final fileData = msg.file!;
        
        if (fileData.startsWith('[') || fileData.startsWith('{')) {
          final dynamic parsed = jsonDecode(fileData);
          if (parsed is List && parsed.isNotEmpty) {
            final fileInfo = parsed[0];
            if (fileInfo is Map<String, dynamic>) {
              final filename = fileInfo['Filename'] ?? fileInfo['filename'];
              if (filename != null) {
                if (filename.toString().startsWith('http://') || filename.toString().startsWith('https://')) {
                  return filename.toString();
                }
                return '${AppConfig.baseUrl}upload/$filename';
              }
            }
          } else if (parsed is Map<String, dynamic>) {
            final filename = parsed['Filename'] ?? parsed['filename'];
            if (filename != null) {
              if (filename.toString().startsWith('http://') || filename.toString().startsWith('https://')) {
                return filename.toString();
              }
              return '${AppConfig.baseUrl}upload/$filename';
            }
          }
        }
        
        if (fileData.startsWith('http://') || fileData.startsWith('https://')) {
          return fileData;
        }
        
        return '${AppConfig.baseUrl}upload/$fileData';
      } catch (e) {
        print('❌ Error extracting image URL from message ${msg.id}: $e');
        print('   File data: ${msg.file}');
      }
    }
    return null;
  }

  String? _getFileUrl() {
    if (message.file != null) {
      try {
        final fileData = message.file!;
        
        if (fileData.startsWith('[') || fileData.startsWith('{')) {
          final dynamic parsed = jsonDecode(fileData);
          if (parsed is List && parsed.isNotEmpty) {
            final fileInfo = parsed[0];
            if (fileInfo is Map<String, dynamic>) {
              final filename = fileInfo['Filename'] ?? fileInfo['filename'];
              if (filename != null) {
                if (filename.toString().startsWith('http://') || filename.toString().startsWith('https://')) {
                  return filename.toString();
                }
                return '${AppConfig.baseUrl}upload/$filename';
              }
            }
          } else if (parsed is Map<String, dynamic>) {
            final filename = parsed['Filename'] ?? parsed['filename'];
            if (filename != null) {
              if (filename.toString().startsWith('http://') || filename.toString().startsWith('https://')) {
                return filename.toString();
              }
              return '${AppConfig.baseUrl}upload/$filename';
            }
          }
        }
        
        if (fileData.startsWith('http://') || fileData.startsWith('https://')) {
          return fileData;
        }
        
        if (!fileData.contains('://') && !fileData.startsWith('file:///')) {
          return '${AppConfig.baseUrl}upload/$fileData';
        }
        
        return null;
      } catch (e) {
        print('Error parsing file data: $e');
        return null;
      }
    }
    
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
                if (filename.toString().startsWith('http://') || filename.toString().startsWith('https://')) {
                  return filename.toString();
                }
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

  // Try to extract media caption from File/Files JSON if present
  String? _getMediaCaption() {
    // Check 'file'
    if (message.file != null) {
      try {
        final fileData = message.file!;
        if (fileData.startsWith('[') || fileData.startsWith('{')) {
          final dynamic parsed = jsonDecode(fileData);
          if (parsed is List && parsed.isNotEmpty) {
            final info = parsed[0];
            if (info is Map<String, dynamic>) {
              final cap = info['Caption'] ?? info['caption'] ?? info['Desc'] ?? info['Description'];
              if (cap is String && cap.trim().isNotEmpty) return cap.trim();
            }
          } else if (parsed is Map<String, dynamic>) {
            final cap = parsed['Caption'] ?? parsed['caption'] ?? parsed['Desc'] ?? parsed['Description'];
            if (cap is String && cap.trim().isNotEmpty) return cap.trim();
          }
        }
      } catch (_) {}
    }
    // Check 'files'
    if (message.files != null) {
      try {
        final filesData = message.files!;
        if (filesData.startsWith('[') || filesData.startsWith('{')) {
          final dynamic parsed = jsonDecode(filesData);
          if (parsed is List && parsed.isNotEmpty) {
            final info = parsed[0];
            if (info is Map<String, dynamic>) {
              final cap = info['Caption'] ?? info['caption'] ?? info['Desc'] ?? info['Description'];
              if (cap is String && cap.trim().isNotEmpty) return cap.trim();
            }
          } else if (parsed is Map<String, dynamic>) {
            final cap = parsed['Caption'] ?? parsed['caption'] ?? parsed['Desc'] ?? parsed['Description'];
            if (cap is String && cap.trim().isNotEmpty) return cap.trim();
          }
        }
      } catch (_) {}
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