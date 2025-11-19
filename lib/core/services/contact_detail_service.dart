import 'package:dio/dio.dart';
import '../app_config.dart';
import '../models/contact_detail_models.dart';
import 'storage_service.dart';

class ContactDetailService {
  static final ContactDetailService _instance = ContactDetailService._internal();
  factory ContactDetailService() => _instance;

  late Dio _dio;

  ContactDetailService._internal() {
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
        print('Contact Detail API Error: ${error.message}');
        handler.next(error);
      },
    ));
  }

  Future<String?> _getRoomIdFromContactId(String contactId) async {
  try {
    print('🔍 Finding Room ID for Contact ID: $contactId');
    
    final requestData = {
      'EqualityFilter': {'CtRealId': contactId},
      'Take': 1,
      'Skip': 0,
      'IncludeColumns': ['Id'],
      'ColumnSelection': 1,
    };

    final response = await _dio.post(
      'Services/Chat/Chatrooms/List',
      data: requestData,
    );

    if (response.statusCode == 200 && response.data['IsError'] != true) {
      final List<dynamic> entities = response.data['Entities'] ?? [];
      if (entities.isNotEmpty) {
        final roomId = entities.first['Id']?.toString();
        print('✅ Found Room ID: $roomId for Contact ID: $contactId');
        return roomId;
      }
    }
    
    print('⚠️ No Room found for Contact ID: $contactId');
    return null;
  } catch (e) {
    print('❌ Error finding Room ID: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> getContactDetailWithRelations(String contactId) async {
  try {
    print('📋 Fetching contact detail with relations for Contact ID: $contactId');
    
    // STEP 1: Convert Contact ID ke Room ID dulu
    final roomId = await _getRoomIdFromContactId(contactId);
    
    if (roomId == null) {
      print('⚠️ Cannot fetch relations: No Room ID found');
      return null;
    }
    
    // STEP 2: Gunakan Room ID untuk get DetailRoom
    final requestData = {
      'EntityId': roomId, // ✅ SEKARANG PAKAI ROOM ID
    };

    print('📋 DetailRoom request data: $requestData');

    final response = await _dio.post(
      'Services/Chat/Chatrooms/DetailRoom',
      data: requestData,
    );

    print('📋 DetailRoom response: ${response.statusCode}');

    if (response.statusCode == 200 && response.data['IsError'] != true) {
      final data = response.data['Data'];
      
      if (data != null) {
        print('✅ Found room data with relations');
        print('  - Campaign: ${data['Campaign'] != null ? "✓" : "✗"}');
        print('  - Deal: ${data['Deal'] != null ? "✓" : "✗"}');
        print('  - FormR: ${data['FormR'] != null ? "✓" : "✗"}');
        
        return data;
      }
    }

    print('⚠️ No data returned from DetailRoom');
    return null;
  } catch (e) {
    print('❌ Error fetching contact detail with relations: $e');
    return null;
  }
}

  Future<ContactDetail?> getContactDetail(String contactId) async {
    try {
      print('Fetching contact detail for ID: $contactId');
      
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'Phone', 'Email', 'Category', 'Address', 'City', 'State', 'Country', 'Postal', 'Photo', 'IsBlock'],
        'ColumnSelection': 1,
        'EqualityFilter': {'Id': contactId},
        'Take': 1,
        'Skip': 0,
      };

      print('Contact detail request data: $requestData');

      final response = await _dio.post(
        'Services/Nobox/Contact/List',
        data: requestData,
      );

      print('Contact detail response status: ${response.statusCode}');
      print('Contact detail response data: ${response.data}');

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        if (entities.isNotEmpty) {
          final contactData = entities.first;
          ContactDetail contact = ContactDetail.fromJson(contactData);
          
          // Try to load agents from DetailRoom API
          try {
            final agents = await getContactAgents(contactId);
            if (agents != null && agents.isNotEmpty) {
              contact = contact.copyWith(agents: agents);
              print('✅ Loaded ${agents.length} agents for contact');
            }
          } catch (agentError) {
            print('⚠️ Could not load agents: $agentError');
          }
          
          return contact;
        } else {
          print('No contact found with ID: $contactId');
          return null;
        }
      }

      print('Contact Detail API Error: ${response.data}');
      return null;
    } catch (e) {
      if (e.toString().contains('404')) {
        print('Contact not found (404) for ID: $contactId');
        return null;
      }
      print('Error fetching contact detail for ID $contactId: $e');
      return null;
    }
  }

  Future<List<GroupAgent>?> getContactAgents(String contactId) async {
    try {
      print('📋 Fetching agents for contact: $contactId');
      
      final data = await getContactDetailWithRelations(contactId);
      
      if (data != null) {
        // Check for RoomAgents or SelectAgents
        if (data['RoomAgents'] != null && data['RoomAgents'] is List) {
          final List<dynamic> agentsData = data['RoomAgents'] as List;
          print('✅ Found ${agentsData.length} RoomAgents');
          return agentsData.map((agent) => GroupAgent.fromJson(agent)).toList();
        } else if (data['SelectAgents'] != null && data['SelectAgents'] is List) {
          final List<dynamic> agentsData = data['SelectAgents'] as List;
          print('✅ Found ${agentsData.length} SelectAgents');
          return agentsData.map((agent) => GroupAgent.fromJson(agent)).toList();
        }
      }
      
      print('⚠️ No agents data available');
      return null;
    } catch (e) {
      print('❌ Error fetching contact agents: $e');
      return null;
    }
  }

  Future<List<ConversationHistory>> getConversationHistory(String contactId) async {
    try {
      print('Fetching conversation history for contact ID: $contactId');
      
      final requestData = {
        'EqualityFilter': {
          'CtRealId': contactId,
        },
        'Sort': ['TimeMsg DESC'],
        'Take': 50,
        'Skip': 0,
        'IncludeColumns': [
          'Id', 'CtRealNm', 'Ct', 'Grp', 'LastMsg', 'TimeMsg', 'St', 
          'ChId', 'ChAcc', 'IsPin', 'Tags', 'Fn'
        ],
        'ColumnSelection': 1,
      };

      print('Conversation history request: $requestData');

      final response = await _dio.post(
        'Services/Chat/Chatrooms/List',
        data: requestData,
      );

      print('Conversation history response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        print('Found ${entities.length} conversation history items');
        return entities.map((item) => ConversationHistory.fromJson(item)).toList();
      }

      print('Conversation History API Error: ${response.data}');
      return [];
    } catch (e) {
      print('Error fetching conversation history: $e');
      // Return empty list instead of throwing error
      return [];
    }
  }

  Future<List<ContactNote>> getContactNotes(String roomId) async {
    try {
      print('Fetching contact notes for room ID: $roomId');
      
      // FIXED: Use DetailRoom API to get notes like the web version
      final requestData = {
        'EntityId': roomId,
      };

      print('Room detail request for notes: $requestData');

      final response = await _dio.post(
        'Services/Chat/Chatrooms/DetailRoom',
        data: requestData,
      );

      print('Room detail response for notes: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final roomData = response.data['Data'];
        if (roomData != null && roomData['Notes'] != null) {
          final List<dynamic> notesData = roomData['Notes'] as List<dynamic>;
          print('Found ${notesData.length} notes from DetailRoom');
          return notesData.map((item) => ContactNote.fromJson(item)).toList();
        } else {
          print('No notes found in DetailRoom response');
          return [];
        }
      }

      print('Room Detail API Error: ${response.data}');
      return [];
    } catch (e) {
      print('Error fetching room notes: $e');
      return [];
    }
  }

 Future<ContactCampaign?> getContactCampaign(String contactId) async {
  try {
    print('📋 Fetching campaign for contact: $contactId');
    
    final data = await getContactDetailWithRelations(contactId);
    
    if (data != null && data['Campaign'] != null) {
      final campaignData = data['Campaign'];
      print('✅ Campaign found: ${campaignData['Name']}');
      return ContactCampaign.fromJson(campaignData);
    }
    
    print('⚠️ No campaign data available');
    return null;
  } catch (e) {
    print('❌ Error fetching contact campaign: $e');
    return null;
  }
}

