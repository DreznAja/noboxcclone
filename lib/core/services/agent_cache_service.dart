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
      
      _agentCache.clear();
      
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
      
      // ✅ DEBUG: Print cache contents
      printCacheContents();
      
    } else {
      print('❌ [Agent Cache] API Error: ${response.data}');
    }
  } catch (e) {
    print('❌ [Agent Cache] Error fetching agents: $e');
  }
}

    /// Debug method - print semua agents di cache
void printCacheContents() {
  print('📋 [Agent Cache] Cache contents:');
  print('   Total agents: ${_agentCache.length}');
  
  if (_agentCache.isEmpty) {
    print('   ⚠️ CACHE KOSONG!');
  } else {
    _agentCache.forEach((id, name) {
      print('   [$id] → "$name"');
    });
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
/// Get agent name synchronously (from cache only, no API call)
String? getAgentNameSync(String? agentId) {
  if (agentId == null || agentId.isEmpty) {
    print('⚠️ [Agent Cache] Null or empty agentId provided');
    return null;
  }
  
  // Coba exact match dulu
  String? name = _agentCache[agentId];
  
  // Jika tidak ketemu, coba parse sebagai int dan cari lagi
  if (name == null) {
    final parsedId = int.tryParse(agentId);
    if (parsedId != null) {
      name = _agentCache[parsedId.toString()];
    }
  }
  
  print('🔍 [Agent Cache] Looking up agentId: $agentId → name: $name');
  print('   Cache size: ${_agentCache.length}');
  
  if (name == null) {
    print('   ⚠️ Agent not found in cache!');
    print('   Available IDs: ${_agentCache.keys.take(10).toList()}');
  }
  
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
