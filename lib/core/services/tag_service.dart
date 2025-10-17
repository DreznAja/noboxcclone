import 'package:dio/dio.dart';
import '../app_config.dart';
import '../models/tag_models.dart';
import 'storage_service.dart';

class TagService {
  static final TagService _instance = TagService._internal();
  factory TagService() => _instance;

  late Dio _dio;

  TagService._internal() {
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
        print('Tag API Error: ${error.message}');
        handler.next(error);
      },
    ));
  }

  Future<String?> createTag(String tagName) async {
    try {
      print('🏷️ [Create Tag] Creating tag with name: $tagName');
      
      final requestData = {
        'Entity': {
          'Nm': tagName,
          'InBy': '',
          'UpBy': '',
        },
      };

      print('🏷️ [Create Tag] Request data: $requestData');
      print('🏷️ [Create Tag] Endpoint: Services/Chat/Chattags/Create');

      final response = await _dio.post(
        'Services/Chat/Chattags/Create',
        data: requestData,
      );

      print('🏷️ [Create Tag] Response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200) {
        // Check if there's an Error field that is not null
        final hasError = response.data['Error'] != null;
        if (!hasError) {
          // Get the EntityId from response
          final entityId = response.data['EntityId'];
          if (entityId != null) {
            print('✅ [Create Tag] Success - EntityId: $entityId');
            return entityId.toString();
          }
        }
      }

      print('❌ Create Tag API Error: ${response.data}');
      return null;
    } catch (e) {
      print('❌ Error creating tag: $e');
      
      // Try to extract error details from DioException
      if (e.toString().contains('DioException')) {
        try {
          final dioError = e as DioException;
          print('❌ Error type: ${dioError.type}');
          print('❌ Error message: ${dioError.message}');
          print('❌ Error response: ${dioError.response?.data}');
          print('❌ Status code: ${dioError.response?.statusCode}');
        } catch (_) {
          // Ignore if casting fails
        }
      }
      
      return null;
    }
  }

  Future<List<MessageTag>> getAvailableTags() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Nm', 'Name'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/Chat/Chattags/List',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        return entities.map((item) => MessageTag.fromJson(item)).toList();
      }

      print('Available Tags API Error: ${response.data}');
      return [];
    } catch (e) {
      print('Error fetching available tags: $e');
      return [];
    }
  }

  Future<List<MessageTag>> getRoomTags(String roomId) async {
    try {
      print('🏷️ Fetching room tags for room ID: $roomId');
      
      // First, get the room detail to get the tag information
      final roomDetailResponse = await _dio.post(
        'Services/Chat/Chatrooms/DetailRoom',
        data: {
          'EntityId': roomId,
        },
      );

      if (roomDetailResponse.statusCode == 200 && roomDetailResponse.data['IsError'] != true) {
        final roomData = roomDetailResponse.data['Data'];
        print('🏷️ Room detail response: $roomData');
        
        // Extract tags from room data
        List<MessageTag> roomTags = [];
        
        // Check if room has Tags data directly
        if (roomData['Tags'] != null && roomData['Tags'] is List) {
          final tagsList = roomData['Tags'] as List;
          roomTags = tagsList.map((tagData) => MessageTag.fromJson(tagData)).toList();
          print('🏷️ Found ${roomTags.length} tags from room Tags field');
        }
        // Check if room has TagsIds and Tags fields (comma-separated)
        else if (roomData['Room'] != null) {
          final room = roomData['Room'];
          final tagsIds = room['TagsIds'];
          final tagsNames = room['Tags']?.toString();
          
          print('🏷️ Room TagsIds: $tagsIds');
          print('🏷️ Room Tags: $tagsNames');
          
          if (tagsIds != null && tagsNames != null && tagsNames.isNotEmpty) {
            
            List<String> idList = [];
            
            // Handle TagsIds as either array or comma-separated string
            if (tagsIds is List) {
              idList = tagsIds.map((id) => id.toString().trim()).where((id) => id.isNotEmpty).toList();
            } else if (tagsIds is String && tagsIds.isNotEmpty) {
              idList = tagsIds.split(',').map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
            }
            
            final nameList = tagsNames.split(',').where((name) => name.trim().isNotEmpty).toList();
            
            print('🏷️ Parsed tag IDs: $idList');
            print('🏷️ Parsed tag names: $nameList');
            
            for (int i = 0; i < idList.length && i < nameList.length; i++) {
              roomTags.add(MessageTag(
                id: idList[i].trim(),
                name: nameList[i].trim(),
              ));
            }
            
            print('🏷️ Created ${roomTags.length} tags from TagsIds/Tags fields');
          }
        }
        
        return roomTags;
      } else {
        print('❌ Room detail API error: ${roomDetailResponse.data}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching room tags: $e');
      return [];
    }
  }

  Future<bool> updateRoomTags(String roomId, List<String> tagIds) async {
    try {
      print('🏷️ Updating room tags for room $roomId with tag IDs: $tagIds');
      
      // Convert string IDs to integers (backend expects List<Int64>)
      final intTagIds = tagIds.map((id) {
        final parsed = int.tryParse(id);
        if (parsed == null) {
          print('⚠️ Warning: Could not parse tag ID: $id');
        }
        return parsed;
      }).where((id) => id != null).cast<int>().toList();
      
      print('🏷️ Converted tag IDs to integers: $intTagIds');
      
      final requestData = {
        'EntityId': int.tryParse(roomId) ?? roomId, // Try to convert roomId to int too
        'Entity': {
          'TagsIds': intTagIds, // Send as array of integers
        },
      };

      print('🏷️ Request data: $requestData');

      final response = await _dio.post(
        'Services/Chat/Chatrooms/Update',
        data: requestData,
      );

      print('🏷️ Update response: ${response.data}');

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        print('✅ Room tags updated successfully');
        return true;
      }

      print('❌ Update room tags API error: ${response.data}');
      return false;
    } catch (e) {
      print('❌ Error updating room tags: $e');
      return false;
    }
  }

  Future<bool> addTagToRoom(String roomId, String tagId) async {
    try {
      // Get current tags first
      final currentTags = await getRoomTags(roomId);
      final currentTagIds = currentTags.map((tag) => tag.id).toList();
      
      // Add new tag if not already present
      if (!currentTagIds.contains(tagId)) {
        currentTagIds.add(tagId);
        return await updateRoomTags(roomId, currentTagIds);
      }
      
      return true; // Tag already exists
    } catch (e) {
      print('Error adding tag to room: $e');
      return false;
    }
  }

  Future<bool> removeTagFromRoom(String roomId, String tagId) async {
    try {
      // Get current tags first
      final currentTags = await getRoomTags(roomId);
      final currentTagIds = currentTags.map((tag) => tag.id).toList();
      
      // Remove tag if present
      currentTagIds.remove(tagId);
      return await updateRoomTags(roomId, currentTagIds);
    } catch (e) {
      print('Error removing tag from room: $e');
      return false;
    }
  }
}