import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag_models.dart';
import '../services/tag_service.dart';

class TagNotifier extends StateNotifier<TagState> {
  TagNotifier() : super(TagState());

  final TagService _service = TagService();

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

  Future<void> loadRoomTags(String roomId) async {
    state = state.copyWith(isLoadingRoomTags: true, error: null);

    try {
      print('🏷️ Loading room tags for room: $roomId');
      final tags = await _service.getRoomTags(roomId);
      print('🏷️ Loaded ${tags.length} tags for room $roomId: ${tags.map((t) => t.name).join(", ")}');
      
      state = state.copyWith(
        roomTags: tags,
        isLoadingRoomTags: false,
      );
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
        // Reload room tags to get updated data
        await loadRoomTags(roomId);
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
        // Reload room tags to get updated data
        await loadRoomTags(roomId);
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
        // Reload room tags to get updated data
        await loadRoomTags(roomId);
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