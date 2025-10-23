import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart'; // TAMBAHKAN INI
import '../../../core/models/chat_models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/account_service.dart';
import '../../../core/theme/app_theme.dart';
import '../chat/chat_screen.dart';

class ConversationHistoryScreen extends ConsumerStatefulWidget {
  final String contactId;
  final String contactName;
  final String? contactImage;

  const ConversationHistoryScreen({
    super.key,
    required this.contactId,
    required this.contactName,
    this.contactImage,
  });

  @override
  ConsumerState<ConversationHistoryScreen> createState() => _ConversationHistoryScreenState();
}

class _ConversationHistoryScreenState extends ConsumerState<ConversationHistoryScreen> {
  List<Room> _historyRooms = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversationHistory();
  }

  Future<void> _loadConversationHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('📜 Loading conversation history for contact: ${widget.contactId}');
      
      final response = await ApiService.getConversationHistory(widget.contactId);
      
      if (response.isError) {
        setState(() {
          _error = response.error;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _historyRooms = response.data ?? [];
        _isLoading = false;
      });

      print('✅ Loaded ${_historyRooms.length} conversation history items');
    } catch (e) {
      print('❌ Error loading conversation history: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openConversation(Room room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          room: room,
          isReadOnly: true,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('dd MMM yyyy').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode; // TAMBAHKAN INI
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : const Color(0xFFF8F9FA), // UPDATE
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor, // Tetap biru
        foregroundColor: Colors.white, // UPDATE
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conversation History',
              style: TextStyle(
                color: Colors.white, // UPDATE
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.contactName,
              style: const TextStyle(
                color: Colors.white70, // UPDATE
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor, // TAMBAHKAN
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: isDarkMode 
                          ? AppTheme.darkTextSecondary 
                          : Colors.grey, // UPDATE
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load conversation history',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode 
                            ? AppTheme.darkTextSecondary 
                            : Colors.grey, // UPDATE
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode 
                            ? AppTheme.darkTextSecondary 
                            : Colors.grey, // UPDATE
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadConversationHistory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _historyRooms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: isDarkMode 
                              ? AppTheme.darkTextSecondary 
                              : Colors.grey.shade400, // UPDATE
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No conversation history',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode 
                                ? AppTheme.darkTextSecondary 
                                : Colors.grey, // UPDATE
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _historyRooms.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1, 
                        color: isDarkMode 
                          ? Colors.white.withOpacity(0.1) 
                          : null, // UPDATE
                      ),
                      itemBuilder: (context, index) {
                        final room = _historyRooms[index];
                        return _buildHistoryItem(room, isDarkMode); // PASS PARAMETER
                      },
                    ),
    );
  }

  Widget _buildHistoryItem(Room room, bool isDarkMode) { // TAMBAHKAN PARAMETER
    return Container(
      color: isDarkMode ? AppTheme.darkSurface : Colors.white, // UPDATE
      child: Column(
        children: [
          // Top separator line
          Container(
            height: 0.5,
            color: isDarkMode 
              ? Colors.white.withOpacity(0.1) 
              : Colors.grey.shade300, // UPDATE
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          
          InkWell(
            onTap: () => _openConversation(room),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: _isValidImageUrl(room.contactImage ?? room.linkImage)
                        ? NetworkImage(room.contactImage ?? room.linkImage!)
                        : null,
                    backgroundColor: isDarkMode 
                      ? Colors.grey.shade800 
                      : Colors.grey.shade200, // UPDATE
                    child: !_isValidImageUrl(room.contactImage ?? room.linkImage)
                        ? Icon(
                            room.isGroup ? Icons.group : Icons.person,
                            color: isDarkMode 
                              ? AppTheme.darkTextSecondary 
                              : Colors.grey, // UPDATE
                          )
                        : null,
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Content area
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // First row: Name and Time
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                room.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                  color: isDarkMode 
                                    ? AppTheme.darkTextPrimary 
                                    : Colors.black, // UPDATE
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            
                            // Time
                            if (room.lastMessageTime != null)
                              Text(
                                _formatDateTime(room.lastMessageTime),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode 
                                    ? AppTheme.darkTextSecondary 
                                    : AppTheme.textSecondary, // UPDATE
                                ),
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 3),

                        // Second row: Last message
                        Text(
                          room.lastMessage ?? 'No messages',
                          style: TextStyle(
                            color: isDarkMode 
                              ? AppTheme.darkTextSecondary 
                              : AppTheme.textSecondary, // UPDATE
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 3),
                        
                        // Tags and Funnel row
                        if (room.tags.isNotEmpty || room.funnel != null) ...[
                          _buildTagsAndFunnelRow(room, isDarkMode), // PASS PARAMETER
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
                                  color: isDarkMode 
                                    ? AppTheme.darkTextSecondary 
                                    : AppTheme.textSecondary, // UPDATE
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _getStatusChip(room.status),
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
            color: isDarkMode 
              ? Colors.white.withOpacity(0.1) 
              : Colors.grey.shade300, // UPDATE
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ],
      ),
    );
  }

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
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

    // Channel lainnya
    Color color;
    IconData icon;

    switch (channelId) {
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
        color: Colors.white,
        size: 8,
      ),
    );
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

  Widget _getStatusChip(int status) {
    String label;
    Color color;

    switch (status) {
      case 1:
        label = 'Open';
        color = const Color(0xFF10B981);
        break;
      case 2:
        label = 'Pending';
        color = const Color(0xFFF59E0B);
        break;
      case 3:
        label = 'Resolved';
        color = const Color(0xFF10B981);
        break;
      case 4:
        label = 'Archived';
        color = const Color(0xFF6B7280);
        break;
      default:
        label = 'Open';
        color = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTagsAndFunnelRow(Room room, bool isDarkMode) { // TAMBAHKAN PARAMETER
    return Row(
      children: [
        // Tags
        if (room.tags.isNotEmpty) ...[
          Flexible(
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: room.tags.take(2).map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDarkMode 
                      ? Colors.blue.shade900.withOpacity(0.3) 
                      : Colors.blue.shade50, // UPDATE
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDarkMode 
                        ? Colors.blue.shade700 
                        : Colors.blue.shade200, // UPDATE
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.label, 
                        size: 10, 
                        color: isDarkMode 
                          ? Colors.blue.shade300 
                          : Colors.blue.shade700, // UPDATE
                      ),
                      const SizedBox(width: 2),
                      Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDarkMode 
                            ? Colors.blue.shade300 
                            : Colors.blue.shade700, // UPDATE
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          if (room.tags.length > 2)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isDarkMode 
                  ? Colors.grey.shade800 
                  : Colors.grey.shade200, // UPDATE
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '+${room.tags.length - 2}',
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkMode 
                    ? AppTheme.darkTextSecondary 
                    : Colors.grey.shade700, // UPDATE
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
        
        // Funnel
        if (room.funnel != null) ...[
          if (room.tags.isNotEmpty) const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDarkMode 
                ? Colors.purple.shade900.withOpacity(0.3) 
                : Colors.purple.shade50, // UPDATE
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isDarkMode 
                  ? Colors.purple.shade700 
                  : Colors.purple.shade200, // UPDATE
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_alt, 
                  size: 10, 
                  color: isDarkMode 
                    ? Colors.purple.shade300 
                    : Colors.purple.shade700, // UPDATE
                ),
                const SizedBox(width: 2),
                Text(
                  room.funnel!,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode 
                      ? Colors.purple.shade300 
                      : Colors.purple.shade700, // UPDATE
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}