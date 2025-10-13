import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/new_conversation_service.dart';
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
        
        // If we found an existing room in memory, use it
        if (existingRoom.id.isNotEmpty) {
          print('Found existing room in memory: ${existingRoom.id} - ${existingRoom.name}');
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
      
      if (mounted) {
        // Close dialog first
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening conversation: ${targetName}'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // FIXED: Navigate to ChatScreen with proper room object
        // The ChatScreen will automatically call selectRoom which will load existing messages
        print('Navigating to ChatScreen with room: ${existingRoom.id}');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(room: existingRoom!),
          ),
        );
        
        // Refresh the room list in background to ensure it includes this conversation
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            print('Refreshing room list after new conversation');
            ref.read(chatProvider.notifier).loadRooms();
          }
        });
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
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, // Background putih
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
                    color: AppTheme.primaryColor, // Warna primary
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: AppTheme.primaryColor, // Warna primary
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Form fields
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Chat Type
                    _buildDropdownField(
                      'Chat',
                      _selectedChatType == ChatType.private ? 'Private' : 'Group',
                      ['Private', 'Group'],
                      (value) => _onChatTypeChanged(
                        value == 'Private' ? ChatType.private : ChatType.group
                      ),
                      isRequired: true,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Channel
                    _buildChannelDropdown(),
                    
                    const SizedBox(height: 16),
                    
                    // Account - FIXED: Only show if channel is selected
                    _buildAccountDropdown(),
                    
                    const SizedBox(height: 16),
                    
                    // Private chat specific fields
                    if (_selectedChatType == ChatType.private) ...[
                      // To radio buttons
                      _buildRadioField(),
                      
                      const SizedBox(height: 16),
                      
                      // Contact or Link dropdown
                      if (_selectedToType == ToType.contact)
                        _buildContactDropdown()
                      else
                        _buildLinkDropdown(),
                    ],
                    
                    // Group chat specific fields
                    if (_selectedChatType == ChatType.group) ...[
                      _buildGroupDropdown(),
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
                    child: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor, // FIXED: Cancel text color primary
                      side: BorderSide(color: AppTheme.primaryColor), // FIXED: Border color primary
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
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
              color: Colors.black, // Warna hitam
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: options.contains(value) ? value : null,
              hint: const Text('--select--', style: TextStyle(color: Colors.grey)),
              isExpanded: true,
              underline: const SizedBox(),
              iconEnabledColor: Colors.black, // Arrow hitam
              style: const TextStyle(color: Colors.black), // Teks item hitam
              dropdownColor: Colors.white, // FIXED: Background dropdown putih
              items: options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option, style: const TextStyle(color: Colors.black)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChannelDropdown() {
    return Row(
      children: [
        const SizedBox(
          width: 80,
          child: Text(
            'Channel',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black, // Warna hitam
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isLoadingChannels
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Loading channels...',
                        style: TextStyle(color: Colors.grey)),
                  )
                : DropdownButton<String>(
                    value: _channels.any((c) => c.id == _selectedChannelId) ? _selectedChannelId : null,
                    hint: const Text('--select--',
                        style: TextStyle(color: Colors.grey)),
                    isExpanded: true,
                    underline: const SizedBox(),
                    iconEnabledColor: Colors.black, // Arrow hitam
                    style: const TextStyle(color: Colors.black), // Teks item hitam
                    dropdownColor: Colors.white, // FIXED: Background dropdown putih
                    items: _channels.map((ChannelOption channel) {
                      return DropdownMenuItem<String>(
                        value: channel.id,
                        child: Text(channel.name, style: const TextStyle(color: Colors.black)),
                      );
                    }).toList(),
                    onChanged: _onChannelChanged,
                  ),
          ),
        ),
      ],
    );
  }

