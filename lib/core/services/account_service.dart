import 'package:dio/dio.dart';
import '../app_config.dart';
import '../models/auth_models.dart';
import 'storage_service.dart';

class AccountService {
  static final AccountService _instance = AccountService._internal();
  factory AccountService() => _instance;

  late Dio _dio;

  AccountService._internal() {
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
        print('Account API Error: ${error.message}');
        handler.next(error);
      },
    ));
  }

  /// Fetch all accounts for the current user
  Future<List<AccountData>> getAllAccounts() async {
    try {
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'Channel'],
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
        return entities.map((item) => AccountData.fromJson(item)).toList();
      }

      print('Account API Error: ${response.data}');
      return [];
    } catch (e) {
      print('Error fetching all accounts: $e');
      return [];
    }
  }

  /// Fetch accounts for a specific channel
  Future<List<AccountData>> getAccountsByChannel(int channelId) async {
    try {
      final requestData = {
        'EqualityFilter': {'Channel': channelId},
        'IncludeColumns': ['Id', 'Name', 'Channel'],
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
        return entities.map((item) => AccountData.fromJson(item)).toList();
      }

      print('Account API Error for channel $channelId: ${response.data}');
      return [];
    } catch (e) {
      print('Error fetching accounts for channel $channelId: $e');
      return [];
    }
  }

  /// Initialize account mappings for the current user
  Future<void> initializeAccountMappings() async {
    try {
      print('🔄 Initializing account mappings for user...');

      // Get all accounts for the user
      final allAccounts = await getAllAccounts();

      if (allAccounts.isEmpty) {
        print('❌ No accounts found for user');
        return;
      }

      print('✅ Found ${allAccounts.length} accounts for user');

      // Group accounts by channel
      final Map<String, String> accountMapping = {};
      final List<String> allAgentIds = [];

      // Create mapping: channelId -> first available accountId
      final Map<int, List<AccountData>> accountsByChannel = {};

      for (final account in allAccounts) {
        final channelId = account.channelId;
        if (!accountsByChannel.containsKey(channelId)) {
          accountsByChannel[channelId] = [];
        }
        accountsByChannel[channelId]!.add(account);
        allAgentIds.add(account.id);
      }

      // Create the mapping using the first account for each channel
      for (final entry in accountsByChannel.entries) {
        final channelId = entry.key;
        final accounts = entry.value;

        if (accounts.isNotEmpty) {
          // Use the first account for this channel
          final primaryAccount = accounts.first;
          accountMapping[channelId.toString()] = primaryAccount.id;

          // Special handling for WhatsApp channels
          // If we have a WhatsApp account (channel 1), also map it to WhatsApp Business API (1561)
          if (channelId == 1) {
            accountMapping['1561'] = primaryAccount.id;
            print(
                '✅ Also mapped WhatsApp Business API (1561) to account ${primaryAccount.id}');
          }

// Add this section to also look for actual WhatsApp Business accounts (channel 1561)
// Check if we have any WhatsApp Business accounts (channel 1561)
          final whatsappBusinessAccounts = accountsByChannel[1561];
          if (whatsappBusinessAccounts != null &&
              whatsappBusinessAccounts.isNotEmpty) {
            final whatsappBusinessAccount = whatsappBusinessAccounts.first;
            accountMapping['1561'] = whatsappBusinessAccount.id;
            print(
                '✅ Mapped WhatsApp Business (1561) to account ${whatsappBusinessAccount.id}');
          } else if (channelId == 1) {
            // Fallback: if no WhatsApp Business account found, use regular WhatsApp account
            accountMapping['1561'] = primaryAccount.id;
            print(
                '✅ Fallback: Mapped WhatsApp Business API (1561) to WhatsApp account ${primaryAccount.id}');
          }

          print(
              '✅ Mapped channel $channelId to account ${primaryAccount.id} (${primaryAccount.name})');
        }
      }

      // Save to user data
      final userData = StorageService.getUserData() ?? {};
      userData['AccountMapping'] = accountMapping;
      userData['AgentAccountIds'] = allAgentIds;
      userData['UserAccounts'] = allAccounts.map((a) => a.toJson()).toList();

      await StorageService.saveUserData(userData);

      print('✅ Account mappings saved successfully');
      print('📊 Total channels mapped: ${accountMapping.length}');
      print('📊 Total agent account IDs: ${allAgentIds.length}');
    } catch (e) {
      print('❌ Failed to initialize account mappings: $e');
      throw Exception('Failed to initialize account mappings: $e');
    }
  }

  /// Get account ID for a specific channel
  String? getAccountIdForChannel(int channelId) {
    final userData = StorageService.getUserData();
    final accountMapping = userData?['AccountMapping'] as Map<String, dynamic>?;

    return accountMapping?[channelId.toString()]?.toString();
  }

  /// Get all user accounts
  List<AccountData> getUserAccounts() {
    final userData = StorageService.getUserData();
    final accountsData = userData?['UserAccounts'] as List<dynamic>?;

    if (accountsData != null) {
      return accountsData.map((data) => AccountData.fromJson(data)).toList();
    }

    return [];
  }

  /// Get accounts for a specific channel from cached data
  List<AccountData> getAccountsForChannel(int channelId) {
    final allAccounts = getUserAccounts();
    return allAccounts
        .where((account) => account.channelId == channelId)
        .toList();
  }

  /// Check if user has accounts for a specific channel
  bool hasAccountForChannel(int channelId) {
    return getAccountIdForChannel(channelId) != null;
  }

  /// Get all available channels for the user
  List<int> getAvailableChannels() {
    final userData = StorageService.getUserData();
    final accountMapping = userData?['AccountMapping'] as Map<String, dynamic>?;

    if (accountMapping != null) {
      return accountMapping.keys.map((key) => int.parse(key)).toList();
    }

    return [];
  }

  /// Refresh account mappings (call this when user's accounts might have changed)
  Future<void> refreshAccountMappings() async {
    await initializeAccountMappings();
  }
}

class AccountData {
  final String id;
  final String name;
  final int channelId;

  AccountData({
    required this.id,
    required this.name,
    required this.channelId,
  });

  factory AccountData.fromJson(Map<String, dynamic> json) {
    return AccountData(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      channelId: json['Channel'] is int
          ? json['Channel']
          : int.tryParse(json['Channel']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'Channel': channelId,
    };
  }
}
