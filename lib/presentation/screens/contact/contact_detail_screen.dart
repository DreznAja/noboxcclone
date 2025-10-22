import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/models/tag_models.dart' as tag_models;
import 'package:nobox_chat/core/models/tag_models.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart';
import 'package:nobox_chat/presentation/widgets/add_note_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nobox_chat/core/models/contact_detail_models.dart';
import '../../../core/providers/contact_detail_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/providers/tag_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/add_funnel_dialog.dart';
import '../../widgets/add_tag_dialog.dart';
import '../../widgets/edit_note_dialog.dart';
import '../../widgets/funnel_selection_dialog.dart';
import '../../widgets/tag_selection_dialog.dart';
import '../../widgets/campaign_selection_dialog.dart';
import '../../widgets/deal_selection_dialog.dart';
import '../../widgets/form_template_selection_dialog.dart';
import '../chat/chat_screen.dart';
import '../../../core/models/chat_models.dart';
import '../../../core/services/account_service.dart';
import 'conversation_history_screen.dart';

class ContactDetailScreen extends ConsumerStatefulWidget {
  final String contactId;
  final String contactName;
  final String? contactImage;
  final bool isSlidePanel;
  final VoidCallback? onClose;
  final bool isGroup;
  final String? groupDescription;

  const ContactDetailScreen({
    super.key,
    required this.contactId,
    required this.contactName,
    this.contactImage,
    this.isSlidePanel = false,
    this.onClose,
    this.isGroup = false,
    this.groupDescription,
  });

  @override
  ConsumerState<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends ConsumerState<ContactDetailScreen> {
  bool _needReply = false;
  bool _muteAIAgent = false;
  String? _currentRoomId;
  OverlayEntry? _funnelOverlayEntry;
  final GlobalKey _funnelKey = GlobalKey();
  bool _isUpdatingNeedReply = false;
  bool _isUpdatingMuteBot = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Don't auto-refresh rooms to avoid disrupting new conversations
      // Room will be refreshed automatically after first message is sent
      // print('🔄 Contact screen opened - refreshing rooms to get latest data');
      // await ref.read(chatProvider.notifier).loadRooms();
      
      // For groups, skip loading contact detail from API as it doesn't exist
      // We'll use Room data directly
      if (!widget.isGroup) {
        ref.read(contactDetailProvider.notifier).loadContactDetail(widget.contactId);
      } else {
        // For groups, create a dummy contact from Room data
        _createContactFromRoom();
      }
      
      ref.read(tagProvider.notifier).loadAvailableTags();
      // Load room tags using the actual room ID, not contact ID
      _loadRoomTagsForContact();
      // Load initial needReply status from refreshed data
      _loadNeedReplyStatus();
    });
  }

  Future<void> _loadRoomTagsForContact() async {
    try {
      // Try to find the room ID for this contact from the chat provider
      final chatState = ref.read(chatProvider);

      // Look for a room that matches this contact
      Room? matchingRoom;
      for (final room in chatState.rooms) {
        if (room.ctId == widget.contactId ||
            room.ctRealId == widget.contactId ||
            room.id == widget.contactId) {
          matchingRoom = room;
          break;
        }
      }

      if (matchingRoom != null) {
        print('🏷️ Found matching room for contact: ${matchingRoom.id}');
        _currentRoomId = matchingRoom.id;
        await ref.read(tagProvider.notifier).loadRoomTags(matchingRoom.id);
      } else {
        print('🏷️ No matching room found for contact, trying with contact ID: ${widget.contactId}');
        _currentRoomId = widget.contactId;
        await ref.read(tagProvider.notifier).loadRoomTags(widget.contactId);
      }
    } catch (e) {
      print('❌ Error loading room tags for contact: $e');
    }
  }

  void _loadNeedReplyStatus() {
    try {
      final chatState = ref.read(chatProvider);

      // Look for a room that matches this contact
      for (final room in chatState.rooms) {
        if (room.ctId == widget.contactId ||
            room.ctRealId == widget.contactId ||
            room.id == widget.contactId) {
          setState(() {
            _needReply = room.needReply;
            _muteAIAgent = room.isMuteBot;
            _currentRoomId = room.id;
          });
          print('🔔 Loaded NeedReply status: $_needReply for room ${room.id}');
          print('🤖 Loaded MuteBot status: $_muteAIAgent for room ${room.id}');
          break;
        }
      }
    } catch (e) {
      print('❌ Error loading needReply status: $e');
    }
  }

  void _createContactFromRoom() {
    // For groups, create a ContactDetail from Room data
    final dummyContact = ContactDetail(
      id: widget.contactId,
      name: widget.contactName,
      channelId: 1, // Default WhatsApp
      channelName: 'WhatsApp',
      image: widget.contactImage,
      isGroup: true,
      description: widget.groupDescription,
    );
    
    print('👥 Created dummy contact for group: ${widget.contactName}');
    
    // Set the contact in provider without API call
    ref.read(contactDetailProvider.notifier).setContact(dummyContact);
  }

  @override
  Widget build(BuildContext context) {
    final contactState = ref.watch(contactDetailProvider);
    final tagState = ref.watch(tagProvider);
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    // Listen for errors (suppress for groups as they might not have contact detail API)
    // DISABLED: Don't show error alerts for contact not found - just log it
    ref.listen<ContactDetailState>(contactDetailProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error && !widget.isGroup) {
        // Just log the error, don't show alert
        print('⚠️ Contact detail error: ${next.error}');
        // Clear the error silently
        ref.read(contactDetailProvider.notifier).clearError();
      }
    });

    // Listen for tag errors
    ref.listen<tag_models.TagState>(tagProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
              onPressed: () {
                ref.read(tagProvider.notifier).clearError();
              },
            ),
          ),
        );
      }
    });
    
    // Listen for changes in chat provider to update needReply and muteBot status
    ref.listen<ChatState>(chatProvider, (previous, next) {
      // Don't sync if we're in the middle of updating (to preserve optimistic update)
      if (_isUpdatingNeedReply || _isUpdatingMuteBot) {
        print('⏸️ Skipping sync - update in progress');
        return;
      }
      
      if (_currentRoomId != null) {
        // Find matching room and update local state
        for (final room in next.rooms) {
          if (room.id == _currentRoomId) {
            if (_needReply != room.needReply || _muteAIAgent != room.isMuteBot) {
              setState(() {
                _needReply = room.needReply;
                _muteAIAgent = room.isMuteBot;
              });
              print('🔄 Synced from chat provider: needReply=$_needReply, muteBot=$_muteAIAgent');
            }
            break;
          }
        }
      }
    });

