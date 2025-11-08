import 'package:dio/dio.dart';
import '../app_config.dart';
import 'storage_service.dart';

class AgentCacheService {
  static final AgentCacheService _instance = AgentCacheService._internal();
  factory AgentCacheService() => _instance;

  late Dio _dio;
  
  // Cache untuk agent data: agentId -> agent name
  static final Map<String, String> _agentCache = {};
  static DateTime? _lastFetchTime;
  static const Duration _cacheExpiry = Duration(hours: 1);

  AgentCacheService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptor for authentication
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = StorageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        print('Agent Cache API Error: ${error.message}');
        handler.next(error);
      },
    ));
  }

  /// Fetch agent list from API dan update cache
  Future<void> fetchAndCacheAgents() async {
    try {
      print('👥 [Agent Cache] Fetching agent list from API...');
      
      final requestData = {
        'IncludeColumns': ['Id', 'UserId', 'DisplayName', 'Username', 'Name'],
        'ColumnSelection': 1,
        'Take': 200,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/Administration/User/ListAgent',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        
        // Clear existing cache
        _agentCache.clear();
        
        // Populate cache dengan data agent
        for (var agent in entities) {
          final id = agent['Id']?.toString() ?? agent['UserId']?.toString();
          final name = agent['DisplayName']?.toString() ?? 
                       agent['Name']?.toString() ?? 
                       agent['Username']?.toString();
          
          if (id != null && name != null && name.isNotEmpty) {
            _agentCache[id] = name;
          }
        }
        
        _lastFetchTime = DateTime.now();
        print('✅ [Agent Cache] Cached ${_agentCache.length} agents');
        
      } else {
        print('❌ [Agent Cache] API Error: ${response.data}');
      }
    } catch (e) {
      print('❌ [Agent Cache] Error fetching agents: $e');
    }
  }

  /// Get agent name by ID
  Future<String?> getAgentName(String? agentId) async {
    if (agentId == null || agentId.isEmpty) return null;
    
    // Check if cache needs refresh
    if (_shouldRefreshCache()) {
      await fetchAndCacheAgents();
    }
    
    return _agentCache[agentId];
  }

  /// Check if cache should be refreshed
  bool _shouldRefreshCache() {
    if (_lastFetchTime == null) return true;
    if (_agentCache.isEmpty) return true;
    
    final now = DateTime.now();
    final timeSinceLastFetch = now.difference(_lastFetchTime!);
    
    return timeSinceLastFetch > _cacheExpiry;
  }

  /// Force refresh cache
  Future<void> refreshCache() async {
    await fetchAndCacheAgents();
  }

  /// Get agent name synchronously (from cache only, no API call)
  String? getAgentNameSync(String? agentId) {
    if (agentId == null || agentId.isEmpty) return null;
    final name = _agentCache[agentId];
    print('🔍 [Agent Cache] Looking up agentId: $agentId → name: $name');
    print('   Cache size: ${_agentCache.length}');
    print('   Cache keys: ${_agentCache.keys.toList()}');
    return name;
  }

  /// Initialize cache on app start
  Future<void> initialize() async {
    if (_agentCache.isEmpty) {
      await fetchAndCacheAgents();
    }
  }

  /// Clear cache
  void clearCache() {
    _agentCache.clear();
    _lastFetchTime = null;
    print('🗑️ [Agent Cache] Cache cleared');
  }
}
