import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag_models.dart';
import '../services/tag_service.dart';

// Cache management untuk room tags
class RoomTagsCache {
  final List<MessageTag> tags;
  final DateTime timestamp;

  RoomTagsCache({
    required this.tags,
    required this.timestamp,
  });

  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inMinutes >= 5; // Cache expires after 5 minutes
  }
}

class TagNotifier extends StateNotifier<TagState> {
  TagNotifier() : super(TagState());

  final TagService _service = TagService();
  
  // ✅ TAMBAHAN: Cache untuk room tags
  final Map<String, RoomTagsCache> _roomTagsCache = {};

  // ✅ TAMBAHAN: Clear cache untuk room tertentu
  void clearRoomCache(String roomId) {
    _roomTagsCache.remove(roomId);
    print('🗑️ Room tags cache cleared for room: $roomId');
  }

  // ✅ TAMBAHAN: Clear expired caches
  void clearExpiredCaches() {
    final now = DateTime.now();
    _roomTagsCache.removeWhere((key, cache) {
      if (cache.isExpired) {
        print('🗑️ Expired room tags cache removed for room: $key');
        return true;
      }
      return false;
    });
  }

  Future<bool> createTag(String tagName) async {
    try {
      final tagId = await _service.createTag(tagName);
      if (tagId != null) {
        // Reload available tags to include the newly created tag
        await loadAvailableTags();
        return true;
      } else {
        state = state.copyWith(error: 'Failed to create tag');
        return false;
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to create tag: $e');
      return false;
    }
  }

  Future<void> loadAvailableTags() async {
    state = state.copyWith(isLoadingAvailable: true, error: null);

    try {
      final tags = await _service.getAvailableTags();
      state = state.copyWith(
        availableTags: tags,
        isLoadingAvailable: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingAvailable: false,
        error: 'Failed to load available tags: $e',
      );
    }
  }

  // ✅ PERBAIKAN: Tambah cache untuk room tags
  Future<void> loadRoomTags(String roomId, {bool forceRefresh = false}) async {
    // Clean up expired caches first
    clearExpiredCaches();

    // ✅ Check cache first (unless force refresh)
    if (!forceRefresh && _roomTagsCache.containsKey(roomId)) {
      final cachedData = _roomTagsCache[roomId]!;
      if (!cachedData.isExpired) {
        print('✅ Using cached room tags for room: $roomId');
        print('⏰ Cache age: ${DateTime.now().difference(cachedData.timestamp).inSeconds}s');
        state = state.copyWith(
          roomTags: cachedData.tags,
          isLoadingRoomTags: false,
        );
        return;
      } else {
        print('⏰ Cache expired for room: $roomId, fetching fresh data');
        _roomTagsCache.remove(roomId);
      }
    }

    // ✅ If no valid cache, fetch from API
    print('🌐 Fetching fresh room tags for room: $roomId');
    state = state.copyWith(isLoadingRoomTags: true, error: null);

    try {
      print('🏷️ Loading room tags for room: $roomId');
      final tags = await _service.getRoomTags(roomId);
      print('🏷️ Loaded ${tags.length} tags for room $roomId: ${tags.map((t) => t.name).join(", ")}');
      
      state = state.copyWith(
        roomTags: tags,
        isLoadingRoomTags: false,
      );

      // ✅ Store in cache
      _roomTagsCache[roomId] = RoomTagsCache(
        tags: tags,
        timestamp: DateTime.now(),
      );
      print('💾 Room tags cached for room: $roomId');
    } catch (e) {
      print('❌ Error loading room tags: $e');
      state = state.copyWith(
        isLoadingRoomTags: false,
        error: 'Failed to load room tags: $e',
      );
    }
  }

  Future<void> updateRoomTags(String roomId, List<String> tagIds) async {
    try {
      final success = await _service.updateRoomTags(roomId, tagIds);
      if (success) {
        // ✅ Clear cache untuk force refresh
        clearRoomCache(roomId);
        // Reload room tags to get updated data
        await loadRoomTags(roomId, forceRefresh: true);
      } else {
        state = state.copyWith(error: 'Failed to update room tags');
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to update room tags: $e');
    }
  }

  Future<void> addTagToRoom(String roomId, String tagId) async {
    try {
      final success = await _service.addTagToRoom(roomId, tagId);
      if (success) {
        // ✅ Clear cache untuk force refresh
        clearRoomCache(roomId);
        // Reload room tags to get updated data
        await loadRoomTags(roomId, forceRefresh: true);
      } else {
        state = state.copyWith(error: 'Failed to add tag to room');
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to add tag to room: $e');
    }
  }

  Future<void> removeTagFromRoom(String roomId, String tagId) async {
    try {
      final success = await _service.removeTagFromRoom(roomId, tagId);
      if (success) {
        // ✅ Clear cache untuk force refresh
        clearRoomCache(roomId);
        // Reload room tags to get updated data
        await loadRoomTags(roomId, forceRefresh: true);
      } else {
        state = state.copyWith(error: 'Failed to remove tag from room');
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to remove tag from room: $e');
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final tagProvider = StateNotifierProvider<TagNotifier, TagState>((ref) {
  return TagNotifier();
});