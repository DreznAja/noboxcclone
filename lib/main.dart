import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nobox_chat/core/background/signalr_background_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';


import 'core/services/background_service_manager.dart';
import 'core/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/services/storage_service.dart';
import 'core/services/api_service.dart';
import 'core/services/account_service.dart';
import 'core/services/push_notification_service.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/chat/chat_screen.dart';
import 'core/providers/auth_provider.dart';
import 'core/models/chat_models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  DartPluginRegistrant.ensureInitialized();
  PluginUtilities.getCallbackHandle(signalrBackgroundEntry);

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Indonesian locale for date formatting
  await initializeDateFormatting('id_ID', null);

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize services
  await StorageService.init();
  await ApiService.init();

  // Initialize AccountService (singleton pattern, no async init needed)
  AccountService();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Optimize keyboard performance
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  runApp(const ProviderScope(child: NoboxChatApp()));
}

class NoboxChatApp extends ConsumerStatefulWidget {
  const NoboxChatApp({super.key});

  @override
  ConsumerState<NoboxChatApp> createState() => _NoboxChatAppState();
}

class _NoboxChatAppState extends ConsumerState<NoboxChatApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupNotificationHandler();
  }

  void _setupNotificationHandler() {
    PushNotificationService.initialize(
      onNotificationTap: (roomId, roomName) {
        print('📱 Notification tapped globally: $roomId');
        _navigateToRoom(roomId, roomName);
      },
    );
  }

  Future<void> _navigateToRoom(String roomId, String roomName) async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      print('⚠️ Navigator context not available');
      return;
    }

    // Navigate ke HomeScreen dulu
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );

    // Delay sebentar lalu fetch data room yang lengkap dan push ke ChatScreen
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (navigatorKey.currentContext == null) return;
      
      try {
        print('🔍 Fetching complete room data for roomId: $roomId');
        
        // Fetch data room yang lengkap dari API
        final response = await ApiService.dio.post(
          'Services/Chat/Chatrooms/DetailRoom',
          data: {
            'EntityId': roomId,
          },
        );
        
        if (response.statusCode == 200 && response.data['IsError'] != true && response.data['Data'] != null) {
          final roomData = response.data['Data']['Room'];
          final room = Room.fromJson(roomData);
          
          print('✅ Got complete room data: ${room.name}');
          
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(room: room),
            ),
          );
        } else {
          // Fallback: gunakan data minimal dari notifikasi jika API gagal
          print('⚠️ Failed to fetch room data, using notification data');
          final room = Room(
            id: roomId,
            name: roomName,
            status: 1,
            channelId: 1,
            channelName: 'Chat',
          );
          
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(room: room),
            ),
          );
        }
      } catch (e) {
        // Fallback: gunakan data minimal dari notifikasi jika terjadi error
        print('❌ Error fetching room data: $e');
        final room = Room(
          id: roomId,
          name: roomName,
          status: 1,
          channelId: 1,
          channelName: 'Chat',
        );
        
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(room: room),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Nobox Chat',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
      builder: (context, child) {
        // Optimize keyboard dismiss behavior
        return GestureDetector(
          onTap: () {
            // Dismiss keyboard when tapping outside TextField
            FocusScope.of(context).unfocus();
          },
          child: child,
        );
      },
    );
  }
}