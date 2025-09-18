import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/chat_models.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/message_bubble_widget.dart';
import '../../widgets/chat_input_widget.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Room room;

  const ChatScreen({
    super.key,
    required this.room,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  ChatMessage? _replyingTo;
  ChatMessage? _selectedMessage;
  bool _isNearTop = false;
  bool _isSelectionMode = false;
  bool _hasInitiallyScrolled = false; // Flag untuk memastikan sudah scroll pertama kali
  bool _isFirstBuild = true; // Flag untuk build pertama

  @override
  void initState() {
    super.initState();
    
    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);
    
    // Select the room and load messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(chatProvider.notifier).selectRoom(widget.room);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      
      // Check if user is near the top (within 200 pixels)
      _isNearTop = currentScroll <= 200;
      
      // Load more messages when user scrolls to top
      if (currentScroll <= 100 && !ref.read(chatProvider).isLoadingMore) {
        ref.read(chatProvider.notifier).loadMoreMessages();
      }
    }
  }

  // Method untuk memastikan scroll ke bawah dengan multiple attempts yang lebih agresif
  void _ensureScrollToBottom() {
    if (!mounted) return;
    
    // Immediate attempt
    _scrollToBottomImmediate();
    
    // Multiple delayed attempts dengan interval yang berbeda
    final delays = [50, 100, 200, 300, 500, 800, 1000];
    
    for (int delay in delays) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted && _scrollController.hasClients) {
          _scrollToBottomImmediate();
        }
      });
    }
  }

  void _scrollToBottomImmediate() {
    if (_scrollController.hasClients && mounted) {
      try {
        final maxExtent = _scrollController.position.maxScrollExtent;
        if (maxExtent > 0) {
          _scrollController.jumpTo(maxExtent);
        }
      } catch (e) {
        // Ignore scroll errors
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && mounted) {
      try {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } catch (e) {
        // Fallback to immediate scroll
        _scrollToBottomImmediate();
      }
    }
  }

  void _onMessageLongPress(ChatMessage message) {
    setState(() {
      _selectedMessage = message;
      _isSelectionMode = true;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedMessage = null;
      _isSelectionMode = false;
    });
  }

  void _handleReply() {
    if (_selectedMessage != null) {
      setState(() {
        _replyingTo = _selectedMessage;
        _isSelectionMode = false;
        _selectedMessage = null;
      });
    }
  }

  void _handleForward() {
    if (_selectedMessage != null) {
      // TODO: Implement forward functionality
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Forward feature coming soon'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      _exitSelectionMode();
    }
  }

  void _handleCopy() {
    if (_selectedMessage != null && _selectedMessage!.message != null) {
      Clipboard.setData(ClipboardData(text: _selectedMessage!.message!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied to clipboard'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      _exitSelectionMode();
    }
  }

  void _handleDelete() {
    if (_selectedMessage != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _exitSelectionMode();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: Implement actual delete logic here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message deleted'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
                _exitSelectionMode();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    }
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  String _getReplyPreviewText(ChatMessage message) {
    // Clean message content first
    final cleanContent = message.message?.trim() ?? '';
    
    switch (message.type) {
      case 1: // Text
        return cleanContent.isNotEmpty ? cleanContent : 'Text message';
      case 2: // Audio
        return cleanContent.isNotEmpty ? '🔊 $cleanContent' : '🔊 Audio';
      case 3: // Image
        return cleanContent.isNotEmpty ? '📷 $cleanContent' : '📷 Photo';
      case 4: // Video
        return cleanContent.isNotEmpty ? '🎥 $cleanContent' : '🎥 Video';
      case 5: // Document
        return cleanContent.isNotEmpty ? '📄 $cleanContent' : '📄 Document';
      case 7: // Sticker
        return '🌟 Sticker';
      case 9: // Location
        return cleanContent.isNotEmpty ? cleanContent : '📍 Location';
      default:
        return cleanContent.isNotEmpty ? cleanContent : 'Message';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    
    // Listen for errors and show them
    ref.listen<ChatState>(chatProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ref.read(chatProvider.notifier).clearError();
              },
            ),
          ),
        );
      }
      
      // Handle scrolling logic
      if (next.messages.isNotEmpty) {
        final isInitialLoad = (previous?.messages.isEmpty ?? true) && next.messages.isNotEmpty;
        final hasNewMessages = previous != null && next.messages.length > previous.messages.length;
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Untuk initial load, selalu scroll ke bawah tanpa peduli posisi user
          if (isInitialLoad || !_hasInitiallyScrolled) {
            _ensureScrollToBottom();
            _hasInitiallyScrolled = true;
          }
          // Untuk pesan baru, cek apakah user sedang melihat pesan lama
          else if (hasNewMessages) {
            if (!_isNearTop) {
              _scrollToBottom();
            }
          }
        });
      }
    });

    // Untuk memastikan scroll ke bawah pada build pertama jika sudah ada messages
    if (_isFirstBuild && chatState.messages.isNotEmpty && !_hasInitiallyScrolled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureScrollToBottom();
        _hasInitiallyScrolled = true;
      });
      _isFirstBuild = false;
    } else if (_isFirstBuild) {
      _isFirstBuild = false;
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatState.messages.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: AppTheme.textSecondary,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              'Start the conversation!',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Load more indicator at top
                          if (!chatState.hasMoreMessages)
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: const Text(
                                'No more messages',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          
                          Expanded(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (scrollInfo) {
                                // Trigger scroll to bottom setelah ListView selesai build
                                if (!_hasInitiallyScrolled && scrollInfo is ScrollEndNotification) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _ensureScrollToBottom();
                                    _hasInitiallyScrolled = true;
                                  });
                                }
                                return true;
                              },
                              child: RefreshIndicator(
                                onRefresh: () async {
                                  if (chatState.hasMoreMessages) {
                                    await ref.read(chatProvider.notifier).loadMoreMessages();
                                  }
                                },
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                                  itemCount: chatState.messages.length + (chatState.isLoadingMore ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    // Show loading indicator at the top when loading more
                                    if (index == 0 && chatState.isLoadingMore) {
                                      return const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    
                                    // Adjust index if loading indicator is shown
                                    final messageIndex = chatState.isLoadingMore ? index - 1 : index;
                                    final message = chatState.messages[messageIndex];
                                    final previousMessage = messageIndex > 0 ? chatState.messages[messageIndex - 1] : null;
                                    final showSenderInfo = previousMessage == null || 
                                        previousMessage.agentId != message.agentId ||
                                        message.timestamp.difference(previousMessage.timestamp).inMinutes > 5;
                                    
                                    return MessageBubbleWidget(
                                      message: message,
                                      showSenderInfo: showSenderInfo,
                                      isSelected: _selectedMessage?.id == message.id,
                                      onLongPress: () => _onMessageLongPress(message),
                                      onTap: _isSelectionMode ? () => _exitSelectionMode() : null,
                                      onReply: () => setState(() => _replyingTo = message),
                                      onDelete: () => _handleDelete(),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
          
          // Reply preview
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(color: AppTheme.primaryColor, width: 4),
                ),
              ),
              child: Row(
                children: [
                  // Reply icon
                  Icon(
                    Icons.reply,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Replying to header
                        const Text(
                          'Replying to:',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Reply content with proper formatting
                        Text(
                          _getReplyPreviewText(_replyingTo!),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4A4A4A),
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: _cancelReply,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
          
          // Input
          ChatInputWidget(
            onSendText: (text) => _handleSendText(text),
            onSendMedia: (type, data, filename) => _handleSendMedia(type, data, filename),
            replyingTo: _replyingTo,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: _isValidImageUrl(widget.room.contactImage ?? widget.room.linkImage)
                ? NetworkImage(widget.room.contactImage ?? widget.room.linkImage!)
                : null,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: !_isValidImageUrl(widget.room.contactImage ?? widget.room.linkImage)
                ? Icon(
                    widget.room.isGroup ? Icons.group : Icons.person,
                    color: Colors.white,
                    size: 20,
                  )
                : null,
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.room.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                
                Row(
                  children: [
                    _getChannelIcon(widget.room.channelId),
                    const SizedBox(width: 6),
                    Text(
                      widget.room.channelName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            switch (value) {
              case 'resolve':
                _handleResolve();
                break;
              case 'archive':
                _handleArchive();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'resolve',
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 20),
                  SizedBox(width: 12),
                  Text('Mark as Resolved'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'archive',
              child: Row(
                children: [
                  Icon(Icons.archive_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Archive'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: _exitSelectionMode,
      ),
      title: const Text(
        '1 selected',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      actions: [
        // Reply
        IconButton(
          icon: const Icon(Icons.reply, color: Colors.white),
          onPressed: _handleReply,
          tooltip: 'Reply',
        ),
        
        // Forward
        IconButton(
          icon: const Icon(Icons.forward, color: Colors.white),
          onPressed: _handleForward,
          tooltip: 'Forward',
        ),
        
        // Copy
        IconButton(
          icon: const Icon(Icons.copy, color: Colors.white),
          onPressed: _handleCopy,
          tooltip: 'Copy',
        ),
        
        // Delete
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.white),
          onPressed: _handleDelete,
          tooltip: 'Delete',
        ),
      ],
    );
  }

  Widget _getChannelIcon(int channelId) {
    Color color = Colors.white70;
    IconData icon = Icons.chat_bubble;

    switch (channelId) {
      case 1:
        color = const Color(0xFF25D366);
        icon = Icons.chat;
        break;
      case 1557:
      case 1561:
        color = const Color(0xFF25D366);
        icon = Icons.business;
        break;
      case 2:
        color = const Color(0xFF0088CC);
        icon = Icons.send;
        break;
      case 3:
        color = const Color(0xFFE4405F);
        icon = Icons.camera_alt;
        break;
      case 4:
        color = const Color(0xFF0084FF);
        icon = Icons.messenger;
        break;
      case 19:
        color = const Color(0xFFEA4335);
        icon = Icons.email;
        break;
    }

    return Icon(icon, size: 12, color: color);
  }

  void _handleSendText(String text) {
    final chatNotifier = ref.read(chatProvider.notifier);
    
    // Validate replyId before sending
    String? validatedReplyId = _replyingTo?.id;
    if (validatedReplyId != null && validatedReplyId.isNotEmpty) {
      // Check if the reply message still exists in the current message list
      final chatState = ref.read(chatProvider);
      final replyExists = chatState.messages.any((msg) => msg.id == validatedReplyId);
      
      if (!replyExists) {
        print('⚠️ Reply message no longer exists, clearing reply');
        validatedReplyId = null;
        setState(() {
          _replyingTo = null;
        });
      } else {
        // Additional validation for ReplyId format
        if (validatedReplyId!.length > 20) {
          print('⚠️ ReplyId too long, clearing reply to avoid server error');
          validatedReplyId = null;
          setState(() {
            _replyingTo = null;
          });
          
          // Show user feedback
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reply reference invalid, sending as regular message'),
              backgroundColor: AppTheme.warningColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
    
    chatNotifier.sendTextMessage(
      text,
      replyId: validatedReplyId,
    );
    
    // Cancel reply after sending
    setState(() {
      _replyingTo = null;
    });
    
    // Scroll to bottom after sending message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _handleSendMedia(String type, String data, String filename, {String? caption, String? replyId}) {
  final chatNotifier = ref.read(chatProvider.notifier);
  if (data.isNotEmpty && filename.isNotEmpty) {
    chatNotifier.sendMediaMessage(
      type: type,
      filename: filename,
      base64Data: data,
      caption: caption, // Pass caption here
      replyId: replyId ?? _replyingTo?.id,
    );
  }
  _cancelReply();
  
  // Scroll to bottom after sending media
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _scrollToBottom();
  });
}

  void _handleResolve() {
    // TODO: Implement resolve functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Conversation marked as resolved'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _handleArchive() {
    // TODO: Implement archive functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Conversation archived'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
  
  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url.startsWith('file:///')) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }
}