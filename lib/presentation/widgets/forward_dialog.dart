import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart';
import '../../core/models/chat_models.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/account_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/message_utils.dart';

class ForwardDialog extends ConsumerStatefulWidget {
  final ChatMessage message;

  const ForwardDialog({
    super.key,
    required this.message,
  });

  @override
  ConsumerState<ForwardDialog> createState() => _ForwardDialogState();
}

class _ForwardDialogState extends ConsumerState<ForwardDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Room> _filteredRooms = [];
  Set<String> _selectedRoomIds = {};
  bool _isForwarding = false;

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
    _searchController.addListener(_filterRooms);
    
    // Load rooms if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatState = ref.read(chatProvider);
      if (chatState.rooms.isEmpty) {
        ref.read(chatProvider.notifier).loadRooms();
      }
      _filterRooms();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterRooms() {
    final chatState = ref.read(chatProvider);
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _filteredRooms = chatState.rooms;
      } else {
        _filteredRooms = chatState.rooms.where((room) {
          return room.name.toLowerCase().contains(query) ||
                 (room.channelName.isNotEmpty && room.channelName.toLowerCase().contains(query));
        }).toList();
      }
    });
  }

  void _toggleRoomSelection(String roomId) {
    setState(() {
      if (_selectedRoomIds.contains(roomId)) {
        _selectedRoomIds.remove(roomId);
      } else {
        _selectedRoomIds.add(roomId);
      }
    });
  }

  Future<void> _forwardMessage() async {
    if (_selectedRoomIds.isEmpty) {
      NotificationService.showWarning(context, 'Please select at least one conversation');
      return;
    }

    setState(() {
      _isForwarding = true;
    });

    try {
      int successCount = 0;
      int failureCount = 0;

      for (final roomId in _selectedRoomIds) {
        try {
          // Find the target room
          final targetRoom = _filteredRooms.firstWhere((room) => room.id == roomId);
          
          // Forward message directly via API without changing active room
          await _forwardToRoom(targetRoom, widget.message);
          
          successCount++;
        } catch (e) {
          print('Failed to forward to room $roomId: $e');
          failureCount++;
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        
        if (successCount > 0) {
          NotificationService.showSuccess(
            context, 
            'Message forwarded to $successCount conversation${successCount > 1 ? 's' : ''}'
          );
        }
        
        if (failureCount > 0) {
          NotificationService.showError(
            context, 
            'Failed to forward to $failureCount conversation${failureCount > 1 ? 's' : ''}'
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to forward message: $e');
      }
    } finally {
      setState(() {
        _isForwarding = false;
      });
    }
  }

  Future<void> _forwardToRoom(Room targetRoom, ChatMessage message) async {
    try {
      // Get account ID for the target room's channel
      final accountService = AccountService();
      final effectiveChannelId = _getEffectiveChannelId(targetRoom.channelId);
      final accountId = accountService.getAccountIdForChannel(effectiveChannelId);
      
      if (accountId == null) {
        throw Exception('No account found for channel ${targetRoom.channelId}');
      }
      
      final linkId = targetRoom.ctId?.isNotEmpty == true ? targetRoom.ctId! : targetRoom.id;
      
      // Prepare message data based on message type
      Map<String, dynamic> messageData;
      
      if (message.type == 1) {
        // Text message
        messageData = {
          'LinkId': int.tryParse(linkId),
          'ChannelId': effectiveChannelId,
          'AccountIds': accountId,
          'BodyType': 1,
          'Body': '📤 Forwarded: ${message.message?.trim() ?? 'Message'}',
          'Attachment': '',
        };
      } else {
        // Media message - forward as text description
        final description = _getForwardedMessageDescription(message);
        messageData = {
          'LinkId': int.tryParse(linkId),
          'ChannelId': effectiveChannelId,
          'AccountIds': accountId,
          'BodyType': 1,
          'Body': description,
          'Attachment': '',
        };
      }
      
      // Validate required fields
      if (messageData['LinkId'] == null || messageData['LinkId'] == 0) {
        throw Exception('Invalid LinkId for room ${targetRoom.name}');
      }
      
      // Send via API
      final response = await ApiService.sendMessage(messageData);
      
      if (response.isError) {
        throw Exception(response.error?.isNotEmpty == true ? response.error! : 'Failed to send to ${targetRoom.name}');
      }
      
      print('✅ Message forwarded successfully to ${targetRoom.name}');
      
    } catch (e) {
      print('❌ Failed to forward to ${targetRoom.name}: $e');
      rethrow;
    }
  }
  
  int _getEffectiveChannelId(int displayChannelId) {
    // Map display channel IDs to actual API channel IDs
    switch (displayChannelId) {
      case 1: // WhatsApp display -> WhatsApp Business API
        return 1561;
      case 1557: // WhatsApp Business display -> WhatsApp Business API  
        return 1561;
      case 2: // Telegram
        return 2;
      case 3: // Instagram
        return 3;
      case 4: // Messenger
        return 4;
      case 6: // TikTok
        return 6;
      case 19: // Email
        return 19;
      case 1492: // Bukalapak
        return 1492;
      case 1502: // Blibli
        return 1502;
      case 1503: // Lazada
        return 1503;
      case 1504: // Shopee
        return 1504;
      case 1505: // Tokopedia
        return 1505;
      case 1532: // OLX
        return 1532;
      case 1556: // Blibli Seller
        return 1556;
      case 1562: // Tokopedia Seller
        return 1562;
      case 1569: // Nobox Chat
        return 1569;
      default:
        return displayChannelId;
    }
  }

  String _getForwardedMessageDescription(ChatMessage message) {
    final prefix = '📤 Forwarded: ';
    
    switch (widget.message.type) {
      case 1:
        return '$prefix${message.message?.trim().isNotEmpty == true ? message.message!.trim() : 'Text message'}';
      case 2:
        final caption = message.message?.trim();
        return caption?.isNotEmpty == true 
            ? '$prefix🔊 Audio: $caption'
            : '${prefix}🔊 Audio Message';
      case 3:
        final caption = message.message?.trim();
        return caption?.isNotEmpty == true 
            ? '$prefix🖼 Photo: $caption'
            : '${prefix}🖼 Photo';
      case 4:
        final caption = message.message?.trim();
        return caption?.isNotEmpty == true 
            ? '$prefix🎬 Video: $caption'
            : '${prefix}🎬 Video';
      case 5:
        final caption = message.message?.trim();
        return caption?.isNotEmpty == true 
            ? '$prefix📄 Document: $caption'
            : '${prefix}📄 Document';
      case 7:
        return '${prefix}🌟 Sticker';
      case 9:
        return message.message?.trim().isNotEmpty == true ? message.message!.trim() : '${prefix}📍 Location';
      default:
        return message.message?.trim().isNotEmpty == true ? message.message!.trim() : '${prefix}Message';
    }
  }

  String _getMessageDescription() {
    return _getForwardedMessageDescription(widget.message);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.forward_to_inbox,
                    color: Color(0xFF1976D2),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Forward Message',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Message preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkBackground : AppTheme.neutralLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade300
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getMessageIcon(),
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getMessagePreview(),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Search bar
            Container(
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkBackground : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade300
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  hintStyle: TextStyle(
                    color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Selected count
            if (_selectedRoomIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_selectedRoomIds.length} conversation${_selectedRoomIds.length > 1 ? 's' : ''} selected',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Room list
            Expanded(
              child: chatState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredRooms.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No conversations found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredRooms.length,
                          itemBuilder: (context, index) {
                            final room = _filteredRooms[index];
                            final isSelected = _selectedRoomIds.contains(room.id);
                            
                            return _ForwardRoomItem(
                              room: room,
                              isSelected: isSelected,
                              onTap: () => _toggleRoomSelection(room.id),
                              isDarkMode: isDarkMode,
                            );
                          },
                        ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.primaryColor,
                      side: BorderSide(
                        color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.primaryColor
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isForwarding || _selectedRoomIds.isEmpty ? null : _forwardMessage,
                    child: _isForwarding
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Forward (${_selectedRoomIds.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  IconData _getMessageIcon() {
    switch (widget.message.type) {
      case 1:
        return Icons.chat_bubble_outline;
      case 2:
        return Icons.mic;
      case 3:
        return Icons.image;
      case 4:
        return Icons.videocam;
      case 5:
        return Icons.insert_drive_file;
      case 7:
        return Icons.emoji_emotions;
      case 9:
        return Icons.location_on;
      default:
        return Icons.message;
    }
  }

  String _getMessagePreview() {
    switch (widget.message.type) {
      case 1:
        return widget.message.message ?? 'Text message';
      case 2:
        return '🔊 Audio message';
      case 3:
        final caption = widget.message.message?.trim();
        return caption?.isNotEmpty == true ? '🖼 Photo: $caption' : '🖼 Photo';
      case 4:
        final caption = widget.message.message?.trim();
        return caption?.isNotEmpty == true ? '🎬 Video: $caption' : '🎬 Video';
      case 5:
        return '📄 Document';
      case 7:
        return '🌟 Sticker';
      case 9:
        return widget.message.message ?? '📍 Location';
      default:
        return 'Message';
    }
  }
}

class _ForwardRoomItem extends StatelessWidget {
  final Room room;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _ForwardRoomItem({
    required this.room,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
  });

  Map<String, String> _getAuthHeaders() {
    final token = StorageService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'User-Agent': 'NoboxChat/1.0',
    };
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Selection checkbox
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected 
                    ? AppTheme.primaryColor 
                    : (isDarkMode ? Colors.white.withOpacity(0.3) : Colors.grey.shade400),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            
            const SizedBox(width: 12),
            
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundImage: _isValidImageUrl(room.contactImage ?? room.linkImage)
                  ? CachedNetworkImageProvider(
                      room.contactImage ?? room.linkImage!,
                      headers: _getAuthHeaders(),
                    )
                  : null,
              backgroundColor: AppTheme.neutralLight,
              child: !_isValidImageUrl(room.contactImage ?? room.linkImage)
                  ? Icon(
                      room.isGroup ? Icons.group : Icons.person,
                      color: AppTheme.textSecondary,
                      size: 20,
                    )
                  : null,
            ),
            
            const SizedBox(width: 12),
            
            // Room info
            Expanded(
              child: Text(
                room.name,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url.startsWith('file:///')) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }
}