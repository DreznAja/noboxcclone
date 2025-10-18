import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:nobox_chat/presentation/widgets/forward_dialog.dart';
import '../../../core/models/chat_models.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../widgets/message_bubble_widget.dart';
import '../../widgets/message_shimmer_widget.dart';
import '../../widgets/chat_input_widget.dart';
import '../../widgets/add_note_dialog.dart';
import '../../widgets/add_agent_dialog.dart';
import '../auth/login_screen.dart';
import '../contact/contact_detail_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Room room;
  final bool isArchived;
  final bool isNewConversation; // Flag untuk new conversation
  final bool isReadOnly; // Flag untuk read-only mode (conversation history)

  const ChatScreen({
    super.key,
    required this.room,
    this.isArchived = false,
    this.isNewConversation = false, // Default false
    this.isReadOnly = false, // Default false
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
  bool _showContactDetail = false;
  StreamSubscription<void>? _sessionExpiredSubscription;

  @override
  void initState() {
    super.initState();

    // Listen to session expiration events
    _sessionExpiredSubscription = ApiService.onSessionExpired.listen((_) {
      print('🔴 Session expired in chat screen - navigating to login');
      _handleSessionExpired();
    });

    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);

    // Set current room to prevent notifications for this chat
    PushNotificationService.setCurrentRoom(widget.room.id);

    // Cancel notifications for this room when entering chat
    PushNotificationService.cancelNotificationsForRoom(widget.room.id);

    // Select the room and load messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print('🔍 ChatScreen Init - Room: ${widget.room.id}, Name: ${widget.room.name}, Status: ${widget.room.status}, IsArchived flag: ${widget.isArchived}');
        
        ref.read(chatProvider.notifier).selectRoom(widget.room, isArchived: widget.isArchived);
        
        // For archived conversations, provide additional time and retry logic
        if (widget.isArchived) {
          print('📦 Archived conversation detected in chat screen - Room Status: ${widget.room.status}');
          
          // Immediate check after initial load
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            
            final st = ref.read(chatProvider);
            print('🔍 First check - Messages count: ${st.messages.length}, IsLoading: ${st.isLoading}, Error: ${st.error}');
            
            if (st.messages.isEmpty && !st.isLoading) {
              print('🔄 Retrying message load for archived conversation with specialized method');
              print('🔍 About to call loadArchivedRoomMessages for room: ${widget.room.id}');
              ref.read(chatProvider.notifier).loadArchivedRoomMessages(widget.room);
              print('🔍 loadArchivedRoomMessages call completed');
              
              // One more attempt if still empty
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (!mounted) return;
                
                final st2 = ref.read(chatProvider);
                print('🔍 Second check - Messages count: ${st2.messages.length}, IsLoading: ${st2.isLoading}, Error: ${st2.error}');
                
                if (st2.messages.isEmpty && !st2.isLoading) {
                  print('⚠️ Final attempt to load archived messages using loadMoreMessages');
                  ref.read(chatProvider.notifier).loadMoreMessages();
                  
                  // Last resort check
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    if (!mounted) return;
                    
                    final st3 = ref.read(chatProvider);
                    print('🔍 Final check - Messages count: ${st3.messages.length}, IsLoading: ${st3.isLoading}, Error: ${st3.error}');
                    
                    if (st3.messages.isEmpty) {
                      print('❌ ARCHIVED CONVERSATION BUG: No messages loaded after all attempts!');
                    }
                  });
                }
              });
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    // Clear current room when leaving ChatScreen
    PushNotificationService.clearCurrentRoom();

    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _sessionExpiredSubscription?.cancel();
    super.dispose();
  }

  void _handleSessionExpired() async {
    if (!mounted) return;
    
    print('🔄 Session expired - attempting auto re-login...');
    
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Refreshing session...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );
    
    // Try auto re-login first
    final success = await ref.read(authProvider.notifier).tryAutoReLogin();
    
    if (!mounted) return;
    
    // Clear the loading snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    if (success) {
      print('✅ Auto re-login successful - continuing session');
      
      // Reload messages after successful re-login
      ref.read(chatProvider.notifier).loadMoreMessages();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session refreshed successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      print('❌ Auto re-login failed - redirecting to login');
      
      // Invalidate auth state and clear data
      ref.read(authProvider.notifier).invalidateSession();
      await StorageService.removeToken();
      await StorageService.removeUserData();
      
      // Navigate to login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      
      // Show message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please login again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
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
    if (!widget.isArchived && !widget.isReadOnly) {
      setState(() {
        _selectedMessage = message;
        _isSelectionMode = true;
      });
    }
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedMessage = null;
      _isSelectionMode = false;
    });
  }

  void _handleReply() {
    if (_selectedMessage != null && !widget.isArchived) {
      setState(() {
        _replyingTo = _selectedMessage;
        _isSelectionMode = false;
        _selectedMessage = null;
      });
    }
  }

  void _handleForward() {
    if (_selectedMessage != null) {
      // Validate message before showing dialog
      final message = _selectedMessage;
      if (message == null) {
        _exitSelectionMode();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message not available for forwarding'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      
      showDialog(
        context: context,
        builder: (context) => ForwardDialog(message: message),
      );
      _exitSelectionMode();
    }
  }

  void _handleCopy() {
    if (_selectedMessage?.message?.isNotEmpty == true) {
      Clipboard.setData(ClipboardData(text: _selectedMessage!.message!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied to clipboard'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      _exitSelectionMode();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No text content to copy'),
          backgroundColor: AppTheme.warningColor,
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
              onPressed: () async {
                Navigator.pop(context);
                
                final messageId = _selectedMessage!.id;
                print('🗑️ Attempting to delete message: $messageId');
                
                // Call provider to delete message
                final success = await ref.read(chatProvider.notifier).deleteMessage(messageId);
                
                _exitSelectionMode();
                
                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message deleted successfully'),
                        backgroundColor: AppTheme.successColor,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to delete message'),
                        backgroundColor: AppTheme.errorColor,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
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
    final isDarkMode = ref.watch(themeProvider).isDarkMode; // TAMBAHKAN INI
    
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
    backgroundColor: isDarkMode ? AppTheme.darkBackground : const Color(0xFFF5F5F5), // UPDATE INI
    resizeToAvoidBottomInset: true,
    extendBody: false,
    appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
    body: GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Stack(
        children: [
          Column(
            children: [
              // Messages
              Expanded(
                child: chatState.isLoading
                ? const MessageShimmerWidget()
                : chatState.messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // System message untuk new conversation
                            if (widget.isNewConversation)
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDarkMode 
                                    ? Colors.blue[900]!.withOpacity(0.3)
                                    : Colors.blue[50], // UPDATE INI
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDarkMode 
                                      ? Colors.blue[700]!
                                      : Colors.blue[200]!, // UPDATE INI
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.info_outline, 
                                      size: 16, 
                                      color: isDarkMode 
                                        ? Colors.blue[300]
                                        : Colors.blue[700], // UPDATE INI
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'New conversation created',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDarkMode 
                                            ? Colors.blue[200]
                                            : Colors.blue[900], // UPDATE INI
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: isDarkMode 
                                ? AppTheme.darkTextSecondary 
                                : AppTheme.textSecondary, // UPDATE INI
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode 
                                  ? AppTheme.darkTextSecondary 
                                  : AppTheme.textSecondary, // UPDATE INI
                              ),
                            ),
                            Text(
                              'Start the conversation!',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode 
                                  ? AppTheme.darkTextSecondary 
                                  : AppTheme.textSecondary, // UPDATE INI
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Load more indicator
                          if (!chatState.hasMoreMessages)
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'No more messages',
                                style: TextStyle(
                                  color: isDarkMode 
                                    ? AppTheme.darkTextSecondary 
                                    : AppTheme.textSecondary, // UPDATE INI
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          
                          Expanded(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (scrollInfo) {
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
                                  physics: const ClampingScrollPhysics(),
                                  cacheExtent: 500,
                                  addAutomaticKeepAlives: true,
                                  addRepaintBoundaries: true,
                                  itemCount: chatState.messages.length + (chatState.isLoadingMore ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    // Show shimmer when loading more
                                    if (index == 0 && chatState.isLoadingMore) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                                        child: Column(
                                          children: [
                                            _buildShimmerMessageBubble(isFromAgent: true, isDarkMode: isDarkMode), // UPDATE INI
                                            const SizedBox(height: 8),
                                            _buildShimmerMessageBubble(isFromAgent: false, isDarkMode: isDarkMode), // UPDATE INI
                                            const SizedBox(height: 8),
                                            _buildShimmerMessageBubble(isFromAgent: true, isDarkMode: isDarkMode), // UPDATE INI
                                          ],
                                        ),
                                      );
                                    }
                                    
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
                color: isDarkMode 
                  ? AppTheme.darkSurface 
                  : const Color(0xFFF8F9FA), // UPDATE INI
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(color: AppTheme.primaryColor, width: 4),
                ),
              ),
              child: Row(
                children: [
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
                        const Text(
                          'Replying to:',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getReplyPreviewText(_replyingTo!),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode 
                              ? AppTheme.darkTextPrimary 
                              : const Color(0xFF4A4A4A), // UPDATE INI
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: isDarkMode 
                        ? AppTheme.darkTextSecondary 
                        : AppTheme.textSecondary, // UPDATE INI
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
          
          // Input widgets dengan background sesuai mode
          if (!widget.isArchived && !widget.isReadOnly && widget.room.status != 3)
            ChatInputWidget(
              onSendText: (text) => _handleSendText(text),
              onSendMedia: (type, data, filename) => _handleSendMedia(type, data, filename),
              replyingTo: _replyingTo,
            )
          else if (widget.isReadOnly)
            Container(
              padding: const EdgeInsets.all(16),
              color: isDarkMode 
                ? Colors.blue[900]!.withOpacity(0.3)
                : Colors.blue[50], // UPDATE INI
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history, 
                    color: isDarkMode 
                      ? Colors.blue[300]
                      : Colors.blue[700], // UPDATE INI
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Viewing conversation history (read-only)',
                    style: TextStyle(
                      color: isDarkMode 
                        ? Colors.blue[200]
                        : Colors.blue[700], // UPDATE INI
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else if (widget.isArchived)
            Container(
              padding: const EdgeInsets.all(16),
              color: isDarkMode 
                ? Colors.grey[800]
                : Colors.grey[200], // UPDATE INI
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.archive, 
                    color: isDarkMode 
                      ? Colors.grey[400]
                      : Colors.grey[600], // UPDATE INI
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'This conversation is archived',
                    style: TextStyle(
                      color: isDarkMode 
                        ? Colors.grey[400]
                        : Colors.grey[600], // UPDATE INI
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else if (widget.room.status == 3)
            Container(
              padding: const EdgeInsets.all(16),
              color: isDarkMode 
                ? Colors.green[900]!.withOpacity(0.3)
                : Colors.green[50], // UPDATE INI
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline, 
                    color: isDarkMode 
                      ? Colors.green[300]
                      : Colors.green[700], // UPDATE INI
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'This conversation has been resolved',
                    style: TextStyle(
                      color: isDarkMode 
                        ? Colors.green[200]
                        : Colors.green[700], // UPDATE INI
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Contact Detail Sliding Panel tetap sama
        if (_showContactDetail)
          GestureDetector(
            onTap: () {
              setState(() {
                _showContactDetail = false;
              });
            },
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          right: _showContactDetail ? 0 : -MediaQuery.of(context).size.width,
          top: 0,
          bottom: 0,
          width: MediaQuery.of(context).size.width * 0.85,
          child: Material(
            elevation: 8,
            child: ContactDetailScreen(
              contactId: widget.room.ctRealId ?? widget.room.ctId ?? widget.room.id,
              contactName: widget.room.name,
              contactImage: widget.room.contactImage ?? widget.room.linkImage,
              isSlidePanel: true,
              onClose: () {
                setState(() {
                  _showContactDetail = false;
                });
              },
            ),
          ),
        ),
      ],
      ),
    ),
  );
}

  // Update the _buildNormalAppBar() method in chat_screen.dart

PreferredSizeWidget _buildNormalAppBar() {
  return AppBar(
    backgroundColor: AppTheme.primaryColor,
    foregroundColor: Colors.white,
    elevation: 0,
    titleSpacing: 0, // Mengurangi jarak dari back button ke title
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
        
        const SizedBox(width: 8), // Dikurangi dari 12 ke 8
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.room.name.isNotEmpty 
                    ? widget.room.name 
                    : (widget.room.accountName ?? widget.room.botName ?? widget.room.channelName),
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
                  Flexible(
                    child: Text(
                      widget.room.accountName ?? widget.room.botName ?? widget.room.channelName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
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
      // Contact/Group Detail Icon - untuk individual dan group
      if ((!widget.room.isGroup && (widget.room.ctId != null || widget.room.ctRealId != null)) ||
          (widget.room.isGroup && widget.room.grpId != null))
        IconButton(
          icon: Icon(LucideIcons.columns, color: Colors.white),
          onPressed: _openContactDetailSlidePanel,
          tooltip: widget.room.isGroup ? 'Group Info' : 'Contact Info',
        ),
      
      if (!widget.isArchived)
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          onSelected: (String value) {
            switch (value) {
              case 'add_agent':
                _handleAddAgent();
                break;
              case 'resolve':
                _handleResolve();
                break;
              case 'archive':
                _handleArchive();
                break;
              case 'add_note':
                _handleAddNote();
                break;
              case 'help':
                _handleHelp();
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(
              value: 'add_agent',
              child: Row(
                children: [
                  Icon(Icons.person_add_outlined, size: 20, color: Colors.blue),
                  SizedBox(width: 12),
                  Text(
                    'Add Human Agent',
                    style: TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'resolve',
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
                  SizedBox(width: 12),
                  Text(
                    'Mark as Resolved',
                    style: TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'help',
              child: Row(
                children: [
                  Icon(Icons.help_outline, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text(
                    'Help',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
    ],
  );
}

// Add this new method to open contact/group detail with slide animation
void _openContactDetailSlidePanel() {
  // For group: use grpId, for contact: use ctRealId or ctId
  final contactId = widget.room.isGroup 
      ? (widget.room.grpId ?? widget.room.id)
      : (widget.room.ctRealId ?? widget.room.ctId ?? widget.room.id);
  
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => ContactDetailScreen(
        contactId: contactId,
        contactName: widget.room.name,
        contactImage: widget.room.contactImage ?? widget.room.linkImage,
        isSlidePanel: true,
        isGroup: widget.room.isGroup,
        groupDescription: widget.room.isGroup ? 'Group conversation' : null,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0); // Start from right
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    ),
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
    // WhatsApp channels - gunakan logo dari asset
    if (channelId == 1 || channelId == 1557 || channelId == 1561) {
      return Container(
        width: 16,
        height: 16,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/wa.png',
            width: 16,
            height: 16,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Channel lainnya tetap menggunakan icon dengan warna
    Color color = Colors.white70;
    IconData icon = Icons.chat_bubble;

    switch (channelId) {
      case 2: // Telegram
        color = const Color(0xFF0088CC);
        icon = Icons.send;
        break;
      case 3: // Instagram
        color = const Color(0xFFE4405F);
        icon = Icons.camera_alt;
        break;
      case 4: // Messenger
        color = const Color(0xFF0084FF);
        icon = Icons.messenger;
        break;
      case 19: // Email
        color = const Color(0xFFEA4335);
        icon = Icons.email;
        break;
    }

    return Icon(icon, size: 12, color: color);
  }

  void _handleSendText(String text) {
    final chatNotifier = ref.read(chatProvider.notifier);
    
    chatNotifier.sendTextMessage(
      text,
      replyId: _replyingTo?.id, // Pass the raw replyId, let the provider handle validation
    );
    
    // Clear reply after a short delay to ensure optimistic message shows reply info
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _replyingTo = null;
        });
      }
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

  void _handleResolve() async {
    final ok = await ref.read(chatProvider.notifier).markActiveRoomResolved();
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversation marked as resolved'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to mark as resolved'),
          backgroundColor: AppTheme.errorColor,
          duration: Duration(seconds: 2),
        ),
      );
    }
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

  void _handleAddAgent() {
    showDialog(
      context: context,
      builder: (context) => AddAgentDialog(
        roomId: widget.room.id,
        onAgentAdded: (agent) {
          // Optional: Reload messages or update UI if needed
          print('✅ Agent ${agent.displayName} added to conversation');
          // You can trigger a message reload here if needed:
          // ref.read(chatProvider.notifier).loadMessages();
        },
      ),
    );
  }

  void _handleAddNote() {
    showDialog(
      context: context,
      builder: (context) => AddNoteDialog(
        onSave: (content) async {
          final success = await ref.read(chatProvider.notifier).createNote(content);
          
          if (mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Note berhasil ditambahkan'),
                  backgroundColor: AppTheme.successColor,
                  duration: Duration(seconds: 2),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gagal menambahkan note'),
                  backgroundColor: AppTheme.errorColor,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _handleHelp() async {
    final url = Uri.parse('https://ubig-co-1.gitbook.io/nobox-ai/real-base-ai-articles-english/menu/messages/inbox');
    
    try {
      // FIXED: Coba beberapa mode launch untuk compatibility
      bool launched = false;
      
      // Try 1: External Application (recommended)
      try {
        launched = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        print('Failed with externalApplication mode: $e');
      }
      
      // Try 2: Platform Default (fallback)
      if (!launched) {
        try {
          launched = await launchUrl(
            url,
            mode: LaunchMode.platformDefault,
          );
        } catch (e) {
          print('Failed with platformDefault mode: $e');
        }
      }
      
      // Try 3: External Non-Browser Application (last resort)
      if (!launched) {
        launched = await launchUrl(
          url,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      }
      
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak bisa membuka dokumentasi. Pastikan ada browser terinstall.'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error opening help URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak bisa membuka dokumentasi. Pastikan ada browser terinstall.'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url.startsWith('file:///')) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  void _navigateToContactDetail() {
    // Only navigate if it's not a group chat and we have contact information
    if (!widget.room.isGroup && (widget.room.ctId != null || widget.room.ctRealId != null)) {
      final contactId = widget.room.ctRealId ?? widget.room.ctId ?? widget.room.id;
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ContactDetailScreen(
            contactId: contactId,
            contactName: widget.room.name,
            contactImage: widget.room.contactImage ?? widget.room.linkImage,
          ),
        ),
      );
    } else if (widget.room.isGroup) {
      // For group chats, show a message that it's a group
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This is a group conversation'),
          backgroundColor: AppTheme.primaryColor,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // For cases where contact ID is not available
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact details not available'),
          backgroundColor: AppTheme.warningColor,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Shimmer message bubble for loading more messages
// Update _buildShimmerMessageBubble untuk dark mode:
Widget _buildShimmerMessageBubble({required bool isFromAgent, required bool isDarkMode}) {
  return Align(
    alignment: isFromAgent ? Alignment.centerLeft : Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      child: Shimmer.fromColors(
        baseColor: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDarkMode ? Colors.grey[700]! : Colors.grey[100]!,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFromAgent)
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[700] : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              if (isFromAgent) const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 14,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[700] : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: MediaQuery.of(context).size.width * 0.5,
                height: 14,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[700] : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 60,
                height: 10,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[700] : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
