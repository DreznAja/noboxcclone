import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/models/chat_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/app_config.dart';

class RoomListWidget extends ConsumerWidget {
  final List<Room> rooms;
  final bool isLoading;
  final String? selectedRoomId;
  final Function(Room)? onRoomTap;
  final bool isSelectionMode;
  final Set<String> selectedRoomIds;
  final Function(String)? onRoomLongPress;
  final Function(String)? onRoomSelectionToggle;
  final bool isArchivedList;

  const RoomListWidget({
    super.key,
    required this.rooms,
    required this.isLoading,
    this.selectedRoomId,
    this.onRoomTap,
    this.isSelectionMode = false,
    this.selectedRoomIds = const {},
    this.onRoomLongPress,
    this.onRoomSelectionToggle,
    this.isArchivedList = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Debug: Log when widget rebuilds with new data
    print('🏠 RoomListWidget rebuild: ${rooms.length} rooms, loading: $isLoading');
    
    if (isLoading && rooms.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (rooms.isEmpty) {
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
    final sortedRooms = List<Room>.from(rooms);
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

    return ListView.builder(
      itemCount: sortedRooms.length,
      itemBuilder: (context, index) {
        final room = sortedRooms[index];
        final isSelected = room.id == selectedRoomId;
        final isSelectedForAction = selectedRoomIds.contains(room.id);
        
        return _RoomListItem(
          room: room,
          isSelected: isSelected,
          isSelectionMode: isSelectionMode,
          isSelectedForAction: isSelectedForAction,
          isArchivedList: isArchivedList,
          onTap: () {
            if (isSelectionMode) {
              onRoomSelectionToggle?.call(room.id);
            } else if (onRoomTap != null) {
              onRoomTap!(room);
            }
          },
          onLongPress: () {
            if (!isSelectionMode) {
              onRoomLongPress?.call(room.id);
            }
          },
        );
      },
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
                        // First row: Name, Time, Pin
                        Row(
                          children: [
                            Expanded(
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
                            
                            // Time
                            if (room.lastMessageTime != null)
                              Text(
                                timeago.format(room.lastMessageTime!),
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
                                    color: room.unreadCount > 0 ? Colors.red : AppTheme.textSecondary,
                                    fontWeight: room.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
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
                        if (room.tags.isNotEmpty || room.funnel != null)
                          _buildTagsAndFunnelRow(room),
                        
                        // Third row: Status chip - tampil di normal mode dan selection mode
                        Row(
                          children: [
                            const Spacer(),
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
    Color color;
    IconData icon;

    switch (channelId) {
      case 1: // WhatsApp
        color = const Color(0xFF25D366);
        icon = Icons.chat;
        break;
      case 1557: // WhatsApp Business
      case 1561:
        color = const Color(0xFF25D366);
        icon = Icons.business;
        break;
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
}