// 🔧 FIXED: Update method untuk Deal
Future<ContactDeal?> getContactDeal(String contactId) async {
  try {
    print('📋 Fetching deal for contact: $contactId');
    
    final data = await getContactDetailWithRelations(contactId);
    
    if (data != null && data['Deal'] != null) {
      final dealData = data['Deal'];
      print('✅ Deal found: ${dealData['Name']}');
      return ContactDeal.fromJson(dealData);
    }
    
    print('⚠️ No deal data available');
    return null;
  } catch (e) {
    print('❌ Error fetching contact deal: $e');
    return null;
  }
}

// 🔧 FIXED: Update method untuk FormTemplate
Future<ContactFormTemplate?> getContactFormTemplate(String contactId) async {
  try {
    print('📋 Fetching form template for contact: $contactId');
    
    final data = await getContactDetailWithRelations(contactId);
    
    if (data != null && data['FormR'] != null) {
      final formRData = data['FormR'];
      
      // FormR berisi FormId, gunakan itu untuk get template detail
      if (formRData['FormId'] != null) {
        final formId = formRData['FormId'].toString();
        print('✅ FormTemplate found with FormId: $formId');
        
        // Buat ContactFormTemplate dari FormR data
        return ContactFormTemplate(
          id: formId,
          name: 'Form #$formId',
          description: null,
        );
      }
    }
    
    print('⚠️ No form template data available');
    return null;
  } catch (e) {
    print('❌ Error fetching contact form template: $e');
    return null;
  }
}

