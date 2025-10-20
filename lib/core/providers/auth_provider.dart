import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/signalr_service.dart';
import '../services/account_service.dart';
import '../services/agent_cache_service.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserData? userData;
  final String? error;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.userData,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserData? userData,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userData: userData ?? this.userData,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    _checkAuthStatus();
  }

void _checkAuthStatus() async {
  final token = StorageService.getToken();
  final userData = StorageService.getUserData();

  if (token != null && userData != null) {
    state = state.copyWith(
      isAuthenticated: true,
      userData: UserData.fromJson(userData),
    );
  } else {
    // 🚀 Kalau token kosong tapi ada username/password tersimpan → auto login
    final savedUsername = StorageService.getSetting<String>('last_username');
    final savedPassword = StorageService.getSetting<String>('last_password');

    if (savedUsername != null && savedPassword != null) {
      print('🔁 Attempting silent login...');
      await login(savedUsername, savedPassword);
    }
  }
}


  Future<bool> login(String username, String password, {bool saveCredentials = true}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      print('Sending login request for username: $username');
      
      final loginRequest = LoginRequest(username: username, password: password);
      final response = await ApiService.login(loginRequest);

      if (response.isError || response.data == null) {
        print('Login API error: ${response.error}');
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Login failed',
        );
        return false;
      }

      print('Login successful, token received');
      
      // Save token
      await StorageService.saveToken(response.data!);
      
      // Save credentials for auto re-login
      if (saveCredentials) {
        print('💾 Saving credentials for auto re-login');
        await StorageService.saveCredentials(username, password);
      }
      
      // Create user data with proper structure
      final userData = UserData(
        userId: 1,
        displayName: username,
        tenantId: 1,
        channels: [],
      );

      // Save user data with account mapping structure
      final userDataMap = {
        'UserId': userData.userId,
        'DisplayName': userData.displayName,
        'TenantId': userData.tenantId,
        'Channels': [],
        'CurrentUserId': userData.userId.toString(),
      };
      
      await StorageService.saveUserData(userDataMap);
      
      // Initialize account mappings using the new service
      try {
        print('🔄 Initializing account mappings...');
        await AccountService().initializeAccountMappings();
        print('✅ Account mappings initialized successfully');
      } catch (e) {
        print('❌ Failed to initialize account mappings: $e');
        // Continue with login even if account mapping fails
      }
      
      // Initialize SignalR AFTER user data is saved
      try {
        print('🔌 Initializing SignalR after login...');
        await SignalRService.init();
        print('✅ SignalR initialized successfully during login');
      } catch (e) {
        print('❌ SignalR initialization failed during login: $e');
        // Continue with login, SignalR will retry connection automatically
      }
      
      // Initialize Agent Cache Service for system message formatting
      try {
        print('👥 Initializing Agent Cache Service...');
        await AgentCacheService().initialize();
        print('✅ Agent Cache Service initialized successfully');
      } catch (e) {
        print('❌ Agent Cache Service initialization failed: $e');
        // Continue with login, agent names will show as 'Agent' in system messages
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        userData: userData,
      );

      return true;
    } catch (e) {
      print('Exception in login: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      // Disconnect SignalR
      SignalRService.dispose();
      
      // Clear Agent Cache
      AgentCacheService().clearCache();
      
      // Clear storage including credentials
      await StorageService.removeToken();
      await StorageService.removeUserData();
      await StorageService.removeCredentials();

      state = AuthState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> tryAutoReLogin() async {
    print('🔄 Attempting auto re-login...');
    
    final credentials = StorageService.getSavedCredentials();
    if (credentials == null) {
      print('❌ No saved credentials found');
      return false;
    }

    print('✅ Found saved credentials, attempting re-login...');
    
    // Login without saving credentials again (already saved)
    final success = await login(
      credentials['username']!,
      credentials['password']!,
      saveCredentials: false,
    );

    if (success) {
      print('✅ Auto re-login successful');
    } else {
      print('❌ Auto re-login failed');
    }

    return success;
  }

  void invalidateSession() {
    print('🔴 Session invalidated - clearing auth state');
    
    try {
      SignalRService.dispose();
      AgentCacheService().clearCache();
    } catch (e) {
      print('⚠️ Error cleaning up services: $e');
    }
    
    state = AuthState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});