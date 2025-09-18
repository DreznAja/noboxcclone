import 'dart:async';
import 'dart:convert';
import 'package:signalr_netcore/signalr_client.dart';
import '../app_config.dart';
import '../models/chat_models.dart';
import 'storage_service.dart';

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
          print('📨 SignalR TerimaPesan: ${message.id} for room ${message.roomId}');
          _messageController.add(message);
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
          print('📨 SignalR TerimaSubSpv: ${room.id} - ${room.name}');
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
          print('📨 SignalR TerimaSubAgent: ${room.id} - ${room.name}');
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
          print('📨 SignalR TerimaRoomBaru: ${room.id} - ${room.name}');
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
      
      // Use only the subscription methods that definitely exist
      await _connection!.invoke('SubscribeUserAgent', args: [userId, tenantId]);
      print('✅ SignalR subscribed as agent successfully');
      
      // Try supervisor subscription as fallback (optional)
      try {
        await _connection!.invoke('SubscribeUserSpv', args: [tenantId]);
        print('✅ SignalR also subscribed as supervisor');
      } catch (e) {
        // This is optional, so ignore errors
        print('ℹ️ SignalR supervisor subscription not available (this is normal)');
      }
      
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
      return Map<String, dynamic>.from(data);
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
        if (data['ReplyId'] != null) 'ReplyId': data['ReplyId'].toString(),
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
      print('✅ SignalR already connected and initialized');
      return; // Already connected
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
        print('✅ SignalR connection restarted successfully');
      }
    } catch (e) {
      print('❌ Failed to ensure SignalR connection: $e');
      throw Exception('SignalR connection failed: $e');
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