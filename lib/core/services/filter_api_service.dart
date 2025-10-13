import 'package:dio/dio.dart';
import '../app_config.dart';
import '../models/filter_models.dart';
import 'storage_service.dart';

class FilterApiService {
  static final FilterApiService _instance = FilterApiService._internal();
  factory FilterApiService() => _instance;
  
  late Dio _dio;

  FilterApiService._internal() {
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
        print('Filter API Error: ${error.message}');
        handler.next(error);
      },
    ));
  }

  Future<List<FunnelItem>> getFunnels() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm'], // Tambahkan lebih banyak kemungkinan field
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/Chat/Chatfunnels/List',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        
        // DEBUG: Print raw response untuk melihat structure data
        if (entities.isNotEmpty) {
          print('=== FUNNEL API RESPONSE DEBUG ===');
          print('First funnel item: ${entities.first}');
          print('Available fields: ${entities.first.keys.toList()}');
          print('================================');
        }
        
        return entities.map((item) => FunnelItem.fromJson(item)).toList();
      }
      
      print('Funnel API Error: ${response.data}');
      return [];
    } catch (e) {
      print('Error fetching funnels: $e');
      return [];
    }
  }

  Future<List<TagItem>> getTags() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm', 'TagName'], // Tambahkan lebih banyak kemungkinan field
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
        
        // DEBUG: Print raw response untuk melihat structure data
        if (entities.isNotEmpty) {
          print('=== TAG API RESPONSE DEBUG ===');
          print('First tag item: ${entities.first}');
          print('Available fields: ${entities.first.keys.toList()}');
          print('=============================');
        }
        
        return entities.map((item) => TagItem.fromJson(item)).toList();
      }
      
      print('Tag API Error: ${response.data}');
      return [];
    } catch (e) {
      print('Error fetching tags: $e');
      return [];
    }
  }

  // ... sisanya sama seperti sebelumnya
  Future<List<ChannelItem>> getChannels() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Nm'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/Master/Channel/List',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        
        // Filter only specific channels as requested
        final allowedChannels = ['Mobile Number', 'NoboxChat', 'Telegram', 'Tokopedia.com', 'WhatsApp'];
        
        return entities
            .map((item) => ChannelItem.fromJson(item))
            .where((channel) => allowedChannels.contains(channel.name))
            .toList();
      }
      
      print('Channel API Error: ${response.data}');
      return [];
    } catch (e) {
      print('Error fetching channels: $e');
      return [];
    }
  }

  Future<List<AccountItem>> getAccounts() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/Nobox/Account/List',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        return entities.map((item) => AccountItem.fromJson(item)).toList();
      }
      
      print('Account API Error: ${response.data}');
      return [];
    } catch (e) {
      print('Error fetching accounts: $e');
      return [];
    }
  }

  Future<List<ContactItem>> getContacts() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/Nobox/Contact/List',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        
        // DEBUG: Print first contact to see structure
        if (entities.isNotEmpty) {
          print('=== CONTACT API RESPONSE DEBUG ===');
          print('First contact item: ${entities.first}');
          print('Available fields: ${(entities.first as Map).keys.toList()}');
          print('================================');
        }
        
        return entities.map((item) => ContactItem.fromJson(item)).toList();
      }
      
      print('Contact API Error: ${response.data}');
      return [];
    } catch (e) {
      print('Error fetching contacts: $e');
      return [];
    }
  }

  Future<List<LinkItem>> getLinks() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/Chat/Chatlinkcontacts/List',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        return entities.map((item) => LinkItem.fromJson(item)).toList();
      }
      
      print('Link API Error: ${response.data}');
      return [];
    } catch (e) {
      print('Error fetching links: $e');
      return [];
    }
  }

  Future<List<GroupItem>> getGroups() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/Nobox/Group/List',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        return entities.map((item) => GroupItem.fromJson(item)).toList();
      }
      
      print('Group API Error: ${response.data}');
      return [];
    } catch (e) {
      print('Error fetching groups: $e');
      return [];
    }
  }

  Future<List<CampaignItem>> getCampaigns() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/Nobox/Campaign/ListActive',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        return entities.map((item) => CampaignItem.fromJson(item)).toList();
      }
      
      print('Campaign API Error: ${response.data}');
      return [];
    } catch (e) {
      print('Error fetching campaigns: $e');
      return [];
    }
  }

  Future<List<DealItem>> getDeals() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/Nobox/Deals/List',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        return entities.map((item) => DealItem.fromJson(item)).toList();
      }
      
      print('Deal API Error: ${response.data}');
      return [];
    } catch (e) {
      print('Error fetching deals: $e');
      return [];
    }
  }

  Future<List<HumanAgentItem>> getHumanAgents() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'UserId', 'DisplayName', 'Username'],
        'ColumnSelection': 1,
        'Take': 100,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/Administration/User/ListAgent',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        return entities.map((item) => HumanAgentItem.fromJson(item)).toList();
      }
      
      print('Human Agent API Error: ${response.data}');
      return [];
    } catch (e) {
      print('Error fetching human agents: $e');
      return [];
    }
  }
}