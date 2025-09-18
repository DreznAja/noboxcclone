import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/services/signalr_service.dart';
import '../../../core/services/account_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/filter_models.dart';
import '../../../core/models/chat_models.dart';
import '../../widgets/room_list_widget.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/filter_dialog.dart';
import '../../widgets/new_conversation_dialog.dart';
import '../auth/login_screen.dart';
import '../chat/chat_screen.dart';
import '../debug/whatsapp_debug_screen.dart';
import 'arsip_contact_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _selectedTab = 'all';
  bool _isSearchMode = false;
  FilterOptions _filterOptions = FilterOptions();
  
  // Selection mode states
  bool _isSelectionMode = false;
  Set<String> _selectedRoomIds = {};

  @override
  void initState() {
    super.initState();
    
    // Load initial data and ensure SignalR connection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).loadRooms();
      ref.read(chatProvider.notifier).loadArchivedRooms(); // Also load archived rooms for count
      _ensureSignalRConnection();
    });
    
    // Listen to chat state changes for real-time updates
    // This ensures the UI updates when new messages arrive
  }

  Future<void> _ensureSignalRConnection() async {
    // Ensure SignalR is connected when home screen loads
    try {
      print('🔌 Ensuring SignalR connection on home screen...');
      await SignalRService.ensureConnection();
      print('✅ SignalR connection ensured on home screen');
      
      // Also ensure account mappings are up to date
      try {
        final accountService = AccountService();
        final availableChannels = accountService.getAvailableChannels();
        print('📊 User has accounts for ${availableChannels.length} channels: $availableChannels');
      } catch (e) {
        print('⚠️ Could not check account mappings: $e');
      }
      
    } catch (e) {
      print('❌ Failed to ensure SignalR connection on home screen: $e');
    }
  }

  void _handleSearch(String query) {
    _applyFilters(searchQuery: query);
  }

  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // Add this helper method to your _HomeScreenState class:
