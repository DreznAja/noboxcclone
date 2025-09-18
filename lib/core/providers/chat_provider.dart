import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/services/media_service.dart';
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
    state = state.copyWith(isLoading: true, error: null);
    
    print('Loading rooms with search: "$search" and filters: $filters');

    try {
      // Clean and validate filters before sending to API
      final cleanedFilters = filters != null ? _cleanFilters(filters) : null;
      
      // IMPORTANT FIX: Ensure we exclude archived rooms (status 4) from regular room list
      Map<String, dynamic>? finalFilters;
      if (cleanedFilters != null) {
        finalFilters = Map<String, dynamic>.from(cleanedFilters);
      } else {
        finalFilters = {};
      }
      
      // If no specific status filter is applied, exclude archived rooms by default
      if (!finalFilters.containsKey('St')) {
        // Only show Unassigned (1), Assigned (2), and Resolved (3) - exclude Archived (4)
        finalFilters['St'] = [1, 2, 3];
      } else {
        // If status filter exists, ensure it doesn't include archived status
        final currentStatuses = finalFilters['St'] as List<dynamic>;
        final filteredStatuses = currentStatuses.where((status) => status != 4).toList();
        if (filteredStatuses.isNotEmpty) {
          finalFilters['St'] = filteredStatuses;
        } else {
          // If all statuses were archived, show unassigned instead
          finalFilters['St'] = [1];
        }
      }
      
      if (finalFilters.isNotEmpty) {
        print('Final filters for regular rooms (excluding archived): $finalFilters');
      }

      final response = await ApiService.getRoomList(
        search: search,
        filters: finalFilters,
      );

      if (response.isError) {
        state = state.copyWith(
          isLoading: false,
          error: response.error,
        );
        print('API Error loading rooms: ${response.error}');
        return;
      }

      final rooms = response.data ?? [];
      
      // Additional client-side filter to ensure no archived rooms slip through
      final nonArchivedRooms = rooms.where((room) => room.status != 4).toList();
      
      print('Successfully loaded ${nonArchivedRooms.length} non-archived rooms (filtered from ${rooms.length} total)');
      
      state = state.copyWith(
        isLoading: false,
        rooms: nonArchivedRooms,
      );
    } catch (e) {
      print('Exception loading rooms: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
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
      final onlyArchivedRooms = archivedRooms.where((room) => room.status == 4).toList();
      
      print('Successfully loaded ${onlyArchivedRooms.length} archived rooms');
      
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
            contactImage: room.contactImage,
            linkImage: room.linkImage,
            isGroup: room.isGroup,
            isPinned: isPinned,
            isBlocked: room.isBlocked,
            isMuteBot: room.isMuteBot,
            tags: room.tags,
            funnel: room.funnel,
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
    final cleanedFilters = <String, dynamic>{};
    
    for (final entry in filters.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Skip null or empty values
      if (value == null) continue;
      
      // Handle list values
      if (value is List) {
        if (value.isNotEmpty) {
          cleanedFilters[key] = value;
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
            }
          } else {
            cleanedFilters[key] = [value];
          }
        }
      }
      // Handle int values
      else if (value is int) {
        cleanedFilters[key] = [value];
      }
      // Handle bool values
      else if (value is bool) {
        cleanedFilters[key] = [value ? 1 : 0];
      }
      else {
        // Keep other types as is
        cleanedFilters[key] = value;
      }
    }
    
    return cleanedFilters;
  }
  
  bool _isNumericFilter(String key) {
    final numericFilters = [
      'ChId', 'CtId', 'GrpId', 'St', 'AgentId', 'AccountId', 
      'LinkId', 'CampaignId', 'FunnelId', 'DealId', 'TagId'
    ];
    return numericFilters.contains(key);
  }

  Future<void> selectRoom(Room room) async {
    state = state.copyWith(isLoading: true, error: null);
    print('Selecting room: ${room.id} - ${room.name}');

    try {
      // Leave previous room if exists
      if (state.activeRoom != null && SignalRService.isConnected) {
        await SignalRService.leaveConversation(state.activeRoom!.id);
      }

      // FIXED: Handle new conversations better
      try {
        // Load initial messages (most recent)
        final messagesResponse = await ApiService.getMessages(
          roomId: room.id,
          take: 20, // Load 20 most recent messages initially
          skip: 0,
        );
        
        if (!messagesResponse.isError && messagesResponse.data != null) {
          // Sort messages by timestamp (newest first from API, then reverse for display)
          final sortedMessages = List<ChatMessage>.from(messagesResponse.data!);
          sortedMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first
          final displayMessages = sortedMessages.reversed.toList(); // Oldest first for display
          
          print('Loaded ${displayMessages.length} messages for room ${room.id}');
          
          state = state.copyWith(
            activeRoom: room,
            messages: displayMessages,
            isLoading: false,
            hasMoreMessages: messagesResponse.data!.length >= 20, // Has more if we got full page
          );
        } else {
          // FIXED: Handle case where room has no messages (normal for new conversations)
          print('No messages found for room ${room.id}, this is normal for new conversations');
          state = state.copyWith(
            activeRoom: room,
            messages: [], // Empty messages list is OK for new conversations
            isLoading: false,
            hasMoreMessages: false,
            error: null, // Don't set error for empty message list
          );
        }
      } catch (messagesError) {
        print('Error loading messages for room ${room.id}: $messagesError');
        // FIXED: Don't treat missing messages as an error for new conversations
        state = state.copyWith(
          activeRoom: room,
          messages: [], // Start with empty messages
          isLoading: false,
          hasMoreMessages: false,
          error: null, // Clear any previous errors
        );
      }
      
      // Join new room for real-time updates after successfully setting up
      if (SignalRService.isConnected) {
        try {
          await SignalRService.joinConversation(room.id, null);
          print('✅ Joined room ${room.id} for real-time updates');
        } catch (joinError) {
          print('Failed to join room after selection: $joinError');
        }
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
      
      // Still try to join room for real-time updates
      if (SignalRService.isConnected) {
        try {
          await SignalRService.joinConversation(room.id, null);
        } catch (joinError) {
          print('Failed to join room after error: $joinError');
        }
      }
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

    // Validate replyId before sending
    String? validatedReplyId = replyId;
    if (replyId != null && replyId.isNotEmpty) {
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
        print('⚠️ Reply message not found for location message, removing ReplyId');
        validatedReplyId = null;
      }
    }

    // Send via API as text message (type 1) with location content
    await _sendMessageViaAPI(locationText, tempId: tempId, replyId: validatedReplyId);
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
      
      // Format data for Inbox API
      final apiMessageData = {
        'LinkId': int.tryParse(linkId),
        'ChannelId': channelId,
        'AccountIds': accountId,
        'BodyType': 1,
        'Body': text.trim(), // Ensure text is properly trimmed
        'Attachment': '',
        // Only include ReplyId if it's not null and not empty
        if (replyId != null && replyId.isNotEmpty) 'ReplyId': replyId,
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
      
      // Additional validation for reply messages
      if (replyId != null && replyId.isNotEmpty) {
        // Validate that the reply message exists in our message list
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
          apiMessageData.remove('ReplyId');
        } else {
          print('✅ Reply message found: ${replyMessage.id} - ${replyMessage.message}');
          
          // Additional validation: Check if ReplyId is too long or has invalid format
          if (replyId.length > 20) {
            print('⚠️ ReplyId too long (${replyId.length} chars), removing ReplyId');
            apiMessageData.remove('ReplyId');
          } else {
            // For WhatsApp Business, try to ensure ReplyId is in correct format
            if (channelId == 1561) {
              // Check if ReplyId looks like a valid message ID
              final isValidFormat = RegExp(r'^\d+$').hasMatch(replyId);
              if (!isValidFormat) {
                print('⚠️ Invalid ReplyId format for WhatsApp Business: $replyId, removing');
                apiMessageData.remove('ReplyId');
              } else {
                print('✅ Valid ReplyId format for WhatsApp Business: $replyId');
              }
            }
          }
        }
      }
      
      print('Sending message via API: ${jsonEncode(apiMessageData)}');
      
      final response = await ApiService.sendMessage(apiMessageData);
      if (response.isError) {
        _updateOptimisticMessage(tempId, 4); // Mark as failed
        state = state.copyWith(error: response.error ?? 'Failed to send message');
      } else {
        _updateOptimisticMessage(tempId, 2); // Mark as sent
        print('Message sent successfully via API');
        print('API Response Data: ${response.data}');
        
        // Also try SignalR for real-time updates
        try {
          // Only try SignalR if we're actually connected
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
                if (replyId != null && replyId.isNotEmpty) 'ReplyId': replyId,
              },
            };
            print('Sending SignalR notification: ${jsonEncode(signalRData)}');
            await SignalRService.sendMessage(signalRData);
            print('SignalR notification sent successfully');
          } else {
            print('ℹ️ SignalR not connected, skipping real-time notification');
          }
        } catch (e) {
          print('SignalR notification failed: $e');
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
      
      // Send media message via API
      await _sendMediaMessageViaAPI(type, caption, uploadResponse.data!, replyId: replyId);
    } catch (e) {
      print('Error sending media message: $e');
      state = state.copyWith(error: 'Failed to send media message: $e');
    }
  }

  Future<void> _sendMediaMessageViaAPI(String type, String? caption, UploadedFile uploadedFile, {String? replyId}) async {
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
      
      attachmentData = jsonEncode([attachmentMap]);
      
      // Format data for Inbox API
      final apiMessageData = {
        'LinkId': int.tryParse(linkId),
        'ChannelId': workingChannelId,
        'AccountIds': accountId,
        'BodyType': int.parse(type),
        'Body': bodyText,
        'Attachment': attachmentData,
        // Only include ReplyId if it's not null and not empty
        if (replyId != null && replyId.isNotEmpty) 'ReplyId': replyId,
      };
      
      // Additional validation for reply messages
      if (replyId != null && replyId.isNotEmpty) {
        // Validate that the reply message exists in our message list
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
          print('⚠️ Reply message not found for media message, removing ReplyId');
          apiMessageData.remove('ReplyId');
        } else {
          print('✅ Reply message found for media: ${replyMessage.id}');
        }
      }
      
      print('Sending media message via API: ${jsonEncode(apiMessageData)}');
      
      final response = await ApiService.sendMessage(apiMessageData);
      if (response.isError) {
        state = state.copyWith(error: response.error ?? 'Failed to send media message');
      } else {
        print('Media message sent successfully via API');
        print('Media message with caption sent successfully');
        
        // Also send via SignalR for real-time updates
        try {
          // Only try SignalR if we're actually connected
          if (SignalRService.isConnected) {
            // For SignalR, send media message with caption
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
                'Files': jsonEncode([uploadedFile.toJson()]),
                if (replyId != null && replyId.isNotEmpty) 'ReplyId': replyId,
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
    // Only update non-archived rooms in the regular rooms list
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

      // Sort rooms again (pinned first, then by last message time)
      rooms.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        
        if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });
      state = state.copyWith(rooms: rooms);
      print('✅ Room list updated, total rooms: ${rooms.length}');
    } else {
      // If it's archived, update archived rooms list
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
    
    // Always update the room list with new message info
    _updateRoomWithNewMessage(message);
    
    // Add message to active room if it matches
    if (state.activeRoom?.id == message.roomId) {
      print('📨 Adding message to active room messages list');
      final messages = List<ChatMessage>.from(state.messages);
      
      // Check if message already exists to avoid duplicates
      final existingIndex = messages.indexWhere((m) => m.id == message.id);
      if (existingIndex == -1) {
        // Check if this is a real message that should replace an optimistic message
        final optimisticIndex = messages.indexWhere((m) => 
            m.id.startsWith('temp_') && 
            m.message == message.message &&
            m.timestamp.difference(message.timestamp).abs().inMinutes < 5);
        
        if (optimisticIndex != -1) {
          // Replace optimistic message with real message
          messages[optimisticIndex] = message;
          print('🔄 Replaced optimistic message with real message');
        } else {
          // Add new message normally
          messages.add(message);
          print('➕ Added new message to active room');
        }
        
        // Sort messages by timestamp
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        state = state.copyWith(messages: messages);
      } else {
        // Update existing message if it's an optimistic message being replaced
        if (messages[existingIndex].id.startsWith('temp_') && !message.id.startsWith('temp_')) {
          messages[existingIndex] = message;
          state = state.copyWith(messages: messages);
          print('🔄 Updated existing optimistic message');
        }
      }
    } else {
      print('📨 Message for different room, only updating room list');
    }
  }

  void _updateRoomWithNewMessage(ChatMessage message) {
    final rooms = List<Room>.from(state.rooms);
    final roomIndex = rooms.indexWhere((r) => r.id == message.roomId);
    
    if (roomIndex != -1) {
      final room = rooms[roomIndex];
      
      // Determine if this message should increase unread count
      final shouldIncreaseUnread = !_isMessageFromCurrentAgent(message);
      
      // Create updated room with new message info
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
      
      // Sort rooms again (pinned first, then by last message time)
      rooms.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        
        if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });
      
      state = state.copyWith(rooms: rooms);
      print('🔍 Updated room ${room.name} with new message from ${message.from}');
    } else {
      print('⚠️ Room ${message.roomId} not found in current room list');
      // Optionally reload rooms if room not found
      loadRooms();
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
    print('Added optimistic message with from: $fromId (channel: ${activeRoom.channelId})');
    
    return tempId;
  }

  void _updateOptimisticMessage(String messageId, int ackStatus) {
    final messages = List<ChatMessage>.from(state.messages);
    final index = messages.indexWhere((m) => m.id == messageId);
    
    if (index != -1) {
      print('Updating optimistic message $messageId with ack status: $ackStatus');
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
        isEdited: messages[index].isEdited,
        note: messages[index].note,
      );
      
      messages[index] = updatedMessage;
      state = state.copyWith(messages: messages);
    } else {
      print('Optimistic message $messageId not found for update');
    }
  }

  void _updateMessageAck(Map<String, dynamic> ackData) {
    if (state.activeRoom?.id == ackData['roomId']) {
      final messages = List<ChatMessage>.from(state.messages);
      final index = messages.indexWhere((m) => m.id == ackData['messageId']);
      
      if (index != -1) {
        // Update message ack status
        // This would require updating the ChatMessage model to be mutable or creating a new instance
      }
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