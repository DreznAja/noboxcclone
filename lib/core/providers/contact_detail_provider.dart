import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact_detail_models.dart';
import '../services/contact_detail_service.dart';

class ContactDetailState {
  final ContactDetail? contact;
  final List<ConversationHistory> conversationHistory;
  final List<ContactNote> notes;
  final ContactCampaign? campaign;
  final ContactDeal? deal;
  final ContactFormTemplate? formTemplate;
  final ContactFormResult? formResult;
  final ContactFunnel? funnel;
  final List<ContactFunnel> availableFunnels;
  final bool isLoading;
  final bool isLoadingHistory;
  final bool isLoadingNotes;
  final bool isLoadingFunnels;
  final String? error;

  ContactDetailState({
    this.contact,
    this.conversationHistory = const [],
    this.notes = const [],
    this.campaign,
    this.deal,
    this.formTemplate,
    this.formResult,
    this.funnel,
    this.availableFunnels = const [],
    this.isLoading = false,
    this.isLoadingHistory = false,
    this.isLoadingNotes = false,
    this.isLoadingFunnels = false,
    this.error,
  });

  ContactDetailState copyWith({
    ContactDetail? contact,
    List<ConversationHistory>? conversationHistory,
    List<ContactNote>? notes,
    ContactCampaign? campaign,
    ContactDeal? deal,
    ContactFormTemplate? formTemplate,
    ContactFormResult? formResult,
    ContactFunnel? funnel,
    List<ContactFunnel>? availableFunnels,
    bool? isLoading,
    bool? isLoadingHistory,
    bool? isLoadingNotes,
    bool? isLoadingFunnels,
    String? error,
  }) {
    return ContactDetailState(
      contact: contact ?? this.contact,
      conversationHistory: conversationHistory ?? this.conversationHistory,
      notes: notes ?? this.notes,
      campaign: campaign ?? this.campaign,
      deal: deal ?? this.deal,
      formTemplate: formTemplate ?? this.formTemplate,
      formResult: formResult ?? this.formResult,
      funnel: funnel ?? this.funnel,
      availableFunnels: availableFunnels ?? this.availableFunnels,
      isLoading: isLoading ?? this.isLoading,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isLoadingNotes: isLoadingNotes ?? this.isLoadingNotes,
      isLoadingFunnels: isLoadingFunnels ?? this.isLoadingFunnels,
      error: error,
    );
  }
}

class ContactDetailNotifier extends StateNotifier<ContactDetailState> {
  ContactDetailNotifier() : super(ContactDetailState());

  final ContactDetailService _service = ContactDetailService();
  
  bool get mounted => !state.isLoading || state.contact != null;

  // Method to directly set contact without API call (for groups)
  void setContact(ContactDetail contact) {
    state = state.copyWith(
      contact: contact,
      isLoading: false,
      error: null,
    );
  }

  Future<void> loadContactDetail(String contactId) async {
    state = state.copyWith(isLoading: true, error: null);

    print('Loading contact detail for ID: $contactId');

    try {
      // Load contact detail
      final contact = await _service.getContactDetail(contactId);
      
      if (contact != null) {
        print('Contact detail loaded successfully: ${contact.name}');
        state = state.copyWith(
          contact: contact,
          isLoading: false,
        );

        // Load additional data in parallel
        // Load additional data but don't fail if they error
        try {
          // Load data sequentially to avoid overwhelming the API
          await loadConversationHistory(contactId);
          await loadContactNotesFromRoom(contactId);
          await loadContactFunnel(contactId);
          await loadAvailableFunnels();
          await _loadCampaign(contactId);
          await _loadDeal(contactId);
          await _loadFormTemplate(contactId);
          await _loadFormResult(contactId);
        } catch (additionalDataError) {
          print('Some additional data failed to load: $additionalDataError');
          // Don't set error state for additional data failures
        }
      } else {
        print('Contact not found for ID: $contactId');
        // Don't set error state - just log it
        state = state.copyWith(
          isLoading: false,
        );
      }
    } catch (e) {
      print('Exception loading contact detail for ID $contactId: $e');
      // Don't set error state - just log it
      state = state.copyWith(
        isLoading: false,
      );
    }
  }

