import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/new_conversation_service.dart';
import '../../core/services/api_service.dart';
import '../../core/models/new_conversation_models.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/models/chat_models.dart';
import '../screens/chat/chat_screen.dart';

enum ChatType { private, group }
enum ToType { contact, link }

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

  Future<void> _loadChannels() async {
    setState(() => _isLoadingChannels = true);
    try {
      final channels = await _service.getChannels();
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
    
    setState(() => _isLoadingAccounts = true);
    try {
      // FIXED: Parse channelId to int and pass it to getAccounts
      final channelIdInt = int.tryParse(_selectedChannelId!);
      final accounts = await _service.getAccounts(channelId: channelIdInt);
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
    setState(() => _isLoadingContacts = true);
    try {
      final contacts = await _service.getContacts();
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
    setState(() => _isLoadingLinks = true);
    try {
      final links = await _service.getLinks();
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
    setState(() => _isLoadingGroups = true);
    try {
      final groups = await _service.getGroups();
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
      });
      
      if (value == ToType.contact) {
        // FIXED: Only load contacts if not already loaded
        if (_contacts.isEmpty && !_isLoadingContacts) {
          _loadContacts();
        }
      } else {
        _loadLinks();
      }
    }
  }

  Future<void> _createConversation() async {
    if (!_validateForm()) return;
    
    setState(() => _isLoading = true);
    
    try {
      String? targetId;
      String targetName = '';
      
      // Get target information
      if (_selectedChatType == ChatType.private) {
        if (_selectedToType == ToType.contact) {
          targetId = _selectedContactId;
          final contact = _contacts.firstWhere((c) => c.id == _selectedContactId);
          targetName = contact.name;
        } else {
          targetId = _selectedLinkId;
          final link = _links.firstWhere((l) => l.id == _selectedLinkId);
          targetName = link.name;
        }
      } else {
        targetId = _selectedGroupId;
        final group = _groups.firstWhere((g) => g.id == _selectedGroupId);
        targetName = group.name;
      }
      
      if (targetId == null) {
        _showError('Please select a target for the conversation');
        setState(() => _isLoading = false);
        return;
      }
      
      print('Creating conversation with targetId: $targetId');
      
      // FIXED: Try to get existing room details first
      // But if resolved (status = 3), treat as new conversation
      Room? existingRoom;
      try {
        print('Checking for existing room with targetId: $targetId');
        
        // Try to find existing room in current room list first
        final chatState = ref.read(chatProvider);
        existingRoom = chatState.rooms.firstWhere(
          (room) {
            // Check if this room matches the target
            if (_selectedChatType == ChatType.group) {
              return room.grpId == targetId;
            } else if (_selectedToType == ToType.contact) {
              return room.ctId == targetId || room.ctRealId == targetId;
            } else {
              // For links, the room ID might be the same as targetId
              return room.id == targetId;
            }
          },
          orElse: () => Room(
            id: '',
            name: '',
            status: 0,
            channelId: 0,
            channelName: '',
          ),
        );
        
        // FIXED: If room exists but is resolved (status = 3), treat as new conversation
        if (existingRoom.id.isNotEmpty) {
          if (existingRoom.status == 3) {
            print('Found resolved room: ${existingRoom.id} - Creating new conversation instead');
            existingRoom = null; // Force create new conversation
          } else {
            print('Found existing active room: ${existingRoom.id} - ${existingRoom.name} (status: ${existingRoom.status})');
          }
        } else {
          existingRoom = null;
        }
      } catch (e) {
        print('No existing room found in memory: $e');
        existingRoom = null;
      }
      
      // If no existing room found, create a new room object
      if (existingRoom == null) {
        print('Creating new room object for targetId: $targetId');
        
        // Create room with proper structure for new conversations
        existingRoom = Room(
          id: targetId, // Use targetId as room ID for new conversations
          ctId: _selectedChatType == ChatType.private && _selectedToType == ToType.contact ? targetId : null,
          ctRealId: _selectedChatType == ChatType.private && _selectedToType == ToType.contact ? targetId : null,
          grpId: _selectedChatType == ChatType.group ? targetId : null,
          name: targetName.isNotEmpty ? targetName : 'New Conversation',
          lastMessage: null,
          lastMessageTime: DateTime.now(),
          unreadCount: 0,
          status: 1, // Unassigned
          channelId: int.tryParse(_selectedChannelId!) ?? 1,
          channelName: _channels.firstWhere((c) => c.id == _selectedChannelId).name,
          contactImage: null,
          linkImage: null,
          isGroup: _selectedChatType == ChatType.group,
          isPinned: false,
          isBlocked: false,
          isMuteBot: false,
          tags: [],
          funnel: null,
        );
        
        print('Created new room object: ${existingRoom.id} - ${existingRoom.name}');
      }
      
      // IMPORTANT: For truly new conversations, create the room at server immediately
      // by sending an empty message
      if (existingRoom != null && existingRoom!.status == 1 && 
          (existingRoom!.lastMessage == null || existingRoom!.lastMessage!.isEmpty)) {
        print('🆕 Creating NEW conversation at server by sending empty message');
        
        try {
          // Send empty message to create room at server
          final createRoomData = {
            'LinkId': int.tryParse(targetId!),
            'ChannelId': int.tryParse(_selectedChannelId!) ?? 1,
            'AccountIds': _selectedAccountId!,
            'BodyType': 1, // Text message
            'Body': '', // Empty body to just create the room
            'Attachment': '',
          };
          
          print('📤 Creating room at server: LinkId=${targetId}, ChannelId=${_selectedChannelId}, AccountId=${_selectedAccountId}');
          
          final response = await ApiService.sendMessage(createRoomData);
          
          if (response.isError) {
            print('❌ Failed to create room at server: ${response.error}');
            // Don't return - continue with local room, user can send message manually
          } else {
            print('✅ Room created successfully at server');
          }
          
          // Wait a bit for server to process
          await Future.delayed(const Duration(milliseconds: 800));
          
          // Refresh room list to get the newly created room from server
          print('🔄 Refreshing room list to get new room from server');
          await ref.read(chatProvider.notifier).loadRooms();
          
          // Try to find the created room in the refreshed list
          final chatState = ref.read(chatProvider);
          final createdRoom = chatState.rooms.firstWhere(
            (room) {
              if (_selectedChatType == ChatType.group) {
                return room.grpId == targetId;
              } else if (_selectedToType == ToType.contact) {
                return room.ctId == targetId || room.ctRealId == targetId;
              } else {
                return room.id == targetId;
              }
            },
            orElse: () => existingRoom!, // Fallback to local room object
          );
          
          print('✅ Found created room: ${createdRoom.id} - ${createdRoom.name} (status: ${createdRoom.status})');
          
          // Use the room from server (which has proper room ID and data)
          existingRoom = createdRoom as Room?;
        } catch (e) {
          print('❌ Exception creating room at server: $e');
          // Don't fail - just continue with local room
        }
      }
      
      if (mounted) {
        // Close dialog
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversation created: ${targetName}'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Navigate to ChatScreen with the created room
        print('Navigating to ChatScreen with room: ${existingRoom?.id}');
        
        final isNewConversation = existingRoom?.status == 1 && (existingRoom?.lastMessage == null || existingRoom?.lastMessage?.isEmpty == true);
        
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              room: existingRoom!,
              isNewConversation: isNewConversation,
            ),
          ),
        );
      }
      
    } catch (e) {
      print('Error creating conversation: $e');
      _showError('Failed to create conversation: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateForm() {
    if (_selectedChannelId == null) {
      _showError('Please select a channel');
      return false;
    }
    
    // FIXED: Don't require account selection if no accounts are available for the selected channel
    if (_accounts.isEmpty) {
      _showError('No accounts available for the selected channel');
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
                      _buildContactDropdown(isDarkMode) // TAMBAHKAN PARAMETER
                    else
                      _buildLinkDropdown(isDarkMode), // TAMBAHKAN PARAMETER
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
  required bool isDarkMode, // TAMBAHKAN
  bool isRequired = false,
}) {
  return Row(
    children: [
      SizedBox(
        width: 80,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black, // UPDATE
          ),
        ),
      ),
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDarkMode 
                ? Colors.grey.shade700 
                : Colors.grey.shade300, // UPDATE
            ),
            borderRadius: BorderRadius.circular(8),
            color: isDarkMode ? AppTheme.darkSurface : Colors.white, // TAMBAHKAN
          ),
          child: DropdownButton<String>(
            value: options.contains(value) ? value : null,
            hint: Text(
              '--select--', 
              style: TextStyle(
                color: isDarkMode 
                  ? AppTheme.darkTextSecondary 
                  : Colors.grey, // UPDATE
              ),
            ),
            isExpanded: true,
            underline: const SizedBox(),
            iconEnabledColor: isDarkMode 
              ? AppTheme.darkTextPrimary 
              : Colors.black, // UPDATE
            style: TextStyle(
              color: isDarkMode 
                ? AppTheme.darkTextPrimary 
                : Colors.black, // UPDATE
            ),
            dropdownColor: isDarkMode 
              ? AppTheme.darkSurface 
              : Colors.white, // UPDATE
            items: options.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option, 
                  style: TextStyle(
                    color: isDarkMode 
                      ? AppTheme.darkTextPrimary 
                      : Colors.black, // UPDATE
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );
}

