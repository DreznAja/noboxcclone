import 'dart:convert';
import 'package:dio/dio.dart';
import '../app_config.dart';
import '../models/auth_models.dart';
import '../models/chat_models.dart';
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
          'LastMsg', 'TimeMsg', 'Uc', 'St', 'ChId', 'ChAcc', 'CtImg', 'LinkImg',
          'IsGrp', 'IsPin', 'CtIsBlock', 'IsMuteBot', 'Tags', 'Fn', 'FnId', 'TagsIds'
        ],
        'ColumnSelection': 1,
      };

      if (search != null && search.isNotEmpty) {
        requestData['ContainsText'] = search;
      }

      if (filters != null) {
        // Handle status filter properly
        if (filters.containsKey('St')) {
          requestData['EqualityFilter'] = {'St': filters['St']};
        } else {
          requestData['EqualityFilter'] = filters;
        }
      }

      final response = await dio.post(
        'Services/Chat/Chatrooms/List',
        data: requestData,
      );

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
          return ApiResponse(
            isError: true,
            error: response.data['ErrorMessage'] ?? response.data['Error'] ?? 'Failed to load rooms',
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
        'EqualityFilter': {'RoomId': roomId},
        'Sort': ['In DESC', 'Type DESC'],
      };

      final response = await dio.post(
        'Services/Chat/Chatmessages/List',
        data: requestData,
      );

      if (response.statusCode == 200) {
        // Safe null checking for IsError
        final isError = response.data['IsError'];
        final hasError = isError == true; // This handles null and false cases properly
        
        if (!hasError && response.data['Entities'] != null) {
          final entities = response.data['Entities'] as List;
          final messages = entities.map((e) => ChatMessage.fromJson(e)).toList();
          
          return ApiResponse(
            isError: false,
            data: messages,
            statusCode: response.statusCode!,
          );
        } else {
          return ApiResponse(
            isError: true,
            error: response.data['ErrorMessage'] ?? response.data['Error'] ?? 'Failed to load messages',
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
      
      // Validate ReplyId if present
      if (messageData.containsKey('ReplyId')) {
        final replyId = messageData['ReplyId'];
        if (replyId == null || replyId.toString().trim().isEmpty) {
          print('⚠️ Empty ReplyId detected, removing from request');
          messageData.remove('ReplyId');
        } else {
          print('✅ Valid ReplyId: $replyId');
        }
      }
      
      // Ensure proper data types for Inbox API
      final inboxData = {
        'LinkId': messageData['LinkId'] is int ? messageData['LinkId'] : int.tryParse(messageData['LinkId']?.toString() ?? '0') ?? 0,
        'ChannelId': messageData['ChannelId'] is int ? messageData['ChannelId'] : int.tryParse(messageData['ChannelId']?.toString() ?? '1') ?? 1,
        'AccountIds': accountIds,
        'BodyType': messageData['BodyType'] is int ? messageData['BodyType'] : int.tryParse(messageData['BodyType']?.toString() ?? messageData['Type']?.toString() ?? '1') ?? 1,
        'Body': messageData['Body']?.toString() ?? messageData['Msg']?.toString() ?? '',
        'Attachment': messageData['Attachment']?.toString() ?? messageData['File']?.toString() ?? '',
        // Only include ReplyId if it exists in the original messageData after validation
        if (messageData.containsKey('ReplyId')) 'ReplyId': messageData['ReplyId']?.toString(),
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
        
        // Validate ReplyId format for WhatsApp Business
        if (inboxData.containsKey('ReplyId')) {
          final replyId = inboxData['ReplyId']?.toString();
          if (replyId != null && replyId.isNotEmpty) {
            // Ensure ReplyId is numeric (WhatsApp Business expects numeric IDs)
            final numericReplyId = int.tryParse(replyId);
            if (numericReplyId == null) {
              print('⚠️ Invalid ReplyId format for WhatsApp Business: $replyId, removing');
              inboxData.remove('ReplyId');
            } else {
              print('✅ Valid numeric ReplyId for WhatsApp Business: $numericReplyId');
            }
          }
        }
        
        // Enhanced logging for media messages with caption
        if (inboxData['BodyType'] > 1) {
          print('WhatsApp Business MEDIA message:');
          print('  BodyType: ${inboxData['BodyType']}');
          print('  Caption/Body: "${inboxData['Body']}"');
          print('  Attachment: "${inboxData['Attachment']}"');
          print('  HasCaption: $hasBody, HasAttachment: $hasAttachment');
          if (inboxData.containsKey('ReplyId')) {
            print('  ReplyId: ${inboxData['ReplyId']}');
          }
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
          // Enhanced success logging for media messages
          if (inboxData['ChannelId'] == 1561 && inboxData['BodyType'] > 1) {
            print('✅ WhatsApp Business MEDIA API Success: ${response.data}');
            if (inboxData['Body'].toString().isNotEmpty) {
              print('✅ Caption was included: "${inboxData['Body']}"');
            }
          }
          
          return ApiResponse(
            isError: false,
            data: response.data['Data']?.toString() ?? 'Message sent successfully',
            statusCode: response.statusCode!,
          );
        } else {
          // Enhanced error logging for media messages
          if (inboxData['ChannelId'] == 1561 && inboxData['BodyType'] > 1) {
            print('❌ WhatsApp Business MEDIA API Error: ${response.data}');
          }
          
          // Enhanced error logging for reply messages
          if (inboxData.containsKey('ReplyId')) {
            print('❌ Reply message API Error: ${response.data}');
            print('❌ ReplyId was: ${inboxData['ReplyId']}');
            
            // If it's a reply message error, try sending without ReplyId as fallback
            if (response.data['Error']?.toString().contains('ReplyId') == true ||
                response.data['ErrorMessage']?.toString().contains('ReplyId') == true) {
              print('🔄 Retrying without ReplyId due to reply-related error...');
              
              final fallbackData = Map<String, dynamic>.from(inboxData);
              fallbackData.remove('ReplyId');
              
              try {
                final fallbackResponse = await dio.post(
                  AppConfig.inboxSendEndpoint,
                  data: fallbackData,
                );
                
                if (fallbackResponse.statusCode == 200 && fallbackResponse.data['IsError'] != true) {
                  print('✅ Fallback message sent successfully without ReplyId');
                  return ApiResponse(
                    isError: false,
                    data: fallbackResponse.data['Data']?.toString() ?? 'Message sent successfully (without reply)',
                    statusCode: fallbackResponse.statusCode!,
                  );
                }
              } catch (fallbackError) {
                print('❌ Fallback also failed: $fallbackError');
              }
            }
          }
          
          return ApiResponse(
            isError: true,
            error: response.data['Error'] ?? response.data['ErrorMessage'] ?? 'Failed to send message',
            statusCode: response.statusCode!,
          );
        }
      } else if (response.statusCode == 500) {
        // Handle 500 errors specifically for reply messages
        if (inboxData.containsKey('ReplyId')) {
          print('🔄 500 error with ReplyId, attempting fallback without ReplyId...');
          
          try {
            final fallbackData = Map<String, dynamic>.from(inboxData);
            fallbackData.remove('ReplyId');
            
            final fallbackResponse = await dio.post(
              AppConfig.inboxSendEndpoint,
              data: fallbackData,
            );
            
            if (fallbackResponse.statusCode == 200 && fallbackResponse.data['IsError'] != true) {
              print('✅ Fallback message sent successfully after 500 error');
              return ApiResponse(
                isError: false,
                data: fallbackResponse.data['Data']?.toString() ?? 'Message sent successfully (reply failed, sent as regular message)',
                statusCode: fallbackResponse.statusCode!,
              );
            }
          } catch (fallbackError) {
            print('❌ Fallback after 500 error also failed: $fallbackError');
          }
        }
        
        return ApiResponse(
          isError: true,
          error: 'Server error (500): Failed to send message. This might be due to an invalid reply reference.',
          statusCode: response.statusCode!,
        );
      } else {
        return ApiResponse(
          isError: true,
          error: 'HTTP ${response.statusCode}: ${response.statusMessage}',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      print('Error in sendMessage: $e');
      if (messageData.containsKey('ReplyId')) {
        print('❌ Error occurred with ReplyId: ${messageData['ReplyId']}');
        
        // If there's an exception with ReplyId, try one more time without it
        try {
          print('🔄 Exception with ReplyId, attempting fallback without ReplyId...');
          final fallbackData = Map<String, dynamic>.from(messageData);
          fallbackData.remove('ReplyId');
          
          final fallbackResponse = await dio.post(
            AppConfig.inboxSendEndpoint,
            data: fallbackData,
          );
          
          if (fallbackResponse.statusCode == 200 && fallbackResponse.data['IsError'] != true) {
            print('✅ Fallback message sent successfully after exception');
            return ApiResponse(
              isError: false,
              data: fallbackResponse.data['Data']?.toString() ?? 'Message sent successfully (reply failed, sent as regular message)',
              statusCode: fallbackResponse.statusCode!,
            );
          }
        } catch (fallbackError) {
          print('❌ Fallback after exception also failed: $fallbackError');
        }
      }
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
}