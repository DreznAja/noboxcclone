import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/models/tag_models.dart';
import 'package:nobox_chat/core/providers/chat_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/contact_detail_provider.dart';
import '../../../core/providers/tag_provider.dart';
import '../../../core/models/contact_detail_models.dart';
import '../../../core/models/tag_models.dart' as tag_models;
import '../../../core/theme/app_theme.dart';
import '../../widgets/add_note_dialog.dart';
import '../../widgets/edit_note_dialog.dart';
import '../../widgets/funnel_selection_dialog.dart';
import '../../widgets/tag_selection_dialog.dart';
import '../chat/chat_screen.dart';
import '../../../core/models/chat_models.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
      // Load initial needReply status
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

    // Listen for errors (suppress for groups as they might not have contact detail API)
    ref.listen<ContactDetailState>(contactDetailProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error && !widget.isGroup) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ref.read(contactDetailProvider.notifier).clearError();
              },
            ),
          ),
        );
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
              textColor: Colors.white,
              onPressed: () {
                ref.read(tagProvider.notifier).clearError();
              },
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Contact Detail',
          style: TextStyle(
            color: Colors.black,
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
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Contact Header with Avatar and Phone Number
                      _buildContactHeader(contactState.contact!),
                      
                      const SizedBox(height: 8),
                      
                      // Conversation History Section
                      _buildConversationHistorySection(),
                      
                      const SizedBox(height: 8),
                      
                      // Group or Contact Section
                      contactState.contact!.isGroup
                          ? _buildGroupSection(contactState.contact!)
                          : _buildContactSection(contactState.contact!),
                      
                      const SizedBox(height: 8),
                      
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

  Widget _buildContactHeader(ContactDetail contact) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundImage: _isValidImageUrl(contact.image)
                ? NetworkImage(contact.image!)
                : null,
            backgroundColor: Colors.grey.shade200,
            child: !_isValidImageUrl(contact.image)
                ? Icon(
                    contact.isGroup ? Icons.group : Icons.person,
                    color: Colors.grey,
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
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
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
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
    return Container(
      color: Colors.white,
      child: ListTile(
        title: const Text(
          'Conversation History',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: () {
          // Navigate to conversation history
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation history feature coming soon'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildContactSection(ContactDetail contact) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 8),
            child: Row(
              children: [
                const Text(
                  'Contact',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.phone, color: Colors.red, size: 20),
                  onPressed: contact.phone != null ? () => _makePhoneCall(contact.phone!) : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
                const Text(
                  'Name',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSection(ContactDetail contact) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Group',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          // Name row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 90,
                child: Text(
                  'Name',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF007AFF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          // Description row
          if (contact.description != null && contact.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 90,
                  child: Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    contact.description!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConversationSection() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 16),
            child: Text(
              'Conversation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          _buildConversationItem('Account', 'Bot WA', hasSwitch: false),
          _buildConversationItem('Need Reply', '', hasSwitch: true, switchValue: _needReply),
          _buildConversationItem('Mute AI Agent', '', hasSwitch: true, switchValue: _muteAIAgent),
        ],
      ),
    );
  }

  Widget _buildConversationItem(String title, String value, {bool hasSwitch = false, bool switchValue = false}) {
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
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
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
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 16),
            child: Row(
              children: [
                const Text(
                  'Funnel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
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
                          color: const Color(0xFFF0F8FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF007AFF).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                currentFunnelName!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: currentFunnelId != null ? () => _removeFunnel(widget.contactId) : null,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showFunnelDropdown(),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: Colors.grey,
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
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'No funnel assigned',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
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

  Widget _buildMessageTagsSection(tag_models.TagState tagState) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 16),
            child: Row(
              children: [
                const Text(
                  'Message Tags',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.blue, size: 20),
                  onPressed: () => _showTagSelectionDialog(tagState),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              child: Text(
                                'No tags added yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
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

  Widget _buildTagChip(tag_models.MessageTag tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag.name,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1976D2),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _removeTag(tag),
            child: const Icon(
              Icons.close,
              size: 14,
              color: Color(0xFF1976D2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(ContactDetailState state) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 16),
            child: Row(
              children: [
                const Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
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
                child: const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'No notes added yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
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
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              note.content,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
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
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campaign',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
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
              onPressed: campaign != null ? () => _viewCampaign(campaign) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealSection(ContactDeal? deal) {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
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
              onPressed: deal != null ? () => _viewDeal(deal) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.blue, size: 20),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Add deal feature coming soon'),
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
    );
  }

  Widget _buildFormTemplateSection(ContactFormTemplate? formTemplate) {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Form Template',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
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
              onPressed: formTemplate != null ? () => _viewFormTemplate(formTemplate) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormResultSection(ContactFormResult? formResult) {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Form Result',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFunnelDialog() {
    final contactState = ref.read(contactDetailProvider);

    if (contactState.availableFunnels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No funnels available. Please create funnels first.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => FunnelSelectionDialog(
        availableFunnels: contactState.availableFunnels,
        currentFunnel: contactState.funnel,
        onFunnelSelected: (funnelId) async {
          if (_currentRoomId != null) {
            await ref.read(contactDetailProvider.notifier).assignFunnel(_currentRoomId!, funnelId);

            // Reload rooms to sync with web
            await ref.read(chatProvider.notifier).loadRooms();
            print('🔄 Reloaded rooms after funnel assignment');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Funnel assigned successfully'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
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
      ),
    );
  }

  void _showFunnelDropdown() {
    final contactState = ref.read(contactDetailProvider);

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
                  color: Colors.white,
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
                          await ref.read(contactDetailProvider.notifier).assignFunnel(_currentRoomId!, funnel.id);

                          // Reload rooms to sync with web
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
                          color: isSelected ? const Color(0xFFF0F8FF) : Colors.white,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
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
                                  color: isSelected ? const Color(0xFF007AFF) : Colors.black,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check,
                                size: 18,
                                color: Color(0xFF007AFF),
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

  void _removeFunnel(String contactId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Funnel'),
        content: const Text('Are you sure you want to remove the funnel from this contact?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(contactDetailProvider.notifier).removeFunnel(contactId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Funnel removed successfully'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
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
      builder: (context) => TagSelectionDialog(
        roomId: roomIdToUse,
        currentTags: tagState.roomTags,
        onTagsSelected: (tagIds) async {
          try {
            // Update room tags
            await ref.read(tagProvider.notifier).updateRoomTags(roomIdToUse, tagIds);
            
            // Check if widget is still mounted before showing SnackBar
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tags updated successfully'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            }
          } catch (e) {
            print('❌ Error updating tags: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
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
        title: const Text('Remove Tag'),
        content: Text('Are you sure you want to remove the tag "${tag.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
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

    // Optimistically update UI
    setState(() {
      _needReply = newValue;
    });

    try {
      // Update via API
      final success = await ref.read(contactDetailProvider.notifier).updateNeedReply(_currentRoomId!, newValue);

      if (success) {
        // Update the room in chat provider to sync with home screen
        final chatState = ref.read(chatProvider);
        for (final room in chatState.rooms) {
          if (room.id == _currentRoomId) {
            // Force a room refresh by loading rooms again
            await ref.read(chatProvider.notifier).loadRooms();
            break;
          }
        }

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

    // Optimistically update UI
    setState(() {
      _muteAIAgent = newValue;
    });

    try {
      // Update via API
      final success = await ref.read(contactDetailProvider.notifier).updateMuteBot(_currentRoomId!, newValue);

      if (success) {
        // Update the room in chat provider to sync with home screen
        await ref.read(chatProvider.notifier).loadRooms();

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
    }
  }
}