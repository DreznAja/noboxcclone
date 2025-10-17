import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/models/chat_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/app_config.dart';
import '../../core/services/account_service.dart';
import '../../core/providers/chat_provider.dart';
import 'room_shimmer_widget.dart';

class RoomListWidget extends ConsumerStatefulWidget {
  final List<Room> rooms;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? selectedRoomId;
  final Function(Room)? onRoomTap;
  final bool isSelectionMode;
  final Set<String> selectedRoomIds;
  final Function(String)? onRoomLongPress;
  final Function(String)? onRoomSelectionToggle;
  final bool isArchivedList;
  final String? searchQuery;
  final Map<String, dynamic>? filters;

  const RoomListWidget({
    super.key,
    required this.rooms,
    required this.isLoading,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.selectedRoomId,
    this.onRoomTap,
    this.isSelectionMode = false,
    this.selectedRoomIds = const {},
    this.onRoomLongPress,
    this.onRoomSelectionToggle,
    this.isArchivedList = false,
    this.searchQuery,
    this.filters,
  });

  @override
  ConsumerState<RoomListWidget> createState() => _RoomListWidgetState();
}

class _RoomListWidgetState extends ConsumerState<RoomListWidget> {
  @override
  Widget build(BuildContext context) {
    // Debug: Log when widget rebuilds with new data
    print('🏠 RoomListWidget rebuild: ${widget.rooms.length} rooms, loading: ${widget.isLoading}');
    
    // Show shimmer for initial load (no data yet)
    if (widget.isLoading && widget.rooms.isEmpty) {
      return const RoomShimmerWidget();
    }
    
    // Show shimmer for refresh (data exists but refreshing)
    if (widget.isLoading && widget.rooms.isNotEmpty) {
      return const RoomShimmerWidget();
    }

    if (widget.rooms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: AppTheme.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'No conversations found',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Sort rooms: pinned first, then by last message time
    final sortedRooms = List<Room>.from(widget.rooms);
    sortedRooms.sort((a, b) {
      // First, sort by pin status (pinned rooms first)
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      
      // Then sort by last message time (newest first)
      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });

    // Calculate item count: rooms + loading indicator
    final itemCount = widget.isLoadingMore ? sortedRooms.length + 1 : sortedRooms.length;

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        // Trigger load more when scrolled to 80% of the list
        if (!widget.isArchivedList && 
            !widget.isLoadingMore && 
            widget.hasMore && 
            scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.8) {
          print('📄 Triggering loadMoreRooms from scroll...');
          ref.read(chatProvider.notifier).loadMoreRooms(
            search: widget.searchQuery,
            filters: widget.filters,
          );
        }
        return false;
      },
      child: ListView.builder(
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Show shimmer effect at the bottom when loading more
          if (index >= sortedRooms.length) {
            return Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar shimmer
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Content shimmer
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Name shimmer
                              Container(
                                width: 120,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              
                              // Time shimmer
                              Container(
                                width: 40,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Account/Bot name shimmer
                          Container(
                            width: 80,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Last message shimmer
                          Container(
                            width: double.infinity,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
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

          final room = sortedRooms[index];
          final isSelected = room.id == widget.selectedRoomId;
          final isSelectedForAction = widget.selectedRoomIds.contains(room.id);
          
          return _RoomListItem(
            room: room,
            isSelected: isSelected,
            isSelectionMode: widget.isSelectionMode,
            isSelectedForAction: isSelectedForAction,
            isArchivedList: widget.isArchivedList,
            onTap: () {
              if (widget.isSelectionMode) {
                widget.onRoomSelectionToggle?.call(room.id);
              } else if (widget.onRoomTap != null) {
                widget.onRoomTap!(room);
              }
            },
            onLongPress: () {
              if (!widget.isSelectionMode) {
                widget.onRoomLongPress?.call(room.id);
              }
            },
          );
        },
      ),
    );
  }
}

class _RoomListItem extends StatelessWidget {
  final Room room;
  final bool isSelected;
  final bool isSelectionMode;
  final bool isSelectedForAction;
  final bool isArchivedList;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _RoomListItem({
    required this.room,
    required this.isSelected,
    required this.isSelectionMode,
    required this.isSelectedForAction,
    required this.isArchivedList,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : null,
      child: Column(
        children: [
          // Top separator line
          Container(
            height: 0.5,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          
          InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isSelectedForAction ? AppTheme.primaryColor.withOpacity(0.1) : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar atau Selection checkbox
                  _buildAvatarOrCheckbox(),
                  
                  const SizedBox(width: 12),
                  
                  // Content area
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // First row: Name, Mute Bot Icon, Time, Pin
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      room.name,
                                      style: TextStyle(
                                        fontWeight: room.unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Muted AI Agent icon - robot merah
                                  if (room.isMuteBot) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.smart_toy,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            
                            // Time
                            if (room.lastMessageTime != null)
                              Text(
                                _formatMessageTime(room.lastMessageTime!),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            
                            // Pin icon - tampil di normal mode dan selection mode
                            if (room.isPinned) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.push_pin,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                            ],
                          ],
                        ),
                        
                        const SizedBox(height: 3),

                        // Second row: Last message, Badge count
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                child: Text(
                                  room.lastMessage ?? 'No messages',
                                  style: TextStyle(
                                    // Need Reply ON → Merah (selalu, apapun status baca)
                                    // Need Reply OFF → Hitam (unread) atau Abu-abu (read) - default behavior
                                    color: room.needReply
                                        ? Colors.red
                                        : room.unreadCount > 0
                                            ? Colors.black
                                            : AppTheme.textSecondary,
                                    fontWeight: room.needReply || room.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            
                            // Badge count - tampil di normal mode dan selection mode
                            if (room.unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  room.unreadCount > 99 ? '99+' : room.unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 3),
                        
                        // Tags and Funnel row
                        if (room.tags.isNotEmpty || room.funnel != null) ...[
                          _buildTagsAndFunnelRow(room),
                          const SizedBox(height: 3),
                        ],
                        
                        // Bot name and Status chip row - dalam satu baris
                        Row(
                          children: [
                            _getChannelIcon(room.channelId),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _getBotName(room),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _getStatusChip(isArchivedList ? 4 : room.status),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom separator line
          Container(
            height: 0.5,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarOrCheckbox() {
    if (isSelectionMode) {
      // Selection mode: tampilkan checkbox
      return Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelectedForAction ? AppTheme.primaryColor : Colors.transparent,
            border: Border.all(
              color: isSelectedForAction ? AppTheme.primaryColor : Colors.grey.shade400,
              width: 2,
            ),
          ),
          child: isSelectedForAction
              ? const Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                )
              : null,
        ),
      );
    } else {
      // Normal mode: tampilkan avatar
      return Stack(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: _isValidImageUrl(room.contactImage ?? room.linkImage)
                ? NetworkImage(room.contactImage ?? room.linkImage!)
                : null,
            backgroundColor: AppTheme.neutralLight,
            child: !_isValidImageUrl(room.contactImage ?? room.linkImage)
                ? Icon(
                    room.isGroup ? Icons.group : Icons.person,
                    color: AppTheme.textSecondary,
                  )
                : null,
          ),
        ],
      );
    }
  }

  Widget _getChannelIcon(int channelId) {
    // WhatsApp channels - gunakan logo dari asset
    if (channelId == 1 || channelId == 1557 || channelId == 1561) {
      return Container(
        width: 17,
        height: 17,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/wa.png',
            width: 14,
            height: 14,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Channel lainnya tetap menggunakan icon
    Color color;
    IconData icon;

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
      default:
        color = AppTheme.textSecondary;
        icon = Icons.chat_bubble;
    }

    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 8,
        color: Colors.white,
      ),
    );
  }

  Widget _getStatusChip(int status) {
    String text;
    Color color;

    switch (status) {
      case 1:
        text = 'Unassigned';
        color = AppTheme.errorColor;
        break;
      case 2:
        text = 'Assigned';
        color = AppTheme.primaryColor;
        break;
      case 3:
        text = 'Resolved';
        color = AppTheme.successColor;
        break;
      case 4: // Support for archived status
        text = 'Archived';
        color = AppTheme.textSecondary;
        break;
      default:
        text = 'Unknown';
        color = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url.startsWith('file:///')) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  Widget _buildTagsAndFunnelRow(Room room) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          // Tags
          if (room.tags.isNotEmpty) ...[
            Icon(
              Icons.local_offer,
              size: 12,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                room.tags.join(', '),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          
          // Spacing between tags and funnel
          if (room.tags.isNotEmpty && room.funnel != null) ...[
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 12,
              color: AppTheme.textSecondary.withOpacity(0.3),
            ),
            const SizedBox(width: 8),
          ],
          
          // Funnel
          if (room.funnel != null) ...[
            Icon(
              Icons.filter_alt,
              size: 12,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                room.funnel!,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime messageTime) {
    // Convert to local timezone if it's UTC
    final localTime = messageTime.isUtc ? messageTime.toLocal() : messageTime;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(localTime.year, localTime.month, localTime.day);
    
    // Check if message is from today
    if (messageDate.isAtSameMomentAs(today)) {
      // Today: show only time (HH:mm)
      return DateFormat('HH:mm').format(localTime);
    } else {
      // Yesterday or before: show date and time (d MMM, HH:mm)
      return DateFormat('d MMM, HH:mm').format(localTime);
    }
  }

  String _getBotName(Room room) {
    // FIXED: Match ChatScreen AppBar display logic exactly
    // Priority: accountName -> botName -> AccountService -> channelName -> fallback
    
    // Priority 1: Use accountName if available (from DetailRoom)
    if (room.accountName != null && room.accountName!.isNotEmpty) {
      return room.accountName!;
    }
    
    // Priority 2: Use botName if available
    if (room.botName != null && room.botName!.isNotEmpty) {
      return room.botName!;
    }

    // Priority 3: Try AccountService to get account name for this channel
    // This provides dynamic names from backend that can change
    try {
      final accountService = AccountService();
      final accounts = accountService.getAccountsForChannel(room.channelId);
      if (accounts.isNotEmpty) {
        // Return account name as-is from backend
        return accounts.first.name;
      }
    } catch (e) {
      // Silently fail, will use fallback
    }

    // Priority 4: Use channelName from API if not "Not Found"
    if (room.channelName.isNotEmpty && room.channelName != 'Not Found') {
      return room.channelName;
    }

    // Priority 5: Final fallback - use generic name based on channel ID
    return _getChannelNameFromId(room.channelId);
  }

  String _getChannelNameFromId(int channelId) {
    switch (channelId) {
      case 1:
      case 1557:
      case 1561:
        return 'Bot WA';
      case 2:
        return 'Telegram Bot';
      case 3:
        return 'Instagram Bot';
      case 4:
        return 'Messenger Bot';
      case 19:
        return 'Email Bot';
      default:
        return 'Bot';
    }
  }
}