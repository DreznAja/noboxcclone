import 'package:dio/dio.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/app_config.dart';
import 'package:nobox_chat/core/providers/new_conversation_cache_provider.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart';
import 'package:nobox_chat/core/services/new_conversation_rest_service.dart';
import 'package:nobox_chat/core/services/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/new_conversation_service.dart' hide NewConversationService;
import '../../core/services/signalr_service.dart';
import '../../core/models/new_conversation_models.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/models/chat_models.dart';
import '../screens/chat/chat_screen.dart';

enum ChatType { private, group }
enum ToType { contact, link, manual }

class NewConversationDialog extends ConsumerStatefulWidget {
  const NewConversationDialog({super.key});

  @override
  ConsumerState<NewConversationDialog> createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends ConsumerState<NewConversationDialog> {
  ChatType _selectedChatType = ChatType.private;
  ToType _selectedToType = ToType.contact;
  
  String? _selectedChannelId;
  String? _selectedAccountId;
  String? _selectedContactId;
  String? _selectedLinkId;
  String? _selectedGroupId;


  String _manualNumber = '';
  final TextEditingController _manualController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoadingChannels = true;
  bool _isLoadingAccounts = false;
  bool _isLoadingContacts = false;
  bool _isLoadingLinks = false;
  bool _isLoadingGroups = false;
  
  List<ChannelOption> _channels = [];
  List<AccountOption> _accounts = [];
  List<ContactOption> _contacts = [];
  List<LinkOption> _links = [];
  List<GroupOption> _groups = [];
  
  final NewConversationService _service = NewConversationService();

  @override
  void initState() {
    super.initState();
    _loadChannels();
    // FIXED: Load contacts immediately since Contact is the default ToType
    _loadContacts();
  }

  @override
void dispose() {
  _manualController.dispose();
  super.dispose();
}

Future<void> _loadChannels() async {
  final cacheNotifier = ref.read(newConversationCacheProvider.notifier);
  final cachedChannels = ref.read(newConversationCacheProvider).channels;
  
  // Cek cache channels
  if (cachedChannels.isNotEmpty && !cacheNotifier.shouldRefresh()) {
    print('✅ Using cached channels');
    setState(() {
      _channels = cachedChannels;
      _isLoadingChannels = false;
    });
    return;
  }

  // Load dari API jika cache kosong/expired
  print('📡 Loading channels from API...');
  setState(() => _isLoadingChannels = true);
  try {
    final channels = await _service.getChannels();
    cacheNotifier.setChannels(channels);
    setState(() {
      _channels = channels;
      _isLoadingChannels = false;
    });
  } catch (e) {
    setState(() => _isLoadingChannels = false);
    _showError('Failed to load channels: $e');
  }
}

  // FIXED: Pass channelId parameter to filter accounts by channel
Future<void> _loadAccounts() async {
  if (_selectedChannelId == null) return;
  
  final cache = ref.read(newConversationCacheProvider);
  
  // Cek cache accounts untuk channel ini
  final cachedAccounts = ref.read(newConversationCacheProvider.notifier)
      .getAccountsForChannel(_selectedChannelId!);
  
  if (cachedAccounts != null && cachedAccounts.isNotEmpty && 
      !ref.read(newConversationCacheProvider.notifier).shouldRefresh()) {
    print('✅ Using cached accounts for channel $_selectedChannelId');
    setState(() {
      _accounts = cachedAccounts;
      _isLoadingAccounts = false;
    });
    return;
  }

  // Load dari API jika cache kosong/expired
  print('📡 Loading accounts from API for channel $_selectedChannelId...');
  setState(() => _isLoadingAccounts = true);
  try {
    final channelIdInt = int.tryParse(_selectedChannelId!);
    final accounts = await _service.getAccounts(channelId: channelIdInt);
    ref.read(newConversationCacheProvider.notifier)
        .setAccountsForChannel(_selectedChannelId!, accounts);
    setState(() {
      _accounts = accounts;
      _isLoadingAccounts = false;
    });
  } catch (e) {
    setState(() => _isLoadingAccounts = false);
    _showError('Failed to load accounts: $e');
  }
}

Future<void> _loadContacts() async {
  final cache = ref.read(newConversationCacheProvider);
  
  // Cek cache contacts
  if (cache.contacts.isNotEmpty && !ref.read(newConversationCacheProvider.notifier).shouldRefresh()) {
    print('✅ Using cached contacts');
    setState(() {
      _contacts = cache.contacts;
      _isLoadingContacts = false;
    });
    return;
  }

  // Load dari API jika cache kosong/expired
  print('📡 Loading contacts from API...');
  setState(() => _isLoadingContacts = true);
  try {
    final contacts = await _service.getContacts();
    ref.read(newConversationCacheProvider.notifier).setContacts(contacts);
    setState(() {
      _contacts = contacts;
      _isLoadingContacts = false;
    });
  } catch (e) {
    setState(() => _isLoadingContacts = false);
    _showError('Failed to load contacts: $e');
  }
}

Future<void> _loadLinks() async {
  final cache = ref.read(newConversationCacheProvider);
  
  // Cek cache links
  if (cache.links.isNotEmpty && !ref.read(newConversationCacheProvider.notifier).shouldRefresh()) {
    print('✅ Using cached links');
    setState(() {
      _links = cache.links;
      _isLoadingLinks = false;
    });
    return;
  }

  // Load dari API jika cache kosong/expired
  print('📡 Loading links from API...');
  setState(() => _isLoadingLinks = true);
  try {
    final links = await _service.getLinks();
    ref.read(newConversationCacheProvider.notifier).setLinks(links);
    setState(() {
      _links = links;
      _isLoadingLinks = false;
    });
  } catch (e) {
    setState(() => _isLoadingLinks = false);
    _showError('Failed to load links: $e');
  }
}

Future<void> _loadGroups() async {
  final cache = ref.read(newConversationCacheProvider);
  
  // Cek cache groups
  if (cache.groups.isNotEmpty && !ref.read(newConversationCacheProvider.notifier).shouldRefresh()) {
    print('✅ Using cached groups');
    setState(() {
      _groups = cache.groups;
      _isLoadingGroups = false;
    });
    return;
  }

  // Load dari API jika cache kosong/expired
  print('📡 Loading groups from API...');
  setState(() => _isLoadingGroups = true);
  try {
    final groups = await _service.getGroups();
    ref.read(newConversationCacheProvider.notifier).setGroups(groups);
    setState(() {
      _groups = groups;
      _isLoadingGroups = false;
    });
  } catch (e) {
    setState(() => _isLoadingGroups = false);
    _showError('Failed to load groups: $e');
  }
}

  void _onChatTypeChanged(ChatType? value) {
    if (value != null) {
      setState(() {
        _selectedChatType = value;
        // Reset selections when chat type changes
        _selectedContactId = null;
        _selectedLinkId = null;
        _selectedGroupId = null;
      });
      
      // Load appropriate data based on chat type
      if (value == ChatType.group) {
        _loadGroups();
      } else if (value == ChatType.private && _selectedToType == ToType.contact) {
        // FIXED: Only load contacts if not already loaded
        if (_contacts.isEmpty && !_isLoadingContacts) {
          _loadContacts();
        }
      } else if (value == ChatType.private && _selectedToType == ToType.link) {
        _loadLinks();
      }
    }
  }

  void _onChannelChanged(String? value) {
    setState(() {
      _selectedChannelId = value;
      _selectedAccountId = null; // Reset account when channel changes
      _accounts.clear(); // FIXED: Clear accounts list
    });
    
    // FIXED: Only load accounts if channel is selected
    if (value != null) {
      _loadAccounts();
    }
  }

void _onToTypeChanged(ToType? value) {
  if (value != null) {
    setState(() {
      _selectedToType = value;
      _selectedContactId = null;
      _selectedLinkId = null;
      _manualNumber = ''; // Reset manual number
      _manualController.clear(); // Clear controller
    });
    
    if (value == ToType.contact) {
      if (_contacts.isEmpty && !_isLoadingContacts) {
        _loadContacts();
      }
    } else if (value == ToType.link) {
      _loadLinks();
    }
    // ToType.manual tidak perlu load data
  }
}
// GANTI SELURUH METHOD _createConversation() di new_conversation_dialog.dart

// GANTI SELURUH METHOD _createConversation() di new_conversation_dialog.dart

Future<void> _createConversation() async {
  if (!_validateForm()) return;

  setState(() => _isLoading = true);

  try {
    String? targetId;
    String targetName = '';
    bool isPrivateChat = _selectedChatType == ChatType.private;
    bool isContact = _selectedToType == ToType.contact;
    bool isLink = _selectedToType == ToType.link;
    bool isManual = _selectedToType == ToType.manual;

    // --- STEP 1: Tentukan target & nama ---
    if (isPrivateChat) {
      if (isContact) {
        targetId = _selectedContactId;
        final contact = _contacts.firstWhere((c) => c.id == _selectedContactId);
        targetName = contact.name;
      } else if (isLink) {
        targetId = _selectedLinkId;
        final link = _links.firstWhere((l) => l.id == _selectedLinkId);
        targetName = link.name;
      } else if (isManual) {
        targetId = null;
        targetName = _manualNumber.trim();
      }
    } else {
      targetId = _selectedGroupId;
      final group = _groups.firstWhere((g) => g.id == _selectedGroupId);
      targetName = group.name;
    }

    print('📞 Creating new room...');
    print('  - Chat Type: ${isPrivateChat ? 'Private' : 'Group'}');
    print('  - To Type: ${isContact ? 'Contact' : isLink ? 'Link' : 'Manual'}');
    print('  - Target ID: $targetId');
    print('  - Target Name: $targetName');
    print('  - Channel ID: $_selectedChannelId');
    print('  - Account ID: $_selectedAccountId');

    // --- STEP 2: Create new room ---
    print('🚀 Calling CreateNewRoom API...');
    
    final accountIdInt = int.tryParse(_selectedAccountId ?? '') ?? 0;
    final channelIdInt = int.tryParse(_selectedChannelId ?? '') ?? 1;
    final targetIdInt = int.tryParse(targetId ?? '') ?? 0;
    
    final requestData = {
      "AccId": accountIdInt,
      "ChId": channelIdInt,
      "LinkId": null,
      "GrpId": null,
      "Chat": 0,
      "CtId": null,
      "Manual": "",
      "To": 1
    };

    if (isPrivateChat) {
      if (isContact) {
        requestData["CtId"] = targetIdInt;
        requestData["To"] = 1;
      } else if (isLink) {
        requestData["LinkId"] = targetIdInt;
        requestData["To"] = 2;
      } else if (isManual) {
        requestData["Manual"] = _manualNumber.trim();
        requestData["To"] = 3;
        requestData["CtId"] = null;
      }
    } else {
      requestData["GrpId"] = targetIdInt;
      requestData["Chat"] = 1;
      requestData["To"] = 3;
    }

    print('📤 Request data: $requestData');

    final result = await _createNewRoomApi(requestData);
    print('✅ CreateNewRoom API response: $result');

    if (result != null && result['success'] == true) {
      // Wait untuk room muncul di list
      final delayDuration = isManual 
        ? const Duration(seconds: 2)
        : const Duration(milliseconds: 1500);
      
      await Future.delayed(delayDuration);
      
      // Refresh room list
      await ref.read(chatProvider.notifier).loadRooms();
      
      final chatState = ref.read(chatProvider);
      Room? newRoom;
      
      // ===== METHOD 1: Cari by roomId dari API response (PALING AKURAT) =====
      if (result['roomId'] != null) {
        final roomId = result['roomId'].toString();
        print('🔍 [Method 1] Searching by roomId from API: $roomId');
        
        try {
          newRoom = chatState.rooms.firstWhere(
            (room) => room.id == roomId,
            orElse: () => throw Exception('Not found'),
          );
          print('✅ [Method 1] SUCCESS - Found room: ${newRoom.name} (ID: ${newRoom.id})');
        } catch (e) {
          print('❌ [Method 1] FAILED - Room ID $roomId not in list yet');
        }
      }
      
      // ===== METHOD 2: Cari by Link ID (khusus untuk Link) =====
      if (newRoom == null && isLink && targetId != null) {
        print('🔍 [Method 2] Searching by Link ID: $targetId');
        
        try {
          // PERBAIKAN UTAMA UNTUK LINK:
          // Link room bisa dicari dengan ctId (yang sebenarnya adalah LinkId)
          newRoom = chatState.rooms.firstWhere(
            (room) {
              // Debug log setiap room
              final matchById = room.id == targetId;
              final matchByCtId = room.ctId == targetId;
              
              if (matchById || matchByCtId) {
                print('   🎯 Potential match found:');
                print('      Room ID: ${room.id}');
                print('      Room Name: ${room.name}');
                print('      Room ctId: ${room.ctId}');
                print('      Room ctRealId: ${room.ctRealId}');
                print('      Room Channel: ${room.channelId}');
                print('      Target ID: $targetId');
                print('      Match by ID: $matchById');
                print('      Match by ctId: $matchByCtId');
              }
              
              return matchById || matchByCtId;
            },
            orElse: () => throw Exception('Not found'),
          );
          
          print('✅ [Method 2] SUCCESS - Found link room: ${newRoom.name} (ID: ${newRoom.id})');
        } catch (e) {
          print('❌ [Method 2] FAILED - Link ID $targetId not found');
          
          // Debug: Print all rooms to see what's available
          print('📋 Available rooms in list:');
          for (var room in chatState.rooms.take(5)) {
            print('   - ID: ${room.id}, Name: ${room.name}, ctId: ${room.ctId}, Channel: ${room.channelId}');
          }
        }
      }
      
      // ===== METHOD 3: Cari by Contact ID (khusus untuk Contact) =====
      if (newRoom == null && isContact && targetId != null) {
        print('🔍 [Method 3] Searching by Contact ID: $targetId');
        
        try {
          newRoom = chatState.rooms.firstWhere(
            (room) {
              final matchByCtId = room.ctId == targetId;
              final matchByCtRealId = room.ctRealId == targetId;
              
              return matchByCtId || matchByCtRealId;
            },
            orElse: () => throw Exception('Not found'),
          );
          
          print('✅ [Method 3] SUCCESS - Found contact room: ${newRoom.name} (ID: ${newRoom.id})');
        } catch (e) {
          print('❌ [Method 3] FAILED - Contact ID $targetId not found');
        }
      }
      
      // ===== METHOD 4: Cari by Manual number =====
      if (newRoom == null && isManual && chatState.rooms.isNotEmpty) {
        print('🔍 [Method 4] Searching manual room by number: $targetName');
        
        try {
          final now = DateTime.now();
          final recentRooms = chatState.rooms.where((room) {
            final isCorrectChannel = room.channelId.toString() == _selectedChannelId;
            final nameContainsNumber = room.name.contains(targetName);
            final isVeryRecent = room.lastMessageTime != null && 
                                  now.difference(room.lastMessageTime!).inSeconds < 10;
            
            return isCorrectChannel && (nameContainsNumber || isVeryRecent);
          }).toList();
          
          if (recentRooms.isNotEmpty) {
            recentRooms.sort((a, b) {
              if (a.lastMessageTime == null) return 1;
              if (b.lastMessageTime == null) return -1;
              return b.lastMessageTime!.compareTo(a.lastMessageTime!);
            });
            
            newRoom = recentRooms.first;
            print('✅ [Method 4] SUCCESS - Found manual room: ${newRoom.name} (ID: ${newRoom.id})');
          }
        } catch (e) {
          print('❌ [Method 4] FAILED - Error: $e');
        }
      }
      
      // ===== METHOD 5: Fallback - Room paling baru dengan channel & account yang sama =====
      if (newRoom == null && chatState.rooms.isNotEmpty) {
        print('🔍 [Method 5 - FALLBACK] Searching most recent room with same channel & account');
        
        try {
          final now = DateTime.now();
          // Filter by channel AND account untuk lebih spesifik
          final matchingRooms = chatState.rooms.where((room) {
            final channelMatch = room.channelId.toString() == _selectedChannelId;
            
            // PERBAIKAN: Cek juga accountName atau botName
            // Karena accountName adalah display name dari account yang dipilih
            final selectedAccount = _accounts.firstWhere(
              (acc) => acc.id == _selectedAccountId,
              orElse: () => AccountOption(id: '', name: ''),
            );
            
            final accountMatch = room.accountName == selectedAccount.name ||
                                 room.botName == selectedAccount.name;
            
            // Hanya ambil room yang dibuat dalam 10 detik terakhir
            final isRecent = room.lastMessageTime != null && now.difference(room.lastMessageTime!).inSeconds < 10;
            
            final matches = channelMatch && accountMatch && isRecent;
            
            if (matches) {
              print('   🎯 Potential fallback match:');
              print('      Room: ${room.name} (${room.id})');
              print('      Channel: ${room.channelId} vs $_selectedChannelId');
              print('      Account: ${room.accountName} vs ${selectedAccount.name}');
              print('      Age: ${room.lastMessageTime != null ? now.difference(room.lastMessageTime!).inSeconds : -1}s');
            }
            
            return matches;
          }).toList();
          
          if (matchingRooms.isNotEmpty) {
            // Sort by time - ambil yang paling baru
            matchingRooms.sort((a, b) {
              if (a.lastMessageTime == null) return 1;
              if (b.lastMessageTime == null) return -1;
              return b.lastMessageTime!.compareTo(a.lastMessageTime!);
            });
            
            newRoom = matchingRooms.first;
            print('✅ [Method 5] SUCCESS - Found by fallback: ${newRoom.name} (ID: ${newRoom.id})');
          } else {
            print('❌ [Method 5] FAILED - No matching rooms found');
          }
        } catch (e) {
          print('❌ [Method 5] ERROR: $e');
        }
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog

        if (newRoom != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Conversation created: ${newRoom.name}'),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
          
          print('🎯 ===== FINAL NAVIGATION =====');
          print('   Room ID: ${newRoom.id}');
          print('   Room Name: ${newRoom.name}');
          print('   Room ctId: ${newRoom.ctId}');
          print('   Room ctRealId: ${newRoom.ctRealId}');
          print('   Channel: ${newRoom.channelId}');
          print('   Account: ${newRoom.accountName}');
          print('==============================');
          
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                room: newRoom!,
                isNewConversation: true,
              ),
            ),
          );
        } else {
          print('❌ ===== NO ROOM FOUND =====');
          print('   All methods failed to find the created room');
          print('   Total rooms in list: ${chatState.rooms.length}');
          print('============================');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Conversation created but could not open chat.\nPlease check your inbox.'),
              backgroundColor: AppTheme.warningColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      final errorMsg = result?['error'] ?? 'Failed to create conversation';
      _showError('Failed to create conversation: $errorMsg');
      setState(() => _isLoading = false);
    }

  } catch (e) {
    print('❌ Error creating conversation: $e');
    _showError('Failed to create conversation: ${e.toString()}');
    setState(() => _isLoading = false);
  }
}

// Alternatif: Gunakan endpoint langsung dari contoh teman
Future<Map<String, dynamic>?> _createNewRoomApi(Map<String, dynamic> data) async {
  try {
    final dio = Dio();
    final token = await StorageService.getToken();
    
    if (token == null) {
      print('❌ No token found');
      return {'success': false, 'error': 'No authentication token'};
    }

    // Gunakan endpoint langsung dari contoh teman
    final url = "https://id.nobox.ai/Inbox/CreateNewRoom";
    
    print('🌐 Calling CreateNewRoom API: $url');
    print('🔑 Using token: ${token.length > 20 ? token.substring(0, 20) + "..." : token}');

    final response = await dio.post(
      url,
      data: data,
      options: Options(
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      ),
    );

    print('📥 Response status: ${response.statusCode}');
    print('📥 Response data: ${response.data}');

    if (response.statusCode == 200) {
      final responseData = response.data;
      
      if (responseData is Map) {
        final result = Map<String, dynamic>.from(responseData);
        
        if (result['IsError'] == true) {
          return {
            'success': false,
            'error': result['ErrorMessage'] ?? result['Error'] ?? 'API error'
          };
        }
        
        return {
          'success': true,
          'roomId': result['Data']?['Id'] ?? result['Data']?['RoomId'] ?? result['Id'],
          'data': result['Data']
        };
      }
      return {'success': true, 'data': responseData};
    }
    
    return {
      'success': false,
      'error': 'HTTP ${response.statusCode}: ${response.statusMessage}'
    };
    
  } catch (e) {
    print('❌ API Error: $e');
    
    if (e is DioException) {
      print('📡 Dio Error Type: ${e.type}');
      print('📡 Dio Error Message: ${e.message}');
      print('📡 Dio Response Status: ${e.response?.statusCode}');
      print('📡 Dio Response Data: ${e.response?.data}');
      print('📡 Dio Request URL: ${e.requestOptions.uri}');
      
      // Debug: Print full request untuk diperiksa
      print('🔍 Full Request Details:');
      print('  URL: ${e.requestOptions.uri}');
      print('  Headers: ${e.requestOptions.headers}');
      print('  Data: ${e.requestOptions.data}');
      
      return {
        'success': false,
        'error': 'API Error: ${e.message}',
        'statusCode': e.response?.statusCode,
        'url': e.requestOptions.uri.toString(),
      };
    }
    
    return {'success': false, 'error': e.toString()};
  }
}

