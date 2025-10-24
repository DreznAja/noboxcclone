import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/models/chat_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/app_config.dart';
import '../../core/services/account_service.dart';
import '../../core/providers/chat_provider.dart';
import 'room_shimmer_widget.dart';

// Update RoomListWidget untuk dark mode shimmer
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
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    
    print('🏠 RoomListWidget rebuild: ${widget.rooms.length} rooms, loading: ${widget.isLoading}');
    
    // Show shimmer for initial load or refresh
    if (widget.isLoading && widget.rooms.isEmpty) {
      return const RoomShimmerWidget();
    }
    
    if (widget.isLoading && widget.rooms.isNotEmpty) {
      return const RoomShimmerWidget();
    }

    if (widget.rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
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
      );
    }

    // Sort rooms
    final sortedRooms = List<Room>.from(widget.rooms);
    sortedRooms.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      
      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });

    final itemCount = widget.isLoadingMore ? sortedRooms.length + 1 : sortedRooms.length;

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
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
          // Show shimmer at bottom when loading more
          if (index >= sortedRooms.length) {
            return Shimmer.fromColors(
              baseColor: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
              highlightColor: isDarkMode ? Colors.grey[700]! : Colors.grey[100]!,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar shimmer
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[700] : Colors.white,
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
                              Container(
                                width: 120,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.grey[700] : Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              Container(
                                width: 40,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.grey[700] : Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 80,
                            height: 12,
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[700] : Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            height: 12,
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[700] : Colors.white,
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
class _RoomListItem extends ConsumerWidget {
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

// REPLACE bagian separator dan InkWell di _RoomListItem dengan ini:

@override
Widget build(BuildContext context, WidgetRef ref) {
  final isDarkMode = ref.watch(themeProvider).isDarkMode;
  
  return Container(
    color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : null,
    child: Column(
      children: [
        // Top separator line dengan margin
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          height: 0.5,
          color: isDarkMode 
            ? Colors.white.withOpacity(0.1)
            : Colors.grey.shade300,
        ),
        
        InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: isSelectedForAction ? AppTheme.primaryColor.withOpacity(0.1) : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar atau Selection checkbox
                _buildAvatarOrCheckbox(isDarkMode),
                
                const SizedBox(width: 12),
                
                // Content area (tetap sama)
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
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                      color: isDarkMode ? Colors.white : Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Muted AI Agent icon
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
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                              ),
                            ),
                          
                          // Pin icon
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
                                  color: room.needReply
                                      ? Colors.red
                                      : (isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                                  fontWeight: FontWeight.normal,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          
                          // Badge count
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
                        _buildTagsAndFunnelRow(room, isDarkMode),
                        const SizedBox(height: 3),
                      ],
                      
                      // Bot name and Status chip row
                      Row(
                        children: [
                          _getChannelIcon(room.channelId),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _getBotName(room),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
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
        
        // Bottom separator line dengan margin
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          height: 0.5,
          color: isDarkMode 
            ? Colors.white.withOpacity(0.1)
            : Colors.grey.shade300,
        ),
      ],
    ),
  );
}

  Widget _buildAvatarOrCheckbox(bool isDarkMode) {
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
            backgroundColor: isDarkMode ? AppTheme.darkSurface : AppTheme.neutralLight,
            child: !_isValidImageUrl(room.contactImage ?? room.linkImage)
                ? Icon(
                    room.isGroup ? Icons.group : Icons.person,
                    color: isDarkMode ? Colors.white : AppTheme.textSecondary,
                  )
                : null,
          ),
        ],
      );
    }
  }

  Widget _buildTagsAndFunnelRow(Room room, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          // Tags
          if (room.tags.isNotEmpty) ...[
            Icon(
              Icons.local_offer,
              size: 12,
              color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                room.tags.join(', '),
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
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
              color: (isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary).withOpacity(0.3),
            ),
            const SizedBox(width: 8),
          ],
          
          // Funnel
          if (room.funnel != null) ...[
            Icon(
              Icons.filter_alt,
              size: 12,
              color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                room.funnel!,
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
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
      case 4:
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

  String _formatMessageTime(DateTime messageTime) {
    final localTime = messageTime.isUtc ? messageTime.toLocal() : messageTime;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(localTime.year, localTime.month, localTime.day);
    
    if (messageDate.isAtSameMomentAs(today)) {
      return DateFormat('HH:mm').format(localTime);
    } else {
      return DateFormat('d MMM, HH:mm').format(localTime);
    }
  }

  String _getBotName(Room room) {
    if (room.accountName != null && room.accountName!.isNotEmpty) {
      return room.accountName!;
    }
    
    if (room.botName != null && room.botName!.isNotEmpty) {
      return room.botName!;
    }

    try {
      final accountService = AccountService();
      final accounts = accountService.getAccountsForChannel(room.channelId);
      if (accounts.isNotEmpty) {
        return accounts.first.name;
      }
    } catch (e) {
      // Silently fail
    }

    if (room.channelName.isNotEmpty && room.channelName != 'Not Found') {
      return room.channelName;
    }

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