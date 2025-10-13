import 'dart:io';
import 'package:flutter/services.dart';

class BackgroundServiceManager {
  static const MethodChannel _platform = MethodChannel('com.example.nbx0/background_service');
  
  /// Start background service to keep SignalR connection alive
  static Future<void> startBackgroundService() async {
    if (!Platform.isAndroid) {
      print('⚠️ Background service only supported on Android');
      return;
    }
    
    try {
      await _platform.invokeMethod('startBackgroundService');
      print('✅ Background service started successfully');
    } catch (e) {
      print('❌ Failed to start background service: $e');
    }
  }
  
  /// Stop background service
  static Future<void> stopBackgroundService() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _platform.invokeMethod('stopBackgroundService');
      print('✅ Background service stopped successfully');
    } catch (e) {
      print('❌ Failed to stop background service: $e');
    }
  }
  
  /// Request battery optimization exemption
  static Future<bool> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final result = await _platform.invokeMethod<bool>('requestBatteryOptimization');
      return result ?? false;
    } catch (e) {
      print('❌ Failed to request battery optimization: $e');
      return false;
    }
  }
  
  /// Check if battery optimization is disabled
  static Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final result = await _platform.invokeMethod<bool>('isBatteryOptimizationDisabled');
      return result ?? false;
    } catch (e) {
      print('❌ Failed to check battery optimization: $e');
      return false;
    }
  }
}