Widget _buildChannelDropdown(bool isDarkMode) { // TAMBAHKAN PARAMETER
  return Row(
    children: [
      SizedBox(
        width: 80,
        child: Text(
          'Channel',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black, // UPDATE
          ),
        ),
      ),
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDarkMode 
                ? Colors.grey.shade700 
                : Colors.grey.shade300, // UPDATE
            ),
            borderRadius: BorderRadius.circular(8),
            color: isDarkMode ? AppTheme.darkSurface : Colors.white, // TAMBAHKAN
          ),
          child: _isLoadingChannels
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Loading channels...',
                    style: TextStyle(
                      color: isDarkMode 
                        ? AppTheme.darkTextSecondary 
                        : Colors.grey, // UPDATE
                    ),
                  ),
                )
              : DropdownButton<String>(
                  value: _channels.any((c) => c.id == _selectedChannelId) ? _selectedChannelId : null,
                  hint: Text(
                    '--select--',
                    style: TextStyle(
                      color: isDarkMode 
                        ? AppTheme.darkTextSecondary 
                        : Colors.grey, // UPDATE
                    ),
                  ),
                  isExpanded: true,
                  underline: const SizedBox(),
                  iconEnabledColor: isDarkMode 
                    ? AppTheme.darkTextPrimary 
                    : Colors.black, // UPDATE
                  style: TextStyle(
                    color: isDarkMode 
                      ? AppTheme.darkTextPrimary 
                      : Colors.black, // UPDATE
                  ),
                  dropdownColor: isDarkMode 
                    ? AppTheme.darkSurface 
                    : Colors.white, // UPDATE
                  items: _channels.map((ChannelOption channel) {
                    return DropdownMenuItem<String>(
                      value: channel.id,
                      child: Text(
                        channel.name, 
                        style: TextStyle(
                          color: isDarkMode 
                            ? AppTheme.darkTextPrimary 
                            : Colors.black, // UPDATE
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: _onChannelChanged,
                ),
        ),
      ),
    ],
  );
}

