import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../app_config.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get instance {
    assert(_prefs != null, 'StorageService not initialized');
    return _prefs!;
  }

  // Last username management (for UI convenience)
static Future<void> saveLastUsername(String username) async {
  await instance.setString('last_logged_username', username);
}

static String? getLastUsername() {
  return instance.getString('last_logged_username');
}

static Future<void> removeLastUsername() async {
  await instance.remove('last_logged_username');
}

  // Token management
  static Future<void> saveToken(String token) async {
    await instance.setString(AppConfig.tokenKey, token);
  }

  static String? getToken() {
    return instance.getString(AppConfig.tokenKey);
  }

  static Future<void> removeToken() async {
    await instance.remove(AppConfig.tokenKey);
  }

  static bool hasToken() {
    return instance.containsKey(AppConfig.tokenKey);
  }

  // User data management
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    await instance.setString(AppConfig.userDataKey, jsonEncode(userData));
  }

  static Map<String, dynamic>? getUserData() {
    final userDataString = instance.getString(AppConfig.userDataKey);
    if (userDataString != null) {
      try {
        return jsonDecode(userDataString);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<void> removeUserData() async {
    await instance.remove(AppConfig.userDataKey);
  }

  // Credentials management for auto re-login
  static Future<void> saveCredentials(String username, String password) async {
    await instance.setString('saved_username', username);
    await instance.setString('saved_password', password);
  }

  static Map<String, String>? getSavedCredentials() {
    final username = instance.getString('saved_username');
    final password = instance.getString('saved_password');
    
    if (username != null && password != null) {
      return {
        'username': username,
        'password': password,
      };
    }
    return null;
  }

  static Future<void> removeCredentials() async {
    await instance.remove('saved_username');
    await instance.remove('saved_password');
  }

  static bool hasCredentials() {
    return instance.containsKey('saved_username') && 
           instance.containsKey('saved_password');
  }

  // Settings management
  static Future<void> saveSetting(String key, dynamic value) async {
    if (value is String) {
      await instance.setString(key, value);  
    } else if (value is int) {
      await instance.setInt(key, value);
    } else if (value is bool) {
      await instance.setBool(key, value);
    } else if (value is double) {
      await instance.setDouble(key, value);
    } else {
      await instance.setString(key, jsonEncode(value));
    }
  }

  static T? getSetting<T>(String key) {
    if (T == String) {
      return instance.getString(key) as T?;
    } else if (T == int) {
      return instance.getInt(key) as T?;
    } else if (T == bool) {
      return instance.getBool(key) as T?;
    } else if (T == double) {
      return instance.getDouble(key) as T?;
    } else {
      final value = instance.getString(key);
      if (value != null) {
        try {
          return jsonDecode(value) as T;
        } catch (e) {
          return null;
        }
      }
      return null;
    }
  }

  // Clear all data
  static Future<void> clearAll() async {
    await instance.clear();
  }
}