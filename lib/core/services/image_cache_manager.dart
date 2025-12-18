// File baru: core/services/image_cache_manager.dart

class ImageCacheManager {
  static final ImageCacheManager _instance = ImageCacheManager._internal();
  factory ImageCacheManager() => _instance;
  ImageCacheManager._internal();

  // Cache storage: URL -> {timestamp, cacheKey}
  final Map<String, CachedImageData> _cache = {};
  
  // Cache duration: 5 minutes
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Check if cache is still valid (less than 5 minutes old)
  bool isCacheValid(String url) {
    final cached = _cache[url];
    if (cached == null) return false;
    
    final now = DateTime.now();
    final age = now.difference(cached.timestamp);
    
    return age < _cacheDuration;
  }

  /// Get cache key for URL (untuk force refresh di CachedNetworkImage)
  String getCacheKey(String url) {
    final cached = _cache[url];
    
    // Jika cache valid, return existing cache key
    if (cached != null && isCacheValid(url)) {
      return cached.cacheKey;
    }
    
    // Jika cache expired atau tidak ada, buat cache key baru
    final newCacheKey = '${url}_${DateTime.now().millisecondsSinceEpoch}';
    _cache[url] = CachedImageData(
      timestamp: DateTime.now(),
      cacheKey: newCacheKey,
    );
    
    return newCacheKey;
  }

  /// Force refresh cache for specific URL
  void refreshCache(String url) {
    _cache.remove(url);
  }

  /// Clear all cache
  void clearAll() {
    _cache.clear();
  }

  /// Clean up expired cache entries
  void cleanupExpired() {
    final now = DateTime.now();
    _cache.removeWhere((url, data) {
      final age = now.difference(data.timestamp);
      return age >= _cacheDuration;
    });
  }
}

class CachedImageData {
  final DateTime timestamp;
  final String cacheKey;

  CachedImageData({
    required this.timestamp,
    required this.cacheKey,
  });
}