Widget _buildAccountDropdown(bool isDarkMode) { // TAMBAHKAN PARAMETER
  return Row(
    children: [
      SizedBox(
        width: 80,
        child: Text(
          'Account',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black, // UPDATE
          ),
        ),
      ),
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDarkMode 
                ? Colors.grey.shade700 
                : Colors.grey.shade300, // UPDATE
            ),
            borderRadius: BorderRadius.circular(8),
            color: isDarkMode ? AppTheme.darkSurface : Colors.white, // TAMBAHKAN
          ),
          child: _isLoadingAccounts
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Loading accounts...',
                    style: TextStyle(
                      color: isDarkMode 
                        ? AppTheme.darkTextSecondary 
                        : Colors.grey, // UPDATE
                    ),
                  ),
                )
              : DropdownButton<String>(
                  value: _accounts.any((a) => a.id == _selectedAccountId) ? _selectedAccountId : null,
                  hint: Text(
                    '--select--',
                    style: TextStyle(
                      color: isDarkMode 
                        ? AppTheme.darkTextSecondary 
                        : Colors.grey, // UPDATE
                    ),
                  ),
                  isExpanded: true,
                  underline: const SizedBox(),
                  iconEnabledColor: isDarkMode 
                    ? AppTheme.darkTextPrimary 
                    : Colors.black, // UPDATE
                  style: TextStyle(
                    color: isDarkMode 
                      ? AppTheme.darkTextPrimary 
                      : Colors.black, // UPDATE
                  ),
                  dropdownColor: isDarkMode 
                    ? AppTheme.darkSurface 
                    : Colors.white, // UPDATE
                  items: _accounts.map((AccountOption account) {
                    return DropdownMenuItem<String>(
                      value: account.id,
                      child: Text(
                        account.name, 
                        style: TextStyle(
                          color: isDarkMode 
                            ? AppTheme.darkTextPrimary 
                            : Colors.black, // UPDATE
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: _selectedChannelId == null ? null : (value) => setState(() => _selectedAccountId = value),
                ),
        ),
      ),
    ],
  );
}