return Scaffold(
  backgroundColor: isDarkMode ? AppTheme.darkBackground : const Color(0xFFF8F9FA), // ← UBAH INI
  appBar: AppBar(
    backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white, // ← UBAH INI
    foregroundColor: isDarkMode ? Colors.white : Colors.black, // ← UBAH INI
    elevation: 0,
    title: Text(
      widget.isGroup ? 'Extra Panel' : 'Contact Detail',
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black, // ← UBAH INI
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.close, color: Colors.black),
        //     onPressed: () => Navigator.of(context).pop(),
        //   ),
        // ],
      ),
      body: contactState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : contactState.contact == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.person_off,
                        size: 64,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Contact details not available',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Contact ID: ${widget.contactId}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.read(contactDetailProvider.notifier).loadContactDetail(widget.contactId);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Contact Header with Avatar and Phone Number (only for individual)
                      if (!widget.isGroup) ...[
                        _buildContactHeader(contactState.contact!),
                        const SizedBox(height: 8),
                      ],
                      
                      // Group name header for Extra Panel (only for groups)
                      if (widget.isGroup) ...[
                        _buildGroupNameHeader(),
                        const SizedBox(height: 8),
                      ],
                      
                      // Conversation History Section
                      _buildConversationHistorySection(),
                      
                      const SizedBox(height: 8),
                      
                      // Group or Contact Section (only for individual)
                      if (!widget.isGroup) ...[
                        contactState.contact!.isGroup
                            ? _buildGroupSection(contactState.contact!)
                            : _buildContactSection(contactState.contact!),
                        const SizedBox(height: 8),
                      ],
                      
                      // Conversation Settings Section
                      _buildConversationSection(),
                      
                      const SizedBox(height: 8),
                      
                      // Funnel Section
                      _buildFunnelSection(),
                      
                      const SizedBox(height: 8),
                      
                      // Message Tags Section
                      _buildMessageTagsSection(tagState),
                      
                      const SizedBox(height: 8),
                      
                      // Notes Section
                      _buildNotesSection(contactState),
                      
                      const SizedBox(height: 8),
                      
                      // Campaign Section
                      _buildCampaignSection(contactState.campaign),
                      
                      const SizedBox(height: 8),
                      
                      // Deal Section
                      _buildDealSection(contactState.deal),
                      
                      const SizedBox(height: 8),
                      
                      // Form Template Section
                      _buildFormTemplateSection(contactState.formTemplate),
                      
                      const SizedBox(height: 8),
                      
                      // Form Result Section
                      _buildFormResultSection(contactState.formResult),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildGroupNameHeader() {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    return Container(
      color: isDarkMode ? AppTheme.darkSurface : Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Group Avatar
          CircleAvatar(
            radius: 24,
            backgroundImage: _isValidImageUrl(widget.contactImage)
                ? NetworkImage(widget.contactImage!)
                : null,
            backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
            child: !_isValidImageUrl(widget.contactImage)
                ? Icon(
                    Icons.group,
                    color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                    size: 28,
                  )
                : null,
          ),
          
          const SizedBox(width: 16),
          
          // Group Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contactName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                  ),
                ),
                if (widget.groupDescription != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.groupDescription!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactHeader(ContactDetail contact) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    return Container(
      color: isDarkMode ? AppTheme.darkSurface : Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundImage: _isValidImageUrl(contact.image)
                ? NetworkImage(contact.image!)
                : null,
            backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
            child: !_isValidImageUrl(contact.image)
                ? Icon(
                    contact.isGroup ? Icons.group : Icons.person,
                    color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                    size: 28,
                  )
                : null,
          ),
          
          const SizedBox(width: 16),
          
          // Contact Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                  ),
                ),
                if (contact.phone != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        contact.phone!,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Close button
          // IconButton(
          //   icon: const Icon(Icons.close, color: Colors.grey),
          //   onPressed: () => Navigator.of(context).pop(),
          //   padding: EdgeInsets.zero,
          //   constraints: const BoxConstraints(),
          // ),
        ],
      ),
    );
  }

  Widget _buildConversationHistorySection() {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    return Container(
      color: isDarkMode ? AppTheme.darkSurface : Colors.white,
      child: ListTile(
        title: Text(
          'Conversation History',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
        ),
        onTap: () {
          // Navigate to conversation history screen
          // Get CtId (NOT CtRealId!) from current room
          final chatState = ref.read(chatProvider);
          String? ctId;
          
          if (_currentRoomId != null) {
            for (final room in chatState.rooms) {
              if (room.id == _currentRoomId) {
                // Use CtId (external contact ID), not CtRealId (internal ID)
                ctId = room.ctId;
                print('🔍 Found room: ${room.id}');
                print('  CtId: ${room.ctId}');
                print('  CtRealId: ${room.ctRealId}');
                break;
              }
            }
          }
          
          print('📜 Navigating to conversation history with CtId: ${ctId ?? widget.contactId}');
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConversationHistoryScreen(
                contactId: ctId ?? widget.contactId,
                contactName: widget.contactName,
                contactImage: widget.contactImage,
              ),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildContactSection(ContactDetail contact) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    return Container(
      color: isDarkMode ? AppTheme.darkSurface : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 8),
            child: Row(
              children: [
                Text(
                  'Contact',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    contact.isBlocked ? Icons.block : Icons.block_outlined,
                    color: contact.isBlocked ? Colors.red : Colors.grey,
                    size: 20,
                  ),
                  onPressed: () => _toggleBlockContact(contact),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: contact.isBlocked ? 'Unblock Contact' : 'Block Contact',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Edit contact feature coming soon'),
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Name',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        contact.name,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF007AFF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                // Country - only show if exists
                if (contact.country != null && contact.country!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Country',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          contact.country!,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // State - only show if exists
                if (contact.state != null && contact.state!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'State',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          contact.state!,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // City - only show if exists
                if (contact.city != null && contact.city!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'City',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          contact.city!,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // Address - only show if exists
                if (contact.address != null && contact.address!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Address',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          contact.address!,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSection(ContactDetail contact) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    return Container(
      color: isDarkMode ? AppTheme.darkSurface : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 12),
            child: Text(
              'Group Info',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
              ),
            ),
          ),
          
          // Group details
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  'Name',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF007AFF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                // Description
                if (contact.description != null && contact.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contact.description!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
                
                // External ID
                if (contact.externalId != null && contact.externalId!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Group ID',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contact.externalId!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
                
                // Assigned Agents
                if (contact.agents != null && contact.agents!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Assigned Agents',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...contact.agents!.map((agent) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: agent.userImage != null && agent.userImage!.isNotEmpty
                              ? NetworkImage(agent.userImage!)
                              : null,
                          backgroundColor: Colors.grey.shade300,
                          child: agent.userImage == null || agent.userImage!.isEmpty
                              ? const Icon(Icons.person, size: 18, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                agent.displayName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                agent.email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationSection() {
    // Get account name from current room
    final chatState = ref.watch(chatProvider);
    String accountName = 'Bot WA'; // Default fallback
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    
    // Find the current room to get account/bot name
    if (_currentRoomId != null) {
      for (final room in chatState.rooms) {
        if (room.id == _currentRoomId) {
          accountName = _getBotName(room);
          break;
        }
      }
    }
    
    return Container(
      color: isDarkMode ? AppTheme.darkSurface : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 16),
            child: Text(
              'Conversation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
              ),
            ),
          ),
          _buildConversationItem('Account', accountName, hasSwitch: false),
          _buildConversationItem('Need Reply', '', hasSwitch: true, switchValue: _needReply),
          _buildConversationItem('Mute AI Agent', '', hasSwitch: true, switchValue: _muteAIAgent),
        ],
      ),
    );
  }

  Widget _buildConversationItem(String title, String value, {bool hasSwitch = false, bool switchValue = false}) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (value.isNotEmpty && !hasSwitch) ...[
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF007AFF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasSwitch)
            Switch(
              value: title == 'Need Reply' ? _needReply : (title == 'Mute AI Agent' ? _muteAIAgent : switchValue),
              onChanged: (newValue) async {
                if (title == 'Need Reply') {
                  await _handleNeedReplyToggle(newValue);
                } else if (title == 'Mute AI Agent') {
                  await _handleMuteAIAgentToggle(newValue);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$title toggle feature coming soon'),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  );
                }
              },
              activeColor: const Color(0xFF007AFF),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
        ],
      ),
    );
  }

  Widget _buildFunnelSection() {
    final contactState = ref.watch(contactDetailProvider);
    final chatState = ref.watch(chatProvider);
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    
    // Get funnel info from active room if available
    String? currentFunnelName = contactState.funnel?.name;
    String? currentFunnelId = contactState.funnel?.id;
    
    // If no funnel from contact detail, check if we have it from the active room
    if (currentFunnelName == null && chatState.activeRoom != null) {
      currentFunnelName = chatState.activeRoom!.funnel;
      currentFunnelId = chatState.activeRoom!.funnelId;
      print('📋 Using funnel from active room: $currentFunnelName (ID: $currentFunnelId)');
    }
    
    return Container(
      color: isDarkMode ? AppTheme.darkSurface : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 16),
            child: Row(
              children: [
                Text(
                  'Funnel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.blue, size: 20),
                  onPressed: _showFunnelDialog,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: contactState.isLoadingFunnels
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : currentFunnelName != null
                    ? Container(
                        key: _funnelKey,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDarkMode 
                            ? AppTheme.darkBackground.withOpacity(0.5) 
                            : const Color(0xFFF0F8FF), // ← UBAH INI
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDarkMode 
                              ? Colors.white.withOpacity(0.2) 
                              : const Color(0xFF007AFF).withOpacity(0.3), // ← UBAH INI JUGA
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                currentFunnelName!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: currentFunnelId != null ? () => _removeFunnel(widget.contactId) : null,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showFunnelDropdown(),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : GestureDetector(
                        key: _funnelKey,
                        onTap: () => _showFunnelDropdown(),
                        child: Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  decoration: BoxDecoration(
    color: isDarkMode ? AppTheme.darkBackground : Colors.grey.shade50, // ← UBAH INI
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: isDarkMode 
        ? Colors.white.withOpacity(0.1) 
        : Colors.grey.shade300 // ← UBAH INI
    ),
  ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'No funnel assigned',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _showFunnelDialog(),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.add,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

// Update bagian _buildMessageTagsSection
Widget _buildMessageTagsSection(tag_models.TagState tagState) {
  final isDarkMode = ref.watch(themeProvider).isDarkMode;

  return Container(
    color: isDarkMode ? AppTheme.darkSurface : Colors.white,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 16),
          child: Row(
            children: [
              Text(
                'Message Tags',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 20),
                onPressed: _showAddTagDialog,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Create new tag',
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.blue, size: 20),
                onPressed: () => _showTagSelectionDialog(tagState),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Assign tags to contact',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: tagState.isLoadingRoomTags
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : tagState.roomTags.isNotEmpty
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tagState.roomTags.map((tag) => _buildTagChip(tag)).toList(),
                    )
                  : Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDarkMode ? AppTheme.darkBackground : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDarkMode 
                            ? Colors.white.withOpacity(0.1) 
                            : Colors.grey.shade300
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'No tags added yet',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    ),
  );
}

// Update _buildTagChip
Widget _buildTagChip(tag_models.MessageTag tag) {
  final isDarkMode = ref.watch(themeProvider).isDarkMode;
  
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: isDarkMode 
        ? const Color(0xFF1976D2).withOpacity(0.3)
        : const Color(0xFFE3F2FD),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDarkMode
          ? const Color(0xFF1976D2).withOpacity(0.5)
          : const Color(0xFF2196F3).withOpacity(0.3)
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tag.name,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white : const Color(0xFF1976D2),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _removeTag(tag),
          child: Icon(
            Icons.close,
            size: 14,
            color: isDarkMode ? Colors.white : const Color(0xFF1976D2),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildNotesSection(ContactDetailState state) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    return Container(
      color: isDarkMode ? AppTheme.darkSurface : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 16),
            child: Row(
              children: [
                Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.blue, size: 20),
                  onPressed: () => _addNote(widget.contactId),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          if (state.isLoadingNotes)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.notes.isNotEmpty)
            ...state.notes.map((note) => _buildNoteItem(note))
          else
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'No notes added yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

 Widget _buildNoteItem(ContactNote note) {
  final isDarkMode = ref.watch(themeProvider).isDarkMode;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              note.content,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
            onPressed: () => _editNote(note, widget.contactId),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _deleteNote(note, widget.contactId),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignSection(ContactCampaign? campaign) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    return Container(
      color: isDarkMode ? AppTheme.darkSurface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campaign',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    campaign?.name ?? 'Not Set',
                    style: TextStyle(
                      fontSize: 14,
                      color: campaign != null ? Colors.black87 : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new, color: Colors.blue, size: 18),
              onPressed: campaign != null ? () => _viewCampaign(campaign) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              onPressed: _showCampaignDialog,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealSection(ContactDeal? deal) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    return Container(
      color: isDarkMode ? AppTheme.darkSurface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    deal?.name ?? 'Not Set',
                    style: TextStyle(
                      fontSize: 14,
                      color: deal != null ? Colors.black87 : Colors.red,
                    ),
                  ),
                  if (deal != null && (deal.pipeline != null || deal.stage != null)) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${deal.pipeline ?? ''} ${deal.stage != null ? '• ${deal.stage}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new, color: Colors.blue, size: 18),
              onPressed: deal != null ? () => _viewDeal(deal) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              onPressed: _showDealDialog,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormTemplateSection(ContactFormTemplate? formTemplate) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    return Container(
      color: isDarkMode ? AppTheme.darkSurface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Form Template',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formTemplate?.name ?? 'Not Set',
                    style: TextStyle(
                      fontSize: 14,
                      color: formTemplate != null ? Colors.black87 : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new, color: Colors.blue, size: 18),
              onPressed: formTemplate != null ? () => _viewFormTemplate(formTemplate) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              onPressed: _showFormTemplateDialog,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormResultSection(ContactFormResult? formResult) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    return Container(
      color: isDarkMode ? AppTheme.darkSurface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Form Result',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Not Set',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new, color: Colors.blue, size: 18),
              onPressed: formResult != null ? () => _viewFormResult(formResult) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url.startsWith('file:///')) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  // Action methods
  void _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _addNote(String contactId) {
    // FIXED: Use roomId instead of contactId for adding notes
    // Backend Chatnotes table only has RoomId field, not CtId
    if (_currentRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room ID not found. Cannot add note.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AddNoteDialog(
        onSave: (content) {
          // Use roomId instead of contactId
          ref.read(contactDetailProvider.notifier).addNote(_currentRoomId!, content);
        },
      ),
    );
  }

  void _editNote(ContactNote note, String contactId) {
    showDialog(
      context: context,
      builder: (context) => EditNoteDialog(
        initialContent: note.content,
        onSave: (content) {
          ref.read(contactDetailProvider.notifier).updateNote(note.id, content, contactId);
        },
      ),
    );
  }

void _deleteNote(ContactNote note, String contactId) {
  final isDarkMode = ref.watch(themeProvider).isDarkMode;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode 
                ? const Color(0xFF1976D2).withOpacity(0.2)
                : const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.delete_outline,
              color: Color(0xFF1976D2),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Delete Note',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
            ),
          ),
        ],
      ),
      content: Text(
        'Are you sure you want to delete this note? This action cannot be undone.',
        style: TextStyle(
          fontSize: 14,
          color: isDarkMode ? AppTheme.darkTextSecondary : Colors.black87,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(contactDetailProvider.notifier).deleteNote(note.id, contactId);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Note deleted successfully'),
                backgroundColor: AppTheme.successColor,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Delete',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

  void _showFunnelDialog() {
    showDialog(
      context: context,
      builder: (context) => AddFunnelDialog(
        onSave: (funnelName) async {
          final success = await ref.read(contactDetailProvider.notifier).createFunnel(funnelName);
          
          if (mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Funnel "$funnelName" created successfully'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to create funnel'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          }
        },
      ),
    );
  }
  
void _showFunnelDropdown() {
  final contactState = ref.read(contactDetailProvider);
  final isDarkMode = ref.read(themeProvider).isDarkMode;

  if (contactState.availableFunnels.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No funnels available. Please create funnels first.'),
        backgroundColor: AppTheme.warningColor,
      ),
    );
    return;
  }

  final RenderBox renderBox = _funnelKey.currentContext!.findRenderObject() as RenderBox;
  final position = renderBox.localToGlobal(Offset.zero);
  final size = renderBox.size;

  _funnelOverlayEntry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        GestureDetector(
          onTap: _removeFunnelOverlay,
          child: Container(
            color: Colors.transparent,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Positioned(
          left: position.dx,
          top: position.dy + size.height + 4,
          width: size.width,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: contactState.availableFunnels.length,
                itemBuilder: (context, index) {
                  final funnel = contactState.availableFunnels[index];
                  final isSelected = funnel.id == contactState.funnel?.id;

                  return InkWell(
                    onTap: () async {
                      _removeFunnelOverlay();
                      if (_currentRoomId != null) {
                        final success = await ref.read(contactDetailProvider.notifier).assignFunnel(_currentRoomId!, funnel.id);

                        if (success) {
                          await ref.read(chatProvider.notifier).loadRooms();
                          print('🔄 Reloaded rooms after funnel assignment');

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Funnel "${funnel.name}" assigned successfully'),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Funnel assignment is only available via web dashboard'),
                                backgroundColor: AppTheme.warningColor,
                                duration: Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Room ID not found. Please try again.'),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected 
                          ? (isDarkMode 
                              ? AppTheme.primaryColor.withOpacity(0.2) 
                              : const Color(0xFFF0F8FF))
                          : (isDarkMode ? AppTheme.darkSurface : Colors.white),
                        border: Border(
                          bottom: BorderSide(
                            color: isDarkMode 
                              ? Colors.white.withOpacity(0.1) 
                              : Colors.grey.shade200,
                            width: index < contactState.availableFunnels.length - 1 ? 1 : 0,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              funnel.name,
                              style: TextStyle(
                                fontSize: 14,
                                color: isSelected 
                                  ? (isDarkMode ? Colors.white : const Color(0xFF007AFF))
                                  : (isDarkMode ? AppTheme.darkTextPrimary : Colors.black),
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check,
                              size: 18,
                              color: isDarkMode ? Colors.white : const Color(0xFF007AFF),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Overlay.of(context).insert(_funnelOverlayEntry!);
}

  void _removeFunnelOverlay() {
    _funnelOverlayEntry?.remove();
    _funnelOverlayEntry = null;
  }

  @override
  void dispose() {
    _removeFunnelOverlay();
    super.dispose();
  }

  Future<void> _toggleBlockContact(ContactDetail contact) async {
    if (_currentRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room ID not found. Please try again.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );  
      return;
    }

    final isCurrentlyBlocked = contact.isBlocked;
    final action = isCurrentlyBlocked ? 'Unblock' : 'Block';
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCurrentlyBlocked ? Icons.check_circle_outline : Icons.block,
                color: const Color(0xFF1976D2),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$action Contact',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          isCurrentlyBlocked
              ? 'Are you sure you want to unblock this contact? You will receive messages from them.'
              : 'Are you sure you want to block this contact? You will not receive messages from them.',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              action,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Call API to update block status using Chatrooms/Update endpoint
      final response = await ref.read(chatProvider.notifier).toggleBlockContact(
        _currentRoomId!,
        !isCurrentlyBlocked,
      );

      if (response && mounted) {
        // Update local contact state
        final updatedContact = ContactDetail(
          id: contact.id,
          name: contact.name,
          phone: contact.phone,
          email: contact.email,
          channelId: contact.channelId,
          channelName: contact.channelName,
          image: contact.image,
          address: contact.address,
          isGroup: contact.isGroup,
          description: contact.description,
          isBlocked: !isCurrentlyBlocked,
        );
        
        ref.read(contactDetailProvider.notifier).setContact(updatedContact);
        
        // Reload rooms to sync with updated block status
        await ref.read(chatProvider.notifier).loadRooms();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCurrentlyBlocked
                  ? 'Contact unblocked successfully'
                  : 'Contact blocked successfully',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${action.toLowerCase()} contact'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      print('❌ Error toggling block status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  String _getBotName(Room room) {
    // FIXED: Match home screen display logic exactly
    // Priority: accountName -> botName -> AccountService -> channelName -> fallback
    
    print('🔍 Getting bot name for room ${room.id}, channelId: ${room.channelId}');
    print('  accountName: ${room.accountName}');
    print('  botName: ${room.botName}');
    print('  channelName: ${room.channelName}');
    
    // Priority 1: Use accountName if available (from DetailRoom)
    if (room.accountName != null && room.accountName!.isNotEmpty) {
      print('  ✅ Using accountName: ${room.accountName}');
      return room.accountName!;
    }
    
    // Priority 2: Use botName if available
    if (room.botName != null && room.botName!.isNotEmpty) {
      print('  ✅ Using botName: ${room.botName}');
      return room.botName!;
    }

    // Priority 3: Try AccountService to get account name for this channel
    // This provides dynamic names from backend that can change
    try {
      final accountService = AccountService();
      final accounts = accountService.getAccountsForChannel(room.channelId);
      if (accounts.isNotEmpty) {
        // Return account name as-is from backend
        print('  ✅ Using AccountService: ${accounts.first.name}');
        return accounts.first.name;
      }
    } catch (e) {
      print('  ⚠️ AccountService error: $e');
      // Silently fail, will use fallback
    }
    
    // Priority 4: Use channelName from API if not "Not Found"
    if (room.channelName.isNotEmpty && room.channelName != 'Not Found') {
      print('  ✅ Using channelName: ${room.channelName}');
      return room.channelName;
    }
    
    // Priority 5: Final fallback - use generic name based on channel ID
    final fallbackName = _getChannelNameFromId(room.channelId);
    print('  ✅ Using fallback: $fallbackName');
    return fallbackName;
  }
  
  String _getChannelNameFromId(int channelId) {
    switch (channelId) {
      case 1:
      case 1557:
      case 1561:
        return 'Bot WA';
      case 2:
        return 'Telegram Bot';
      case 3:
        return 'Instagram Bot';
      case 4:
        return 'Messenger Bot';
      case 19:
        return 'Email Bot';
      default:
        return 'Bot';
    }
  }

  void _removeFunnel(String contactId) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    // Use roomId instead of contactId
    if (_currentRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room ID not found. Please try again.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.filter_alt_off,
                color: Color(0xFF1976D2),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Remove Funnel',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove the funnel from this contact?',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              // Use _currentRoomId instead of contactId
              final success = await ref.read(contactDetailProvider.notifier).removeFunnel(_currentRoomId!);
              
              if (mounted) {
                if (success) {
                  // Provider already updates state to null, no need to reload
                  // Just reload rooms to sync with web
                  await ref.read(chatProvider.notifier).loadRooms();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Funnel removed successfully'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to remove funnel'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTagDialog() {
    showDialog(
      context: context,
      builder: (context) => AddTagDialog(
        onSave: (tagName) async {
          final success = await ref.read(tagProvider.notifier).createTag(tagName);
          
          if (mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Tag "$tagName" created successfully'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to create tag'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showTagSelectionDialog(TagState tagState) {
    // Find the correct room ID for this contact
    final chatState = ref.read(chatProvider);
    String roomIdToUse = widget.contactId;
    
    // Look for a room that matches this contact
    for (final room in chatState.rooms) {
      if (room.ctId == widget.contactId || 
          room.ctRealId == widget.contactId ||
          room.id == widget.contactId) {
        roomIdToUse = room.id;
        print('🏷️ Using room ID for tag selection: $roomIdToUse');
        break;
      }
    }
    
    showDialog(
      context: context,
      builder: (dialogContext) => TagSelectionDialog(
        roomId: roomIdToUse,
        currentTags: tagState.roomTags,
        onTagsSelected: (tagIds) async {
          // Save ScaffoldMessenger before async operation
          final messenger = ScaffoldMessenger.of(context);
          
          try {
            // Update room tags
            await ref.read(tagProvider.notifier).updateRoomTags(roomIdToUse, tagIds);
            
            // Use saved messenger instead of context
            if (mounted) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Tags updated successfully'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            }
          } catch (e) {
            print('❌ Error updating tags: $e');
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Failed to update tags: $e'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _removeTag(tag_models.MessageTag tag) {
    // Find the correct room ID for this contact
    final chatState = ref.read(chatProvider);
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    String roomIdToUse = widget.contactId;
    
    // Look for a room that matches this contact
    for (final room in chatState.rooms) {
      if (room.ctId == widget.contactId || 
          room.ctRealId == widget.contactId ||
          room.id == widget.contactId) {
        roomIdToUse = room.id;
        break;
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.label_off,
                color: Color(0xFF1976D2),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Remove Tag',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove the tag "${tag.name}"?',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              try {
                await ref.read(tagProvider.notifier).removeTagFromRoom(roomIdToUse, tag.id);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tag "${tag.name}" removed successfully'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              } catch (e) {
                print('❌ Error removing tag: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to remove tag: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _viewCampaign(ContactCampaign campaign) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View campaign "${campaign.name}" feature coming soon'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _viewDeal(ContactDeal deal) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View deal "${deal.name}" feature coming soon'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _viewFormTemplate(ContactFormTemplate formTemplate) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View form template "${formTemplate.name}" feature coming soon'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _viewFormResult(ContactFormResult formResult) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View form result "${formResult.senderName}" feature coming soon'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _showCampaignDialog() {
    showDialog(
      context: context,
      builder: (context) => CampaignSelectionDialog(
        contactId: widget.contactId,
        onCampaignSelected: (campaignId, campaignName) {
          print('📌 Selected campaign: $campaignName (ID: $campaignId)');
          // TODO: Save campaign to contact
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Campaign "$campaignName" selected'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        },
      ),
    );
  }

  void _showDealDialog() {
    showDialog(
      context: context,
      builder: (context) => DealSelectionDialog(
        contactId: widget.contactId,
        onDealSelected: (dealId, dealName, pipeline, stage) {
          print('📌 Selected deal: $dealName (ID: $dealId)');
          print('  Pipeline: $pipeline, Stage: $stage');
          // TODO: Save deal to contact
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deal "$dealName" selected'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        },
      ),
    );
  }

  void _showFormTemplateDialog() {
    showDialog(
      context: context,
      builder: (context) => FormTemplateSelectionDialog(
        contactId: widget.contactId,
        onFormSelected: (formTemplateId, formTemplateName, formResultId) {
          print('📌 Selected form template: $formTemplateName (ID: $formTemplateId)');
          if (formResultId != null) {
            print('  Form result ID: $formResultId');
          }
          // TODO: Save form template to contact
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Form template "$formTemplateName" selected'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleNeedReplyToggle(bool newValue) async {
    if (_currentRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot update: Room ID not found'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Mark as updating to prevent listener from overriding
    _isUpdatingNeedReply = true;
    
    // Optimistically update UI
    setState(() {
      _needReply = newValue;
    });

    try {
      // Update via API
      final success = await ref.read(contactDetailProvider.notifier).updateNeedReply(_currentRoomId!, newValue);

      if (success) {
        // Add delay to let backend sync
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Update the room in chat provider to sync with home screen
        await ref.read(chatProvider.notifier).loadRooms();
        
        // Wait a bit more before allowing listener sync
        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Need Reply ${newValue ? "activated" : "deactivated"}'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        // Revert UI on failure
        if (mounted) {
          setState(() {
            _needReply = !newValue;
          });
        }
      }
    } catch (e) {
      print('❌ Error updating Need Reply: $e');
      // Revert UI on error
      if (mounted) {
        setState(() {
          _needReply = !newValue;
        });
      }
    } finally {
      // Always reset the flag
      _isUpdatingNeedReply = false;
    }
  }

  Future<void> _handleMuteAIAgentToggle(bool newValue) async {
    if (_currentRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot update: Room ID not found'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Mark as updating to prevent listener from overriding
    _isUpdatingMuteBot = true;
    
    // Optimistically update UI
    setState(() {
      _muteAIAgent = newValue;
    });

    try {
      // Update via API
      final success = await ref.read(contactDetailProvider.notifier).updateMuteBot(_currentRoomId!, newValue);

      if (success) {
        // Add delay to let backend sync
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Update the room in chat provider to sync with home screen
        await ref.read(chatProvider.notifier).loadRooms();
        
        // Wait a bit more before allowing listener sync
        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI Agent ${newValue ? "muted" : "unmuted"}'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        // Revert UI on failure
        if (mounted) {
          setState(() {
            _muteAIAgent = !newValue;
          });
        }
      }
    } catch (e) {
      print('❌ Error updating Mute AI Agent: $e');
      // Revert UI on error
      if (mounted) {
        setState(() {
          _muteAIAgent = !newValue;
        });
      }
    } finally {
      // Always reset the flag
      _isUpdatingMuteBot = false;
    }
  }
}