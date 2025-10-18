import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeState {
  final ThemeMode themeMode;
  
  ThemeState({required this.themeMode});
  
  bool get isDarkMode => themeMode == ThemeMode.dark;
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(ThemeState(themeMode: ThemeMode.light)) {
    _loadThemeMode();
  }
  
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('isDarkMode') ?? false;
      state = ThemeState(themeMode: isDark ? ThemeMode.dark : ThemeMode.light);
    } catch (e) {
      print('Error loading theme mode: $e');
    }
  }
  
  Future<void> toggleTheme() async {
    try {
      final newMode = state.isDarkMode ? ThemeMode.light : ThemeMode.dark;
      state = ThemeState(themeMode: newMode);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', newMode == ThemeMode.dark);
    } catch (e) {
      print('Error saving theme mode: $e');
    }
  }
  
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      state = ThemeState(themeMode: mode);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', mode == ThemeMode.dark);
    } catch (e) {
      print('Error saving theme mode: $e');
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});