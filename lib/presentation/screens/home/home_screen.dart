import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart';
import 'package:nobox_chat/core/services/signalr_service.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/push_notification_service.dart';
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

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _selectedTab = 'all';
  bool _isSearchMode = false;
  FilterOptions _filterOptions = FilterOptions();
  
  // Selection mode states
  bool _isSelectionMode = false;
  Set<String> _selectedRoomIds = {};
  
  // Real-time update management
  StreamSubscription<String>? _connectionSubscription;
  StreamSubscription<void>? _sessionExpiredSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen to session expiration events
    _sessionExpiredSubscription = ApiService.onSessionExpired.listen((_) {
      print('🔴 Session expired - navigating to login');
      _handleSessionExpired();
    });

    // Setup realtime listeners immediately
    _setupRealtimeListeners();

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _cancelRealtimeListeners();
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
      
      // Refresh data after successful re-login
      _handleRefresh();
      
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App resumed, ensure SignalR is connected and refresh data
      print('🔄 App resumed, refreshing connection and data');
      _ensureSignalRConnection();
      _handleRefresh();
    }
  }

  void _loadInitialData() async {
    // Refresh AccountService to get latest account names from backend
    try {
      print('🔄 Refreshing account mappings...');
      await AccountService().refreshAccountMappings();
      print('✅ Account mappings refreshed');
    } catch (e) {
      print('⚠️ Failed to refresh account mappings: $e');
    }

    // Ensure SignalR is connected FIRST before loading rooms
    await _ensureSignalRConnection();

    // Force re-subscribe to ensure listeners are active
    // This fixes the bug where realtime only works after entering chat screen
    await _forceResubscribe();

    // Then load rooms
    ref.read(chatProvider.notifier).loadRooms();
    ref.read(chatProvider.notifier).loadArchivedRooms();
  }

  Future<void> _forceResubscribe() async {
    try {
      print('🔄 Force re-subscribing to SignalR to activate listeners...');
      await SignalRService.forceResubscribe();
      print('✅ SignalR re-subscription complete - realtime updates now active');
    } catch (e) {
      print('⚠️ Failed to force re-subscribe: $e');
    }
  }

  void _setupRealtimeListeners() {
    print('🎧 HOME SCREEN: Setting up real-time listeners');

    // Cancel existing subscriptions
    _cancelRealtimeListeners();

    // IMPORTANT: We don't need to listen to SignalR streams here anymore
    // because ChatProvider already handles all SignalR events and updates the state
    // The home screen will automatically rebuild when chatProvider state changes

    // We only need to listen to connection status for reconnection handling
    _connectionSubscription = SignalRService.connectionStatus.listen((status) {
      print('📡 HOME SCREEN: Connection status changed to: $status');

      if (status == 'connected' && mounted) {
        // When reconnected, refresh data
        print('✅ HOME SCREEN: Connected! Refreshing data in 500ms...');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _handleRefresh();
          }
        });
      }
    });

    print('✅ HOME SCREEN: Real-time listeners set up successfully');
    print('✅   - ChatProvider handles room updates automatically');
    print('✅   - ChatProvider handles message updates automatically');
    print('✅   - Connection status listener: ACTIVE');
  }

  void _cancelRealtimeListeners() {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }

  Map<String, dynamic>? _getCurrentFilters() {
    final tabFilters = _getFiltersForTab(_selectedTab);
    final additionalFilters = _filterOptions.toMap();
    
    if (tabFilters.isEmpty && additionalFilters.isEmpty) {
      return null;
    }
    
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
  }


  Future<void> _ensureSignalRConnection() async {
    try {
      print('🔌 Ensuring SignalR connection on home screen...');
      await SignalRService.ensureConnection();
      print('✅ SignalR connection ensured on home screen');
      
      final accountService = AccountService();
      final availableChannels = accountService.getAvailableChannels();
      print('📱 User has accounts for ${availableChannels.length} channels: $availableChannels');
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
    switch (tab) {
      case 'unassigned':
        return {'St': [1]};
      case 'assigned':
        return {'St': [2]};
      case 'resolved':
        return {'St': [3]};
      default:
        return {'St': [1, 2, 3]};
    }
  }

  void _selectTab(String tab) {
    setState(() {
      _selectedTab = tab;
    });
    _applyFilters();
  }

  void _applyFilters({String? searchQuery}) {
    final tabFilters = _getFiltersForTab(_selectedTab);
    final additionalFilters = _filterOptions.toMap();
    final mergedFilters = <String, dynamic>{};
    
    // Start with tab filters as base
    mergedFilters.addAll(tabFilters);
    
    // Add all additional filters from FilterDialog
    additionalFilters.forEach((key, value) {
      if (key == 'St') {
        // For status filter, if user has selected specific status in filter dialog,
        // it should override tab filter
        final userSelectedStatuses = value as List<dynamic>;
        final filteredStatuses = userSelectedStatuses.where((status) => status != 4).toList();
        if (filteredStatuses.isNotEmpty) {
          mergedFilters['St'] = filteredStatuses; // Override tab filter
        }
      } else {
        // For other filters, just add them
        mergedFilters[key] = value;
      }
    });

    print('🔍 Filter Debug:');
    print('  - Selected Tab: $_selectedTab');
    print('  - Tab Filters: $tabFilters');
    print('  - User Filters: $additionalFilters');
    print('  - Merged Filters: $mergedFilters');
    print('  - Search Query: $searchQuery');
    
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
          
          print('Filter applied: ${filters.toMap()}');
          _applyFilters(
            searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
          );
        },
      ),
    );
  }

  void _navigateToChat(room) async {
    // Fetch complete room data before navigating, like notification does
    try {
      print('🔍 Fetching complete room data for roomId: ${room.id}');
      
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
        print('✅ Got complete room data: ${roomToNavigate.name}, AccountName: ${roomToNavigate.accountName}, BotName: ${roomToNavigate.botName}');
      } else {
        print('⚠️ Failed to fetch complete room data, using list data');
      }
      
      if (!mounted) return;
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(room: roomToNavigate),
        ),
      ).then((_) {
        // Refresh data when returning from chat screen
        print('🔄 Returned from chat, refreshing data');
        _handleRefresh();
      });
    } catch (e) {
      print('❌ Error fetching complete room data: $e');
      
      // Fallback to using the list data if API fails
      if (!mounted) return;
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(room: room),
        ),
      ).then((_) {
        print('🔄 Returned from chat, refreshing data');
        _handleRefresh();
      });
    }
  }

  void _navigateToArchive() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ArsipContactScreen(),
      ),
    ).then((_) {
      // Refresh when returning from archive
      print('🔄 Returned from archive, refreshing data');
      _handleRefresh();
    });
  }

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
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Archiving conversations...'),
        backgroundColor: AppTheme.primaryColor,
        duration: Duration(seconds: 2),
      ),
    );
    
    await ref.read(chatProvider.notifier).archiveRooms(selectedRoomIdsList);
    
    _exitSelectionMode();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${selectedRoomIdsList.length} conversation(s) archived'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Future<void> _handleRefresh() async {
    try {
      // Refresh AccountService to get latest account names
      try {
        await AccountService().refreshAccountMappings();
        print('✅ Account mappings refreshed on pull-to-refresh');
      } catch (e) {
        print('⚠️ Failed to refresh account mappings: $e');
      }
      
      await ref.read(chatProvider.notifier).loadRooms(
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        filters: _getCurrentFilters(),
      );
      
      await ref.read(chatProvider.notifier).loadArchivedRooms();
    } catch (e) {
      print('Error refreshing data: $e');
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

  void _onFloatingActionButtonPressed() {
    showDialog(
      context: context,
      builder: (context) => const NewConversationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    // Listen for state changes and handle errors
    ref.listen<ChatState>(chatProvider, (previous, next) {
      if (previous != null && next.rooms.length != previous.rooms.length) {
        print('🏠 HOME: Room count changed from ${previous.rooms.length} to ${next.rooms.length}');
      }
      
      if (previous != null && 
          previous.archivedRooms.length > next.archivedRooms.length &&
          !next.isLoading) {
        print('Archived rooms count decreased, refreshing regular rooms');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ref.read(chatProvider.notifier).loadRooms();
          }
        });
      }
      
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
      backgroundColor: isDarkMode ? AppTheme.darkBackground : Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: _isSelectionMode 
          ? _buildSelectionAppBar() 
          : (_isSearchMode ? _buildSearchAppBar() : _buildNormalAppBar()),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppTheme.primaryColor,
        backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
        child: Column(
          children: [
            // Tabs
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkBackground : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDarkMode 
                      ? Colors.white.withOpacity(0.1) 
                      : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
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
            
            // Room List
            Expanded(
              child: RoomListWidget(
                rooms: chatState.rooms,
                isLoading: chatState.isLoading,
                isLoadingMore: chatState.isLoadingMoreRooms,
                hasMore: chatState.hasMoreRooms,
                selectedRoomId: null,
                onRoomTap: _isSelectionMode ? null : _navigateToChat,
                isSelectionMode: _isSelectionMode,
                selectedRoomIds: _selectedRoomIds,
                onRoomLongPress: _enterSelectionMode,
                onRoomSelectionToggle: _toggleRoomSelection,
                searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
                filters: _getCurrentFilters(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
  margin: const EdgeInsets.only(bottom: 20, right: 10),
  child: SizedBox(
    width: 60,
    height: 60,
    child: FloatingActionButton(
      onPressed: _onFloatingActionButtonPressed,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white, // Icon selalu putih karena background biru
      elevation: 6,
      child: const Icon(Icons.add, size: 30),
    ),
  ),
),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    ),
  );

  }

Widget _buildNormalAppBar() {
  final isDarkMode = ref.watch(themeProvider).isDarkMode;
  
  return Container(
    color: AppTheme.primaryColor,
    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
    child: SizedBox(
      height: 60,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 12),
          Image.asset('assets/nobox.png', width: 40, height: 40, fit: BoxFit.contain),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NoBox Chat', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => setState(() => _isSearchMode = true),
                icon: const Icon(Icons.search, color: Colors.white, size: 27),
                padding: const EdgeInsets.all(8),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: _showFilterDialog,
                    icon: const Icon(Icons.filter_alt, color: Colors.white, size: 27),
                    padding: const EdgeInsets.all(8),
                  ),
                  if (_filterOptions.hasActiveFilters)
                    Positioned(
                      right: 6, top: 6,
                      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    ),
                ],
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 27),
            color: isDarkMode ? AppTheme.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              if (value == 'logout') {
                _handleLogout();
              } else if (value == 'debug') {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WhatsAppDebugScreen()));
              } else if (value == 'archive') {
                _navigateToArchive();
              } else if (value == 'theme') {
                await ref.read(themeProvider.notifier).toggleTheme();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(
                      isDarkMode ? Icons.light_mode : Icons.dark_mode,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isDarkMode ? 'Light Mode' : 'Dark Mode',
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(Icons.archive, color: isDarkMode ? Colors.white : Colors.blue),
                    const SizedBox(width: 12),
                    Text(
                      'Archived Conversation',
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Colors.red),
                    const SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(color: isDarkMode ? Colors.red.shade300 : Colors.red),
                    ),
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
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: SizedBox(
        height: 60,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 4),
            IconButton(onPressed: _exitSelectionMode, icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24), padding: const EdgeInsets.all(8)),
            Expanded(child: Text('${_selectedRoomIds.length} selected', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500))),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(onPressed: _pinSelectedRooms, icon: Icon(allSelectedRoomsPinned ? Icons.push_pin_outlined : Icons.push_pin, color: Colors.white, size: 24), padding: const EdgeInsets.all(8)),
                IconButton(onPressed: _archiveSelectedRooms, icon: const Icon(Icons.archive, color: Colors.white, size: 24), padding: const EdgeInsets.all(8)),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

 Widget _buildSearchAppBar() {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    
    return Container(
      color: AppTheme.primaryColor,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: SizedBox(
        height: 60,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDarkMode ? AppTheme.darkSurface : Colors.white, 
            borderRadius: BorderRadius.circular(12)
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: true,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: 'Search conversations...',
              hintStyle: TextStyle(
                color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey, 
                fontSize: 16, 
                fontFamily: 'Poppins'
              ),
              border: InputBorder.none,
              isDense: true,
              filled: true, // TAMBAHKAN INI - FORCE FILL
              fillColor: isDarkMode ? AppTheme.darkSurface : Colors.white, // TAMBAHKAN INI
              prefixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _isSearchMode = false;
                    _searchController.clear();
                  });
                  _applyFilters();
                },
                icon: Icon(
                  Icons.arrow_back_ios_new, 
                  color: isDarkMode ? Colors.white : AppTheme.primaryColor, 
                  size: 24
                ),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () { _searchController.clear(); _applyFilters(); }, 
                      icon: Icon(
                        Icons.clear, 
                        color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey
                      )
                    )
                  : null,
            ),
            style: TextStyle(
              fontSize: 16, 
              fontFamily: 'Poppins', 
              color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black
            ),
            onChanged: _handleSearch,
          ),
        ),
      ),
    );
  }

Widget _buildTab(String value, String label) {
  final isSelected = _selectedTab == value;
  final isDarkMode = ref.watch(themeProvider).isDarkMode;
  
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
            color: isSelected 
              ? AppTheme.primaryColor 
              : (isDarkMode ? Colors.white : AppTheme.textSecondary),
            fontSize: 14,
          ),
        ),
      ),
    ),
  );
}
}