int _getSelectedIndex() {
  switch (_selectedTab) {
    case 'all':
      return 0;
    case 'unassigned':
      return 1;
    case 'assigned':
      return 2;
    case 'resolved':
      return 3;
    default:
      return 0;
  }
}

  Map<String, dynamic> _getFiltersForTab(String tab) {
    // FIXED: Ensure archived rooms (status 4) are never shown in home screen
    switch (tab) {
      case 'unassigned':
        return {'St': [1]}; // Only unassigned
      case 'assigned':
        return {'St': [2]}; // Only assigned
      case 'resolved':
        return {'St': [3]}; // Only resolved
      default:
        return {'St': [1, 2, 3]}; // All active statuses, explicitly exclude archived (4)
    }
  }

  void _selectTab(String tab) {
    setState(() {
      _selectedTab = tab;
    });
    
    // Apply filters when tab is selected
    _applyFilters();
  }

  void _applyFilters({String? searchQuery}) {
    // Get base filters for selected tab (this excludes archived by default)
    final tabFilters = _getFiltersForTab(_selectedTab);
    
    // Get additional filters from filter options
    final additionalFilters = _filterOptions.toMap();
    
    // Merge filters - additionalFilters override tabFilters for same keys
    final mergedFilters = <String, dynamic>{};
    mergedFilters.addAll(tabFilters);
    
    // Handle special case for status (St) - ensure archived is never included
    if (additionalFilters.containsKey('St')) {
      final userSelectedStatuses = additionalFilters['St'] as List<dynamic>;
      // Filter out archived status (4) even if user somehow selected it
      final filteredStatuses = userSelectedStatuses.where((status) => status != 4).toList();
      if (filteredStatuses.isNotEmpty) {
        mergedFilters['St'] = filteredStatuses;
      }
    }
    
    // Add all other filters
    additionalFilters.forEach((key, value) {
      if (key != 'St') { // Skip St as we handled it above
        mergedFilters[key] = value;
      }
    });

    print('Applying filters (excluding archived): $mergedFilters'); // Debug print
    
    // Apply to chat provider
    ref.read(chatProvider.notifier).loadRooms(
      search: searchQuery?.isNotEmpty == true ? searchQuery : null,
      filters: mergedFilters.isNotEmpty ? mergedFilters : null,
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => FilterDialog(
        initialFilters: _filterOptions,
        onApply: (FilterOptions filters) {
          setState(() {
            _filterOptions = filters;
          });
          
          print('Filter applied: ${filters.toMap()}'); // Debug print
          
          // Apply filters immediately
          _applyFilters(
            searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
          );
        },
      ),
    );
  }

  void _navigateToChat(room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(room: room),
      ),
    );
  }

  void _navigateToArchive() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ArsipContactScreen(),
      ),
    );
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

  void _pinSelectedRooms() {
    final chatState = ref.read(chatProvider);
    final selectedRooms = chatState.rooms.where((room) => _selectedRoomIds.contains(room.id)).toList();
    
    for (final room in selectedRooms) {
      ref.read(chatProvider.notifier).togglePinRoom(room.id, !room.isPinned);
    }
    
    _exitSelectionMode();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedRooms.any((r) => !r.isPinned) 
            ? '${selectedRooms.length} conversation(s) pinned'
            : '${selectedRooms.length} conversation(s) unpinned'
        ),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _archiveSelectedRooms() async {
    final selectedRoomIdsList = _selectedRoomIds.toList();
    
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Archiving conversations...'),
        backgroundColor: AppTheme.primaryColor,
        duration: Duration(seconds: 2),
      ),
    );
    
    // Archive rooms
    await ref.read(chatProvider.notifier).archiveRooms(selectedRoomIdsList);
    
    _exitSelectionMode();
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${selectedRoomIdsList.length} conversation(s) archived'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  // Pull to refresh function
  Future<void> _handleRefresh() async {
    try {
      // Refresh rooms with current filters
      await ref.read(chatProvider.notifier).loadRooms(
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        filters: _getFiltersForTab(_selectedTab).isNotEmpty || _filterOptions.hasActiveFilters
            ? (() {
                final tabFilters = _getFiltersForTab(_selectedTab);
                final additionalFilters = _filterOptions.toMap();
                final mergedFilters = <String, dynamic>{};
                mergedFilters.addAll(tabFilters);
                
                if (additionalFilters.containsKey('St')) {
                  final userSelectedStatuses = additionalFilters['St'] as List<dynamic>;
                  final filteredStatuses = userSelectedStatuses.where((status) => status != 4).toList();
                  if (filteredStatuses.isNotEmpty) {
                    mergedFilters['St'] = filteredStatuses;
                  }
                }
                
                additionalFilters.forEach((key, value) {
                  if (key != 'St') {
                    mergedFilters[key] = value;
                  }
                });
                
                return mergedFilters.isNotEmpty ? mergedFilters : null;
              })()
            : null,
      );
      
      // Also refresh archived rooms count
      await ref.read(chatProvider.notifier).loadArchivedRooms();
    } catch (e) {
      print('Error refreshing data: $e');
      // Show error message if needed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to refresh data'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // FloatingActionButton onPressed function - Updated to show new conversation dialog
  void _onFloatingActionButtonPressed() {
    showDialog(
      context: context,
      builder: (context) => const NewConversationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final authState = ref.watch(authProvider);

    // Listen for real-time updates and refresh UI
    ref.listen<ChatState>(chatProvider, (previous, next) {
      // Log when rooms are updated for debugging
      if (previous != null && next.rooms.length != previous.rooms.length) {
        print('🏠 HOME: Room count changed from ${previous.rooms.length} to ${next.rooms.length}');
      }
      
      // If archived rooms count decreased (items were unarchived), refresh regular rooms
      if (previous != null && 
          previous.archivedRooms.length > next.archivedRooms.length &&
          !next.isLoading) {
        print('Archived rooms count decreased, refreshing regular rooms');
        // Small delay to ensure backend has processed the unarchive
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ref.read(chatProvider.notifier).loadRooms();
          }
        });
      }
      
      // Show error messages if any
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
    });

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvoked: (didPop) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _isSelectionMode 
            ? _buildSelectionAppBar() 
            : (_isSearchMode ? _buildSearchAppBar() : _buildNormalAppBar()),
        ),
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppTheme.primaryColor,
          backgroundColor: Colors.white,
          child: Column(
            children: [
              // Connection status and filter indicator
              // Container(
              //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              //   color: Colors.white,
              //   child: Row(
              //     children: [
              //       Consumer(
              //         builder: (context, ref, child) {
              //           final chatState = ref.watch(chatProvider);
              //           final isConnected = chatState.connectionStatus == 'connected';
              //           final isConnecting = chatState.connectionStatus == 'connecting';
                        
              //           return Row(
              //             children: [
              //               Container(
              //                 width: 8,
              //                 height: 8,
              //                 decoration: BoxDecoration(
              //                   color: isConnected 
              //                       ? Colors.green 
              //                       : (isConnecting ? Colors.orange : Colors.red),
              //                   shape: BoxShape.circle,
              //                 ),
              //               ),
              //               const SizedBox(width: 6),
              //               Text(
              //                 isConnected 
              //                     ? 'Connected' 
              //                     : (isConnecting ? 'Connecting...' : 'Disconnected'),
              //                 style: TextStyle(
              //                   fontSize: 12,
              //                   color: isConnected 
              //                       ? Colors.green 
              //                       : (isConnecting ? Colors.orange : Colors.red),
              //                   fontWeight: FontWeight.w500,
              //                 ),
              //               ),
              //             ],
              //           );
              //         },
              //       ),
              //       const Spacer(),
              //       if (_filterOptions.hasActiveFilters)
              //         Container(
              //           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              //           decoration: BoxDecoration(
              //             color: AppTheme.primaryColor.withOpacity(0.1),
              //             borderRadius: BorderRadius.circular(12),
              //           ),
              //           child: Text(
              //             'Filtered',
              //             style: TextStyle(
              //               fontSize: 11,
              //               color: AppTheme.primaryColor,
              //               fontWeight: FontWeight.w500,
              //             ),
              //           ),
              //         ),
              //     ],
              //   ),
              // ),
            
              // Tabs - tetap tampil meskipun selection mode
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    _buildTab('all', 'All'),
                    _buildTab('unassigned', 'Unassigned'),
                    _buildTab('assigned', 'Assigned'),
                    _buildTab('resolved', 'Resolved'),
                  ],
                ),
              ),

              // Archived Conversation Section - aligned with contact list layout
              Container(
                color: Colors.white,
                padding: const EdgeInsets.only(bottom: 6), // Reduced spacing between archived and contact list
                child: InkWell(
                  onTap: _navigateToArchive,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Archive icon - aligned with avatar (same size as avatar area)
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.archive_outlined,
                            color: Color(0xFF007AFF),
                            size: 35,
                          ),
                        ),
                        
                        const SizedBox(width: 12), // Same spacing as in RoomListItem
                        
                        // Text - aligned with contact name
                        const Expanded(
                          child: Text(
                            'Archived Conversation',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        
                        // Arrow at the right
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Room List with Pull to Refresh
              Expanded(
                child: RoomListWidget(
                  rooms: chatState.rooms,
                  isLoading: chatState.isLoading,
                  selectedRoomId: null,
                  onRoomTap: _isSelectionMode ? null : _navigateToChat,
                  isSelectionMode: _isSelectionMode,
                  selectedRoomIds: _selectedRoomIds,
                  onRoomLongPress: _enterSelectionMode,
                  onRoomSelectionToggle: _toggleRoomSelection,
                ),
              ),
            ],
          ),
        ),
        // Updated FloatingActionButton to show new conversation dialog
        floatingActionButton: Container(
          margin: const EdgeInsets.only(bottom: 20, right: 10),
          child: SizedBox(
            width: 60,
            height: 60,
            child: FloatingActionButton(
              onPressed: _onFloatingActionButtonPressed,
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 6,
              child: const Icon(
                Icons.add,
                size: 30,
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildNormalAppBar() {
    return Container(
      color: AppTheme.primaryColor,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
      ),
      child: SizedBox(
        height: 60,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 12),
            Image.asset(
              'assets/nobox.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 16),

            // Title
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NoBox Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),

            // Compact icon group
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search icon
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isSearchMode = true;
                    });
                  },
                  icon: const Icon(Icons.search, color: Colors.white, size: 27),
                  padding: const EdgeInsets.all(8),
                ),

                // Filter icon
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: _showFilterDialog,
                      icon: const Icon(Icons.filter_alt, color: Colors.white, size: 27),
                      padding: const EdgeInsets.all(8),
                    ),
                    // Show active filter indicator
                    if (_filterOptions.hasActiveFilters)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // More menu dengan hanya logout
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 27),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) async {
                if (value == 'logout') {
                  _handleLogout();
                } else if (value == 'debug') {
                  // Navigate to debug screen for testing
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const WhatsAppDebugScreen(),
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'debug',
                  child: Row(
                    children: [
                      Icon(Icons.bug_report, color: Colors.orange),
                      SizedBox(width: 12),
                      Text('Debug Tools'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              padding: const EdgeInsets.all(8),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionAppBar() {
    final chatState = ref.read(chatProvider);
    final selectedRooms = chatState.rooms.where((room) => _selectedRoomIds.contains(room.id)).toList();
    final allSelectedRoomsPinned = selectedRooms.isNotEmpty && selectedRooms.every((room) => room.isPinned);

    return Container(
      color: AppTheme.primaryColor,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
      ),
      child: SizedBox(
        height: 60,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 4),
            
            // Back button
            IconButton(
              onPressed: _exitSelectionMode,
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              padding: const EdgeInsets.all(8),
            ),

            // Selection count
            Expanded(
              child: Text(
                '${_selectedRoomIds.length} selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Action icons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pin/Unpin icon
                IconButton(
                  onPressed: _pinSelectedRooms,
                  icon: Icon(
                    allSelectedRoomsPinned ? Icons.push_pin_outlined : Icons.push_pin,
                    color: Colors.white,
                    size: 24,
                  ),
                  padding: const EdgeInsets.all(8),
                ),

                // Archive icon
                IconButton(
                  onPressed: _archiveSelectedRooms,
                  icon: const Icon(Icons.archive, color: Colors.white, size: 24),
                  padding: const EdgeInsets.all(8),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAppBar() {
    return Container(
      color: AppTheme.primaryColor,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
      ),
      child: SizedBox(
        height: 60,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: true,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: 'Search conversations...',
              hintStyle: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontFamily: 'Poppins',
                fontStyle: FontStyle.normal,
              ),
              border: InputBorder.none,
              isDense: true,
              prefixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _isSearchMode = false;
                    _searchController.clear();
                  });
                  _applyFilters(); // Reapply filters without search
                },
                icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.primaryColor, size: 24),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters(); // Clear search but keep other filters
                      },
                      icon: const Icon(Icons.clear, color: Colors.grey),
                    )
                  : null,
            ),
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'Poppins',
              color: Colors.black,
            ),
            onChanged: _handleSearch,
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String value, String label) {
    final isSelected = _selectedTab == value;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectTab(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}