  Future<void> loadConversationHistory(String contactId) async {
    if (!mounted) return;
    state = state.copyWith(isLoadingHistory: true);

    try {
      final history = await _service.getConversationHistory(contactId);
      if (mounted) {
        state = state.copyWith(
          conversationHistory: history,
          isLoadingHistory: false,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoadingHistory: false,
        );
      }
      print('Failed to load conversation history: $e');
    }
  }

  Future<void> loadContactNotesFromRoom(String contactId) async {
    if (!mounted) return;
    state = state.copyWith(isLoadingNotes: true);

    try {
      // FIXED: Find the room ID for this contact first
      String roomIdToUse = contactId;
      
      // Try to find the actual room ID from conversation history
      final history = await _service.getConversationHistory(contactId);
      if (history.isNotEmpty) {
        // Use the most recent conversation room ID
        roomIdToUse = history.first.id;
        print('🗒️ Using room ID for notes: $roomIdToUse (from conversation history)');
      } else {
        print('🗒️ No conversation history found, using contact ID as room ID: $roomIdToUse');
      }
      
      final notes = await _service.getContactNotes(roomIdToUse);
      if (mounted) {
        state = state.copyWith(
          notes: notes,
          isLoadingNotes: false,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoadingNotes: false,
        );
      }
      print('Failed to load notes: $e');
    }
  }

  // Keep the old method for backward compatibility
  Future<void> loadContactNotes(String contactId) async {
    await loadContactNotesFromRoom(contactId);
  }
  Future<void> loadContactFunnel(String contactId) async {
    if (!mounted) return;
    state = state.copyWith(isLoadingFunnels: true);

    try {
      final funnel = await _service.getContactFunnel(contactId);
      if (mounted) {
        state = state.copyWith(
          funnel: funnel,
          isLoadingFunnels: false,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoadingFunnels: false,
        );
      }
      print('Failed to load contact funnel: $e');
    }
  }

  Future<void> loadAvailableFunnels() async {
    if (!mounted) return;
    
    try {
      final funnels = await _service.getAllFunnels();
      if (mounted) {
        state = state.copyWith(
          availableFunnels: funnels,
        );
      }
    } catch (e) {
      print('Failed to load available funnels: $e');
      if (mounted) {
        state = state.copyWith(
          availableFunnels: <ContactFunnel>[], // Provide empty list instead of null
        );
      }
    }
  }