 bool _validateForm() {
  if (_selectedChannelId == null) {
    _showError('Please select a channel');
    return false;
  }
  
  if (_selectedAccountId == null) {
    _showError('Please select an account');
    return false;
  }
  
  if (_selectedChatType == ChatType.private) {
    if (_selectedToType == ToType.contact && _selectedContactId == null) {
      _showError('Please select a contact');
      return false;
    }
    if (_selectedToType == ToType.link && _selectedLinkId == null) {
      _showError('Please select a link');
      return false;
    }
    // TAMBAHKAN VALIDASI MANUAL
    if (_selectedToType == ToType.manual && _manualNumber.trim().isEmpty) {
      _showError('Please enter a phone number');
      return false;
    }
  } else {
    if (_selectedGroupId == null) {
      _showError('Please select a group');
      return false;
    }
  }
  
  return true;
}

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

return Dialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkBackground : Colors.white, // UPDATE INI
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'New Conversation',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode 
                    ? AppTheme.darkTextPrimary 
                    : AppTheme.primaryColor, // UPDATE INI
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close,
                  color: isDarkMode 
                    ? AppTheme.darkTextPrimary 
                    : AppTheme.primaryColor, // UPDATE INI
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Form fields - pass isDarkMode to all builder methods
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildDropdownField(
                    'Chat',
                    _selectedChatType == ChatType.private ? 'Private' : 'Group',
                    ['Private', 'Group'],
                    (value) => _onChatTypeChanged(
                      value == 'Private' ? ChatType.private : ChatType.group
                    ),
                    isDarkMode: isDarkMode, // TAMBAHKAN
                    isRequired: true,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildChannelDropdown(isDarkMode), // TAMBAHKAN PARAMETER
                  
                  const SizedBox(height: 16),
                  
                  _buildAccountDropdown(isDarkMode), // TAMBAHKAN PARAMETER
                  
                  const SizedBox(height: 16),
                  
                  if (_selectedChatType == ChatType.private) ...[
                    _buildRadioField(isDarkMode), // TAMBAHKAN PARAMETER
                    
                    const SizedBox(height: 16),
                    
                    if (_selectedToType == ToType.contact)
                      _buildContactDropdown(isDarkMode)
                    else if (_selectedToType == ToType.link)
                      _buildLinkDropdown(isDarkMode)
                    else if (_selectedToType == ToType.manual)
                      _buildManualInput(isDarkMode),
                  ],
                  
                  if (_selectedChatType == ChatType.group) ...[
                    _buildGroupDropdown(isDarkMode), // TAMBAHKAN PARAMETER
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDarkMode 
                        ? AppTheme.darkTextPrimary 
                        : AppTheme.primaryColor, // UPDATE INI
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDarkMode 
                        ? AppTheme.darkTextPrimary 
                        : AppTheme.primaryColor, // UPDATE INI
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createConversation,
                  child: _isLoading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white, // TAMBAHKAN
                          ),
                        )
                      : const Text('Create'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor, // Tetap biru
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}


Widget _buildDropdownField(
  String label,
  String? value,
  List<String> options,
  Function(String?) onChanged, {
  required bool isDarkMode,
  bool isRequired = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
            ),
          ),
        ),
        Expanded(
          child: DropdownSearch<String>(
            items: options,
            selectedItem: options.contains(value) ? value : null,
            onChanged: onChanged,
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                hintText: '--select--',
                hintStyle: TextStyle(
                  color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            popupProps: PopupProps.menu(
              showSearchBox: true,
              constraints: const BoxConstraints(maxHeight: 200),
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(
                    color: isDarkMode 
                      ? AppTheme.darkTextSecondary.withOpacity(0.5)
                      : Colors.grey.shade400,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: isDarkMode 
                    ? AppTheme.darkBackground.withOpacity(0.5)
                    : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDarkMode 
                        ? Colors.white.withOpacity(0.1) 
                        : Colors.grey.shade200,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
              menuProps: MenuProps(
                backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              itemBuilder: (context, item, isSelected) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : Colors.transparent,
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              },
              emptyBuilder: (context, searchEntry) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 40,
                        color: isDarkMode 
                          ? AppTheme.darkTextSecondary.withOpacity(0.5)
                          : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No results found',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode 
                            ? AppTheme.darkTextSecondary 
                            : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            dropdownButtonProps: DropdownButtonProps(
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isDarkMode ? AppTheme.darkTextPrimary : Colors.grey.shade600,
              ),
            ),
            dropdownBuilder: (context, selectedItem) {
  return Text(
    selectedItem ?? '--select--',
    style: TextStyle(
      color: isDarkMode ? Colors.white : Colors.black,
      fontSize: 14,
    ),
  );
},
          ),
        ),
      ],
    ),
  );
}

