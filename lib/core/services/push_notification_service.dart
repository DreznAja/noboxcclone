import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/chat_models.dart';
import 'storage_service.dart';
import 'api_service.dart';

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 Background message received: ${message.messageId}');
  print('📨 Data: ${message.data}');

  // Background messages are automatically displayed by FCM
  // The native Android service (MyFirebaseMessagingService) handles the notification display
}

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static const MethodChannel _notificationChannel =
      MethodChannel('com.example.nbx0/notification');
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static Function(String roomId, String roomName)? _onNotificationTap;
  static bool _isInitialized = false;
  static String? _currentRoomId;

  static Future<void> initialize({
    Function(String roomId, String roomName)? onNotificationTap,
  }) async {
    if (_isInitialized) return;

    _onNotificationTap = onNotificationTap;

    try {
      // Setup method channel for notification taps from Android
      _notificationChannel.setMethodCallHandler((call) async {
        if (call.method == 'openChat') {
          final roomId = call.arguments['roomId'] as String?;
          final roomName = call.arguments['roomName'] as String?;
          if (roomId != null && roomName != null) {
            print('📱 Opening chat from notification: $roomId');
            _onNotificationTap?.call(roomId, roomName);
          }
        }
      });

      // Set background message handler FIRST before any other Firebase operations
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Initialize Firebase messaging
      await _initializeFirebaseMessaging();

      _isInitialized = true;
      print('✅ Push notification service initialized');
    } catch (e) {
      print('❌ Failed to initialize push notifications: $e');
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@drawable/nobox2');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'chat_notifications',
      'Chat Notifications',
      description: 'Notifications for new chat messages',
      importance: Importance.high,
      enableVibration: true,
      enableLights: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  static Future<void> _initializeFirebaseMessaging() async {
    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Push notification permission granted');

      // Get and save FCM token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('📱 FCM Token: ${token.substring(0, 20)}...');
        await _saveTokenToStorage(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((token) {
        print('📱 FCM Token refreshed');
        _saveTokenToStorage(token);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Handle app launch from notification
      RemoteMessage? initialMessage =
          await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print('📱 App launched from notification');
        _handleNotificationTap(initialMessage);
      }
    } else {
      print('❌ Push notification permission denied');
    }
  }

  static Future<void> _saveTokenToStorage(String token) async {
    await StorageService.saveSetting('fcm_token', token);
    // TODO: Send token to backend server for user registration
    print('💾 FCM Token saved to storage');
  }

  static String? getFCMToken() {
    return StorageService.getSetting<String>('fcm_token');
  }

  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final roomId = data['roomId'] as String?;
        final roomName = data['roomName'] as String?;

        if (roomId != null && roomName != null) {
          print('📱 Local notification tapped: $roomId');
          _onNotificationTap?.call(roomId, roomName);
        }
      } catch (e) {
        print('❌ Error parsing notification payload: $e');
      }
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📨 Foreground FCM message: ${message.messageId}');

    // Extract message data
    final data = message.data;
    final roomId = data['roomId'];
    final roomName = data['roomName'] ?? 'Chat';
    final senderName = data['senderName'] ?? 'Someone';
    final messageText = data['message'] ?? 'New message';

    // Debug: Log current room state
    print('🔍 Notification check - Current room: $_currentRoomId, Message room: $roomId');
    
    // Don't show notification if user is currently in this room
    if (_currentRoomId != null && _currentRoomId == roomId) {
      print('🚫 User in current room - skipping notification');
      return;
    }
    
    print('✅ User NOT in this room - showing notification');

    // Show local notification when app is in foreground
    if (roomId != null) {
      // Try to get actual contact name from room detail
      String actualSenderName = senderName;
      try {
        final roomDetail = await _getRoomDetailForNotification(roomId);
        if (roomDetail != null) {
          actualSenderName = roomDetail;
          print('✅ Got actual contact name: $actualSenderName');
        }
      } catch (e) {
        print('⚠️ Could not fetch room detail, using fallback name: $senderName');
      }
      
      await showChatNotification(
        roomId: roomId,
        roomName: roomName,
        senderName: actualSenderName,
        message: messageText,
      );
    }
  }

  static void _handleNotificationTap(RemoteMessage message) {
    print('📱 FCM notification tapped: ${message.messageId}');

    final data = message.data;
    final roomId = data['roomId'];
    final roomName = data['roomName'] ?? 'Chat';

    if (roomId != null) {
      _onNotificationTap?.call(roomId, roomName);
    }
  }

  // Helper function to get actual contact name from room detail
  static Future<String?> _getRoomDetailForNotification(String roomId) async {
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
      print('❌ Error fetching room detail for notification: $e');
    }
    return null;
  }

  // Store notification messages per room for grouping
  static final Map<String, List<Map<String, String>>> _notificationMessages = {};

  // Show notification for new chat messages
  static Future<void> showChatNotification({
    required String roomId,
    required String roomName,
    required String senderName,
    required String message,
  }) async {
    try {
      // Add message to the list for this room
      if (!_notificationMessages.containsKey(roomId)) {
        _notificationMessages[roomId] = [];
      }
      _notificationMessages[roomId]!.add({
        'sender': senderName,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      // Keep only last 10 messages per room
      if (_notificationMessages[roomId]!.length > 10) {
        _notificationMessages[roomId]!.removeAt(0);
      }

      // Build messaging style with all messages
      final messages = _notificationMessages[roomId]!;
      final messagingStyle = MessagingStyleInformation(
        Person(name: 'Me', key: 'me'),
        conversationTitle: senderName,
        groupConversation: false,
        messages: messages.map((msg) {
          return Message(
            msg['message']!,
            DateTime.fromMillisecondsSinceEpoch(int.parse(msg['timestamp']!)),
            Person(name: msg['sender']!, key: msg['sender']!),
          );
        }).toList(),
      );

      final androidDetails = AndroidNotificationDetails(
        'chat_notifications',
        'Chat Notifications',
        channelDescription: 'Notifications for new chat messages',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        enableLights: true,
        color: const Color(0xFF3B82F6),
        icon: '@drawable/nobox2',
        styleInformation: messagingStyle,
        groupKey: 'chat_$roomId', // Group by room/contact
        setAsGroupSummary: false,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = jsonEncode({
        'roomId': roomId,
        'roomName': roomName,
      });

      await _localNotifications.show(
        roomId.hashCode, // Use room ID hash as notification ID - same ID updates existing
        senderName,
        message,
        details,
        payload: payload,
      );

      print('📱 Chat notification shown for room: $roomId (${messages.length} messages)');
    } catch (e) {
      print('❌ Error showing chat notification: $e');
    }
  }

  // Cancel notifications for a specific room
  static Future<void> cancelNotificationsForRoom(String roomId) async {
    await _localNotifications.cancel(roomId.hashCode);
    // Clear message history for this room
    _notificationMessages.remove(roomId);
    print('📱 Notifications cleared for room: $roomId');
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
    // Clear all message history
    _notificationMessages.clear();
    print('📱 All notifications cleared');
  }

  // Subscribe to topic (for broadcast notifications)
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('📡 Subscribed to topic: $topic');
    } catch (e) {
      print('❌ Failed to subscribe to topic $topic: $e');
    }
  }

  // Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('📡 Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ Failed to unsubscribe from topic $topic: $e');
    }
  }

  // Set current room (to prevent notifications for current chat)
  static void setCurrentRoom(String? roomId) {
    _currentRoomId = roomId;
    print('📍 Current room set: $roomId');
  }

  // Clear current room when leaving chat
  static void clearCurrentRoom() {
    _currentRoomId = null;
    print('📍 Current room cleared');
  }
  
  // Get current room ID (for checking if user is in a specific room)
  static String? getCurrentRoomId() {
    return _currentRoomId;
  }

  // Handle notification from SignalR messages
  static Future<void> handleSignalRMessage(
      ChatMessage message, Room room) async {
    // Only show notification if app is in background or message is not from current user
    final userData = StorageService.getUserData();
    final currentUserId = userData?['UserId']?.toString();

    // Don't show notification for own messages
    if (message.agentId.toString() == currentUserId) {
      print('🚫 Own message - skipping notification');
      return;
    }

    // Debug: Log current room state
    print('🔍 SignalR notification check - Current room: $_currentRoomId, Message room: ${room.id}');
    
    // Don't show notification if user is currently in this room
    if (_currentRoomId != null && _currentRoomId == room.id) {
      print('🚫 User in current room - skipping SignalR notification');
      return;
    }
    
    print('✅ User NOT in this room - showing SignalR notification');

    // Show notification
    await showChatNotification(
      roomId: room.id,
      roomName: room.name,
      senderName: room.name,
      message: _getNotificationMessage(message),
    );
  }

  static String _getNotificationMessage(ChatMessage message) {
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

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
