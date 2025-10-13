import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/chat_provider.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/chat_models.dart';
import 'package:nobox_chat/presentation/widgets/room_list_widget.dart';
import '../chat/chat_screen.dart';

class ArsipContactScreen extends ConsumerStatefulWidget {
  const ArsipContactScreen({super.key});

  @override
  ConsumerState<ArsipContactScreen> createState() => _ArsipContactScreenState();
}

class _ArsipContactScreenState extends ConsumerState<ArsipContactScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Selection mode states
  bool _isSelectionMode = false;
  Set<String> _selectedRoomIds = {};

  @override
  void initState() {
    super.initState();

    // Load archived rooms
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).loadArchivedRooms();
    });
  }

  void _handleSearch(String query) {
    ref.read(chatProvider.notifier).loadArchivedRooms(search: query);
  }

  // Selection mode functions
  void _enterSelectionMode(String roomId) {
    setState(() {
      _isSelectionMode = true;
      _selectedRoomIds = {roomId};
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedRoomIds.clear();
    });
  }

  void _toggleRoomSelection(String roomId) {
    setState(() {
      if (_selectedRoomIds.contains(roomId)) {
        _selectedRoomIds.remove(roomId);
        if (_selectedRoomIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedRoomIds.add(roomId);
      }
    });
  }

  void _unarchiveSelectedRooms() async {
    final selectedRoomIdsList = _selectedRoomIds.toList();

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unarchiving conversations...'),
        backgroundColor: AppTheme.primaryColor,
        duration: Duration(seconds: 2),
      ),
    );

    // Unarchive rooms
    await ref.read(chatProvider.notifier).unarchiveRooms(selectedRoomIdsList);

    _exitSelectionMode();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('${selectedRoomIdsList.length} conversation(s) unarchived'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvoked: (didPop) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar:
            _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
        body: Column(
          children: [
            // Search bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search conversation',
                    hintStyle: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: _handleSearch,
                ),
              ),
            ),

            // Archived room list
            Expanded(
              child: chatState.isLoadingArchived
                  ? const Center(child: CircularProgressIndicator())
                  : chatState.archivedRooms.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.archive_outlined,
                                size: 64,
                                color: AppTheme.textSecondary,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No archived conversations',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Archived conversations will appear here',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RoomListWidget(
                          rooms: chatState.archivedRooms,
                          isLoading: false,
                          selectedRoomId: null,
                          onRoomTap: (room) async {
                            // Fetch complete room data before navigating
                            try {
                              print('🔍 Fetching complete archived room data for roomId: ${room.id}');
                              
                              final response = await ApiService.dio.post(
                                'Services/Chat/Chatrooms/DetailRoom',
                                data: {
                                  'EntityId': room.id,
                                },
                              );
                              
                              Room roomToNavigate = room; // Fallback to current room
                              
                              if (response.statusCode == 200 && 
                                  response.data['IsError'] != true && 
                                  response.data['Data'] != null) {
                                final roomData = response.data['Data']['Room'];
                                roomToNavigate = Room.fromJson(roomData);
                                print('✅ Got complete archived room data: ${roomToNavigate.name}, AccountName: ${roomToNavigate.accountName}, BotName: ${roomToNavigate.botName}');
                              } else {
                                print('⚠️ Failed to fetch complete archived room data, using list data');
                              }
                              
                              if (!mounted) return;
                              
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    room: roomToNavigate,
                                    isArchived: true,
                                  ),
                                ),
                              );
                            } catch (e) {
                              print('❌ Error fetching complete archived room data: $e');
                              
                              // Fallback to using the list data if API fails
                              if (!mounted) return;
                              
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    room: room,
                                    isArchived: true,
                                  ),
                                ),
                              );
                            }
                          },
                          isSelectionMode: _isSelectionMode,
                          selectedRoomIds: _selectedRoomIds,
                          onRoomLongPress: _enterSelectionMode,
                          onRoomSelectionToggle: _toggleRoomSelection,
                        ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      backgroundColor: AppTheme.primaryColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Archived Conversation',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      backgroundColor: AppTheme.primaryColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: _exitSelectionMode,
      ),
      title: Text(
        '${_selectedRoomIds.length} selected',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      actions: [
        // Unarchive icon
        IconButton(
          onPressed: _unarchiveSelectedRooms,
          icon: const Icon(Icons.unarchive, color: Colors.white, size: 24),
          padding: const EdgeInsets.all(8),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