Widget _buildManualInput(bool isDarkMode) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            'Manual',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: _manualController,
            onChanged: (value) => setState(() => _manualNumber = value),
            keyboardType: TextInputType.phone,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
            ),
            decoration: InputDecoration(
              hintText: '62xx',
              hintStyle: TextStyle(
                color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                fontSize: 14,
              ),
              filled: true,
              fillColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildChannelDropdown(bool isDarkMode) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            'Channel',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
            ),
          ),
        ),
        Expanded(
          child: _isLoadingChannels
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppTheme.darkSurface : Colors.white,
                    border: Border.all(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Loading channels...',
                        style: TextStyle(
                          color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : DropdownSearch<ChannelOption>(
                  items: _channels,
                  itemAsString: (ChannelOption item) => item.name,
                  selectedItem: _channels.where((c) => c.id == _selectedChannelId).firstOrNull,
                  onChanged: (ChannelOption? selected) => _onChannelChanged(selected?.id),
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      hintText: '--select--',
                      hintStyle: TextStyle(
                        color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    constraints: const BoxConstraints(maxHeight: 200),
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(
                          color: isDarkMode 
                            ? AppTheme.darkTextSecondary.withOpacity(0.5)
                            : Colors.grey.shade400,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: isDarkMode 
                          ? AppTheme.darkBackground.withOpacity(0.5)
                          : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDarkMode 
                              ? Colors.white.withOpacity(0.1) 
                              : Colors.grey.shade200,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                    ),
                    menuProps: MenuProps(
                      backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    itemBuilder: (context, item, isSelected) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.transparent,
                        ),
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                    emptyBuilder: (context, searchEntry) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 40,
                              color: isDarkMode 
                                ? AppTheme.darkTextSecondary.withOpacity(0.5)
                                : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No results found',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode 
                                  ? AppTheme.darkTextSecondary 
                                  : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  dropdownButtonProps: DropdownButtonProps(
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDarkMode ? AppTheme.darkTextPrimary : Colors.grey.shade600,
                    ),
                  ),
                  dropdownBuilder: (context, selectedItem) {
  return Text(
    selectedItem?.name ?? '--select--',
    style: TextStyle(
      color: isDarkMode ? Colors.white : Colors.black,
      fontSize: 14,
    ),
    overflow: TextOverflow.ellipsis,
  );
},
                ),
        ),
      ],
    ),
  );
}

