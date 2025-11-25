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
  final List<Map<String, dynamic>> roomTags; // TAMBAH INI
  final List<Map<String, dynamic>> roomHumanAgents; // TAMBAH INI

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
    this.roomTags = const [], // TAMBAH INI
    this.roomHumanAgents = const [], // TAMBAH INI
  });

  // ✅ COPYWITH YANG BENER - PAKAI CLEAR FLAGS
  ContactDetailState copyWith({
    ContactDetail? contact,
    List<ConversationHistory>? conversationHistory,
    List<ContactNote>? notes,
    List<Map<String, dynamic>>? roomTags, // TAMBAH INI
    List<Map<String, dynamic>>? roomHumanAgents, // TAMBAH INI
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
      roomTags: roomTags ?? this.roomTags, // TAMBAH INI
      roomHumanAgents: roomHumanAgents ?? this.roomHumanAgents, // TAMBAH INI
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
  state = state.copyWith(isLoading: true, clearError: true, clearFunnel: true);

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
        // ✅ PERBAIKAN: Load data dengan getContactDetailWithRelations dulu
        final detailData = await _service.getContactDetailWithRelations(contactId);
        
        await Future.wait([
          loadConversationHistory(contactId),
          loadContactNotesFromRoom(contactId),
          loadContactFunnel(contactId),
          loadAvailableFunnels(),
          // ✅ HANYA load jika ada datanya di backend
          if (detailData?['Campaign'] != null) loadContactCampaign(contactId),
          if (detailData?['Deal'] != null) loadContactDeal(contactId),
          if (detailData?['FormR'] != null) ...[
            loadContactFormTemplate(contactId),
            loadContactFormResult(contactId),
          ],
          loadRoomTags(contactId),
          loadRoomHumanAgents(contactId),
        ]);
        
        // ✅ CLEAR state untuk yang tidak ada datanya
        if (detailData?['Campaign'] == null) {
          state = state.copyWith(clearCampaign: true);
        }
        if (detailData?['Deal'] == null) {
          state = state.copyWith(clearDeal: true);
        }
        if (detailData?['FormR'] == null) {
          state = state.copyWith(clearFormTemplate: true, clearFormResult: true);
        }
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

Future<bool> assignCampaign(String roomId, String campaignId) async {
  try {
    final success = await _service.assignCampaignToContact(roomId, campaignId);
    if (success) {
      // Reload untuk update UI
      await loadContactCampaign(roomId);
      return true;
    }
    return false;
  } catch (e) {
    print('❌ Error assigning campaign: $e');
    return false;
  }
}

Future<bool> assignDeal(String roomId, String dealId) async {
  try {
    final success = await _service.assignDealToContact(roomId, dealId);
    if (success) {
      await loadContactDeal(roomId);
      return true;
    }
    return false;
  } catch (e) {
    print('❌ Error assigning deal: $e');
    return false;
  }
}

Future<bool> assignFormTemplate(String roomId, String formTemplateId, String? formResultId) async {
  try {
    final success = await _service.assignFormTemplateToContact(roomId, formTemplateId, formResultId);
    if (success) {
      await loadContactFormTemplate(roomId);
      if (formResultId != null) {
        await loadContactFormResult(roomId);
      }
      return true;
    }
    return false;
  } catch (e) {
    print('❌ Error assigning form template: $e');
    return false;
  }
}

// Tambahkan method baru
Future<void> loadRoomTags(String contactId) async {
  if (!mounted) return;
  
  try {
    final tags = await _service.getRoomTags(contactId);
    if (mounted) {
      state = state.copyWith(roomTags: tags);
      print('✅ Loaded ${tags.length} room tags');
    }
  } catch (e) {
    print('Failed to load room tags: $e');
  }
}

Future<void> loadRoomHumanAgents(String contactId) async {
  if (!mounted) return;
  
  try {
    final agents = await _service.getRoomHumanAgents(contactId);
    if (mounted) {
      state = state.copyWith(roomHumanAgents: agents);
      print('✅ Loaded ${agents.length} room human agents');
    }
  } catch (e) {
    print('Failed to load room human agents: $e');
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

// contact_detail_provider.dart - Perbaikan di loadContactFunnel

// contact_detail_provider.dart - Perbaikan loadContactFunnel

Future<void> loadContactFunnel(String contactId) async {
  if (!mounted) return;
  state = state.copyWith(isLoadingFunnels: true);

  try {
    final funnel = await _service.getContactFunnel(contactId);
    
    if (funnel != null) {
      print('📋 Loaded contact funnel: ${funnel.name} (ID: ${funnel.id})');
      
      // ✅ PERBAIKAN: Verifikasi dengan availableFunnels untuk consistency
      ContactFunnel? verifiedFunnel = funnel;
      
      if (state.availableFunnels.isNotEmpty) {
        final matchedFunnel = state.availableFunnels.firstWhere(
          (f) => f.id == funnel.id,
          orElse: () => funnel,
        );
        
        // Gunakan nama dari availableFunnels jika lebih lengkap
        // Tapi prioritaskan nama dari Room karena itu yang aktif
        if (matchedFunnel.id == funnel.id) {
          // ID cocok, gunakan nama dari Room (funnel) karena itu real-time
          verifiedFunnel = funnel;
          print('✅ Using funnel name from Room: ${funnel.name}');
        }
      }
      
      if (mounted) {
        state = state.copyWith(
          funnel: verifiedFunnel,
          isLoadingFunnels: false,
        );
      }
    } else {
      print('⚠️ No funnel data returned from service');
      if (mounted) {
        state = state.copyWith(
          clearFunnel: true, // ← PENTING: Clear funnel jika tidak ada
          isLoadingFunnels: false,
        );
      }
    }
  } catch (e) {
    print('❌ Error loading contact funnel: $e');
    if (mounted) {
      state = state.copyWith(
        isLoadingFunnels: false,
      );
    }
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

// contact_detail_provider.dart - Perbaikan di method assignFunnel

Future<bool> assignFunnel(String roomId, String funnelId) async {
  try {
    final success = await _service.assignFunnelToContact(roomId, funnelId);
    if (success) {
      // ✅ PERBAIKAN: Cari funnel dari availableFunnels dan set langsung
      final assignedFunnel = state.availableFunnels.firstWhere(
        (f) => f.id == funnelId,
        orElse: () => ContactFunnel(id: funnelId, name: ''), // Fallback jika tidak ketemu
      );
      
      if (mounted && assignedFunnel.name.isNotEmpty) {
        // ✅ Update state dengan funnel object yang lengkap
        state = state.copyWith(funnel: assignedFunnel);
        print('✅ Provider: Funnel state updated to: ${assignedFunnel.name} (${assignedFunnel.id})');
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
    print('📋 Fetching campaign for contact: $contactId');
    
    final data = await _service.getContactDetailWithRelations(contactId);
    
    // ✅ ONLY set jika ada data
    if (data != null && data['Campaign'] != null) {
      final campaignData = data['Campaign'];
      print('✅ Campaign found: ${campaignData['Name']}');
      
      if (mounted) {
        state = state.copyWith(campaign: ContactCampaign.fromJson(campaignData));
      }
    } else {
      print('⚠️ No campaign data - clearing state');
      
      // ✅ CLEAR jika tidak ada
      if (mounted) {
        state = state.copyWith(clearCampaign: true);
      }
    }
  } catch (e) {
    print('❌ Error fetching contact campaign: $e');
    if (mounted) {
      state = state.copyWith(clearCampaign: true);
    }
  }
}

Future<void> loadContactDeal(String contactId) async {
  if (!mounted) return;
  
  try {
    print('📋 Fetching deal for contact: $contactId');
    
    final data = await _service.getContactDetailWithRelations(contactId);
    
    // ✅ ONLY set jika ada data
    if (data != null && data['Deal'] != null) {
      final dealData = data['Deal'];
      print('✅ Deal found: ${dealData['Name']}');
      
      if (mounted) {
        state = state.copyWith(deal: ContactDeal.fromJson(dealData));
      }
    } else {
      print('⚠️ No deal data - clearing state');
      
      // ✅ CLEAR jika tidak ada
      if (mounted) {
        state = state.copyWith(clearDeal: true);
      }
    }
  } catch (e) {
    print('❌ Error fetching contact deal: $e');
    if (mounted) {
      state = state.copyWith(clearDeal: true);
    }
  }
}

Future<void> loadContactFormTemplate(String contactId) async {
  if (!mounted) return;
  
  try {
    print('📋 Fetching form template for contact: $contactId');
    
    final data = await _service.getContactDetailWithRelations(contactId);
    
    // ✅ ONLY set jika ada data
    if (data != null && data['FormR'] != null) {
      final formRData = data['FormR'];
      
      if (formRData['FormId'] != null) {
        final formId = formRData['FormId'].toString();
        print('✅ FormTemplate found with FormId: $formId');
        
        if (mounted) {
          state = state.copyWith(
            formTemplate: ContactFormTemplate(
              id: formId,
              name: 'Form #$formId',
              description: null,
            ),
          );
        }
      } else {
        print('⚠️ No FormId - clearing state');
        if (mounted) {
          state = state.copyWith(clearFormTemplate: true);
        }
      }
    } else {
      print('⚠️ No form template data - clearing state');
      if (mounted) {
        state = state.copyWith(clearFormTemplate: true);
      }
    }
  } catch (e) {
    print('❌ Error fetching contact form template: $e');
    if (mounted) {
      state = state.copyWith(clearFormTemplate: true);
    }
  }
}

Future<void> loadContactFormResult(String contactId) async {
  if (!mounted) return;
  
  try {
    print('📋 Fetching form result for contact: $contactId');
    
    final data = await _service.getContactDetailWithRelations(contactId);
    
    // ✅ ONLY set jika ada data
    if (data != null && data['FormR'] != null) {
      final formRData = data['FormR'];
      print('✅ FormResult found: ${formRData['SenderNm']}');
      
      if (mounted) {
        state = state.copyWith(formResult: ContactFormResult.fromJson(formRData));
      }
    } else {
      print('⚠️ No form result data - clearing state');
      
      // ✅ CLEAR jika tidak ada
      if (mounted) {
        state = state.copyWith(clearFormResult: true);
      }
    }
  } catch (e) {
    print('❌ Error fetching contact form result: $e');
    if (mounted) {
      state = state.copyWith(clearFormResult: true);
    }
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