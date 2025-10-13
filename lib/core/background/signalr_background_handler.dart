import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/signalr_service.dart';
import '../services/storage_service.dart';

// Background entry point - must be top-level function
@pragma('vm:entry-point')
void signalrBackgroundEntry() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize background handler
  SignalRBackgroundHandler.initialize();
}

class SignalRBackgroundHandler {
  static const MethodChannel _channel = MethodChannel('com.example.nbx0/signalr_background');
  static Timer? _connectionCheckTimer;
  
  static Future<void> initialize() async {
    try {
      print('🔄 SignalR Background Handler initializing...');
      
      // Initialize storage service
      await StorageService.init();
      
      // Check if user is authenticated
      final token = StorageService.getToken();
      if (token == null) {
        print('❌ No token available, stopping background service');
        return;
      }
      
      // Initialize SignalR connection
      await SignalRService.init();
      
      // Update notification
      await _updateNotificationStatus('Connected - Monitoring messages');
      
      // Start periodic connection check
      _startConnectionCheck();
      
      print('✅ SignalR Background Handler initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize SignalR Background Handler: $e');
      await _updateNotificationStatus('Connection error');
    }
  }
  
  static void _startConnectionCheck() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      try {
        if (!SignalRService.isConnected) {
          print('🔄 Background: SignalR disconnected, reconnecting...');
          await _updateNotificationStatus('Reconnecting...');
          await SignalRService.ensureConnection();
          await _updateNotificationStatus('Connected - Monitoring messages');
        } else {
          print('✅ Background: SignalR connection healthy');
        }
      } catch (e) {
        print('❌ Background: Connection check failed: $e');
        await _updateNotificationStatus('Connection issue - Retrying...');
      }
    });
  }
  
  static Future<void> _updateNotificationStatus(String status) async {
    try {
      await _channel.invokeMethod('updateNotification', {'status': status});
    } catch (e) {
      print('❌ Failed to update notification: $e');
    }
  }
  
  static void dispose() {
    _connectionCheckTimer?.cancel();
    SignalRService.dispose();
  }
}