Widget _buildAccountDropdown(bool isDarkMode) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            'Account',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
            ),
          ),
        ),
        Expanded(
          child: _isLoadingAccounts
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppTheme.darkSurface : Colors.white,
                    border: Border.all(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Loading accounts...',
                        style: TextStyle(
                          color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : DropdownSearch<AccountOption>(
                  items: _accounts,
                  itemAsString: (AccountOption item) => item.name,
                  selectedItem: _accounts.where((a) => a.id == _selectedAccountId).firstOrNull,
                  onChanged: _selectedChannelId == null 
                    ? null 
                    : (AccountOption? selected) => setState(() => _selectedAccountId = selected?.id),
                  enabled: _selectedChannelId != null,
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      hintText: '--select--',
                      hintStyle: TextStyle(
                        color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    constraints: const BoxConstraints(maxHeight: 200),
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(
                          color: isDarkMode 
                            ? AppTheme.darkTextSecondary.withOpacity(0.5)
                            : Colors.grey.shade400,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: isDarkMode 
                          ? AppTheme.darkBackground.withOpacity(0.5)
                          : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDarkMode 
                              ? Colors.white.withOpacity(0.1) 
                              : Colors.grey.shade200,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                    ),
                    menuProps: MenuProps(
                      backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    itemBuilder: (context, item, isSelected) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.transparent,
                        ),
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                    emptyBuilder: (context, searchEntry) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 40,
                              color: isDarkMode 
                                ? AppTheme.darkTextSecondary.withOpacity(0.5)
                                : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No results found',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode 
                                  ? AppTheme.darkTextSecondary 
                                  : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  dropdownButtonProps: DropdownButtonProps(
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDarkMode ? AppTheme.darkTextPrimary : Colors.grey.shade600,
                    ),
                  ),
                  dropdownBuilder: (context, selectedItem) {
  return Text(
    selectedItem?.name ?? '--select--',
    style: TextStyle(
      color: isDarkMode ? Colors.white : Colors.black,
      fontSize: 14,
    ),
    overflow: TextOverflow.ellipsis,
  );
},
                ),
        ),
      ],
    ),
  );
}

