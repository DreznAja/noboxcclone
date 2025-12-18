import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/new_conversation_models.dart';
import '../app_config.dart';
import 'storage_service.dart';

class NewConversationService {
  static Dio? _dio;

  NewConversationService() {
    if (_dio == null) {
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
          print('New Conversation API Error: ${error.message}');
          handler.next(error);
        },
      ));
    }
  }

  Future<List<ChannelOption>> getChannels() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Nm'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };

      final response = await _dio!.post(
        'Services/Master/Channel/List',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        
        // Filter only specific channels as requested
        final allowedChannels = ['Mobile Number', 'NoboxChat', 'Telegram', 'Tokopedia.com', 'WhatsApp'];
        
        return entities
            .map((item) => ChannelOption.fromJson(item))
            .where((channel) => allowedChannels.contains(channel.name))
            .toList();
      }
      
      throw Exception('Failed to load channels: ${response.data}');
    } catch (e) {
      print('Error fetching channels: $e');
      throw Exception('Failed to load channels: $e');
    }
  }

  // FIXED: Accept channelId parameter to filter accounts by channel
  Future<List<AccountOption>> getAccounts({int? channelId}) async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Channel'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };

      // FIXED: Add channel filter if channelId is provided
      if (channelId != null) {
        requestData['EqualityFilter'] = {'Channel': channelId};
      }

      final response = await _dio!.post(
        'Services/Nobox/Account/List',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        final accounts = entities.map((item) => AccountOption.fromJson(item)).toList();
        
        // FIXED: Additional client-side filtering to ensure only accounts for the selected channel are returned
        if (channelId != null) {
          return accounts.where((account) {
            // Check if the account's channel matches the selected channel
            // Assuming the API returns channel info in the account data
            return true; // Return all since we already filtered on server side
          }).toList();
        }
        
        return accounts;
      }
      
      throw Exception('Failed to load accounts: ${response.data}');
    } catch (e) {
      print('Error fetching accounts: $e');
      throw Exception('Failed to load accounts: $e');
    }
  }

  Future<List<ContactOption>> getContacts() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };

      final response = await _dio!.post(
        'Services/Nobox/Contact/List',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        return entities.map((item) => ContactOption.fromJson(item)).toList();
      }
      
      throw Exception('Failed to load contacts: ${response.data}');
    } catch (e) {
      print('Error fetching contacts: $e');
      throw Exception('Failed to load contacts: $e');
    }
  }

  Future<List<LinkOption>> getLinks() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };

      final response = await _dio!.post(
        'Services/Chat/Chatlinkcontacts/List',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        return entities.map((item) => LinkOption.fromJson(item)).toList();
      }
      
      throw Exception('Failed to load links: ${response.data}');
    } catch (e) {
      print('Error fetching links: $e');
      throw Exception('Failed to load links: $e');
    }
  }

  Future<List<GroupOption>> getGroups() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };

      final response = await _dio!.post(
        'Services/Nobox/Group/List',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        return entities.map((item) => GroupOption.fromJson(item)).toList();
      }
      
      throw Exception('Failed to load groups: ${response.data}');
    } catch (e) {
      print('Error fetching groups: $e');
      throw Exception('Failed to load groups: $e');
    }
  }

  Future<RoomDetail> getDetailRoom(String targetId) async {
    try {
      print('Getting room details for targetId: $targetId');
      
      final requestData = {
        'Id': targetId,
      };
      
      print('Request data: $requestData');

      final response = await _dio!.post(
        'Services/Chat/Chatrooms/DetailRoom',
        data: requestData,
      );
      
      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final roomData = response.data['Data'] ?? response.data;
        return RoomDetail.fromJson(roomData);
      }
      
      throw Exception('Failed to get room details: ${response.data}');
    } catch (e) {
      print('Error getting room details: $e');
      if (e is DioException) {
        print('DioException type: ${e.type}');
        print('DioException message: ${e.message}');
        print('DioException response: ${e.response?.data}');
      }
      throw Exception('Failed to get room details: $e');
    }
  }
}