Widget _buildAccountDropdown() {
  return Row(
    children: [
      const SizedBox(
        width: 80,
        child: Text(
          'Account',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black, // Warna hitam
          ),
        ),
      ),
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _isLoadingAccounts
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Loading accounts...',
                      style: TextStyle(color: Colors.grey)),
                )
              : DropdownButton<String>(
                  value: _accounts.any((a) => a.id == _selectedAccountId) ? _selectedAccountId : null,
                  hint: const Text('--select--',
                      style: TextStyle(color: Colors.grey)),
                  isExpanded: true,
                  underline: const SizedBox(),
                  iconEnabledColor: Colors.black, // Arrow hitam
                  style: const TextStyle(color: Colors.black), // Teks item hitam
                  dropdownColor: Colors.white, // Background dropdown putih
                  items: _accounts.map((AccountOption account) {
                    return DropdownMenuItem<String>(
                      value: account.id,
                      child: Text(account.name, style: const TextStyle(color: Colors.black)),
                    );
                  }).toList(),
                  onChanged: _selectedChannelId == null ? null : (value) => setState(() => _selectedAccountId = value),
                ),
        ),
      ),
    ],
  );
}

  Widget _buildRadioField() {
    return Row(
      children: [
        const SizedBox(
          width: 80,
          child: Text(
            'To',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black, // Warna hitam
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start, // FIXED: Align to start
              children: [
                // Contact radio button
                Row(
                  mainAxisSize: MainAxisSize.min, // FIXED: Minimize size
                  children: [
                    Radio<ToType>(
                      value: ToType.contact,
                      groupValue: _selectedToType,
                      onChanged: _onToTypeChanged,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // FIXED: Reduce tap area
                      visualDensity: VisualDensity.compact, // FIXED: Compact radio
                      activeColor: AppTheme.primaryColor, // FIXED: Radio button color when selected
                    ),
                    const Text(
                      'Contact',
                      style: TextStyle(color: Colors.black), // FIXED: Text color primary
                    ),
                  ],
                ),
                const SizedBox(width: 16), // FIXED: Reduced spacing
                // Link radio button
                Row(
                  mainAxisSize: MainAxisSize.min, // FIXED: Minimize size
                  children: [
                    Radio<ToType>(
                      value: ToType.link,
                      groupValue: _selectedToType,
                      onChanged: _onToTypeChanged,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // FIXED: Reduce tap area
                      visualDensity: VisualDensity.compact, // FIXED: Compact radio
                      activeColor: AppTheme.primaryColor, // FIXED: Radio button color when selected
                    ),
                    const Text(
                      'Link',
                      style: TextStyle(color: Colors.black), // FIXED: Text color primary
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

  Widget _buildContactDropdown() {
    return Row(
      children: [
        const SizedBox(
          width: 80,
          child: Text(
            'Contact',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black, // Warna hitam
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isLoadingContacts
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Loading contacts...',
                        style: TextStyle(color: Colors.grey)),
                  )
                : DropdownButton<String>(
                    value: _contacts.any((c) => c.id == _selectedContactId) ? _selectedContactId : null,
                    hint: const Text('--select--',
                        style: TextStyle(color: Colors.grey)),
                    isExpanded: true,
                    underline: const SizedBox(),
                    iconEnabledColor: Colors.black, // Arrow hitam
                    style: const TextStyle(color: Colors.black), // Teks item hitam
                    dropdownColor: Colors.white, // FIXED: Background dropdown putih
                    items: _contacts.map((ContactOption contact) {
                      return DropdownMenuItem<String>(
                        value: contact.id,
                        child: Text(contact.name, style: const TextStyle(color: Colors.black)),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedContactId = value),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkDropdown() {
    return Row(
      children: [
        const SizedBox(
          width: 80,
          child: Text(
            'Link',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black, // Warna hitam
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isLoadingLinks
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Loading links...',
                        style: TextStyle(color: Colors.grey)),
                  )
                : DropdownButton<String>(
                    value: _links.any((l) => l.id == _selectedLinkId) ? _selectedLinkId : null,
                    hint: const Text('--select--',
                        style: TextStyle(color: Colors.grey)),
                    isExpanded: true,
                    underline: const SizedBox(),
                    iconEnabledColor: Colors.black, // Arrow hitam
                    style: const TextStyle(color: Colors.black), // Teks item hitam
                    dropdownColor: Colors.white, // FIXED: Background dropdown putih
                    items: _links.map((LinkOption link) {
                      return DropdownMenuItem<String>(
                        value: link.id,
                        child: Text(link.name, style: const TextStyle(color: Colors.black)),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedLinkId = value),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupDropdown() {
    return Row(
      children: [
        const SizedBox(
          width: 80,
          child: Text(
            'Group',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black, // Warna hitam
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isLoadingGroups
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Loading groups...',
                        style: TextStyle(color: Colors.grey)),
                  )
                : DropdownButton<String>(
                    value: _groups.any((g) => g.id == _selectedGroupId) ? _selectedGroupId : null,
                    hint: const Text('--select--',
                        style: TextStyle(color: Colors.grey)),
                    isExpanded: true,
                    underline: const SizedBox(),
                    iconEnabledColor: Colors.black, // Arrow hitam
                    style: const TextStyle(color: Colors.black), // Teks item hitam
                    dropdownColor: Colors.white, // FIXED: Background dropdown putih
                    items: _groups.map((GroupOption group) {
                      return DropdownMenuItem<String>(
                        value: group.id,
                        child: Text(group.name, style: const TextStyle(color: Colors.black)),
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