Widget _buildRadioField(bool isDarkMode) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start, // TAMBAHKAN INI
    children: [
      SizedBox(
        width: 80,
        child: Text(
          'To',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
          ),
        ),
      ),
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDarkMode 
                ? Colors.grey.shade700 
                : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isDarkMode ? AppTheme.darkSurface : Colors.white,
          ),
          child: Column( // GANTI ROW JADI COLUMN
            crossAxisAlignment: CrossAxisAlignment.start, // TAMBAHKAN
            children: [
              // Baris 1: Contact dan Link
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Contact Radio
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<ToType>(
                        value: ToType.contact,
                        groupValue: _selectedToType,
                        onChanged: _onToTypeChanged,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        activeColor: AppTheme.primaryColor,
                      ),
                      Text(
                        'Contact',
                        style: TextStyle(
                          color: isDarkMode 
                            ? AppTheme.darkTextPrimary 
                            : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Link Radio
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<ToType>(
                        value: ToType.link,
                        groupValue: _selectedToType,
                        onChanged: _onToTypeChanged,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        activeColor: AppTheme.primaryColor,
                      ),
                      Text(
                        'Link',
                        style: TextStyle(
                          color: isDarkMode 
                            ? AppTheme.darkTextPrimary 
                            : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Baris 2: Manual (DI BAWAH)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<ToType>(
                    value: ToType.manual,
                    groupValue: _selectedToType,
                    onChanged: _onToTypeChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    activeColor: AppTheme.primaryColor,
                  ),
                  Text(
                    'Manual',
                    style: TextStyle(
                      color: isDarkMode 
                        ? AppTheme.darkTextPrimary 
                        : Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildContactDropdown(bool isDarkMode) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            'Contact',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
            ),
          ),
        ),
        Expanded(
          child: _isLoadingContacts
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppTheme.darkSurface : Colors.white,
                    border: Border.all(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Loading contacts...',
                        style: TextStyle(
                          color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : DropdownSearch<ContactOption>(
                  items: _contacts,
                  itemAsString: (ContactOption item) => item.name,
                  selectedItem: _contacts.where((c) => c.id == _selectedContactId).firstOrNull,
                  onChanged: (ContactOption? selected) => setState(() => _selectedContactId = selected?.id),
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      hintText: '--select--',
                      hintStyle: TextStyle(
                        color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    constraints: const BoxConstraints(maxHeight: 200),
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(
                          color: isDarkMode 
                            ? AppTheme.darkTextSecondary.withOpacity(0.5)
                            : Colors.grey.shade400,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: isDarkMode 
                          ? AppTheme.darkBackground.withOpacity(0.5)
                          : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDarkMode 
                              ? Colors.white.withOpacity(0.1) 
                              : Colors.grey.shade200,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                    ),
                    menuProps: MenuProps(
                      backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    itemBuilder: (context, item, isSelected) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.transparent,
                        ),
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                    emptyBuilder: (context, searchEntry) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 40,
                              color: isDarkMode 
                                ? AppTheme.darkTextSecondary.withOpacity(0.5)
                                : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No results found',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode 
                                  ? AppTheme.darkTextSecondary 
                                  : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  dropdownButtonProps: DropdownButtonProps(
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDarkMode ? AppTheme.darkTextPrimary : Colors.grey.shade600,
                    ),
                  ),
                  dropdownBuilder: (context, selectedItem) {
  return Text(
    selectedItem?.name ?? '--select--',
    style: TextStyle(
      color: isDarkMode ? Colors.white : Colors.black,
      fontSize: 14,
    ),
    overflow: TextOverflow.ellipsis,
  );
},
                ),
        ),
      ],
    ),
  );
}

Widget _buildLinkDropdown(bool isDarkMode) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            'Link',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
            ),
          ),
        ),
        Expanded(
          child: _isLoadingLinks
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppTheme.darkSurface : Colors.white,
                    border: Border.all(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Loading links...',
                        style: TextStyle(
                          color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : DropdownSearch<LinkOption>(
                  items: _links,
                  itemAsString: (LinkOption item) => item.name,
                  selectedItem: _links.where((l) => l.id == _selectedLinkId).firstOrNull,
                  onChanged: (LinkOption? selected) => setState(() => _selectedLinkId = selected?.id),
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      hintText: '--select--',
                      hintStyle: TextStyle(
                        color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    constraints: const BoxConstraints(maxHeight: 200),
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(
                          color: isDarkMode 
                            ? AppTheme.darkTextSecondary.withOpacity(0.5)
                            : Colors.grey.shade400,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: isDarkMode 
                          ? AppTheme.darkBackground.withOpacity(0.5)
                          : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDarkMode 
                              ? Colors.white.withOpacity(0.1) 
                              : Colors.grey.shade200,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                    ),
                    menuProps: MenuProps(
                      backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    itemBuilder: (context, item, isSelected) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.transparent,
                        ),
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                    emptyBuilder: (context, searchEntry) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 40,
                              color: isDarkMode 
                                ? AppTheme.darkTextSecondary.withOpacity(0.5)
                                : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No results found',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode 
                                  ? AppTheme.darkTextSecondary 
                                  : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  dropdownButtonProps: DropdownButtonProps(
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDarkMode ? AppTheme.darkTextPrimary : Colors.grey.shade600,
                    ),
                  ),
                  dropdownBuilder: (context, selectedItem) {
  return Text(
    selectedItem?.name ?? '--select--',
    style: TextStyle(
      color: isDarkMode ? Colors.white : Colors.black,
      fontSize: 14,
    ),
    overflow: TextOverflow.ellipsis,
  );
},
                ),
        ),
      ],
    ),
  );
}