  Future<bool> createFunnel(String funnelName) async {
    try {
      final funnelId = await _service.createFunnel(funnelName);
      if (funnelId != null) {
        // Reload available funnels to include the newly created funnel
        await loadAvailableFunnels();
        return true;
      } else {
        state = state.copyWith(error: 'Failed to create funnel');
        return false;
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to create funnel: $e');
      return false;
    }
  }

  Future<bool> assignFunnel(String roomId, String funnelId) async {
    try {
      // assignFunnelToContact now expects roomId instead of contactId
      final success = await _service.assignFunnelToContact(roomId, funnelId);
      if (success) {
        // Update state directly with the assigned funnel from availableFunnels
        final assignedFunnel = state.availableFunnels.firstWhere(
          (f) => f.id == funnelId,
          orElse: () => ContactFunnel(id: funnelId, name: 'Unknown Funnel'),
        );
        
        if (mounted) {
          state = state.copyWith(funnel: assignedFunnel);
          print('✅ Funnel state updated: ${assignedFunnel.name} (${assignedFunnel.id})');
        }
        
        return true;
      } else {
        state = state.copyWith(error: 'Failed to assign funnel');
        return false;
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to assign funnel: $e');
      return false;
    }
  }

  Future<bool> removeFunnel(String roomId) async {
    try {
      // To remove funnel, just assign null (0) as funnelId
      final success = await _service.assignFunnelToContact(roomId, '0');
      if (success) {
        // Update state directly to null (funnel removed)
        if (mounted) {
          state = state.copyWith(funnel: null);
          print('✅ Funnel removed from state');
        }
        return true;
      } else {
        state = state.copyWith(error: 'Failed to remove funnel');
        return false;
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to remove funnel: $e');
      return false;
    }
  }
  Future<void> _loadCampaign(String contactId) async {
    if (!mounted) return;
    
    try {
      final campaign = await _service.getContactCampaign(contactId);
      if (mounted) {
        state = state.copyWith(campaign: campaign);
      }
    } catch (e) {
      print('Error loading campaign: $e');
    }
  }

  Future<void> _loadDeal(String contactId) async {
    if (!mounted) return;
    
    try {
      final deal = await _service.getContactDeal(contactId);
      if (mounted) {
        state = state.copyWith(deal: deal);
      }
    } catch (e) {
      print('Error loading deal: $e');
    }
  }

  Future<void> _loadFormTemplate(String contactId) async {
    if (!mounted) return;
    
    try {
      final formTemplate = await _service.getContactFormTemplate(contactId);
      if (mounted) {
        state = state.copyWith(formTemplate: formTemplate);
      }
    } catch (e) {
      print('Error loading form template: $e');
    }
  }

  Future<void> _loadFormResult(String contactId) async {
    if (!mounted) return;
    
    try {
      final formResult = await _service.getContactFormResult(contactId);
      if (mounted) {
        state = state.copyWith(formResult: formResult);
      }
    } catch (e) {
      print('Error loading form result: $e');
    }
  }

  Future<void> addNote(String roomId, String content) async {
    try {
      // FIXED: addContactNote now expects roomId, not contactId
      // Backend Chatnotes table only has RoomId field
      final success = await _service.addContactNote(roomId, content);
      if (success) {
        // Reload notes to get the updated list
        await loadContactNotes(roomId);
      } else {
        state = state.copyWith(error: 'Failed to add note');
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to add note: $e');
    }
  }

  Future<void> updateNote(String noteId, String content, String contactId) async {
    try {
      final success = await _service.updateContactNote(noteId, content);
      if (success) {
        // Reload notes to get the updated list
        await loadContactNotes(contactId);
      } else {
        state = state.copyWith(error: 'Failed to update note');
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to update note: $e');
    }
  }

  Future<void> deleteNote(String noteId, String contactId) async {
    try {
      final success = await _service.deleteContactNote(noteId);
      if (success) {
        // Reload notes to get the updated list
        await loadContactNotes(contactId);
      } else {
        state = state.copyWith(error: 'Failed to delete note');
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete note: $e');
    }
  }

  Future<bool> updateNeedReply(String roomId, bool needReply) async {
    try {
      print('Updating NeedReply status for room $roomId to $needReply');
      final success = await _service.updateNeedReply(roomId, needReply);
      if (success) {
        print('NeedReply status updated successfully');
        return true;
      } else {
        state = state.copyWith(error: 'Failed to update Need Reply status');
        return false;
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to update Need Reply status: $e');
      return false;
    }
  }

  Future<bool> updateMuteBot(String roomId, bool muteBot) async {
    try {
      print('Updating MuteBot status for room $roomId to $muteBot');
      final success = await _service.updateMuteBot(roomId, muteBot);
      if (success) {
        print('MuteBot status updated successfully');
        return true;
      } else {
        state = state.copyWith(error: 'Failed to update Mute AI Agent status');
        return false;
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to update Mute AI Agent status: $e');
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final contactDetailProvider = StateNotifierProvider<ContactDetailNotifier, ContactDetailState>((ref) {
  return ContactDetailNotifier();
});