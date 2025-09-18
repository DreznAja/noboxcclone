import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/chat_models.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/theme/app_theme.dart';
import 'message_bubble_widget.dart';
import 'chat_input_widget.dart';

class ChatDetailWidget extends ConsumerStatefulWidget {
  final Room room;
  final List<ChatMessage> messages;
  final bool isLoading;

  const ChatDetailWidget({
    super.key,
    required this.room,
    required this.messages,
    required this.isLoading,
  });

  @override
  ConsumerState<ChatDetailWidget> createState() => _ChatDetailWidgetState();
}

class _ChatDetailWidgetState extends ConsumerState<ChatDetailWidget> {
  final ScrollController _scrollController = ScrollController();
  ChatMessage? _replyingTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void didUpdateWidget(ChatDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Scroll to bottom when new messages arrive
    if (widget.messages.length > oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleReply(ChatMessage message) {
    setState(() {
      _replyingTo = message;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: widget.room.contactImage != null || widget.room.linkImage != null
                    ? NetworkImage(widget.room.contactImage ?? widget.room.linkImage!)
                    : null,
                backgroundColor: AppTheme.neutralLight,
                child: widget.room.contactImage == null && widget.room.linkImage == null
                    ? Icon(
                        widget.room.isGroup ? Icons.group : Icons.person,
                        color: AppTheme.textSecondary,
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
                        fontSize: 18,
                      ),
                    ),
                    
                    Row(
                      children: [
                        _getChannelIcon(widget.room.channelId),
                        const SizedBox(width: 6),
                        Text(
                          widget.room.channelName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              PopupMenuButton<String>(
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
          ),
        ),
        
        // Messages
        Expanded(
          child: widget.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.messages.length,
                  itemBuilder: (context, index) {
                    final message = widget.messages[index];
                    return MessageBubbleWidget(
                      message: message,
                      onReply: () => _handleReply(message),
                      onDelete: () => _handleDelete(message),
                      showSenderInfo: true,
                    );
                  },
                ),
        ),
        
        // Reply preview
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.neutralLight,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(color: AppTheme.primaryColor, width: 3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Replying to',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        _replyingTo!.message ?? 'Media message',
                        style: const TextStyle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _cancelReply,
                  iconSize: 20,
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
    );
  }

  Widget _getChannelIcon(int channelId) {
    Color color = AppTheme.textSecondary;
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
    // This will be handled by the provider
  }

  void _handleSendMedia(String type, String data, String filename) {
    // This will be handled by the provider
  }

  void _handleResolve() {
    // Implement resolve functionality
  }

  void _handleArchive() {
    // Implement archive functionality
  }

  void _handleDelete(ChatMessage message) {
    // Implement delete functionality
  }
}