Widget _buildRadioField(bool isDarkMode) { // TAMBAHKAN PARAMETER
  return Row(
    children: [
      SizedBox(
        width: 80,
        child: Text(
          'To',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black, // UPDATE
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
                : Colors.grey.shade300, // UPDATE
            ),
            borderRadius: BorderRadius.circular(8),
            color: isDarkMode ? AppTheme.darkSurface : Colors.white, // TAMBAHKAN
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<ToType>(
                    value: ToType.contact,
                    groupValue: _selectedToType,
                    onChanged: _onToTypeChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    activeColor: AppTheme.primaryColor, // Tetap biru
                  ),
                  Text(
                    'Contact',
                    style: TextStyle(
                      color: isDarkMode 
                        ? AppTheme.darkTextPrimary 
                        : Colors.black, // UPDATE
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<ToType>(
                    value: ToType.link,
                    groupValue: _selectedToType,
                    onChanged: _onToTypeChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    activeColor: AppTheme.primaryColor, // Tetap biru
                  ),
                  Text(
                    'Link',
                    style: TextStyle(
                      color: isDarkMode 
                        ? AppTheme.darkTextPrimary 
                        : Colors.black, // UPDATE
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
  return Row(
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDarkMode 
                ? Colors.grey.shade700 
                : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isDarkMode ? AppTheme.darkSurface : Colors.white,
          ),
          child: _isLoadingContacts
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Loading contacts...',
                    style: TextStyle(
                      color: isDarkMode 
                        ? AppTheme.darkTextSecondary 
                        : Colors.grey,
                    ),
                  ),
                )
              : DropdownButton<String>(
                  value: _contacts.any((c) => c.id == _selectedContactId) ? _selectedContactId : null,
                  hint: Text(
                    '--select--',
                    style: TextStyle(
                      color: isDarkMode 
                        ? AppTheme.darkTextSecondary 
                        : Colors.grey,
                    ),
                  ),
                  isExpanded: true,
                  underline: const SizedBox(),
                  iconEnabledColor: isDarkMode 
                    ? AppTheme.darkTextPrimary 
                    : Colors.black,
                  style: TextStyle(
                    color: isDarkMode 
                      ? AppTheme.darkTextPrimary 
                      : Colors.black,
                  ),
                  dropdownColor: isDarkMode 
                    ? AppTheme.darkSurface 
                    : Colors.white,
                  items: _contacts.map((ContactOption contact) {
                    return DropdownMenuItem<String>(
                      value: contact.id,
                      child: Text(
                        contact.name, 
                        style: TextStyle(
                          color: isDarkMode 
                            ? AppTheme.darkTextPrimary 
                            : Colors.black,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedContactId = value),
                ),
        ),
      ),
    ],
  );
}

Widget _buildLinkDropdown(bool isDarkMode) {
  return Row(
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDarkMode 
                ? Colors.grey.shade700 
                : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isDarkMode ? AppTheme.darkSurface : Colors.white,
          ),
          child: _isLoadingLinks
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Loading links...',
                    style: TextStyle(
                      color: isDarkMode 
                        ? AppTheme.darkTextSecondary 
                        : Colors.grey,
                    ),
                  ),
                )
              : DropdownButton<String>(
                  value: _links.any((l) => l.id == _selectedLinkId) ? _selectedLinkId : null,
                  hint: Text(
                    '--select--',
                    style: TextStyle(
                      color: isDarkMode 
                        ? AppTheme.darkTextSecondary 
                        : Colors.grey,
                    ),
                  ),
                  isExpanded: true,
                  underline: const SizedBox(),
                  iconEnabledColor: isDarkMode 
                    ? AppTheme.darkTextPrimary 
                    : Colors.black,
                  style: TextStyle(
                    color: isDarkMode 
                      ? AppTheme.darkTextPrimary 
                      : Colors.black,
                  ),
                  dropdownColor: isDarkMode 
                    ? AppTheme.darkSurface 
                    : Colors.white,
                  items: _links.map((LinkOption link) {
                    return DropdownMenuItem<String>(
                      value: link.id,
                      child: Text(
                        link.name, 
                        style: TextStyle(
                          color: isDarkMode 
                            ? AppTheme.darkTextPrimary 
                            : Colors.black,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedLinkId = value),
                ),
        ),
      ),
    ],
  );
}

Widget _buildGroupDropdown(bool isDarkMode) {
  return Row(
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDarkMode 
                ? Colors.grey.shade700 
                : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isDarkMode ? AppTheme.darkSurface : Colors.white,
          ),
          child: _isLoadingGroups
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Loading groups...',
                    style: TextStyle(
                      color: isDarkMode 
                        ? AppTheme.darkTextSecondary 
                        : Colors.grey,
                    ),
                  ),
                )
              : DropdownButton<String>(
                  value: _groups.any((g) => g.id == _selectedGroupId) ? _selectedGroupId : null,
                  hint: Text(
                    '--select--',
                    style: TextStyle(
                      color: isDarkMode 
                        ? AppTheme.darkTextSecondary 
                        : Colors.grey,
                    ),
                  ),
                  isExpanded: true,
                  underline: const SizedBox(),
                  iconEnabledColor: isDarkMode 
                    ? AppTheme.darkTextPrimary 
                    : Colors.black,
                  style: TextStyle(
                    color: isDarkMode 
                      ? AppTheme.darkTextPrimary 
                      : Colors.black,
                  ),
                  dropdownColor: isDarkMode 
                    ? AppTheme.darkSurface 
                    : Colors.white,
                  items: _groups.map((GroupOption group) {
                    return DropdownMenuItem<String>(
                      value: group.id,
                      child: Text(
                        group.name, 
                        style: TextStyle(
                          color: isDarkMode 
                            ? AppTheme.darkTextPrimary 
                            : Colors.black,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedGroupId = value),
                ),
        ),
      ),
    ],
  );
}
}