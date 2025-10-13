import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/services/media_service.dart';
import 'package:nobox_chat/core/theme/app_theme.dart';
import 'dart:convert';
import '../services/account_service.dart';
import '../models/chat_models.dart';
import '../services/api_service.dart';
import '../services/signalr_service.dart';
import '../services/storage_service.dart';

class ChatState {
  final List<Room> rooms;
  final List<Room> archivedRooms;
  final List<ChatMessage> messages;
  final Room? activeRoom;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isLoadingArchived;
  final bool hasMoreMessages;
  final String? error;
  final String connectionStatus;

  ChatState({
    this.rooms = const [],
    this.archivedRooms = const [],
    this.messages = const [],
    this.activeRoom,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isLoadingArchived = false,
    this.hasMoreMessages = true,
    this.error,
    this.connectionStatus = 'disconnected',
  });

  ChatState copyWith({
    List<Room>? rooms,
    List<Room>? archivedRooms,
    List<ChatMessage>? messages,
    Room? activeRoom,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isLoadingArchived,
    bool? hasMoreMessages,
    String? error,
    String? connectionStatus,
  }) {
    return ChatState(
      rooms: rooms ?? this.rooms,
      archivedRooms: archivedRooms ?? this.archivedRooms,
      messages: messages ?? this.messages,
      activeRoom: activeRoom ?? this.activeRoom,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isLoadingArchived: isLoadingArchived ?? this.isLoadingArchived,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      error: error,
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(ChatState()) {
    // Don't initialize SignalR here - it will be initialized after login
    _setupSignalRListeners();
  }

  // Create note for active room
  Future<bool> createNote(String content) async {
    final activeRoom = state.activeRoom;
    if (activeRoom == null) {
      state = state.copyWith(error: 'No active room');
      return false;
    }

    final roomId = activeRoom.id;
    print('📝 [Create Note] Creating note for room: $roomId');

    try {
      final response = await ApiService.createNote(
        roomId: roomId,
        content: content,
      );

      if (response.isError) {
        print('❌ [Create Note] Failed: ${response.error}');
        state = state.copyWith(error: response.error);
        return false;
      }

      print('✅ [Create Note] Note created successfully');
      print('📝 [Create Note] Response: ${response.data}');
      
      // Clear any previous error
      state = state.copyWith(error: null);
      return true;
    } catch (e) {
      print('❌ [Create Note] Exception: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Mark an active room as resolved (status = 3)
  Future<bool> markActiveRoomResolved() async {
    final activeRoom = state.activeRoom;
    if (activeRoom == null) return false;

    final roomId = activeRoom.id;
    print('🟢 Marking room as resolved: $roomId');

    // Optimistic update: set status to 3 on rooms and activeRoom
    final prevRooms = List<Room>.from(state.rooms);
    final prevActive = state.activeRoom;

    try {
      // Update rooms list
      final rooms = List<Room>.from(state.rooms);
      final idx = rooms.indexWhere((r) => r.id == roomId);
      if (idx != -1) {
        final r = rooms[idx];
        rooms[idx] = Room(
          id: r.id,
          ctId: r.ctId,
          ctRealId: r.ctRealId,
          grpId: r.grpId,
          name: r.name,
          lastMessage: r.lastMessage,
          lastMessageTime: DateTime.now(),
          unreadCount: 0,
          status: 3,
          channelId: r.channelId,
          channelName: r.channelName,
          accountName: r.accountName,
          botName: r.botName,
          contactImage: r.contactImage,
          linkImage: r.linkImage,
          isGroup: r.isGroup,
          isPinned: r.isPinned,
          isBlocked: r.isBlocked,
          isMuteBot: r.isMuteBot,
          tags: r.tags,
          messageTags: r.messageTags,
          funnel: r.funnel,
          funnelId: r.funnelId,
          tagIds: r.tagIds,
          needReply: r.needReply,
        );
      }

      // Update activeRoom
      final updatedActive = Room(
        id: activeRoom.id,
        ctId: activeRoom.ctId,
        ctRealId: activeRoom.ctRealId,
        grpId: activeRoom.grpId,
        name: activeRoom.name,
        lastMessage: activeRoom.lastMessage,
        lastMessageTime: DateTime.now(),
        unreadCount: 0,
        status: 3,
        channelId: activeRoom.channelId,
        channelName: activeRoom.channelName,
        accountName: activeRoom.accountName,
        botName: activeRoom.botName,
        contactImage: activeRoom.contactImage,
        linkImage: activeRoom.linkImage,
        isGroup: activeRoom.isGroup,
        isPinned: activeRoom.isPinned,
        isBlocked: activeRoom.isBlocked,
        isMuteBot: activeRoom.isMuteBot,
        tags: activeRoom.tags,
        messageTags: activeRoom.messageTags,
        funnel: activeRoom.funnel,
        funnelId: activeRoom.funnelId,
        tagIds: activeRoom.tagIds,
        needReply: activeRoom.needReply,
      );

      state = state.copyWith(rooms: rooms, activeRoom: updatedActive, error: null);

      // Call API
      final apiResp = await ApiService.markRoomResolved(roomId);
      if (apiResp.isError) {
        print('❌ Failed to resolve room via API: ${apiResp.error}');
        // revert
        state = state.copyWith(rooms: prevRooms, activeRoom: prevActive, error: apiResp.error);
        return false;
      }

      print('✅ Room $roomId marked as resolved');
      return true;
    } catch (e) {
      print('❌ Exception while resolving room: $e');
      state = state.copyWith(rooms: prevRooms, activeRoom: prevActive, error: e.toString());
      return false;
    }
  }

  void _setupSignalRListeners() {
    // Listen to connection status
    SignalRService.connectionStatus.listen((status) {
      state = state.copyWith(connectionStatus: status);
      print('📡 SignalR connection status changed to: $status');
    });

    // Listen to room updates
    SignalRService.roomUpdates.listen((room) {
      print('📨 Received room update for room: ${room.id} - ${room.name}');
      _updateRoom(room);
    });

    // Listen to new messages
    SignalRService.messages.listen((message) {
      print('📨 Received new message for room: ${message.roomId}');
      _addMessage(message);
    });

    // Listen to message acknowledgments
    SignalRService.messageAcks.listen((ackData) {
      _updateMessageAck(ackData);
    });
  }

Future<void> loadRooms({String? search, Map<String, dynamic>? filters}) async {
  // CRITICAL FIX: Store current active room state BEFORE loading
  final preserveActiveRoom = state.activeRoom;
  final preserveMessages = state.messages;
  final preserveHasMore = state.hasMoreMessages;
  
  // Always show loading state (for shimmer effect)
  state = state.copyWith(
    isLoading: true,
    error: null,
  );
  
  print('🔍 [CHAT PROVIDER] Loading rooms with search: "$search"');
  print('🔍 [CHAT PROVIDER] Received filters: $filters');

  try {
    print('🔍 [CHAT PROVIDER] Step 1: Cleaning filters...');
    final cleanedFilters = filters != null ? _cleanFilters(filters) : null;
    print('🔍 [CHAT PROVIDER] Cleaned filters: $cleanedFilters');
    
    Map<String, dynamic>? finalFilters;
    if (cleanedFilters != null) {
      finalFilters = Map<String, dynamic>.from(cleanedFilters);
    } else {
      finalFilters = {};
    }
    
    print('🔍 [CHAT PROVIDER] Step 2: Processing status filter...');
    if (!finalFilters.containsKey('St')) {
      finalFilters['St'] = [1, 2, 3];
      print('🔍 [CHAT PROVIDER] No status filter provided, using default: [1, 2, 3]');
    } else {
      final currentStatuses = finalFilters['St'] as List<dynamic>;
      print('🔍 [CHAT PROVIDER] Status filter before filtering: $currentStatuses');
      final filteredStatuses = currentStatuses.where((status) => status != 4).toList();
      if (filteredStatuses.isNotEmpty) {
        finalFilters['St'] = filteredStatuses;
        print('🔍 [CHAT PROVIDER] Status filter after filtering archived: $filteredStatuses');
      } else {
        finalFilters['St'] = [1];
        print('🔍 [CHAT PROVIDER] All statuses were archived, using default: [1]');
      }
    }
    
    print('🔍 [CHAT PROVIDER] Step 3: Final filters to be sent to API: $finalFilters');

    final response = await ApiService.getRoomList(
      search: search,
      filters: finalFilters,
    );

    if (response.isError) {
      state = state.copyWith(
        isLoading: false,
        error: response.error,
        // CRITICAL: Restore active room state even on error
        activeRoom: preserveActiveRoom,
        messages: preserveMessages,
        hasMoreMessages: preserveHasMore,
      );
      print('API Error loading rooms: ${response.error}');
      return;
    }

    var rooms = response.data ?? [];
    
    // IMPORTANT: Client-side filtering for Private chats
    // Backend might not support IsGrp=[0] filter, so we filter here
    if (filters != null && filters.containsKey('ChatTypeFilter')) {
      final chatTypeFilter = filters['ChatTypeFilter'];
      if (chatTypeFilter == 'Private') {
        print('🔍 [CHAT PROVIDER] Applying client-side Private chat filter');
        rooms = rooms.where((room) => !room.isGroup).toList();
        print('🔍 [CHAT PROVIDER] After Private filter: ${rooms.length} rooms');
      }
      // Remove the temporary filter key before continuing
      finalFilters.remove('ChatTypeFilter');
    }
    
    final nonArchivedRooms = rooms.where((room) => room.status != 4).toList();
    
    print('Successfully loaded ${nonArchivedRooms.length} non-archived rooms');
    
    // CRITICAL FIX: ALWAYS preserve active room and messages during loadRooms
    state = state.copyWith(
      isLoading: false,
      rooms: nonArchivedRooms,
      activeRoom: preserveActiveRoom, // Keep active room unchanged
      messages: preserveMessages, // Keep messages unchanged
      hasMoreMessages: preserveHasMore, // Keep pagination state
    );
  } catch (e) {
    print('Exception loading rooms: $e');
    state = state.copyWith(
      isLoading: false,
      error: e.toString(),
      // CRITICAL: Restore active room state even on exception
      activeRoom: preserveActiveRoom,
      messages: preserveMessages,
      hasMoreMessages: preserveHasMore,
    );
  }
}

  Future<void> loadArchivedRooms({String? search}) async {
    state = state.copyWith(isLoadingArchived: true, error: null);
    
    print('Loading archived rooms with search: "$search"');

    try {
      // Load archived rooms with specific filter for archived status (4)
      final filters = {
        'St': [4] // Status 4 = Archived
      };

      final response = await ApiService.getRoomList(
        search: search,
        filters: filters,
      );

      if (response.isError) {
        state = state.copyWith(
          isLoadingArchived: false,
          error: response.error,
        );
        print('API Error loading archived rooms: ${response.error}');
        return;
      }

      final archivedRooms = response.data ?? [];
      
      // Additional client-side filter to ensure only archived rooms
      print('📦 Raw archived rooms from API: ${archivedRooms.length}');
      for (final room in archivedRooms) {
        print('📦 Room: ${room.id} - ${room.name} - Status: ${room.status}');
      }
      
      final onlyArchivedRooms = archivedRooms.where((room) => room.status == 4).toList();
      
      print('Successfully loaded ${onlyArchivedRooms.length} archived rooms (filtered)');
      
      // Log each archived room for debugging
      for (final room in onlyArchivedRooms) {
        print('✅ Archived Room: ${room.id} - ${room.name} - Status: ${room.status}');
      }
      
      state = state.copyWith(
        isLoadingArchived: false,
        archivedRooms: onlyArchivedRooms,
      );
    } catch (e) {
      print('Exception loading archived rooms: $e');
      state = state.copyWith(
        isLoadingArchived: false,
        error: e.toString(),
      );
    }
  }

  // Archive selected rooms
  Future<void> archiveRooms(List<String> roomIds) async {
    try {
      print('Archiving rooms: $roomIds');
      
      for (final roomId in roomIds) {
        // First, mark as resolved
        final markResolvedResponse = await ApiService.markRoomResolved(roomId);
        
        if (!markResolvedResponse.isError) {
          // Then, move to archive
          final archiveResponse = await ApiService.moveToArchive(roomId);
          
          if (archiveResponse.isError) {
            print('Failed to archive room $roomId: ${archiveResponse.error}');
            state = state.copyWith(error: 'Failed to archive some conversations');
          } else {
            print('Successfully archived room $roomId');
            
            // Remove from current rooms list immediately
            final updatedRooms = state.rooms.where((room) => room.id != roomId).toList();
            state = state.copyWith(rooms: updatedRooms);
          }
        } else {
          print('Failed to mark room $roomId as resolved: ${markResolvedResponse.error}');
          state = state.copyWith(error: 'Failed to resolve some conversations before archiving');
        }
      }
      
      // Reload rooms to reflect any remaining changes
      await loadRooms();
      
    } catch (e) {
      print('Exception archiving rooms: $e');
      state = state.copyWith(error: 'Failed to archive conversations: $e');
    }
  }

  // Unarchive selected rooms
  Future<void> unarchiveRooms(List<String> roomIds) async {
    try {
      print('Unarchiving rooms: $roomIds');
      
      for (final roomId in roomIds) {
        final response = await ApiService.unarchiveRoom(roomId);
        
        if (response.isError) {
          print('Failed to unarchive room $roomId: ${response.error}');
          state = state.copyWith(error: 'Failed to unarchive some conversations');
        } else {
          print('Successfully unarchived room $roomId');
          
          // Remove from archived rooms list immediately
          final updatedArchivedRooms = state.archivedRooms.where((room) => room.id != roomId).toList();
          state = state.copyWith(archivedRooms: updatedArchivedRooms);
        }
      }
      
      // IMPORTANT FIX: After unarchiving, we need to reload both archived and regular rooms
      // This ensures unarchived rooms appear in the home screen
      await Future.wait([
        loadArchivedRooms(), // Refresh archived list
        loadRooms(),         // Refresh regular rooms list to show unarchived items
      ]);
      
    } catch (e) {
      print('Exception unarchiving rooms: $e');
      state = state.copyWith(error: 'Failed to unarchive conversations: $e');
    }
  }

  // Toggle pin status for a room
  Future<void> togglePinRoom(String roomId, bool isPinned) async {
    try {
      // Update locally first for immediate feedback
      final updatedRooms = state.rooms.map((room) {
        if (room.id == roomId) {
          return Room(
            id: room.id,
            ctId: room.ctId,
            ctRealId: room.ctRealId,
            grpId: room.grpId,
            name: room.name,
            lastMessage: room.lastMessage,
            lastMessageTime: room.lastMessageTime,
            unreadCount: room.unreadCount,
            status: room.status,
            channelId: room.channelId,
            channelName: room.channelName,
            accountName: room.accountName,
            botName: room.botName,
            contactImage: room.contactImage,
            linkImage: room.linkImage,
            isGroup: room.isGroup,
            isPinned: isPinned,
            isBlocked: room.isBlocked,
            isMuteBot: room.isMuteBot,
            tags: room.tags,
            funnel: room.funnel,
            funnelId: room.funnelId,
            tagIds: room.tagIds,
          );
        }
        return room;
      }).toList();

      state = state.copyWith(rooms: updatedRooms);

      // Call API to update pin status on server
      final response = await ApiService.togglePinRoom(roomId, isPinned);
      
      if (response.isError) {
        print('Failed to update pin status: ${response.error}');
        state = state.copyWith(error: 'Failed to update pin status');
        // Revert local changes on failure
        await loadRooms();
      } else {
        print('Room $roomId pin status updated to: $isPinned');
      }
      
    } catch (e) {
      print('Error toggling pin status: $e');
      state = state.copyWith(error: 'Failed to update pin status');
      // Revert local changes on failure
      await loadRooms();
    }
  }

  // Clean and validate filter data before sending to API
  Map<String, dynamic> _cleanFilters(Map<String, dynamic> filters) {
    print('🧹 [_cleanFilters] Input filters: $filters');
    final cleanedFilters = <String, dynamic>{};
    
    for (final entry in filters.entries) {
      final key = entry.key;
      final value = entry.value;
      print('🧹 [_cleanFilters] Processing key: $key, value: $value (type: ${value.runtimeType})');
      
      // Skip ChatTypeFilter - this is for client-side filtering only
      if (key == 'ChatTypeFilter') {
        print('   🚫 Skipping ChatTypeFilter (client-side only)');
        continue;
      }
      
      // Skip null or empty values
      if (value == null) continue;
      
      // Handle list values
      if (value is List) {
        if (value.isNotEmpty) {
          cleanedFilters[key] = value;
          print('   ✅ Added as list: $key = $value');
        } else {
          print('   ⚠️ Skipped empty list for key: $key');
        }
      }
      // Handle string values
      else if (value is String) {
        if (value.isNotEmpty) {
          // Try to convert to appropriate type if needed
          if (_isNumericFilter(key)) {
            final intValue = int.tryParse(value);
            if (intValue != null) {
              cleanedFilters[key] = [intValue];
              print('   ✅ Converted string to int list: $key = [$intValue]');
            }
          } else {
            cleanedFilters[key] = [value];
            print('   ✅ Added string as list: $key = [$value]');
          }
        } else {
          print('   ⚠️ Skipped empty string for key: $key');
        }
      }
      // Handle int values
      else if (value is int) {
        cleanedFilters[key] = [value];
        print('   ✅ Converted int to list: $key = [$value]');
      }
      // Handle bool values
      else if (value is bool) {
        cleanedFilters[key] = [value ? 1 : 0];
        print('   ✅ Converted bool to int list: $key = [${value ? 1 : 0}]');
      }
      else {
        // Keep other types as is
        cleanedFilters[key] = value;
        print('   ℹ️ Kept as-is: $key = $value');
      }
    }
    
    print('🧹 [_cleanFilters] Output cleanedFilters: $cleanedFilters');
    return cleanedFilters;
  }
  
  bool _isNumericFilter(String key) {
    final numericFilters = [
      'ChId', 'CtId', 'GrpId', 'St', 'AgentId', 'AccountId', 
      'LinkId', 'CampaignId', 'FunnelId', 'DealId', 'TagId'
    ];
    return numericFilters.contains(key);
  }

  Future<void> selectRoom(Room room, {bool? isArchived}) async {
    state = state.copyWith(isLoading: true, error: null);
    final isRoomArchived = isArchived ?? (room.status == 4);
    print('Selecting room: ${room.id} - ${room.name} (Status: ${room.status}, IsArchived: $isRoomArchived)');

    try {
      // Leave previous room if exists (only for non-archived rooms)
      if (state.activeRoom != null && SignalRService.isConnected && !isRoomArchived) {
        await SignalRService.leaveConversation(state.activeRoom!.id);
      }

      // Get detailed room information including funnel data (skip for archived)
      Room updatedRoom = room;
      if (!isRoomArchived) { // Only get details for non-archived rooms
        try {
          final roomDetailResponse = await _getRoomDetail(room.id);
          if (roomDetailResponse != null) {
            // Update room with detailed information including funnel
            updatedRoom = Room(
              id: room.id,
              ctId: room.ctId,
              ctRealId: room.ctRealId,
              grpId: room.grpId,
              name: room.name,
              lastMessage: room.lastMessage,
              lastMessageTime: room.lastMessageTime,
              unreadCount: room.unreadCount,
              status: room.status,
              channelId: room.channelId,
              channelName: room.channelName,
              accountName: room.accountName,
              botName: room.botName,
              contactImage: room.contactImage,
              linkImage: room.linkImage,
              isGroup: room.isGroup,
              isPinned: room.isPinned,
              isBlocked: room.isBlocked,
              isMuteBot: room.isMuteBot,
              tags: room.tags,
              funnel: roomDetailResponse['Room']?['Fn'] ?? roomDetailResponse['Room']?['FnNm'] ?? room.funnel,
              funnelId: roomDetailResponse['Room']?['FnId']?.toString() ?? roomDetailResponse['Room']?['FunnelId']?.toString() ?? room.funnelId,
              tagIds: room.tagIds,
            );
            print('✅ Updated room with detailed funnel info: ${updatedRoom.funnel} (ID: ${updatedRoom.funnelId})');
          }
        } catch (detailError) {
          print('⚠️ Could not get room detail, using original room data: $detailError');
        }
      } else {
        print('📦 Archived room detected, skipping detail fetch');
      }

      // Load messages - use specialized method for archived conversations
      if (isRoomArchived) {
        // For archived conversations, use the specialized loading method
        print('📦 Using specialized archived loading method');
        await loadArchivedRoomMessages(updatedRoom);
      } else {
        // For active conversations, use standard loading
        try {
          print('Loading messages for active room ${updatedRoom.id}');
          
          final messagesResponse = await ApiService.getMessages(
            roomId: updatedRoom.id,
            take: 20,
            skip: 0,
          );
          
          if (!messagesResponse.isError && messagesResponse.data != null) {
            // Sort messages by timestamp (newest first from API, then reverse for display)
            final sortedMessages = List<ChatMessage>.from(messagesResponse.data!);
            sortedMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first
            final displayMessages = sortedMessages.reversed.toList(); // Oldest first for display
            
            print('Successfully loaded ${displayMessages.length} messages for active room ${updatedRoom.id}');
            
            state = state.copyWith(
              activeRoom: updatedRoom,
              messages: displayMessages,
              isLoading: false,
              hasMoreMessages: messagesResponse.data!.length >= 20,
            );
          } else {
            print('No messages found for active room ${updatedRoom.id}, this is normal for new conversations');
            state = state.copyWith(
              activeRoom: updatedRoom,
              messages: [],
              isLoading: false,
              hasMoreMessages: false,
              error: null,
            );
          }
        } catch (messagesError) {
          print('Error loading messages for active room ${updatedRoom.id}: $messagesError');
          state = state.copyWith(
            activeRoom: updatedRoom,
            messages: [],
            isLoading: false,
            hasMoreMessages: false,
            error: null,
          );
        }
      }
      
      // Join new room for real-time updates after successfully setting up (only for non-archived)
      if (SignalRService.isConnected && !isRoomArchived) {
        try {
          await SignalRService.joinConversation(updatedRoom.id, null);
          print('✅ Joined room ${updatedRoom.id} for real-time updates');
        } catch (joinError) {
          print('Failed to join room after selection: $joinError');
        }
      } else if (isRoomArchived) {
        print('📦 Archived room: skipping SignalR join');
      }
      
    } catch (e) {
      print('Error selecting room: $e');
      state = state.copyWith(
        activeRoom: room,
        messages: [],
        isLoading: false,
        hasMoreMessages: false,
        error: null, // Don't show error to user for room selection issues
      );
      
      // Still try to join room for real-time updates (only for non-archived)
      if (SignalRService.isConnected && !isRoomArchived) {
        try {
          await SignalRService.joinConversation(room.id, null);
        } catch (joinError) {
          print('Failed to join room after error: $joinError');
        }
      }
    }
  }

  // Helper method to get detailed room information
  Future<Map<String, dynamic>?> _getRoomDetail(String roomId) async {
    try {
      final response = await ApiService.dio.post(
        'Services/Chat/Chatrooms/DetailRoom',
        data: {
          'EntityId': roomId,
        },
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        print('✅ Got room detail for room $roomId: ${response.data['Data']}');
        return response.data['Data'];
      } else {
        print('❌ Failed to get room detail: ${response.data}');
        return null;
      }
    } catch (e) {
      print('❌ Exception getting room detail: $e');
      return null;
    }
  }

  // Specialized method for loading archived conversation messages with enhanced error handling
  Future<void> loadArchivedRoomMessages(Room room) async {
    // FIXED: Don't check status here since room might not have correct status when passed from UI
    print('📦 loadArchivedRoomMessages called for room: ${room.id} - ${room.name} (Status: ${room.status})');
    
    // Continue regardless of status - let the specialized loading handle it

    state = state.copyWith(isLoading: true, error: null);
    print('📦 Loading archived room messages for: ${room.id} - ${room.name}');
    
    try {
      // Use special endpoint for archived conversations
      print('🔄 Using DetailArchived endpoint for archived room');
      
      final archivedDetailResponse = await ApiService.getArchivedRoomDetail(
        roomId: room.id,
      );
      
      print('📨 API Response - IsError: ${archivedDetailResponse.isError}');
      
      List<ChatMessage> loadedMessages = [];
      
      if (!archivedDetailResponse.isError && archivedDetailResponse.data != null) {
        final data = archivedDetailResponse.data!;
        print('📦 Archived detail data keys: ${data.keys}');
        
        // Try to extract messages from the response
        // The structure might be different, let's check multiple possible keys
        dynamic messagesData;
        
        if (data.containsKey('Messages')) {
          messagesData = data['Messages'];
          print('📦 Found Messages key');
        } else if (data.containsKey('ChatMessages')) {
          messagesData = data['ChatMessages'];
          print('📦 Found ChatMessages key');
        } else if (data.containsKey('Entities')) {
          messagesData = data['Entities'];
          print('📦 Found Entities key');
        } else if (data.containsKey('Data')) {
          messagesData = data['Data'];
          print('📦 Found Data key');
        }
        
        if (messagesData != null) {
          if (messagesData is List) {
            print('📦 Messages is a List with ${messagesData.length} items');
            loadedMessages = messagesData.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
            print('✅ Successfully loaded ${loadedMessages.length} messages for archived room');
          } else if (messagesData is Map) {
            print('📦 Messages is a Map, looking for nested list...');
            print('📦 Messages Map keys: ${messagesData.keys}');
            
            // Try to find list inside the Map
            dynamic nestedList;
            final messagesMap = messagesData as Map<String, dynamic>;
            
            // Common keys that might contain the actual messages list
            final possibleKeys = ['Entities', 'Data', 'Items', 'List', 'Messages', 'ChatMessages', 'Msgs'];
            
            for (final key in possibleKeys) {
              if (messagesMap.containsKey(key)) {
                final value = messagesMap[key];
                
                // Check if it's already a list
                if (value is List) {
                  nestedList = value;
                  print('✅ Found messages list in key: $key');
                  break;
                }
                // Check if it's a JSON string that needs parsing
                else if (value is String && value.isNotEmpty) {
                  print('📦 Key "$key" is a String, attempting to parse as JSON...');
                  try {
                    final parsed = jsonDecode(value);
                    if (parsed is List) {
                      nestedList = parsed;
                      print('✅ Successfully parsed JSON string to list with ${parsed.length} items');
                      break;
                    } else {
                      print('⚠️ Parsed JSON is not a List: ${parsed.runtimeType}');
                    }
                  } catch (e) {
                    print('❌ Failed to parse JSON string: $e');
                  }
                }
              }
            }
            
            if (nestedList != null && nestedList is List) {
              print('📦 Found nested list with ${nestedList.length} items');
              loadedMessages = nestedList.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
              print('✅ Successfully loaded ${loadedMessages.length} messages for archived room');
            } else {
              print('❌ Could not find messages list in Map structure');
              print('📦 Messages Map keys: ${messagesMap.keys.toList()}');
              
              // Print each key and its type for debugging
              messagesMap.forEach((key, value) {
                print('📦 Key "$key": type=${value.runtimeType}, isNull=${value == null}');
                if (value is List) {
                  print('   -> List with ${value.length} items');
                } else if (value is Map) {
                  print('   -> Map with keys: ${value.keys}');
                }
              });
            }
          } else {
            print('⚠️ Messages data is not a List or Map: ${messagesData.runtimeType}');
            print('📦 Messages data: $messagesData');
          }
        } else {
          print('⚠️ No messages found in response. Available keys: ${data.keys}');
          print('📦 Full data structure: $data');
        }
      } else {
        print('❌ Error loading archived detail: ${archivedDetailResponse.error}');
      }
      
      if (loadedMessages.isNotEmpty) {
        // Sort messages by timestamp (newest first from API, then reverse for display)
        final sortedMessages = List<ChatMessage>.from(loadedMessages);
        sortedMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final displayMessages = sortedMessages.reversed.toList();
        
        state = state.copyWith(
          activeRoom: room,
          messages: displayMessages,
          isLoading: false,
          hasMoreMessages: loadedMessages.length >= 20,
          error: null,
        );
        
        print('✅ Archived conversation loaded successfully with ${displayMessages.length} messages');
      } else {
        // No messages found with any approach
        state = state.copyWith(
          activeRoom: room,
          messages: [],
          isLoading: false,
          hasMoreMessages: false,
          error: null, // Don't treat empty archived conversation as error
        );
        
        print('⚠️ No messages found for archived conversation ${room.id} with any approach');
      }
      
    } catch (e) {
      print('❌ Exception loading archived room messages: $e');
      state = state.copyWith(
        activeRoom: room,
        messages: [],
        isLoading: false,
        hasMoreMessages: false,
        error: 'Failed to load archived conversation: ${e.toString()}',
      );
    }
  }
  Future<void> loadMoreMessages() async {
    final activeRoom = state.activeRoom;
    if (activeRoom == null || state.isLoadingMore || !state.hasMoreMessages) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final currentMessageCount = state.messages.length;
      
      final messagesResponse = await ApiService.getMessages(
        roomId: activeRoom.id,
        take: 20,
        skip: currentMessageCount, // Skip messages we already have
      );

      if (!messagesResponse.isError && messagesResponse.data != null) {
        final newMessages = messagesResponse.data!;
        
        if (newMessages.isNotEmpty) {
          // Sort new messages (newest first from API, then reverse)
          final sortedNewMessages = List<ChatMessage>.from(newMessages);
          sortedNewMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          final displayNewMessages = sortedNewMessages.reversed.toList();
          
          // Prepend new (older) messages to existing messages
          final allMessages = [...displayNewMessages, ...state.messages];
          
          state = state.copyWith(
            messages: allMessages,
            isLoadingMore: false,
            hasMoreMessages: newMessages.length >= 20, // Has more if we got full page
          );
        } else {
          // No more messages
          state = state.copyWith(
            isLoadingMore: false,
            hasMoreMessages: false,
          );
        }
      } else {
        state = state.copyWith(
          isLoadingMore: false,
          error: messagesResponse.error,
        );
      }
    } catch (e) {
      print('Error loading more messages: $e');
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> sendTextMessage(String text, {String? replyId}) async {
    final activeRoom = state.activeRoom;
    if (activeRoom == null) return;

    // Validate message text
    if (text.trim().isEmpty) {
      state = state.copyWith(error: 'Message cannot be empty');
      return;
    }

    // Add optimistic message first for better UX
    final tempId = _addOptimisticMessage(text, replyId: replyId);

    // Use API directly for sending messages to ensure they reach external platforms
    await _sendMessageViaAPI(text, tempId: tempId, replyId: replyId);
  }

  Future<void> sendLocationMessage(Map<String, double> location, {String? replyId}) async {
    final activeRoom = state.activeRoom;
    if (activeRoom == null) return;

    // Format location as text message
    final locationText = 'Location: ${location['latitude']!.toStringAsFixed(6)}, ${location['longitude']!.toStringAsFixed(6)}\n'
                         'https://maps.google.com/maps?q=${location['latitude']},${location['longitude']}';

    // Add optimistic message first
    final tempId = _addOptimisticMessage(locationText, replyId: replyId);

    // CRITICAL FIX: For location with reply, use SignalR only
    if (replyId != null && replyId.isNotEmpty) {
      await _sendLocationViaSignalR(locationText, tempId: tempId, replyId: replyId);
    } else {
      // Send via API as text message (type 1) with location content
      await _sendMessageViaAPI(locationText, tempId: tempId, replyId: replyId);
    }
  }
  
  Future<void> _sendLocationViaSignalR(String locationText, {required String tempId, String? replyId}) async {
    final activeRoom = state.activeRoom;
    if (activeRoom == null) return;

    try {
      // Get the agent account ID using the correct channel mapping
      final effectiveChannelId = _getEffectiveChannelId(activeRoom.channelId);
      final accountId = await _getAgentAccountId(effectiveChannelId);
      if (accountId == null) {
        _updateOptimisticMessage(tempId, 4); // Mark as failed
        state = state.copyWith(error: 'Unable to determine agent account ID');
        return;
      }
      
      final linkId = activeRoom.ctId ?? activeRoom.id;
      
      // Enhanced ReplyId validation for location messages
      String? validatedReplyId;
      if (replyId != null && replyId.isNotEmpty) {
        final numericReplyId = int.tryParse(replyId);
        if (numericReplyId != null && numericReplyId > 0) {
          validatedReplyId = numericReplyId.toString();
          print('✅ Using validated ReplyId for location via SignalR: $validatedReplyId');
        } else {
          print('⚠️ Invalid ReplyId format for location: $replyId');
        }
      }
      
      if (SignalRService.isConnected && validatedReplyId != null) {
        final signalRData = {
          'Room': {
            'IdLink': linkId,
            'IdGroup': activeRoom.grpId,
            'IdAccount': int.tryParse(accountId) ?? 1,
            'IdRoom': activeRoom.id,
          },
          'Msg': {
            'Type': '1', // Send as text message with location content
            'Msg': locationText,
            'File': '',
            'Files': '',
            'ReplyId': validatedReplyId,
          },
        };
        
        print('Sending location reply via SignalR: ${jsonEncode(signalRData)}');
        await SignalRService.sendMessage(signalRData);
        _updateOptimisticMessage(tempId, 2); // Mark as sent
        print('✅ Location reply sent successfully via SignalR');
      } else {
        _updateOptimisticMessage(tempId, 4); // Mark as failed
        state = state.copyWith(error: 'Cannot send location reply. Connection not available or invalid reply ID.');
      }
    } catch (e) {
      _updateOptimisticMessage(tempId, 4); // Mark as failed
      print('❌ Location reply via SignalR failed: $e');
      state = state.copyWith(error: 'Failed to send location reply: $e');
    }
  }
  Future<void> _sendMessageViaAPI(String text, {required String tempId, String? replyId}) async {
    final activeRoom = state.activeRoom;
    if (activeRoom == null) return;

    // Ensure SignalR connection before sending
    try {
      await SignalRService.ensureConnection();
    } catch (e) {
      print('⚠️ SignalR not available, continuing with API only: $e');
    }

    try {
      // Get the agent account ID using the correct channel mapping
      final effectiveChannelId = _getEffectiveChannelId(activeRoom.channelId);
      final accountId = await _getAgentAccountId(effectiveChannelId);
      if (accountId == null) {
        _updateOptimisticMessage(tempId, 4); // Mark as failed
        state = state.copyWith(error: 'Unable to determine agent account ID');
        return;
      }
      
      // Get the proper LinkId from the room
      final linkId = activeRoom.ctId ?? activeRoom.id;
      
      // Use the effective channel ID for sending
      final channelId = effectiveChannelId;
      
      print('Room channelId: ${activeRoom.channelId}, Effective channelId: $channelId');
      
      // CRITICAL FIX: For reply messages, use SignalR only (no API)
      // Backend confirmed that reply feature only works via WebSocket
      if (replyId != null && replyId.isNotEmpty) {
        print('🔄 Reply message detected, using SignalR only (API does not support reply)');
        
        // Enhanced ReplyId validation for SignalR
        String? validatedReplyId;
        
        // Find the reply message in our local message list
        final replyMessage = state.messages.firstWhere(
          (msg) => msg.id == replyId,
          orElse: () => ChatMessage(
            id: '',
            roomId: '',
            from: '',
            agentId: 0,
            type: 1,
            timestamp: DateTime.now(),
          ),
        );
        
        if (replyMessage.id.isEmpty) {
          print('⚠️ Reply message not found in local messages, removing ReplyId');
        } else {
          // Validate ReplyId format - must be numeric and positive
          final numericReplyId = int.tryParse(replyId);
          if (numericReplyId != null && numericReplyId > 0) {
            validatedReplyId = numericReplyId.toString();
            print('✅ Using validated ReplyId for SignalR: $validatedReplyId');
          } else {
            print('⚠️ Invalid ReplyId format for SignalR: $replyId');
          }
        }
        
        // Send ONLY via SignalR for reply messages
        if (SignalRService.isConnected && validatedReplyId != null) {
          try {
            final signalRData = {
              'Room': {
                'IdLink': linkId,
                'IdGroup': activeRoom.grpId,
                'IdAccount': int.tryParse(accountId) ?? 1,
                'IdRoom': activeRoom.id,
              },
              'Msg': {
                'Type': '1',
                'Msg': text.trim(),
                'File': '',
                'Files': '',
                'ReplyId': validatedReplyId,
              },
            };
            
            print('Sending reply message via SignalR only: ${jsonEncode(signalRData)}');
            await SignalRService.sendMessage(signalRData);
            _updateOptimisticMessage(tempId, 2); // Mark as sent
            print('✅ Reply message sent successfully via SignalR');
            return; // Exit early for reply messages
          } catch (signalRError) {
            _updateOptimisticMessage(tempId, 4); // Mark as failed
            print('❌ SignalR reply failed: $signalRError');
            state = state.copyWith(error: 'Failed to send reply message. Reply feature requires active connection.');
            return;
          }
        } else {
          _updateOptimisticMessage(tempId, 4); // Mark as failed
          state = state.copyWith(error: 'Cannot send reply message. Connection not available or invalid reply ID.');
          return;
        }
      }
      
      // For non-reply messages, use API as primary method
      final apiMessageData = {
        'LinkId': int.tryParse(linkId),
        'ChannelId': channelId,
        'AccountIds': accountId,
        'BodyType': 1,
        'Body': text.trim(),
        'Attachment': '',
      };
      
      // Validate required fields
      if (apiMessageData['LinkId'] == null || apiMessageData['LinkId'] == 0) {
        _updateOptimisticMessage(tempId, 4); // Mark as failed
        state = state.copyWith(error: 'Invalid LinkId: ${linkId}');
        return;
      }
      
      if (text.trim().isEmpty) {
        _updateOptimisticMessage(tempId, 4); // Mark as failed
        state = state.copyWith(error: 'Message text cannot be empty');
        return;
      }
      
      print('Sending regular message via API: ${jsonEncode(apiMessageData)}');
      
      final response = await ApiService.sendMessage(apiMessageData);
      if (response.isError) {
        _updateOptimisticMessage(tempId, 4); // Mark as failed
        state = state.copyWith(error: response.error ?? 'Failed to send message');
      } else {
        _updateOptimisticMessage(tempId, 2); // Mark as sent
        print('Regular message sent successfully via API');
        
        // Also send via SignalR for real-time updates (without ReplyId)
        try {
          if (SignalRService.isConnected) {
            final signalRData = {
              'Room': {
                'IdLink': linkId,
                'IdGroup': activeRoom.grpId,
                'IdAccount': int.tryParse(accountId) ?? 1,
                'IdRoom': activeRoom.id,
              },
              'Msg': {
                'Type': '1',
                'Msg': text.trim(),
                'File': '',
                'Files': '',
              },
            };
            print('Sending SignalR notification for regular message: ${jsonEncode(signalRData)}');
            await SignalRService.sendMessage(signalRData);
            print('SignalR notification sent successfully');
          } else {
            print('ℹ️ SignalR not connected, skipping real-time notification');
          }
        } catch (e) {
          print('SignalR notification failed (this is OK): $e');
        }
      }
    } catch (apiError) {
      _updateOptimisticMessage(tempId, 4); // Mark as failed
      print('API fallback failed: $apiError');
      state = state.copyWith(error: 'Failed to send message: $apiError');
    }
  }

  Future<void> sendMediaMessage({
    required String type,
    required String filename,
    required String base64Data,
    String? caption,
    String? replyId,
  }) async {
    final activeRoom = state.activeRoom;
    if (activeRoom == null) return;

    try {
      print('Uploading media file: $filename, type: $type');
      
      // Upload file first
      final uploadResponse = await MediaService.uploadBase64(
        filename: filename,
        mimetype: _getMimeType(filename),
        base64Data: base64Data,
      );

      if (uploadResponse.isError) {
        print('Upload failed: ${uploadResponse.error}');
        state = state.copyWith(error: uploadResponse.error);
        return;
      }

      print('Upload successful: ${uploadResponse.data?.filename}');
      
      // Add optimistic media message (pending single-check)
      final tempId = _addOptimisticMediaMessage(
        type: type,
        uploadedFile: uploadResponse.data!,
        caption: caption,
        replyId: replyId,
      );
      
      // Send media message via API or SignalR (depending on reply)
      await _sendMediaMessageViaAPI(type, caption, uploadResponse.data!, replyId: replyId, tempId: tempId);
    } catch (e) {
      print('Error sending media message: $e');
      state = state.copyWith(error: 'Failed to send media message: $e');
    }
  }

  Future<void> _sendMediaMessageViaAPI(String type, String? caption, UploadedFile uploadedFile, {String? replyId, String? tempId}) async {
    final activeRoom = state.activeRoom;
    if (activeRoom == null) return;

    // CRITICAL FIX: For media messages with reply, use SignalR only
    if (replyId != null && replyId.isNotEmpty) {
      print('🔄 Media reply message detected, using SignalR only (API does not support reply)');
      await _sendMediaReplyViaSignalR(type, caption, uploadedFile, replyId: replyId, tempId: tempId);
      return;
    }

    try {
      // Get the agent account ID using the correct channel mapping
      final effectiveChannelId = _getEffectiveChannelId(activeRoom.channelId);
      final accountId = await _getAgentAccountId(effectiveChannelId);
      if (accountId == null) {
        state = state.copyWith(error: 'Unable to determine agent account ID');
        return;
      }
      
      // Get the proper LinkId and AccountId from the room
      final linkId = activeRoom.ctId ?? activeRoom.id;
      
      // Use the effective channel ID for sending
      final workingChannelId = effectiveChannelId;
      
      // FIXED: For media messages, caption should be in Body field for WhatsApp Business
      String bodyText = caption?.trim() ?? '';
      String attachmentData = '';
      
      // Create attachment data
      final attachmentMap = {
        'Filename': uploadedFile.filename,
        'OriginalName': uploadedFile.originalName,
      };
      
      // Some channels (e.g., WhatsApp Business) expect caption inside attachment object
      if (bodyText.isNotEmpty && (type == '3' || type == '4')) {
        attachmentMap['Caption'] = bodyText;
      }
      
      attachmentData = jsonEncode([attachmentMap]);
      
      // Format data for Inbox API
      final apiMessageData = {
        'LinkId': int.tryParse(linkId),
        'ChannelId': workingChannelId,
        'AccountIds': accountId,
        'BodyType': int.parse(type),
        'Body': bodyText,
        'Attachment': attachmentData,
      };
      
      print('Sending media message via API: ${jsonEncode(apiMessageData)}');
      
      final response = await ApiService.sendMessage(apiMessageData);
      if (response.isError) {
        state = state.copyWith(error: response.error ?? 'Failed to send media message');
        if (tempId != null && tempId.isNotEmpty) {
          _updateOptimisticMessage(tempId, 4); // failed
        }
      } else {
        print('Media message sent successfully via API');
        print('Media message with caption sent successfully');
        if (tempId != null && tempId.isNotEmpty) {
          _updateOptimisticMessage(tempId, 2); // sent
        }
        
        // Also send via SignalR for real-time updates
        try {
          // Only try SignalR if we're actually connected
          if (SignalRService.isConnected) {
            // For SignalR, send media message with caption
            // Build file map with caption for SignalR as well
            final fileMap = {
              'Filename': uploadedFile.filename,
              'OriginalName': uploadedFile.originalName,
            };
            if ((caption ?? '').trim().isNotEmpty) {
              fileMap['Caption'] = caption!.trim();
            }

            final signalRData = {
              'Room': {
                'IdLink': linkId,
                'IdGroup': activeRoom.grpId,
                'IdAccount': int.tryParse(accountId) ?? 1,
                'IdRoom': activeRoom.id,
              },
              'Msg': {
                'Type': type,
                'Msg': caption?.trim(), // Include caption in SignalR message
                'File': uploadedFile.filename,
                'Files': jsonEncode([fileMap]),
              },
            };
            await SignalRService.sendMessage(signalRData);
            print('Media message with caption sent via SignalR');
          } else {
            print('ℹ️ SignalR not connected, skipping real-time notification');
          }
        } catch (e) {
          print('SignalR notification failed (this is OK): $e');
        }
      }
    } catch (apiError) {
      print('Media API fallback failed: $apiError');
      state = state.copyWith(error: 'Failed to send media message: $apiError');
      if (tempId != null && tempId.isNotEmpty) {
        _updateOptimisticMessage(tempId, 4);
      }
    }
  }
  
  Future<void> _sendMediaReplyViaSignalR(String type, String? caption, UploadedFile uploadedFile, {String? replyId, String? tempId}) async {
    final activeRoom = state.activeRoom;
    if (activeRoom == null) return;

    try {
      // Get the agent account ID using the correct channel mapping
      final effectiveChannelId = _getEffectiveChannelId(activeRoom.channelId);
      final accountId = await _getAgentAccountId(effectiveChannelId);
      if (accountId == null) {
        state = state.copyWith(error: 'Unable to determine agent account ID');
        return;
      }
      
      final linkId = activeRoom.ctId ?? activeRoom.id;
      
      // Enhanced ReplyId validation for media reply messages
      String? validatedReplyId;
      if (replyId != null && replyId.isNotEmpty) {
        final numericReplyId = int.tryParse(replyId);
        if (numericReplyId != null && numericReplyId > 0) {
          validatedReplyId = numericReplyId.toString();
          print('✅ Using validated ReplyId for media reply via SignalR: $validatedReplyId');
        } else {
          print('⚠️ Invalid ReplyId format for media reply: $replyId');
        }
      }
      
      if (SignalRService.isConnected && validatedReplyId != null) {
        // Build file map with caption for SignalR reply
        final fileMap = {
          'Filename': uploadedFile.filename,
          'OriginalName': uploadedFile.originalName,
        };
        if ((caption ?? '').trim().isNotEmpty) {
          fileMap['Caption'] = caption!.trim();
        }

        final signalRData = {
          'Room': {
            'IdLink': linkId,
            'IdGroup': activeRoom.grpId,
            'IdAccount': int.tryParse(accountId) ?? 1,
            'IdRoom': activeRoom.id,
          },
          'Msg': {
            'Type': type,
            'Msg': caption?.trim(),
            'File': uploadedFile.filename,
            'Files': jsonEncode([fileMap]),
            'ReplyId': validatedReplyId,
          },
        };
        
        print('Sending media reply via SignalR: ${jsonEncode(signalRData)}');
        await SignalRService.sendMessage(signalRData);
        print('✅ Media reply sent successfully via SignalR');
        if (tempId != null && tempId.isNotEmpty) {
          _updateOptimisticMessage(tempId, 2);
        }
        
        // Media reply sent successfully, you can update the state or use a callback to notify UI
        print('Media reply sent successfully');
        state = state.copyWith(error: null); // Optionally clear any previous error
      } else {
        state = state.copyWith(error: 'Cannot send media reply. Connection not available or invalid reply ID.');
      }
    } catch (e) {
      print('❌ Media reply via SignalR failed: $e');
      state = state.copyWith(error: 'Failed to send media reply: $e');
    }
  }
  
  Future<String?> _getAgentAccountId(int channelId) async {
    // Use the new AccountService to get account ID for channel
    final accountService = AccountService();
    
    // First try to get from cached mapping
    String? accountId = accountService.getAccountIdForChannel(channelId);
    
    if (accountId != null) {
      print('✅ Using cached account ID for channel $channelId: $accountId');
      return accountId;
    }
    
    // If no cached mapping, fetch fresh data and update mappings
    try {
      print('🔄 No cached account for channel $channelId, refreshing mappings...');
      await accountService.refreshAccountMappings();
      
      // Try again after refresh
      accountId = accountService.getAccountIdForChannel(channelId);
      
      if (accountId != null) {
        print('✅ Found account after refresh for channel $channelId: $accountId');
        return accountId;
      }
      
    } catch (e) {
      print('⚠ Error refreshing account mappings: $e');
    }
    
    // Try to fetch agent accounts for channel from API as fallback
    try {
      print('Fetching agent accounts for channelId: $channelId');
      final response = await ApiService.getAccountList(channelId: channelId);
      if (!response.isError && response.data != null && response.data!.isNotEmpty) {
        // Return the first agent account ID for this channel
        final account = response.data!.first;
        final fallbackAccountId = account['Id']?.toString();
        print('Found agent account: $fallbackAccountId for channel: $channelId');
        
        // Save it for future use
        if (fallbackAccountId != null) {
          final userData = StorageService.getUserData() ?? {};
          userData['AgentAccountId'] = fallbackAccountId;
          userData['AgentAccountIds'] = response.data!.map((a) => a['Id']?.toString()).where((id) => id != null).toList();
          await StorageService.saveUserData(userData);
          print('Saved AgentAccountId to storage: $fallbackAccountId');
        }
        
        return fallbackAccountId;
      } else {
        print('No agent accounts found for channelId: $channelId');
        print('API Response: ${response.data}');
      }
    } catch (e) {
      print('Error fetching account list: $e');
    }
    
    print('⚠ No account found for channel $channelId after refresh');
    return null;
  }

 void _updateRoom(Room room) {
  if (room.status != 4) {
    final rooms = List<Room>.from(state.rooms);
    final index = rooms.indexWhere((r) => r.id == room.id);

    if (index != -1) {
      print('🔄 Updating existing room: ${room.name}');
      rooms[index] = room;
    } else {
      print('➕ Adding new room to list: ${room.name}');
      rooms.insert(0, room);
    }

    rooms.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });

    // CRITICAL: If this room is active, update activeRoom object reference
    // but DON'T change messages or trigger reload
    Room? updatedActiveRoom = state.activeRoom;
    if (state.activeRoom?.id == room.id) {
      updatedActiveRoom = room;
      print('🔄 Updated active room metadata (no reload)');
    }

    state = state.copyWith(
      rooms: rooms,
      activeRoom: updatedActiveRoom,
      // CRITICAL: Don't touch messages during room update
    );
    print('✅ Room list updated, total rooms: ${rooms.length}');
  } else {
    final archivedRooms = List<Room>.from(state.archivedRooms);
    final index = archivedRooms.indexWhere((r) => r.id == room.id);

    if (index != -1) {
      print('🔄 Updating existing archived room: ${room.name}');
      archivedRooms[index] = room;
    } else {
      print('➕ Adding new room to archived list: ${room.name}');
      archivedRooms.insert(0, room);
    }

    state = state.copyWith(archivedRooms: archivedRooms);
  }
}


 void _addMessage(ChatMessage message) {
  print('📨 New message received: ${message.id} for room ${message.roomId}');
  
  // ALWAYS update room list metadata
  _updateRoomWithNewMessage(message);
  
  // CRITICAL: Only modify messages if this is the ACTIVE room
  if (state.activeRoom?.id == message.roomId) {
    print('📨 Message for active room, adding to messages list');
    final messages = List<ChatMessage>.from(state.messages);
    
    final existingIndex = messages.indexWhere((m) => m.id == message.id);
    if (existingIndex == -1) {
      // Check for optimistic message to replace
      final optimisticIndex = messages.indexWhere((m) => 
          m.id.startsWith('temp_') && 
          m.message == message.message &&
          m.timestamp.difference(message.timestamp).abs().inMinutes < 5);
      
      if (optimisticIndex != -1) {
        messages[optimisticIndex] = message;
        print('🔄 Replaced optimistic message');
      } else {
        messages.add(message);
        print('➕ Added new message');
      }
      
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // CRITICAL: ONLY update messages, nothing else
      state = state.copyWith(messages: messages);
    } else if (messages[existingIndex].id.startsWith('temp_')) {
      messages[existingIndex] = message;
      state = state.copyWith(messages: messages);
      print('🔄 Updated optimistic message');
    }
  } else {
    print('📨 Message for different room, room list already updated');
  }
}

  void _updateRoomWithNewMessage(ChatMessage message) {
  final rooms = List<Room>.from(state.rooms);
  final roomIndex = rooms.indexWhere((r) => r.id == message.roomId);
  
  if (roomIndex != -1) {
    final room = rooms[roomIndex];
    final shouldIncreaseUnread = !_isMessageFromCurrentAgent(message);
    
    final updatedRoom = Room(
      id: room.id,
      ctId: room.ctId,
      ctRealId: room.ctRealId,
      grpId: room.grpId,
      name: room.name,
      lastMessage: message.message ?? _getMessageTypeDescription(message.type),
      lastMessageTime: message.timestamp,
      unreadCount: shouldIncreaseUnread ? room.unreadCount + 1 : room.unreadCount,
      status: room.status,
      channelId: room.channelId,
      channelName: room.channelName,
      accountName: room.accountName,
      botName: room.botName,
      contactImage: room.contactImage,
      linkImage: room.linkImage,
      isGroup: room.isGroup,
      isPinned: room.isPinned,
      isBlocked: room.isBlocked,
      isMuteBot: room.isMuteBot,
      tags: room.tags,
      funnel: room.funnel,
      funnelId: room.funnelId,
      tagIds: room.tagIds,
    );
    
    rooms[roomIndex] = updatedRoom;
    
    rooms.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      
      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });
    
    // CRITICAL: Update activeRoom metadata if same room
    Room? newActiveRoom = state.activeRoom;
    if (state.activeRoom?.id == message.roomId) {
      newActiveRoom = updatedRoom;
      print('🔄 Updated active room metadata from message');
    }
    
    // CRITICAL: Only update rooms and activeRoom, NOT messages
    state = state.copyWith(
      rooms: rooms,
      activeRoom: newActiveRoom,
    );
    print('🔄 Room ${room.name} updated with new message');
  } else {
    print('⚠️ Room ${message.roomId} not found');
    // DON'T call loadRooms here - it causes refresh loop
  }
}

  String _getCurrentAgentId() {
    final userData = StorageService.getUserData();
    return userData?['AgentAccountId']?.toString() ?? 
           userData?['CurrentUserId']?.toString() ?? 
           userData?['UserId']?.toString() ?? 
           'me';
  }

  bool _isMessageFromCurrentAgent(ChatMessage message) {
    final userData = StorageService.getUserData();
    final agentAccountIds = userData?['AgentAccountIds'] as List<dynamic>? ?? [];
    final currentUserId = userData?['UserId']?.toString();
    
    // Check if message is from any of the agent account IDs
    final messageFrom = message.from.toString();
    final isFromAgentAccount = agentAccountIds.any((id) => id.toString() == messageFrom);
    
    // Check if message has agentId > 0 (sent via app)
    final isFromApp = message.agentId > 0;
    
    // Check if message is from current user ID
    final isFromCurrentUser = currentUserId != null && messageFrom == currentUserId;
    
    // Also check using AccountService for more reliable detection
    final accountService = AccountService();
    final userAccounts = accountService.getUserAccounts();
    final isFromUserAccount = userAccounts.any((account) => account.id == messageFrom);
    
    final result = isFromAgentAccount || isFromApp || isFromCurrentUser || isFromUserAccount;
    
    if (result) {
      print('🤖 Message from agent: $messageFrom (agentId: ${message.agentId}, isUserAccount: $isFromUserAccount)');
    } else {
      print('👤 Message from customer: $messageFrom (agentId: ${message.agentId})');
    }
    
    return result;
  }
  
  String _getMessageTypeDescription(int type) {
    switch (type) {
      case 1: return 'Text message';
      case 2: return '🔊 Audio';
      case 3: return '🖼 Photo';
      case 4: return '🎬 Video';
      case 5: return '📄 Document';
      case 7: return '🌟 Sticker';
      case 9: return '📍 Location';
      default: return 'Message';
    }
  }

  String _addOptimisticMessage(String text, {String? replyId}) {
    final activeRoom = state.activeRoom;
    if (activeRoom == null) return '';

    // Use AccountService to get the proper agent account ID for this channel
    final accountService = AccountService();
    final agentAccountId = accountService.getAccountIdForChannel(activeRoom.channelId);
    
    // Fallback to user ID if no account mapping found
    final userData = StorageService.getUserData();
    final fallbackId = userData?['CurrentUserId']?.toString() ?? userData?['UserId']?.toString() ?? 'agent';
    final fromId = agentAccountId ?? fallbackId;
    
    final now = DateTime.now();
    final tempId = 'temp_${now.millisecondsSinceEpoch}_${text.hashCode}';
    
    // Get reply information if replying to a message
    ChatMessage? replyToMessage;
    if (replyId != null) {
      try {
        replyToMessage = state.messages.firstWhere((m) => m.id == replyId);
        print('✅ Found reply message for optimistic message: ${replyToMessage.id} - ${replyToMessage.message}');
      } catch (e) {
        print('Reply message not found: $replyId');
      }
    }
    
    final optimisticMessage = ChatMessage(
      id: tempId,
      roomId: activeRoom.id,
      from: fromId,
      agentId: int.tryParse(userData?['UserId']?.toString() ?? '1') ?? 1,
      type: 1,
      message: text,
      timestamp: now,
      ack: 1, // Pending
      replyId: replyId,
      replyType: replyToMessage?.type,
      replyFrom: replyToMessage?.from,
      replyMessage: replyToMessage?.message,
      replyFiles: replyToMessage?.files,
      replyGrpMember: replyToMessage?.from != fromId ? 'Customer' : null,
    );
    
    // Add to messages immediately for better UX
    final messages = List<ChatMessage>.from(state.messages);
    messages.add(optimisticMessage);
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    state = state.copyWith(messages: messages);
    print('Added optimistic message with reply info - from: $fromId, replyId: $replyId, replyMessage: ${replyToMessage?.message}');
    
    return tempId;
  }

  // Add optimistic media message (image/video/document/audio)
  String _addOptimisticMediaMessage({
    required String type,
    required UploadedFile uploadedFile,
    String? caption,
    String? replyId,
  }) {
    final activeRoom = state.activeRoom;
    if (activeRoom == null) return '';

    // Resolve sender (same logic as text)
    final accountService = AccountService();
    final agentAccountId = accountService.getAccountIdForChannel(activeRoom.channelId);
    final userData = StorageService.getUserData();
    final fallbackId = userData?['CurrentUserId']?.toString() ?? userData?['UserId']?.toString() ?? 'agent';
    final fromId = agentAccountId ?? fallbackId;

    final now = DateTime.now();
    final tempId = 'temp_${now.millisecondsSinceEpoch}_${uploadedFile.filename.hashCode}';

    // Build file payload for optimistic display
    final fileMap = {
      'Filename': uploadedFile.filename,
      'OriginalName': uploadedFile.originalName,
      if ((caption ?? '').trim().isNotEmpty) 'Caption': caption!.trim(),
    };

    // Reply info if any
    ChatMessage? replyToMessage;
    if (replyId != null) {
      try {
        replyToMessage = state.messages.firstWhere((m) => m.id == replyId);
      } catch (_) {}
    }

    final optimisticMessage = ChatMessage(
      id: tempId,
      roomId: activeRoom.id,
      from: fromId,
      agentId: int.tryParse(userData?['UserId']?.toString() ?? '1') ?? 1,
      type: int.tryParse(type) ?? 1,
      message: caption?.trim(),
      file: jsonEncode(fileMap),
      files: jsonEncode([fileMap]),
      timestamp: now,
      ack: 1, // pending single check
      replyId: replyId,
      replyType: replyToMessage?.type,
      replyFrom: replyToMessage?.from,
      replyMessage: replyToMessage?.message,
      replyFiles: replyToMessage?.files,
      replyGrpMember: replyToMessage?.from != fromId ? 'Customer' : null,
    );

    final messages = List<ChatMessage>.from(state.messages);
    messages.add(optimisticMessage);
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    state = state.copyWith(messages: messages);

    print('🖼 Added optimistic media message: ${uploadedFile.originalName} (type=$type)');

    return tempId;
  }

  void _updateOptimisticMessage(String messageId, int ackStatus) {
    final messages = List<ChatMessage>.from(state.messages);
    final index = messages.indexWhere((m) => m.id == messageId);
    
    if (index != -1) {
      print('Updating optimistic message $messageId with ack status: $ackStatus, preserving reply data');
      final updatedMessage = ChatMessage(
        id: messages[index].id,
        roomId: messages[index].roomId,
        from: messages[index].from,
        to: messages[index].to,
        agentId: messages[index].agentId,
        type: messages[index].type,
        message: messages[index].message,
        file: messages[index].file,
        files: messages[index].files,
        timestamp: messages[index].timestamp,
        ack: ackStatus,
        replyId: messages[index].replyId,
        replyType: messages[index].replyType,
        replyFrom: messages[index].replyFrom,
        replyMessage: messages[index].replyMessage,
        replyFiles: messages[index].replyFiles,
        replyGrpMember: messages[index].replyGrpMember,
        isEdited: messages[index].isEdited,
        note: messages[index].note,
      );
      
      messages[index] = updatedMessage;
      state = state.copyWith(messages: messages);
      print('✅ Updated optimistic message, reply data preserved: replyId=${updatedMessage.replyId}');
    } else {
      print('Optimistic message $messageId not found for update');
    }
  }

  void _updateMessageAck(Map<String, dynamic> ackData) {
    // Check if this is a NeedReply update
    if (ackData['type'] == 'needReply') {
      _handleNeedReplyUpdate(ackData);
      return;
    }

    if (state.activeRoom?.id == ackData['roomId']) {
      final messages = List<ChatMessage>.from(state.messages);
      final index = messages.indexWhere((m) => m.id == ackData['messageId']);

      if (index != -1) {
        // Update message ack status
        // This would require updating the ChatMessage model to be mutable or creating a new instance
      }
    }
  }

  void _handleNeedReplyUpdate(Map<String, dynamic> data) {
    final roomId = data['roomId'] as String;
    final needReply = data['needReply'] as bool;

    print('🔔 Handling NeedReply update: Room $roomId, NeedReply: $needReply');

    // Update the room in the rooms list
    final rooms = List<Room>.from(state.rooms);
    final roomIndex = rooms.indexWhere((r) => r.id == roomId);

    if (roomIndex != -1) {
      final updatedRoom = Room(
        id: rooms[roomIndex].id,
        ctId: rooms[roomIndex].ctId,
        ctRealId: rooms[roomIndex].ctRealId,
        grpId: rooms[roomIndex].grpId,
        name: rooms[roomIndex].name,
        lastMessage: rooms[roomIndex].lastMessage,
        lastMessageTime: rooms[roomIndex].lastMessageTime,
        unreadCount: rooms[roomIndex].unreadCount,
        status: rooms[roomIndex].status,
        channelId: rooms[roomIndex].channelId,
        channelName: rooms[roomIndex].channelName,
        accountName: rooms[roomIndex].accountName,
        botName: rooms[roomIndex].botName,
        contactImage: rooms[roomIndex].contactImage,
        linkImage: rooms[roomIndex].linkImage,
        isGroup: rooms[roomIndex].isGroup,
        isPinned: rooms[roomIndex].isPinned,
        isBlocked: rooms[roomIndex].isBlocked,
        isMuteBot: rooms[roomIndex].isMuteBot,
        tags: rooms[roomIndex].tags,
        messageTags: rooms[roomIndex].messageTags,
        funnel: rooms[roomIndex].funnel,
        funnelId: rooms[roomIndex].funnelId,
        tagIds: rooms[roomIndex].tagIds,
        needReply: needReply, // Update the needReply field
      );

      rooms[roomIndex] = updatedRoom;

      // Also update active room if this is the active room
      Room? updatedActiveRoom = state.activeRoom;
      if (state.activeRoom?.id == roomId) {
        updatedActiveRoom = updatedRoom;
      }

      state = state.copyWith(
        rooms: rooms,
        activeRoom: updatedActiveRoom,
      );

      print('✅ NeedReply status updated for room $roomId');
    }
  }

  void _saveMessageHistory(ChatMessage message) {
    final userData = StorageService.getUserData() ?? {};
    final history = userData['messageHistory'] as List<dynamic>? ?? [];
    
    history.add({
      'from': message.from,
      'agentId': message.agentId,
      'timestamp': message.timestamp.toIso8601String(),
      'message': message.message,
    });
    
    // Keep only last 100 messages for history
    if (history.length > 100) {
      history.removeAt(0);
    }
    
    userData['messageHistory'] = history;
    StorageService.saveUserData(userData);
  }

  String _getMimeType(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mp3';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'wav':
        return 'audio/wav';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  // Helper method to map display channel IDs to actual sending channel IDs
  int _getEffectiveChannelId(int displayChannelId) {
    // Map display channel IDs to actual API channel IDs based on backend requirements
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
        return displayChannelId; // Use as-is if no mapping found
    } 
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});