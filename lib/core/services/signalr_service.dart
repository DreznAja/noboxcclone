import 'dart:async';
import 'dart:convert';
import 'package:signalr_netcore/signalr_client.dart';
import '../app_config.dart';
import '../models/chat_models.dart';
import 'storage_service.dart';
import 'push_notification_service.dart';
import 'api_service.dart';

class SignalRService {
  static HubConnection? _connection;
  static final StreamController<Room> _roomUpdateController = StreamController<Room>.broadcast();
  static final StreamController<ChatMessage> _messageController = StreamController<ChatMessage>.broadcast();
  static final StreamController<Map<String, dynamic>> _ackController = StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<String> _connectionStatusController = StreamController<String>.broadcast();
  
  static Timer? _heartbeatTimer;
  static Timer? _reconnectTimer;
  static Timer? _subscriptionTimer;
  static bool _isReconnecting = false;
  static int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static bool _isFullyInitialized = false;

  // Streams
  static Stream<Room> get roomUpdates => _roomUpdateController.stream;
  static Stream<ChatMessage> get messages => _messageController.stream;
  static Stream<Map<String, dynamic>> get messageAcks => _ackController.stream;
  static Stream<String> get connectionStatus => _connectionStatusController.stream;

  static Future<void> init() async {
    final token = StorageService.getToken();
    if (token == null) {
      print('❌ No token available for SignalR initialization');
      return;
    }

    final userData = StorageService.getUserData();
    if (userData == null) {
      print('❌ No user data available for SignalR initialization');
      return;
    }

    // Reset initialization flag
    _isFullyInitialized = false;
    
    print('🔌 Starting SignalR initialization...');
    print('📡 Token available: ${token.substring(0, 20)}...');
    print('👤 User data available: ${userData['UserId']}');

    // Dispose existing connection if any
    await _disposeConnection();
    
    _connectionStatusController.add('connecting');

    _connection = HubConnectionBuilder()
        .withUrl(AppConfig.signalRUrl)
        .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 30000])
        .build();

    // Setup event handlers
    _setupEventHandlers();

    try {
      await _connection!.start()!.timeout(const Duration(seconds: 15));
      _reconnectAttempts = 0;
      print('🔌 SignalR connection established successfully');

      // CRITICAL: Verify event handlers are registered
      print('📡 Verifying event handlers are registered...');

      // Don't mark as connected until subscription is complete
      print('📡 Subscribing user to SignalR...');

      try {
        await _subscribeUser();
        _connectionStatusController.add('connected');
        _isFullyInitialized = true;
        _startHeartbeat();
        print('✅ SignalR fully initialized and connected successfully');
      } catch (subscribeError) {
        print('❌ Failed to subscribe user: $subscribeError');
        _connectionStatusController.add('connecting');
        _scheduleReconnect();
      }
    } catch (e) {
      _connectionStatusController.add('connecting');
      print('❌ SignalR connection failed: $e');
      _scheduleReconnect();
    }
  }

  static Future<void> _disposeConnection() async {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscriptionTimer?.cancel();
    
    if (_connection != null) {
      try {
        await _connection!.stop();
      } catch (e) {
        print('Error stopping existing connection: $e');
      }
      _connection = null;
    }
  }

  static void _setupEventHandlers() {
    if (_connection == null) return;

    // Connection state handlers
    _connection!.onclose(({error}) {
      _connectionStatusController.add('connecting');
      _isFullyInitialized = false;
      _heartbeatTimer?.cancel();
      print('🔌 SignalR connection closed: $error');
      if (!_isReconnecting) {
        _scheduleReconnect();
      }
    });

    _connection!.onreconnected(({connectionId}) {
      print('🔄 SignalR reconnected with ID: $connectionId');
      _reconnectAttempts = 0;
      _isReconnecting = false;
      
      // Re-subscribe and then mark as connected
      _subscribeUser().then((_) {
        _connectionStatusController.add('connected');
        _isFullyInitialized = true;
        _startHeartbeat();
        print('✅ SignalR fully reconnected and subscribed');
      }).catchError((error) {
        print('❌ Failed to re-subscribe after reconnection: $error');
        _connectionStatusController.add('connecting');
        _scheduleReconnect();
      });
    });

    _connection!.onreconnecting(({error}) {
      print('🔄 SignalR reconnecting: $error');
      _connectionStatusController.add('reconnecting');
      _isReconnecting = true;
    });

    // Message handlers - simplified and more reliable
    _connection!.on('TerimaPesan', (List<Object?>? arguments) {
      if (arguments != null && arguments.length >= 2) {
        try {
          final messageData = arguments[1] as String;
          final parsedData = jsonDecode(messageData);
          final message = ChatMessage.fromJson(parsedData);
          print('📨 ═══════════════════════════════════════════════════════');
          print('📨 SignalR: TerimaPesan received!');
          print('📨   Message ID: ${message.id}');
          print('📨   Room ID: ${message.roomId}');
          print('📨   Message: ${message.message}');
          print('📨   From: ${message.from}');
          print('📨   Broadcasting to ${_messageController.hasListener ? "ACTIVE" : "NO"} listeners');
          print('📨 ═══════════════════════════════════════════════════════');
          _messageController.add(message);

          // Show push notification for new messages
          _handleNewMessageNotification(message);
        } catch (e) {
          print('❌ Error parsing TerimaPesan: $e');
        }
      }
    });

    // Room update handlers
    _connection!.on('TerimaSubSpv', (List<Object?>? arguments) {
      if (arguments != null && arguments.length >= 2) {
        try {
          final roomData = arguments[1] as String;
          final room = Room.fromJson(jsonDecode(roomData));
          print('🏠 ═══════════════════════════════════════════════════════');
          print('🏠 SignalR: TerimaSubSpv received!');
          print('🏠   Room ID: ${room.id}');
          print('🏠   Room Name: ${room.name}');
          print('🏠   Last Message: ${room.lastMessage}');
          print('🏠   Broadcasting to ${_roomUpdateController.hasListener ? "ACTIVE" : "NO"} listeners');
          print('🏠 ═══════════════════════════════════════════════════════');
          _roomUpdateController.add(room);
        } catch (e) {
          print('❌ Error parsing TerimaSubSpv: $e');
        }
      }
    });

    _connection!.on('TerimaSubAgent', (List<Object?>? arguments) {
      if (arguments != null && arguments.length >= 2) {
        try {
          final roomData = arguments[1] as String;
          final room = Room.fromJson(jsonDecode(roomData));
          print('🏠 ═══════════════════════════════════════════════════════');
          print('🏠 SignalR: TerimaSubAgent received!');
          print('🏠   Room ID: ${room.id}');
          print('🏠   Room Name: ${room.name}');
          print('🏠   Last Message: ${room.lastMessage}');
          print('🏠   Broadcasting to ${_roomUpdateController.hasListener ? "ACTIVE" : "NO"} listeners');
          print('🏠 ═══════════════════════════════════════════════════════');
          _roomUpdateController.add(room);
        } catch (e) {
          print('❌ Error parsing TerimaSubAgent: $e');
        }
      }
    });

    // New room notifications
    _connection!.on('TerimaRoomBaru', (List<Object?>? arguments) {
      if (arguments != null && arguments.length >= 2) {
        try {
          final roomData = arguments[1] as String;
          final room = Room.fromJson(jsonDecode(roomData));
          print('🆕 ═══════════════════════════════════════════════════════');
          print('🆕 SignalR: TerimaRoomBaru (New Room) received!');
          print('🆕   Room ID: ${room.id}');
          print('🆕   Room Name: ${room.name}');
          print('🆕   Last Message: ${room.lastMessage}');
          print('🆕   Broadcasting to ${_roomUpdateController.hasListener ? "ACTIVE" : "NO"} listeners');
          print('🆕 ═══════════════════════════════════════════════════════');
          _roomUpdateController.add(room);
        } catch (e) {
          print('❌ Error parsing TerimaRoomBaru: $e');
        }
      }
    });

    // Message acknowledgments
    _connection!.on('TerimaAck', (List<Object?>? arguments) {
      if (arguments != null && arguments.length >= 3) {
        try {
          final roomId = arguments[0] as String;
          final messageId = arguments[1] as String;
          final status = arguments[2] as int;
          final error = arguments.length > 3 ? arguments[3] as String? : null;
          
          _ackController.add({
            'roomId': roomId,
            'messageId': messageId,
            'status': status,
            'error': error,
          });
        } catch (e) {
          print('❌ Error parsing TerimaAck: $e');
        }
      }
    });
  }

  static Future<void> _handleNewMessageNotification(ChatMessage message) async {
    // Don't show notification for own messages
    final userData = StorageService.getUserData();
    final currentUserId = userData?['UserId']?.toString();
    
    if (message.agentId.toString() == currentUserId || message.agentId > 0) {
      return; // Skip notifications for agent messages
    }
    
    // CRITICAL: Don't show notification if user is currently in this room
    // Get current room from PushNotificationService
    final currentRoomId = PushNotificationService.getCurrentRoomId();
    if (currentRoomId != null && currentRoomId == message.roomId) {
      print('🚫 User in current room ${message.roomId} - skipping SignalR notification');
      return;
    }
    
    print('✅ User NOT in room ${message.roomId} (current: $currentRoomId) - showing notification');
    
    // Get actual contact name from room detail
    String senderName = 'Customer';
    String roomName = 'New Message';
    
    try {
      // Fetch room detail to get actual contact name
      final contactName = await _getRoomNameForNotification(message.roomId);
      if (contactName != null && contactName.isNotEmpty) {
        senderName = contactName;
        roomName = contactName;
        print('✅ Got actual contact name for notification: $contactName');
      }
    } catch (e) {
      print('⚠️ Could not fetch contact name, using fallback: $e');
    }
    
    // Show notification for customer messages
    await PushNotificationService.showChatNotification(
      roomId: message.roomId,
      roomName: roomName,
      senderName: senderName,
      message: _getNotificationText(message),
    );
  }
  
  static String _getNotificationText(ChatMessage message) {
    switch (message.type) {
      case 1: // Text
        return message.message ?? 'New message';
      case 2: // Audio
        return '🔊 Voice message';
      case 3: // Image
        final caption = message.message?.trim();
        return caption?.isNotEmpty == true ? '📷 $caption' : '📷 Photo';
      case 4: // Video
        final caption = message.message?.trim();
        return caption?.isNotEmpty == true ? '🎥 $caption' : '🎥 Video';
      case 5: // Document
        return '📄 Document';
      case 7: // Sticker
        return '🌟 Sticker';
      case 9: // Location
        return '📍 Location';
      default:
        return 'New message';
    }
  }

  // Helper function to get actual contact name from room detail
  static Future<String?> _getRoomNameForNotification(String roomId) async {
    try {
      final response = await ApiService.dio.post(
        'Services/Chat/Chatrooms/DetailRoom',
        data: {
          'EntityId': roomId,
        },
      );

      if (response.statusCode == 200 && 
          response.data['IsError'] != true && 
          response.data['Data'] != null) {
        final roomData = response.data['Data']['Room'];
        
        // Get the actual contact name from the room data
        // Priority: CtRealNm > Ct > Grp
        final contactName = roomData['CtRealNm'] ?? 
                           roomData['Ct'] ?? 
                           roomData['Grp'] ?? 
                           roomData['Name'];
        
        return contactName;
      }
    } catch (e) {
      print('❌ Error fetching room name for notification: $e');
    }
    return null;
  }

  static void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
      if (_connection?.state == HubConnectionState.Connected) {
        // Use a simple method that definitely exists
        try {
          _connection!.invoke('GetConnectionId');
        } catch (e) {
          // Ignore heartbeat errors - they're not critical
        }
      } else {
        timer.cancel();
      }
    });
  }

  static Future<void> _subscribeUser() async {
    if (_connection == null || _connection!.state != HubConnectionState.Connected) {
      print('❌ SignalR not connected for user subscription');
      throw Exception('SignalR not connected');
    }

    final userData = StorageService.getUserData();
    if (userData == null) {
      print('❌ No user data available for subscription');
      throw Exception('No user data available');
    }

    try {
      final userId = userData['UserId']?.toString() ?? '1';
      final tenantId = userData['TenantId']?.toString() ?? '1';

      print('📡 Subscribing SignalR user - UserId: $userId, TenantId: $tenantId');

      // CRITICAL FIX: Subscribe to both Agent AND Supervisor channels for complete coverage
      // This ensures we receive ALL room updates and messages, not just when in a specific room

      // 1. Subscribe as Agent (for messages and rooms assigned to this agent)
      await _connection!.invoke('SubscribeUserAgent', args: [userId, tenantId]).timeout(
        const Duration(seconds: 5),
      );
      print('✅ SignalR subscribed as agent successfully');

      // 2. Subscribe as Supervisor (for ALL rooms in tenant - critical for home screen updates!)
      try {
        await _connection!.invoke('SubscribeUserSpv', args: [tenantId]).timeout(
          const Duration(seconds: 5),
        );
        print('✅ SignalR subscribed as supervisor - will receive ALL tenant room updates');
      } catch (e) {
        print('⚠️ SignalR supervisor subscription failed: $e');
        print('⚠️ Will only receive agent-specific updates, not all room updates');
      }

      print('🎉 SignalR subscription complete - ready to receive real-time updates on home screen');

      // Verify subscription by checking listener status
      print('📊 Post-subscription listener status:');
      print('   - Message controller has listeners: ${_messageController.hasListener}');
      print('   - Room update controller has listeners: ${_roomUpdateController.hasListener}');

    } catch (e) {
      print('❌ Failed to subscribe SignalR user: $e');
      throw Exception('Failed to subscribe user: $e');
    }
  }

  static Future<void> joinConversation(String roomId, String? previousRoomId) async {
    if (_connection == null || _connection!.state != HubConnectionState.Connected) {
      print('❌ SignalR not connected, cannot join conversation');
      return;
    }
    
    try {
      // Leave previous room first if exists
      if (previousRoomId != null && previousRoomId.isNotEmpty) {
        await _connection!.invoke('LeaveConversation', args: [previousRoomId]);
        print('👋 Left previous conversation: $previousRoomId');
      }
      
      // Join new conversation
      await _connection!.invoke('JoinConversation', args: [roomId, previousRoomId ?? '']);
      print('👋 Joined conversation: $roomId');
      
    } catch (e) {
      print('❌ Failed to join conversation: $e');
      // Don't throw error - we can still receive messages via global subscription
    }
  }

  static Future<void> leaveConversation(String roomId) async {
    if (_connection == null || _connection!.state != HubConnectionState.Connected) {
      return;
    }
    
    try {
      await _connection!.invoke('LeaveConversation', args: [roomId]);
      print('👋 Left conversation: $roomId');
    } catch (e) {
      print('❌ Failed to leave conversation: $e');
      // Ignore error - not critical
    }
  }

  static Future<bool> sendMessage(Map<String, dynamic> messageData) async {
    try {
      await ensureConnection();
      
      final cleanedData = _cleanMessageData(messageData);
      print('📤 Sending message via SignalR: ${jsonEncode(cleanedData)}');
      
      await _connection!.invoke('KirimPesan', args: [jsonEncode(cleanedData)]).timeout(
        const Duration(seconds: 10),
      );
      print('✅ Message sent successfully via SignalR');
      return true;
    } catch (e) {
      print('❌ Failed to send message via SignalR: $e');
      return false;
    }
  }

  static Map<String, dynamic> _cleanMessageData(Map<String, dynamic> data) {
    if (data.containsKey('Room') && data.containsKey('Msg')) {
      // CRITICAL FIX: Enhanced ReplyId validation for SignalR (reply only works via WebSocket)
      final cleanedData = Map<String, dynamic>.from(data);
      
      if (cleanedData['Msg'] != null && cleanedData['Msg']['ReplyId'] != null) {
        final replyId = cleanedData['Msg']['ReplyId'].toString().trim();
        
        if (replyId.isNotEmpty && !replyId.startsWith('temp_')) {
          // Validate ReplyId format - must be numeric and positive
          final numericReplyId = int.tryParse(replyId);
          if (numericReplyId != null && numericReplyId > 0) {
            // CRITICAL FIX: Keep ReplyId as string format for SignalR (reply feature only works here)
            cleanedData['Msg']['ReplyId'] = numericReplyId.toString();
            print('✅ SignalR: Using validated ReplyId (reply only works via WebSocket): $replyId');
          } else {
            cleanedData['Msg'].remove('ReplyId');
            print('⚠️ SignalR: Removed invalid ReplyId format: $replyId (not positive numeric)');
          }
        } else {
          cleanedData['Msg'].remove('ReplyId');
          print('⚠️ SignalR: Removed empty or temporary ReplyId: $replyId');
        }
      }
      
      return cleanedData;
    }
    
    return {
      'Room': {
        'IdLink': data['IdLink']?.toString() ?? data['LinkId']?.toString(),
        'IdGroup': data['IdGroup']?.toString() ?? data['GroupId']?.toString(),
        'IdAccount': int.tryParse(data['IdAccount']?.toString() ?? '1') ?? 1,
        'IdRoom': data['IdRoom']?.toString() ?? data['RoomId']?.toString(),
      },
      'Msg': {
        'Type': data['Type']?.toString() ?? '1',
        'Msg': data['Msg']?.toString() ?? '',
        'File': data['File']?.toString() ?? '',
        'Files': data['Files']?.toString() ?? '',
        // CRITICAL FIX: Enhanced ReplyId handling for SignalR (only method that supports reply)
        if (data['ReplyId'] != null) ...() {
          final replyId = data['ReplyId'].toString().trim();
          if (replyId.isNotEmpty && !replyId.startsWith('temp_')) {
            final numericReplyId = int.tryParse(replyId);
            if (numericReplyId != null && numericReplyId > 0) {
              // CRITICAL FIX: SignalR expects ReplyId as string (only method supporting reply)
              return {'ReplyId': numericReplyId.toString()};
            } else {
              print('⚠️ SignalR: Invalid ReplyId format, skipping: $replyId (not positive numeric)');
            }
          } else {
            print('⚠️ SignalR: Empty or temporary ReplyId, skipping: $replyId');
          }
          return <String, dynamic>{};
        }(),
      },
    };
  }

  static void _scheduleReconnect() {
    if (_isReconnecting || _reconnectAttempts >= _maxReconnectAttempts) {
      return;
    }
    
    _isReconnecting = true;
    _reconnectAttempts++;
    
    final delay = Duration(seconds: _reconnectAttempts * 2); // Exponential backoff
    print('🔄 Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      try {
        if (_connection != null && _connection!.state != HubConnectionState.Connected) {
          print('🔄 Attempting to reconnect SignalR... (attempt $_reconnectAttempts)');
          await _connection!.start();
          
          try {
            await _subscribeUser();
            _connectionStatusController.add('connected');
            _isFullyInitialized = true;
            _reconnectAttempts = 0;
            _isReconnecting = false;
            _startHeartbeat();
            print('✅ SignalR reconnected and subscribed successfully');
          } catch (subscribeError) {
            print('❌ Reconnection failed during subscription: $subscribeError');
            _connectionStatusController.add('connecting');
            _isReconnecting = false;
            if (_reconnectAttempts < _maxReconnectAttempts) {
              _scheduleReconnect();
            }
          }
        }
      } catch (e) {
        print('❌ Reconnection attempt $_reconnectAttempts failed: $e');
        _connectionStatusController.add('connecting');
        _isReconnecting = false;
        
        if (_reconnectAttempts < _maxReconnectAttempts) {
          _scheduleReconnect();
        } else {
          print('❌ Max reconnection attempts reached. Stopping reconnection.');
        }
      }
    });
  }

  static Future<void> ensureConnection() async {
    if (_connection?.state == HubConnectionState.Connected && _isFullyInitialized) {
      print('✅ SignalR already connected and fully initialized');

      // CRITICAL FIX: Verify subscription is actually working by checking if we have listeners
      if (_messageController.hasListener && _roomUpdateController.hasListener) {
        print('✅ SignalR listeners are active');
        return; // Already connected and working
      } else {
        print('⚠️ SignalR connected but listeners inactive, re-subscribing...');
        try {
          await _subscribeUser();
          print('✅ Re-subscription successful');
          return;
        } catch (e) {
          print('❌ Re-subscription failed: $e, will reinitialize');
        }
      }
    }

    print('🔄 Ensuring SignalR connection...');
    _connectionStatusController.add('connecting');

    if (_isReconnecting) {
      print('⏳ Waiting for ongoing reconnection...');
      // Wait for ongoing reconnection
      int waitCount = 0;
      while (_isReconnecting && waitCount < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        waitCount++;
      }
      if (_connection?.state == HubConnectionState.Connected && _isFullyInitialized) {
        print('✅ Reconnection completed successfully');
        return;
      }
    }

    // Try to reconnect
    try {
      if (_connection == null) {
        print('🔄 No existing connection, initializing new one...');
        await init();
      } else {
        print('🔄 Restarting existing connection...');
        await _connection!.start()!.timeout(const Duration(seconds: 10));
        await _subscribeUser();
        _connectionStatusController.add('connected');
        _isFullyInitialized = true;
        _startHeartbeat();
        print('✅ SignalR connection restarted and subscribed successfully');
      }
    } catch (e) {
      print('❌ Failed to ensure SignalR connection: $e');
      throw Exception('SignalR connection failed: $e');
    }
  }

  /// Force re-subscribe to SignalR to ensure listeners are active
  /// This fixes the bug where realtime updates only work after entering chat screen
  static Future<void> forceResubscribe() async {
    print('🔄 Force re-subscribe called...');
    print('🔄   Connection state: ${_connection?.state}');
    print('🔄   Is fully initialized: $_isFullyInitialized');

    if (_connection?.state != HubConnectionState.Connected) {
      print('⚠️ Cannot force re-subscribe: SignalR not connected');
      await ensureConnection();

      // Check again after ensuring connection
      if (_connection?.state != HubConnectionState.Connected) {
        print('❌ Still not connected after ensureConnection');
        return;
      }
    }

    print('🔄 Force re-subscribing to activate realtime listeners on home screen...');
    print('🔄 Checking listeners BEFORE re-subscribe:');
    print('🔄   - Message listener has ${_messageController.hasListener ? "subscribers" : "NO subscribers"}');
    print('🔄   - Room update listener has ${_roomUpdateController.hasListener ? "subscribers" : "NO subscribers"}');

    try {
      await _subscribeUser();

      // Wait a bit for subscriptions to propagate
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify listeners are now active
      final hasListeners = _messageController.hasListener && _roomUpdateController.hasListener;

      print('🔄 Checking listeners AFTER re-subscribe:');
      print('🔄   - Message listener has ${_messageController.hasListener ? "subscribers" : "NO subscribers"}');
      print('🔄   - Room update listener has ${_roomUpdateController.hasListener ? "subscribers" : "NO subscribers"}');

      if (hasListeners) {
        print('✅ Force re-subscribe successful - listeners are now ACTIVE');
      } else {
        print('⚠️ Force re-subscribe completed but listeners still inactive');
        print('⚠️ This is expected if no widgets are currently listening to the streams');
      }

    } catch (e) {
      print('❌ Force re-subscribe failed: $e');
      throw Exception('Failed to force re-subscribe: $e');
    }
  }

  static void dispose() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscriptionTimer?.cancel();
    
    _isFullyInitialized = false;
    
    _connection?.stop();
    _connection = null;
    
    _roomUpdateController.close();
    _messageController.close();
    _ackController.close();
    _connectionStatusController.close();
  }

  static bool get isConnected => _connection?.state == HubConnectionState.Connected && _isFullyInitialized;
}