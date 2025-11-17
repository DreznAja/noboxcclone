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

  // ✅ COPYWITH YANG BENER - PAKAI CLEAR FLAGS
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
    // Clear flags untuk nullable fields
    bool clearContact = false,
    bool clearCampaign = false,
    bool clearDeal = false,
    bool clearFormTemplate = false,
    bool clearFormResult = false,
    bool clearFunnel = false,
    bool clearError = false,
  }) {
    return ContactDetailState(
      contact: clearContact ? null : (contact ?? this.contact),
      conversationHistory: conversationHistory ?? this.conversationHistory,
      notes: notes ?? this.notes,
      campaign: clearCampaign ? null : (campaign ?? this.campaign),
      deal: clearDeal ? null : (deal ?? this.deal),
      formTemplate: clearFormTemplate ? null : (formTemplate ?? this.formTemplate),
      formResult: clearFormResult ? null : (formResult ?? this.formResult),
      funnel: clearFunnel ? null : (funnel ?? this.funnel),
      availableFunnels: availableFunnels ?? this.availableFunnels,
      isLoading: isLoading ?? this.isLoading,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isLoadingNotes: isLoadingNotes ?? this.isLoadingNotes,
      isLoadingFunnels: isLoadingFunnels ?? this.isLoadingFunnels,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ContactDetailNotifier extends StateNotifier<ContactDetailState> {
  ContactDetailNotifier() : super(ContactDetailState());

  final ContactDetailService _service = ContactDetailService();
  
  bool get mounted => !state.isLoading || state.contact != null;

  void setContact(ContactDetail contact) {
    state = state.copyWith(
      contact: contact,
      isLoading: false,
      clearError: true,
    );
  }

  Future<void> loadContactDetail(String contactId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    print('Loading contact detail for ID: $contactId');

    try {
      final contact = await _service.getContactDetail(contactId);
      
      if (contact != null) {
        print('Contact detail loaded successfully: ${contact.name}');
        state = state.copyWith(
          contact: contact,
          isLoading: false,
        );

        try {
          await Future.wait([
            loadConversationHistory(contactId),
            loadContactNotesFromRoom(contactId),
            loadContactFunnel(contactId),
            loadAvailableFunnels(),
            loadContactCampaign(contactId),
            loadContactDeal(contactId),
            loadContactFormTemplate(contactId),
            loadContactFormResult(contactId),
          ]);
        } catch (additionalDataError) {
          print('Some additional data failed to load: $additionalDataError');
        }
      } else {
        print('Contact not found for ID: $contactId');
        state = state.copyWith(
          isLoading: false,
        );
      }
    } catch (e) {
      print('Exception loading contact detail for ID $contactId: $e');
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
      String roomIdToUse = contactId;
      
      final history = await _service.getConversationHistory(contactId);
      if (history.isNotEmpty) {
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
          availableFunnels: <ContactFunnel>[],
        );
      }
    }
  }

  Future<bool> createFunnel(String funnelName) async {
    try {
      final funnelId = await _service.createFunnel(funnelName);
      if (funnelId != null) {
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
      final success = await _service.assignFunnelToContact(roomId, funnelId);
      if (success) {
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
      final success = await _service.assignFunnelToContact(roomId, '0');
      if (success) {
        if (mounted) {
          state = state.copyWith(clearFunnel: true);
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

  Future<void> loadContactCampaign(String contactId) async {
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

  Future<void> loadContactDeal(String contactId) async {
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

  Future<void> loadContactFormTemplate(String contactId) async {
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

  Future<void> loadContactFormResult(String contactId) async {
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
      final success = await _service.addContactNote(roomId, content);
      if (success) {
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

Future<bool> updateContact({
  required String contactId,
  String? name,
  String? category,
  String? address,
  String? zipCode,
  String? city,
  String? state,
  String? country,
  String? photoBase64,
}) async {
  try {
    print('Updating contact: $contactId');
    final success = await _service.updateContact(
      contactId: contactId,
      name: name,
      category: category,
      address: address,
      zipCode: zipCode,
      city: city,
      state: state,
      country: country,
      photoBase64: photoBase64,
    );
    
    if (success) {
      print('Contact updated successfully, reloading contact detail...');
      await loadContactDetail(contactId);
      return true;
    } else {
      // ✅ FIX: Ganti jadi gini
      this.state = this.state.copyWith(error: 'Failed to update contact');
      return false;
    }
  } catch (e) {
    // ✅ FIX: Ganti jadi gini
    this.state = this.state.copyWith(error: 'Failed to update contact: $e');
    return false;
  }
}

  Future<bool> removeAgentFromConversation({
    required String chatroomAgentId,
    required String roomId,
    required int currentUserId,
    required String contactId,
  }) async {
    try {
      print('Removing chatroomagent ID $chatroomAgentId from conversation');
      final success = await _service.removeAgentFromConversation(
        chatroomAgentId: chatroomAgentId,
        roomId: roomId,
        currentUserId: currentUserId,
      );
      
      if (success) {
        print('Agent removed successfully, reloading contact detail...');
        await loadContactDetail(contactId);
        return true;
      } else {
        this.state = this.state.copyWith(error: 'Failed to remove agent from conversation');
        return false;
      }
    } catch (e) {
      this.state = this.state.copyWith(error: 'Failed to remove agent: $e');
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final contactDetailProvider = StateNotifierProvider<ContactDetailNotifier, ContactDetailState>((ref) {
  return ContactDetailNotifier();
});