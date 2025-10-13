import 'dart:convert';
import 'package:dio/dio.dart';
import '../app_config.dart';
import '../models/auth_models.dart';
import '../models/chat_models.dart';
import '../models/quick_reply_models.dart';
import 'storage_service.dart';

class ApiResponse<T> {
  final bool isError;
  final T? data;
  final String? error;
  final int statusCode;

  ApiResponse({
    required this.isError,
    this.data,
    this.error,
    this.statusCode = 200,
  });
}

class ApiService {
  static Dio? _dio;

  static Future<void> init() async {
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
    _dio!.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = StorageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        print('API Error: ${error.message}');
        handler.next(error);
      },
    ));
  }

  static Dio get dio {
    assert(_dio != null, 'ApiService not initialized');
    return _dio!;
  }

  // Authentication
  static Future<ApiResponse<String>> login(LoginRequest request) async {
    try {
      final response = await dio.post(
        AppConfig.generateTokenEndpoint,
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        final token = response.data['token'];
        if (token != null) {
          return ApiResponse(
            isError: false,
            data: token,
            statusCode: response.statusCode!,
          );
        } else {
          return ApiResponse(
            isError: true,
            error: response.data['error'] ?? 'Login failed',
            statusCode: response.statusCode!,
          );
        }
      } else {
        return ApiResponse(
          isError: true,
          error: 'Login failed with status: ${response.statusCode}',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Get room list
  static Future<ApiResponse<List<Room>>> getRoomList({
    String? search,
    Map<String, dynamic>? filters,
    int take = 20,
    int skip = 0,
  }) async {
    try {
      // Build the request data to match the backend format
      final requestData = {
        'Take': take,
        'Skip': skip,
        'Sort': ['IsPin DESC', 'TimeMsg DESC'],
        'IncludeColumns': [
          'Id', 'CtId', 'CtRealId', 'GrpId', 'CtRealNm', 'Ct', 'Grp',
          'LastMsg', 'TimeMsg', 'Uc', 'St', 'ChId', 'ChAcc', 'AccNm', 'BotNm', 'CtImg', 'LinkImg',
          'IsGrp', 'IsPin', 'CtIsBlock', 'IsMuteBot', 'Tags', 'Fn', 'FnId', 'FnNm', 'FunnelId', 'TagsIds'
        ],
        'ColumnSelection': 1,
      };

      if (search != null && search.isNotEmpty) {
        requestData['ContainsText'] = search;
      }

      if (filters != null) {
        print('📡 [API SERVICE] Received filters: $filters');
        // FIXED: Send ALL filters, not just status
        // Previously this code was sending only St when it exists, ignoring other filters
        requestData['EqualityFilter'] = filters;
        print('📡 [API SERVICE] Setting EqualityFilter: $filters');
      }

      print('📡 [API SERVICE] Request data: $requestData');
      
      final response = await dio.post(
        'Services/Chat/Chatrooms/List',
        data: requestData,
      );
      
      print('📡 [API SERVICE] Response status: ${response.statusCode}');
      print('📡 [API SERVICE] Response data keys: ${response.data?.keys}');
      if (response.data?['Entities'] != null) {
        print('📡 [API SERVICE] Number of rooms returned: ${(response.data['Entities'] as List).length}');
      }

      if (response.statusCode == 200) {
        // Safe null checking for IsError
        final isError = response.data['IsError'];
        final hasError = isError == true; // This handles null and false cases properly
        
        if (!hasError && response.data['Entities'] != null) {
          final entities = response.data['Entities'] as List;
          final rooms = entities.map((e) => Room.fromJson(e)).toList();
          
          return ApiResponse(
            isError: false,
            data: rooms,
            statusCode: response.statusCode!,
          );
        } else {
          final errorMessage = response.data['ErrorMessage'] ?? response.data['Error'] ?? 'Failed to load rooms';
          print('❌ [API SERVICE] API returned error: $errorMessage');
          print('❌ [API SERVICE] Full response data: ${response.data}');
          return ApiResponse(
            isError: true,
            error: errorMessage,
            statusCode: response.statusCode!,
          );
        }
      } else {
        return ApiResponse(
          isError: true,
          error: 'HTTP ${response.statusCode}: ${response.statusMessage}',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      print('Error in getRoomList: $e');
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Get archived room detail with messages - SPECIAL ENDPOINT for archived conversations
  static Future<ApiResponse<Map<String, dynamic>>> getArchivedRoomDetail({
    required String roomId,
  }) async {
    try {
      print('📦 API Request for archived room detail - RoomId: $roomId');
      
      final requestData = {
        'EntityId': roomId,
      };
      
      print('📦 Request data: $requestData');
      
      final response = await dio.post(
        'Services/Chat/Chatrooms/DetailArchived',
        data: requestData,
      );
      
      print('📦 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final isError = response.data['IsError'];
        final hasError = isError == true;
        
        print('📦 API Response - HasError: $hasError');
        print('📦 Full response data keys: ${response.data?.keys}');
        
        if (!hasError && response.data['Data'] != null) {
          final data = response.data['Data'] as Map<String, dynamic>;
          print('✅ Successfully got archived room detail');
          print('📦 Data keys: ${data.keys}');
          
          return ApiResponse(
            isError: false,
            data: data,
            statusCode: response.statusCode!,
          );
        } else {
          final errorMsg = response.data['ErrorMessage'] ?? response.data['Error'] ?? 'Failed to load archived room detail';
          print('❌ API Error loading archived room: $errorMsg');
          
          return ApiResponse(
            isError: true,
            error: errorMsg,
            statusCode: response.statusCode!,
          );
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode} - ${response.statusMessage}');
        return ApiResponse(
          isError: true,
          error: 'HTTP ${response.statusCode}: ${response.statusMessage}',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      print('❌ Exception in getArchivedRoomDetail: $e');
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Get messages for a room
  static Future<ApiResponse<List<ChatMessage>>> getMessages({
    required String roomId,
    int take = 20,
    int skip = 0,
  }) async {
    try {
      final requestData = {
        'Take': take,
        'Skip': skip,
        // Ensure RoomId is sent with correct type (int if possible)
        'EqualityFilter': {
          'RoomId': int.tryParse(roomId) ?? roomId,
        },
        'Sort': ['In DESC', 'Type DESC'],
      };

      print('📨 API Request for messages - RoomId: $roomId, Take: $take, Skip: $skip');
      print('📨 Request data: $requestData');

      final response = await dio.post(
        'Services/Chat/Chatmessages/List',
        data: requestData,
      );

      if (response.statusCode == 200) {
        // Safe null checking for IsError
        final isError = response.data['IsError'];
        final hasError = isError == true; // This handles null and false cases properly
        
        print('📨 API Response for messages - HasError: $hasError, Entities count: ${(response.data['Entities'] as List?)?.length ?? 0}');
        
        if (!hasError && response.data['Entities'] != null) {
          final entities = response.data['Entities'] as List;
          final messages = entities.map((e) => ChatMessage.fromJson(e)).toList();
          
          print('✅ Successfully parsed ${messages.length} messages from API response');
          
          return ApiResponse(
            isError: false,
            data: messages,
            statusCode: response.statusCode!,
          );
        } else {
          final errorMsg = response.data['ErrorMessage'] ?? response.data['Error'] ?? 'Failed to load messages';
          print('❌ API Error loading messages: $errorMsg');
          print('❌ Full response data: ${response.data}');
          
          return ApiResponse(
            isError: true,
            error: errorMsg,
            statusCode: response.statusCode!,
          );
        }
      } else {
        return ApiResponse(
          isError: true,
          error: 'HTTP ${response.statusCode}: ${response.statusMessage}',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Send message using Inbox API (the proper way to send messages)
  static Future<ApiResponse<String>> sendMessage(Map<String, dynamic> messageData) async {
    try {
      // Validate that we have a valid account ID
      final accountIds = messageData['AccountIds']?.toString();
      if (accountIds == null || accountIds.isEmpty) {
        return ApiResponse(
          isError: true,
          error: 'No account ID provided for sending message',
          statusCode: 400,
        );
      }
      
      // CRITICAL FIX: Remove ReplyId from API requests entirely
      // Backend confirmed that reply feature only works via WebSocket, not API
      if (messageData.containsKey('ReplyId')) {
        print('⚠️ Removing ReplyId from API request - reply only supported via WebSocket');
        messageData.remove('ReplyId');
      }
      
      // Ensure proper data types for Inbox API
      final inboxData = {
        'LinkId': messageData['LinkId'] is int ? messageData['LinkId'] : int.tryParse(messageData['LinkId']?.toString() ?? '0') ?? 0,
        'ChannelId': messageData['ChannelId'] is int ? messageData['ChannelId'] : int.tryParse(messageData['ChannelId']?.toString() ?? '1') ?? 1,
        'AccountIds': accountIds,
        'BodyType': messageData['BodyType'] is int ? messageData['BodyType'] : int.tryParse(messageData['BodyType']?.toString() ?? messageData['Type']?.toString() ?? '1') ?? 1,
        'Body': messageData['Body']?.toString() ?? messageData['Msg']?.toString() ?? '',
        'Attachment': messageData['Attachment']?.toString() ?? messageData['File']?.toString() ?? '',
      };

      // Ensure LinkId is not 0 (which causes the error)
      if (inboxData['LinkId'] == 0) {
        return ApiResponse(
          isError: true,
          error: 'Invalid LinkId: LinkId cannot be 0',
          statusCode: 400,
        );
      }

      // Additional validation for WhatsApp Business API
      if (inboxData['ChannelId'] == 1561) { // WhatsApp Business
        // For WhatsApp Business, validate attachment and body properly
        final hasAttachment = inboxData['Attachment'].toString().trim().isNotEmpty && inboxData['Attachment'] != '[]';
        final hasBody = inboxData['Body'].toString().trim().isNotEmpty;
        
        // For media messages (BodyType > 1), we must have attachment
        if (inboxData['BodyType'] > 1 && !hasAttachment) {
          return ApiResponse(
            isError: true,
            error: 'Media message must have attachment',
            statusCode: 400,
          );
        }
        
        // For text messages (BodyType = 1), we must have body text
        if (inboxData['BodyType'] == 1 && !hasBody) {
          return ApiResponse(
            isError: true,
            error: 'Text message must have body content',
            statusCode: 400,
          );
        }
        
        // Enhanced logging for media messages with caption
        if (inboxData['BodyType'] > 1) {
          print('WhatsApp Business MEDIA message:');
          print('  BodyType: ${inboxData['BodyType']}');
          print('  Caption/Body: "${inboxData['Body']}"');
          print('  Attachment: "${inboxData['Attachment']}"');
          print('  HasCaption: $hasBody, HasAttachment: $hasAttachment');
        }
      }

      print('Sending message via Inbox API: ${jsonEncode(inboxData)}');

      final response = await dio.post(
        AppConfig.inboxSendEndpoint,
        data: inboxData,
      );

      print('Inbox API response: ${response.data}');

      if (response.statusCode == 200) {
        // Handle both boolean and null cases for IsError
        final isError = response.data['IsError'];
        final hasError = isError == true; // This handles null and false cases properly
        
        if (!hasError) {
          return ApiResponse(
            isError: false,
            data: response.data['Data']?.toString() ?? 'Message sent successfully',
            statusCode: response.statusCode!,
          );
        } else {
          return ApiResponse(
            isError: true,
            error: response.data['Error'] ?? response.data['ErrorMessage'] ?? 'Failed to send message',
            statusCode: response.statusCode!,
          );
        }
      } else {
        return ApiResponse(
          isError: true,
          error: 'HTTP ${response.statusCode}: ${response.statusMessage}',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      print('Error in sendMessage: $e');
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Mark room as resolved
  static Future<ApiResponse<String>> markRoomResolved(String roomId) async {
    try {
      final userData = StorageService.getUserData();
      final agentId = userData?['UserId']?.toString() ?? '1';
      final agentName = userData?['DisplayName']?.toString() ?? 'Agent';
      
      final requestData = {
        'EntityId': roomId,
        'Entity': {
          'St': 3,
          'Uc': 0,
          'IsPin': 1,
          'Isblock': 1,
          'ReById': agentId,
          'ReByNm': agentName,
        },
      };

      final response = await dio.post(
        'Services/Chat/Chatrooms/MarkResolved',
        data: requestData,
      );

      if (response.statusCode == 200) {
        final isError = response.data['IsError'];
        final hasError = isError == true;
        
        if (!hasError) {
          return ApiResponse(
            isError: false,
            data: 'Room marked as resolved successfully',
            statusCode: response.statusCode!,
          );
        } else {
          return ApiResponse(
            isError: true,
            error: response.data['ErrorMsg'] ?? response.data['Error'] ?? 'Failed to mark room as resolved',
            statusCode: response.statusCode!,
          );
        }
      } else {
        return ApiResponse(
          isError: true,
          error: 'HTTP ${response.statusCode}: ${response.statusMessage}',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Move room to archive
  static Future<ApiResponse<String>> moveToArchive(String roomId) async {
    try {
      final requestData = {
        'EntityId': roomId,
      };

      final response = await dio.post(
        'Services/Chat/Chatrooms/MoveArchive',
        data: requestData,
      );

      if (response.statusCode == 200) {
        final isError = response.data['IsError'];
        final hasError = isError == true;
        
        if (!hasError) {
          return ApiResponse(
            isError: false,
            data: 'Room archived successfully',
            statusCode: response.statusCode!,
          );
        } else {
          return ApiResponse(
            isError: true,
            error: response.data['ErrorMsg'] ?? response.data['Error'] ?? 'Failed to archive room',
            statusCode: response.statusCode!,
          );
        }
      } else {
        return ApiResponse(
          isError: true,
          error: 'HTTP ${response.statusCode}: ${response.statusMessage}',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Unarchive room - using the correct endpoint from the second file
  static Future<ApiResponse<String>> unarchiveRoom(String roomId) async {
    try {
      final requestData = {
        'EntityId': roomId,
      };

      // Use the correct unarchive endpoint as requested
      final response = await dio.post(
        'Services/Chat/Chatrooms/RestoreArchived',
        data: requestData,
      );

      if (response.statusCode == 200) {
        final isError = response.data['IsError'];
        final hasError = isError == true;
        
        if (!hasError) {
          return ApiResponse(
            isError: false,
            data: 'Room unarchived successfully',
            statusCode: response.statusCode!,
          );
        } else {
          return ApiResponse(
            isError: true,
            error: response.data['ErrorMsg'] ?? response.data['Error'] ?? 'Failed to unarchive room',
            statusCode: response.statusCode!,
          );
        }
      } else {
        return ApiResponse(
          isError: true,
          error: 'HTTP ${response.statusCode}: ${response.statusMessage}',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Toggle pin status
  static Future<ApiResponse<String>> togglePinRoom(String roomId, bool isPinned) async {
    try {
      final requestData = {
        'EntityId': roomId,
        'Entity': {
          'IsPin': isPinned ? 2 : 1, // 2 = pinned, 1 = not pinned
        },
      };

      final response = await dio.post(
        'Services/Chat/Chatrooms/Update',
        data: requestData,
      );

      if (response.statusCode == 200) {
        final isError = response.data['IsError'];
        final hasError = isError == true;
        
        if (!hasError) {
          return ApiResponse(
            isError: false,
            data: 'Pin status updated successfully',
            statusCode: response.statusCode!,
          );
        } else {
          return ApiResponse(
            isError: true,
            error: response.data['ErrorMsg'] ?? response.data['Error'] ?? 'Failed to update pin status',
            statusCode: response.statusCode!,
          );
        }
      } else {
        return ApiResponse(
          isError: true,
          error: 'HTTP ${response.statusCode}: ${response.statusMessage}',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Upload base64 file - combined improved error handling
  static Future<ApiResponse<UploadedFile>> uploadBase64({
    required String filename,
    required String mimetype,
    required String base64Data,
  }) async {
    try {
      final requestData = {
        'filename': filename,
        'mimetype': mimetype,
        'data': base64Data,
      };

      final response = await dio.post(
        AppConfig.uploadBase64Endpoint,
        data: requestData,
      );

      if (response.statusCode == 200) {
        // Handle both boolean and null cases for IsError (improved version)
        final isError = response.data['IsError'];
        final hasError = isError == true;
        
        if (!hasError && response.data['Data'] != null) {
          final data = response.data['Data'];
          final uploadedFile = UploadedFile.fromJson(data);
          
          return ApiResponse(
            isError: false,
            data: uploadedFile,
            statusCode: response.statusCode!,
          );
        } else {
          return ApiResponse(
            isError: true,
            error: response.data['Error'] ?? response.data['ErrorMessage'] ?? 'Upload failed',
            statusCode: response.statusCode!,
          );
        }
      } else {
        return ApiResponse(
          isError: true,
          error: 'Upload failed with status: ${response.statusCode}',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      print('Error in uploadBase64: $e');
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Get contact list
  static Future<ApiResponse<List<Contact>>> getContactList({
    int take = 20,
    int skip = 0,
  }) async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name'],
        'ColumnSelection': 1,
        'Take': take,
        'Skip': skip,
      };

      final response = await dio.post(
        AppConfig.contactListEndpoint,
        data: requestData,
      );

      if (response.statusCode == 200 && !response.data['IsError']) {
        final entities = response.data['Entities'] as List;
        final contacts = entities.map((e) => Contact.fromJson(e)).toList();
        
        return ApiResponse(
          isError: false,
          data: contacts,
          statusCode: response.statusCode!,
        );
      } else {
        return ApiResponse(
          isError: true,
          error: response.data['ErrorMessage'] ?? 'Failed to load contacts',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Get channel list
  static Future<ApiResponse<List<Map<String, dynamic>>>> getChannelList() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Nm'],
        'ColumnSelection': 1,
      };

      final response = await dio.post(
        AppConfig.channelListEndpoint,
        data: requestData,
      );

      if (response.statusCode == 200 && !response.data['IsError']) {
        final entities = response.data['Entities'] as List;
        
        return ApiResponse(
          isError: false,
          data: entities.cast<Map<String, dynamic>>(),
          statusCode: response.statusCode!,
        );
      } else {
        return ApiResponse(
          isError: true,
          error: response.data['ErrorMessage'] ?? 'Failed to load channels',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Get account list
  static Future<ApiResponse<List<Map<String, dynamic>>>> getAccountList({
    int? channelId,
  }) async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'Channel'],
        'ColumnSelection': 1,
      };

      if (channelId != null) {
        requestData['EqualityFilter'] = {'Channel': channelId};
      }

      final response = await dio.post(
        AppConfig.accountListEndpoint,
        data: requestData,
      );

      if (response.statusCode == 200 && !response.data['IsError']) {
        final entities = response.data['Entities'] as List;
        
        return ApiResponse(
          isError: false,
          data: entities.cast<Map<String, dynamic>>(),
          statusCode: response.statusCode!,
        );
      } else {
        return ApiResponse(
          isError: true,
          error: response.data['ErrorMessage'] ?? 'Failed to load accounts',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      return ApiResponse(
        isError: true,  
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Create Note for Room/Conversation
  static Future<ApiResponse<Map<String, dynamic>>> createNote({
    required String roomId,
    required String content,
  }) async {
    try {
      // Try to parse roomId as integer for backend consistency
      final roomIdValue = int.tryParse(roomId) ?? roomId;
      
      final requestData = {
        'Entity': {
          'RoomId': roomIdValue,  // Send as int if parseable, else string
          'Cnt': content,
        },
      };

      print('📝 [Create Note] Request - RoomId: $roomId (sent as: $roomIdValue), Content: $content');
      print('📝 [Create Note] Full request: $requestData');
      
      final response = await dio.post(
        'Services/Chat/Chatnotes/Create',
        data: requestData,
      );

      print('📝 [Create Note] Response status: ${response.statusCode}');
      print('📝 [Create Note] Response data: ${response.data}');

      if (response.statusCode == 200) {
        final isError = response.data['Error'] != null;
        
        if (!isError) {
          return ApiResponse(
            isError: false,
            data: response.data,
            statusCode: response.statusCode!,
          );
        } else {
          return ApiResponse(
            isError: true,
            error: response.data['Error'] ?? 'Failed to create note',
            statusCode: response.statusCode!,
          );
        }
      } else {
        return ApiResponse(
          isError: true,
          error: 'HTTP ${response.statusCode}: ${response.statusMessage}',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      print('❌ [Create Note] Error: $e');
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Get Quick Reply Templates
  static Future<ApiResponse<List<QuickReplyTemplate>>> getQuickReplyTemplates({
    String? search,
    int take = 20,
    int skip = 0,
  }) async {
    try {
      final requestData = {
        'Take': take,
        'Skip': skip,
        'IncludeColumns': ['Id', 'Cmd', 'Files', 'Cnt', 'Type', 'In', 'InBy', 'Up', 'UpBy'],
        'ColumnSelection': 1,
      };

      if (search != null && search.isNotEmpty) {
        requestData['ContainsText'] = search;
      }

      print('🚀 [Quick Reply] Fetching templates...');
      final response = await dio.post(
        'Services/Chat/Chattemplates/List',
        data: requestData,
      );

      if (response.statusCode == 200) {
        final isError = response.data['IsError'];
        final hasError = isError == true;
        
        if (!hasError && response.data['Entities'] != null) {
          final entities = response.data['Entities'] as List;
          final templates = entities.map((e) => QuickReplyTemplate.fromJson(e)).toList();
          
          print('✅ [Quick Reply] Loaded ${templates.length} templates');
          return ApiResponse(
            isError: false,
            data: templates,
            statusCode: response.statusCode!,
          );
        } else {
          return ApiResponse(
            isError: true,
            error: response.data['ErrorMessage'] ?? response.data['Error'] ?? 'Failed to load templates',
            statusCode: response.statusCode!,
          );
        }
      } else {
        return ApiResponse(
          isError: true,
          error: 'HTTP ${response.statusCode}: ${response.statusMessage}',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      print('❌ [Quick Reply] Error: $e');
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }
}