Widget _buildGroupDropdown(bool isDarkMode) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            'Group',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
            ),
          ),
        ),
        Expanded(
          child: _isLoadingGroups
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppTheme.darkSurface : Colors.white,
                    border: Border.all(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Loading groups...',
                        style: TextStyle(
                          color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : DropdownSearch<GroupOption>(
                  items: _groups,
                  itemAsString: (GroupOption item) => item.name,
                  selectedItem: _groups.where((g) => g.id == _selectedGroupId).firstOrNull,
                  onChanged: (GroupOption? selected) => setState(() => _selectedGroupId = selected?.id),
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      hintText: '--select--',
                      hintStyle: TextStyle(
                        color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                                            enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    constraints: const BoxConstraints(maxHeight: 200),
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(
                          color: isDarkMode 
                            ? AppTheme.darkTextSecondary.withOpacity(0.5)
                            : Colors.grey.shade400,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: isDarkMode 
                          ? AppTheme.darkBackground.withOpacity(0.5)
                          : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDarkMode 
                              ? Colors.white.withOpacity(0.1) 
                              : Colors.grey.shade200,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                    ),
                    menuProps: MenuProps(
                      backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    itemBuilder: (context, item, isSelected) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.transparent,
                        ),
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                    emptyBuilder: (context, searchEntry) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 40,
                              color: isDarkMode 
                                ? AppTheme.darkTextSecondary.withOpacity(0.5)
                                : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No results found',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode 
                                  ? AppTheme.darkTextSecondary 
                                  : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  dropdownButtonProps: DropdownButtonProps(
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDarkMode ? AppTheme.darkTextPrimary : Colors.grey.shade600,
                    ),
                  ),
                  dropdownBuilder: (context, selectedItem) {
  return Text(
    selectedItem?.name ?? '--select--',
    style: TextStyle(
      color: isDarkMode ? Colors.white : Colors.black,
      fontSize: 14,
    ),
    overflow: TextOverflow.ellipsis,
  );
},
                ),
        ),
      ],
    ),
  );
}
}