// 🔧 FIXED: Update method untuk FormResult
Future<ContactFormResult?> getContactFormResult(String contactId) async {
  try {
    print('📋 Fetching form result for contact: $contactId');
    
    final data = await getContactDetailWithRelations(contactId);
    
    if (data != null && data['FormR'] != null) {
      final formRData = data['FormR'];
      print('✅ FormResult found: ${formRData['SenderNm']}');
      return ContactFormResult.fromJson(formRData);
    }
    
    print('⚠️ No form result data available');
    return null;
  } catch (e) {
    print('❌ Error fetching contact form result: $e');
    return null;
  }
}


  Future<ContactFunnel?> getContactFunnel(String contactId) async {
    try {
      print('Fetching contact funnel for contact ID: $contactId');
      
      final requestData = {
        'EqualityFilter': {'CtId': contactId},
        'IncludeColumns': ['Id', 'Name', 'Description'],
        'ColumnSelection': 1,
        'Take': 1,
        'Skip': 0,
      };

      print('Contact funnel request: $requestData');

      final response = await _dio.post(
        'Services/Chat/Chatfunnels/List',
        data: requestData,
      );

      print('Contact funnel response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        if (entities.isNotEmpty) {
          print('Found contact funnel: ${entities.first}');
          return ContactFunnel.fromJson(entities.first);
        } else {
          print('No funnel found for contact ID: $contactId');
        }
      } else {
        print('Contact Funnel API Error: ${response.data}');
      }

      return null;
    } catch (e) {
      print('Error fetching contact funnel: $e');
      return null;
    }
  }

  Future<List<ContactFunnel>> getAllFunnels() async {
    try {
      print('Fetching all available funnels');
      
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'DisplayName', 'Title', 'Nm', 'FunnelName', 'Label', 'Description', 'Desc'],
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
        
        // Enhanced DEBUG: Print raw response untuk melihat structure data
        if (entities.isNotEmpty) {
          print('=== CONTACT FUNNEL API RESPONSE DEBUG ===');
          for (int i = 0; i < entities.length && i < 3; i++) {
            print('Funnel $i: ${entities[i]}');
            print('Available fields: ${entities[i].keys.toList()}');
          }
          print('========================================');
        }
        
        print('Found ${entities.length} available funnels');
        return entities.map((item) => ContactFunnel.fromJson(item)).toList();
      }

      print('Funnels API Error: ${response.data}');
      return [];
    } catch (e) {
      print('Error fetching all funnels: $e');
      return [];
    }
  }

  Future<String?> createFunnel(String funnelName) async {
    try {
      print('🔨 [Create Funnel] Creating funnel with name: $funnelName');
      
      final requestData = {
        'Entity': {
          'Nm': funnelName,
          'InBy': '',
          'UpBy': '',
        },
      };

      print('🔨 [Create Funnel] Request data: $requestData');
      print('🔨 [Create Funnel] Endpoint: Services/Chat/Chatfunnels/Create');

      final response = await _dio.post(
        'Services/Chat/Chatfunnels/Create',
        data: requestData,
      );

      print('🔨 [Create Funnel] Response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200) {
        // Check if there's an Error field that is not null
        final hasError = response.data['Error'] != null;
        if (!hasError) {
          // Get the EntityId from response
          final entityId = response.data['EntityId'];
          if (entityId != null) {
            print('✅ [Create Funnel] Success - EntityId: $entityId');
            return entityId.toString();
          }
        }
      }

      print('❌ Create Funnel API Error: ${response.data}');
      return null;
    } catch (e) {
      print('❌ Error creating funnel: $e');
      
      // Try to extract error details from DioException
      if (e.toString().contains('DioException')) {
        try {
          final dioError = e as DioException;
          print('❌ Error type: ${dioError.type}');
          print('❌ Error message: ${dioError.message}');
          print('❌ Error response: ${dioError.response?.data}');
          print('❌ Status code: ${dioError.response?.statusCode}');
        } catch (_) {
          // Ignore if casting fails
        }
      }
      
      return null;
    }
  }

  Future<bool> assignFunnelToContact(String roomId, String funnelId) async {
    try {
      print('🎯 [Assign Funnel] Assigning funnel $funnelId to room $roomId');
      
      // Special case: if funnelId is '0', we're removing the funnel (set to null)
      final isRemoving = funnelId == '0';
      
      dynamic funnelValue;
      if (isRemoving) {
        funnelValue = null; // Set to null to remove funnel
        print('🎯 [Assign Funnel] Removing funnel (setting FnId to null)');
      } else {
        // Convert funnelId to int
        final funnelIdInt = int.tryParse(funnelId);
        if (funnelIdInt == null) {
          print('❌ [Assign Funnel] Invalid funnelId format: $funnelId');
          return false;
        }
        funnelValue = funnelIdInt;
      }
      
      final requestData = {
        'EntityId': roomId,
        'Entity': {
          'FnId': funnelValue,
        },
      };
      
      print('🎯 [Assign Funnel] Request data: $requestData');
      print('🎯 [Assign Funnel] Endpoint: Services/Chat/Chatrooms/Update');
      
      final response = await _dio.post(
        'Services/Chat/Chatrooms/Update',
        data: requestData,
      );
      
      print('🎯 [Assign Funnel] Response: ${response.statusCode} - ${response.data}');
      
      if (response.statusCode == 200) {
        final isError = response.data['IsError'];
        final hasError = isError == true;
        
        if (!hasError) {
          print('✅ [Assign Funnel] Success');
          return true;
        } else {
          print('❌ [Assign Funnel] Error: ${response.data['ErrorMsg'] ?? response.data['Error']}');
          return false;
        }
      }
      
      print('❌ [Assign Funnel] API Error: ${response.data}');
      return false;
    } catch (e) {
      print('❌ [Assign Funnel] Exception: $e');
      
      if (e.toString().contains('DioException')) {
        try {
          final dioError = e as DioException;
          print('❌ Error type: ${dioError.type}');
          print('❌ Error message: ${dioError.message}');
          print('❌ Error response: ${dioError.response?.data}');
        } catch (_) {}
      }
      
      return false;
    }
  }

  Future<bool> addContactNote(String roomId, String content) async {
    try {
      print('📝 [Add Contact Note] Starting - RoomId: $roomId');
      print('📝 [Add Contact Note] Content: $content');
      
      // FIXED: Chatnotes table doesn't have CtId field, only RoomId!
      // Backend error: "Could not find field 'CtId' on row of type 'ChatnotesRow'"
      
      // Convert roomId to int (backend expects integer)
      final roomIdInt = int.tryParse(roomId);
      if (roomIdInt == null) {
        print('❌ [Add Contact Note] Invalid roomId format: $roomId');
        return false;
      }
      
      // Format request dengan Entity wrapper - HANYA RoomId, bukan CtId!
      final requestData = {
        'Entity': {
          'RoomId': roomIdInt,  // FIXED: Use RoomId instead of CtId
          'Cnt': content,
        },
      };

      print('📝 [Add Contact Note] Request data: $requestData');
      print('📝 [Add Contact Note] Endpoint: Services/Chat/Chatnotes/Create');

      final response = await _dio.post(
        'Services/Chat/Chatnotes/Create',
        data: requestData,
      );

      print('📝 [Add Contact Note] Response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200) {
        // Check jika ada Error field yang tidak null
        final hasError = response.data['Error'] != null;
        if (!hasError) {
          print('✅ [Add Contact Note] Success');
          return true;
        }
      }

      print('❌ Add Note API Error: ${response.data}');
      return false;
    } catch (e) {
      print('❌ Error adding contact note: $e');
      
      // Try to extract error details from DioException
      if (e.toString().contains('DioException')) {
        try {
          final dioError = e as DioException;
          print('❌ Error type: ${dioError.type}');
          print('❌ Error message: ${dioError.message}');
          print('❌ Error response: ${dioError.response?.data}');
          print('❌ Status code: ${dioError.response?.statusCode}');
        } catch (_) {
          // Ignore if casting fails
        }
      }
      
      return false;
    }
  }

  Future<bool> updateContactNote(String noteId, String content) async {
    try {
      final requestData = {
        'EntityId': noteId,
        'Entity': {
          'Cnt': content,
        },
      };

      final response = await _dio.post(
        'Services/Chat/Chatnotes/Update',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        return true;
      }

      print('Update Note API Error: ${response.data}');
      return false;
    } catch (e) {
      print('Error updating contact note: $e');
      return false;
    }
  }

  Future<bool> deleteContactNote(String noteId) async {
    try {
      final requestData = {
        'EntityId': noteId,
      };

      final response = await _dio.post(
        'Services/Chat/Chatnotes/Delete',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        return true;
      }

      print('Delete Note API Error: ${response.data}');
      return false;
    } catch (e) {
      print('Error deleting contact note: $e');
      return false;
    }
  }

  Future<bool> updateNeedReply(String roomId, bool needReply) async {
    try {
      print('Updating NeedReply status for room $roomId to $needReply');

      final requestData = {
        'EntityId': roomId,
        'Entity': {
          'IsNeedReply': needReply ? 1 : 0,
        },
      };

      print('NeedReply update request: $requestData');

      final response = await _dio.post(
        'Services/Chat/Chatrooms/Update',
        data: requestData,
      );

      print('NeedReply update response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        print('Successfully updated NeedReply status');
        return true;
      }

      print('Update NeedReply API Error: ${response.data}');
      return false;
    } catch (e) {
      print('Error updating NeedReply status: $e');
      return false;
    }
  }

  Future<bool> updateMuteBot(String roomId, bool muteBot) async {
    try {
      print('Updating MuteBot status for room $roomId to $muteBot');

      final requestData = {
        'EntityId': roomId,
        'Entity': {
          'IsMuteBot': muteBot ? 1 : 0,
        },
      };

      print('MuteBot update request: $requestData');

      final response = await _dio.post(
        'Services/Chat/Chatrooms/Update',
        data: requestData,
      );

      print('MuteBot update response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        print('Successfully updated MuteBot status');
        return true;
      }

      print('Update MuteBot API Error: ${response.data}');
      return false;
    } catch (e) {
      print('Error updating MuteBot status: $e');
      return false;
    }
  }

  Future<List<String>> getContactCategories() async {
    try {
      print('Fetching contact categories...');
      
      final requestData = {
        'Take': 1000,
        'Skip': 0,
        'IncludeColumns': ['Category'],
        'ColumnSelection': 1,
      };

      final response = await _dio.post(
        'Services/Nobox/Contact/List',
        data: requestData,
      );

      print('Categories response: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        
        // Extract unique categories
        final categories = <String>{};
        for (var entity in entities) {
          final category = entity['Category'];
          if (category != null && category.toString().isNotEmpty) {
            categories.add(category.toString());
          }
        }
        
        final sortedCategories = categories.toList()..sort();
        print('Found ${sortedCategories.length} unique categories');
        return sortedCategories;
      }

      return [];
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
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
  String? photoBase64, // ✅ Sekarang ini adalah filename dari TemporaryUpload
}) async {
  try {
    print('Updating contact: $contactId');
    
    final Map<String, dynamic> entity = {};
    
    if (name != null && name.isNotEmpty) entity['Name'] = name;
    if (category != null && category.isNotEmpty) entity['Category'] = category;
    if (address != null) entity['Address'] = address;
    if (zipCode != null) entity['Postal'] = zipCode;
    if (city != null) entity['City'] = city;
    if (state != null) entity['State'] = state;
    if (country != null) entity['Country'] = country;
    
    // ✅ PERBAIKAN: Kirim filename dari TemporaryUpload, bukan base64
    if (photoBase64 != null) {
      if (photoBase64.isEmpty) {
        // Empty string means remove photo
        entity['Photo'] = '';
        print('📸 Removing photo');
      } else {
        // Send filename from TemporaryUpload
        entity['Photo'] = photoBase64;
        print('📸 Setting photo to: $photoBase64');
      }
    }
    
    final requestData = {
      'EntityId': contactId,
      'Entity': entity,
    };

    print('Update contact request: $requestData');

    final response = await _dio.post(
      'Services/Nobox/Contact/Update',
      data: requestData,
    );

    print('Update contact response: ${response.statusCode} - ${response.data}');

    if (response.statusCode == 200 && response.data['Error'] == null) {
      print('✅ Successfully updated contact');
      return true;
    }

    print('❌ Update Contact API Error: ${response.data}');
    return false;
  } catch (e) {
    print('❌ Error updating contact: $e');
    
    if (e.toString().contains('DioException')) {
      try {
        final dioError = e as DioException;
        print('❌ Error type: ${dioError.type}');
        print('❌ Error message: ${dioError.message}');
        print('❌ Error response: ${dioError.response?.data}');
      } catch (_) {}
    }
    
    return false;
  }
}

  Future<bool> removeAgentFromConversation({
    required String chatroomAgentId, // ID from chatroomagents table
    required String roomId,
    required int currentUserId,
  }) async {
    try {
      print('🗑️ [Remove Agent] Removing chatroomagent ID $chatroomAgentId from room $roomId');
      
      final requestData = {
        'Delete': {
          'EntityId': chatroomAgentId,
        },
        'Msg': {
          'Type': 6,
          'RoomId': roomId,
          'Msg': '{"msg":"Site.Inbox.AgentOutBy","user":$currentUserId,"userHandle":"$currentUserId"}',
        },
      };

      print('🗑️ [Remove Agent] Request data: $requestData');
      print('🗑️ [Remove Agent] Endpoint: Services/Chat/Chatrooms/RemoveAgentFromConversation');

      final response = await _dio.post(
        'Services/Chat/Chatrooms/RemoveAgentFromConversation',
        data: requestData,
      );

      print('🗑️ [Remove Agent] Response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200) {
        final isError = response.data['IsError'];
        final hasError = isError == true;
        
        if (!hasError) {
          print('✅ [Remove Agent] Successfully removed agent from conversation');
          return true;
        } else {
          print('❌ [Remove Agent] Error: ${response.data['ErrorMsg'] ?? response.data['Error']}');
          return false;
        }
      }

      print('❌ [Remove Agent] API Error: ${response.data}');
      return false;
    } catch (e) {
      print('❌ [Remove Agent] Exception: $e');
      
      if (e.toString().contains('DioException')) {
        try {
          final dioError = e as DioException;
          print('❌ Error type: ${dioError.type}');
          print('❌ Error message: ${dioError.message}');
          print('❌ Error response: ${dioError.response?.data}');
        } catch (_) {}
      }
      
      return false;
    }
  }
}