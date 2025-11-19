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
import '../../core/services/storage_service.dart';
import '../../core/utils/message_detection_utils.dart';
import '../../core/utils/message_utils.dart';
import '../screens/media/image_viewer_screen.dart';
import '../screens/media/image_gallery_viewer_screen.dart';
import '../screens/media/video_player_screen.dart';
import 'forward_dialog.dart';

class MessageBubbleWidget extends ConsumerStatefulWidget {
  final ChatMessage message;
  final List<ChatMessage>? allMessages;
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
  ConsumerState<MessageBubbleWidget> createState() => _MessageBubbleWidgetState();
}

class _MessageBubbleWidgetState extends ConsumerState<MessageBubbleWidget> 
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0;
  static const double _maxDragDistance = 80.0;
  static const double _replyThreshold = 60.0;
  late AnimationController _resetAnimationController;
  late Animation<double> _resetAnimation;
  bool _hasTriggeredHaptic = false;
  bool _isDragging = false;

  Map<String, String> _getAuthHeaders() {
    final token = StorageService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'User-Agent': 'NoboxChat/1.0',
    };
  }

  @override
  void initState() {
    super.initState();
    _resetAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _resetAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _resetAnimationController,
        curve: Curves.easeOutCubic,
      ),
    )..addListener(() {
      setState(() {
        _dragPosition = _resetAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _resetAnimationController.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    print('👆 Drag started');
    _resetAnimationController.stop();
    setState(() {
      _isDragging = true;
      _hasTriggeredHaptic = false;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    
    setState(() {
      // Only allow swipe to right
      double newPosition = _dragPosition + details.delta.dx;
      if (newPosition < 0) newPosition = 0;
      
      // Elastic resistance after threshold
      if (newPosition > _replyThreshold) {
        final excess = newPosition - _replyThreshold;
        final resistance = 1 - (excess / (_maxDragDistance - _replyThreshold)) * 0.5;
        newPosition = _replyThreshold + (excess * resistance);
      }
      
      if (newPosition > _maxDragDistance) newPosition = _maxDragDistance;
      
      _dragPosition = newPosition;
      
      // Haptic feedback at threshold (only once)
      if (_dragPosition >= _replyThreshold && !_hasTriggeredHaptic) {
        HapticFeedback.lightImpact();
        _hasTriggeredHaptic = true;
      } else if (_dragPosition < _replyThreshold && _hasTriggeredHaptic) {
        _hasTriggeredHaptic = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    print('✋ Drag ended. Position: $_dragPosition');
    
    _isDragging = false;
    
    if (_dragPosition >= _replyThreshold && widget.onReply != null) {
      print('✅ Reply triggered!');
      HapticFeedback.mediumImpact();
      widget.onReply!();
    }
    
    // Smooth animate back to 0
    _resetAnimation = Tween<double>(
      begin: _dragPosition,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _resetAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _resetAnimationController.forward(from: 0);
    _hasTriggeredHaptic = false;
  }

  void _onHorizontalDragCancel() {
    print('🚫 Drag cancelled');
    _isDragging = false;
    
    // Smooth animate back to 0
    _resetAnimation = Tween<double>(
      begin: _dragPosition,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _resetAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _resetAnimationController.forward(from: 0);
    _hasTriggeredHaptic = false;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    if (MessageDetectionUtils.isSystemMessage(widget.message)) {
      return _buildSystemMessage(context, isDarkMode);
    }
    
    final isMe = MessageDetectionUtils.isAgentMessage(widget.message);
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onHorizontalDragStart: widget.onReply != null ? _onHorizontalDragStart : null,
      onHorizontalDragUpdate: widget.onReply != null ? _onHorizontalDragUpdate : null,
      onHorizontalDragEnd: widget.onReply != null ? _onHorizontalDragEnd : null,
      onHorizontalDragCancel: widget.onReply != null ? _onHorizontalDragCancel : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        child: Stack(
          children: [
            // Reply icon background with smooth animation
            if (_dragPosition > 5)
              Positioned(
                right: isMe ? null : 16,
                left: isMe ? 16 : null,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedScale(
                    scale: (_dragPosition / _maxDragDistance).clamp(0.5, 1.0),
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeOut,
                    child: AnimatedOpacity(
                      opacity: (_dragPosition / _replyThreshold).clamp(0.3, 1.0),
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (_dragPosition >= _replyThreshold 
                              ? AppTheme.primaryColor 
                              : Colors.grey.shade500).withOpacity(
                                _dragPosition >= _replyThreshold ? 0.25 : 0.15
                              ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.reply_rounded,
                          color: _dragPosition >= _replyThreshold 
                              ? AppTheme.primaryColor 
                              : Colors.grey.shade600,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            
            // Message content with smooth transform
            AnimatedContainer(
              duration: _isDragging 
                  ? Duration.zero 
                  : const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(_dragPosition, 0, 0),
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
                              if (widget.message.replyId != null) 
                                _buildReplyPreview(context, isMe, isDarkMode),
                              
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: widget.isSelected
                                      ? (isMe 
                                          ? AppTheme.primaryColor.withOpacity(0.8) 
                                          : (isDarkMode 
                                              ? AppTheme.darkSurface.withOpacity(0.8) 
                                              : AppTheme.otherMessageColor.withOpacity(0.8)))
                                      : (isMe 
                                          ? AppTheme.primaryColor 
                                          : (isDarkMode ? AppTheme.darkSurface : Colors.white)),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(12),
                                    topRight: const Radius.circular(12),
                                    bottomLeft: Radius.circular(isMe ? 12 : 2),
                                    bottomRight: Radius.circular(isMe ? 2 : 12),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
                                      blurRadius: 1,
                                      offset: const Offset(0, 0.5),
                                    ),
                                  ],
                                ),
                                child: _buildMessageContent(context, isMe, isDarkMode),
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
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context, bool isDarkMode) {
    final cleanMessage = MessageDetectionUtils.cleanMessageContent(widget.message.message ?? '');
    final localTime = widget.message.timestamp.toLocal();
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
              color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
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
                      color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey.shade600,
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
                        : Colors.grey.shade400,
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
              color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTimestampRow(bool isMe) {
    final localTime = widget.message.timestamp.toLocal();
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
    if (widget.message.replyId == null || widget.message.replyId!.isEmpty) return const SizedBox.shrink();
    
    if (widget.message.replyId!.startsWith('temp_')) {
      print('🔍 Skipping reply preview for temporary message ID: ${widget.message.replyId}');
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
              : const Color(0xFFE8F5E8)),
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
          _buildReplyContentWidget(isMe, isDarkMode),
        ],
      ),
    );
  }
  
  String _getReplyContent() {
    final replyText = widget.message.replyMessage?.trim() ?? '';
    
    if (widget.message.replyType == null) {
      return replyText.isNotEmpty ? replyText : 'Message';
    }
    
    switch (widget.message.replyType!) {
      case 1: return replyText.isNotEmpty ? replyText : 'Text message';
      case 2: return replyText.isNotEmpty ? '🔊 $replyText' : '🔊 Audio';
      case 3: return replyText.isNotEmpty ? replyText : '📷 Photo';
      case 4: return replyText.isNotEmpty ? replyText : '🎥 Video';
      case 5: return replyText.isNotEmpty ? '📄 $replyText' : '📄 Document';
      case 7: return '🌟 Sticker';
      case 9: return replyText.isNotEmpty ? replyText : '📍 Location';
      default: return replyText.isNotEmpty ? replyText : 'Message';
    }
  }
  
  String _getReplySender() {
    if (widget.message.replyFrom != null) {
      final tempMessage = ChatMessage(
        id: 'temp_reply_check',
        roomId: widget.message.roomId,
        from: widget.message.replyFrom!,
        agentId: 0,
        type: 1,
        timestamp: DateTime.now(),
      );
      
      final isFromAgent = MessageDetectionUtils.isAgentMessage(tempMessage);
      return isFromAgent ? 'You' : widget.message.replyGrpMember ?? 'Customer';
    }
    
    return 'Unknown';
  }
  
  Widget _buildReplyContentWidget(bool isMe, bool isDarkMode) {
    final replyContent = _getReplyContent();
    
    if ((widget.message.replyType == 3 || widget.message.replyType == 7 || widget.message.replyType == 4) && 
        widget.message.replyFiles != null && widget.message.replyFiles!.isNotEmpty) {
      try {
        final dynamic parsed = jsonDecode(widget.message.replyFiles!);
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
                  color: isDarkMode ? Colors.grey[700] : Colors.grey.shade300,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: 32,
                    height: 32,
                    placeholder: (context, url) => Container(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey.shade200,
                      child: Icon(
                        widget.message.replyType == 4 ? Icons.videocam : Icons.image,
                        size: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey.shade200,
                      child: Icon(
                        widget.message.replyType == 4 ? Icons.videocam : Icons.image,
                        size: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey,
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
                      : (isDarkMode ? AppTheme.darkTextPrimary : const Color(0xFF4A4A4A)),
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
          : (isDarkMode ? AppTheme.darkTextPrimary : const Color(0xFF4A4A4A)),
        height: 1.2,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isMe, bool isDarkMode) {
    if (widget.message.type == 1 && MessageUtils.isLocationMessage(widget.message.message)) {
      return _buildLocationMessage(isMe, isDarkMode);
    }
    
    switch (widget.message.type) {
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
    final cleanMessage = MessageDetectionUtils.cleanMessageContent(widget.message.message ?? '');
     
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: _buildTextWithLinks(cleanMessage, isMe, isDarkMode),
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
            : (isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
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
              : (isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
            fontSize: 16,
            height: 1.3,
          ),
        ));
      }
      
     final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: isMe ? Colors.white : Colors.blue,
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
            : (isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
          fontSize: 16,
          height: 1.3,
        ),
      ));
    } 
    
    return RichText(text: TextSpan(children: spans));
  }
  
  Future<void> _launchURL(String url) async {
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
    String? caption = widget.message.message?.trim();
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
              color: isMe ? Colors.white.withOpacity(0.2) : (isDarkMode ? Colors.grey[800] : Colors.grey.shade200),
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
              if (widget.allMessages != null && widget.allMessages!.isNotEmpty) {
                final imageMessages = widget.allMessages!.where((m) => m.type == 3).toList();
                
                print('🖼️ Found ${imageMessages.length} image messages in chat');
                
                if (imageMessages.length > 1) {
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
                print('⚠️ No widget.allMessages provided, opening single viewer');
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
                  httpHeaders: _getAuthHeaders(),
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
    String? caption = widget.message.message?.trim();
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
          caption: widget.message.message?.trim().isNotEmpty == true ? widget.message.message : null,
        ),
        const SizedBox(height: 4),
        _buildTimestampRow(isMe),
      ],
    );
  }

  Widget _buildDocumentMessage(bool isMe, bool isDarkMode) {
    String fileName = 'Document';
    final documentUrl = _getFileUrl();
    String? caption = widget.message.message?.trim();
    final hasCaption = caption != null && caption.isNotEmpty;
    
    if (widget.message.file != null) {
      try {
        final fileData = widget.message.file!;
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
              color: isDarkMode ? Colors.grey[800] : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_emotions, size: 32, color: Colors.grey),
                const SizedBox(height: 4),
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
                httpHeaders: _getAuthHeaders(),
                errorWidget: (context, url, error) => Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_emotions, size: 32, color: Colors.grey),
                      const SizedBox(height: 4),
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
    final messageText = widget.message.message ?? '';
    
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
                          child: const Text(
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
    if (widget.message.file != null) {
      try {
        final fileData = widget.message.file!;
        
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
    
    if (widget.message.files != null) {
      try {
        final filesData = widget.message.files!;
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

  String? _getMediaCaption() {
    if (widget.message.file != null) {
      try {
        final fileData = widget.message.file!;
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
    if (widget.message.files != null) {
      try {
        final filesData = widget.message.files!;
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

    switch (widget.message.ack) {
      case 1:
        icon = Icons.access_time;
        color = AppTheme.textSecondary;
        break;
      case 2:
        icon = Icons.check;
        color = AppTheme.textSecondary;
        break;
      case 3:
        icon = Icons.done_all;
        color = AppTheme.textSecondary;
        break;
      case 4:
        icon = Icons.error_outline;
        color = AppTheme.errorColor;
        break;
      case 5:
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