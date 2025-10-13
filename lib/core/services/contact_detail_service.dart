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

  Future<ContactDetail?> getContactDetail(String contactId) async {
    try {
      print('Fetching contact detail for ID: $contactId');
      
      final requestData = {
        'IncludeColumns': ['Id', 'Name', 'Phone', 'Email', 'Address', 'City', 'State', 'Country', 'ZipCode', 'Photo', 'IsBlock'],
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
          return ContactDetail.fromJson(contactData);
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
      final requestData = {
        'EqualityFilter': {'CtId': contactId},
        'Take': 1,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/Nobox/Campaign/List',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        if (entities.isNotEmpty) {
          return ContactCampaign.fromJson(entities.first);
        }
      }

      return null;
    } catch (e) {
      print('Error fetching contact campaign: $e');
      return null;
    }
  }

  Future<ContactDeal?> getContactDeal(String contactId) async {
    try {
      final requestData = {
        'EqualityFilter': {'CtId': contactId},
        'Take': 1,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/Nobox/Deals/List',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        if (entities.isNotEmpty) {
          return ContactDeal.fromJson(entities.first);
        }
      }

      return null;
    } catch (e) {
      print('Error fetching contact deal: $e');
      return null;
    }
  }

  Future<ContactFormTemplate?> getContactFormTemplate(String contactId) async {
    try {
      final requestData = {
        'EqualityFilter': {'CtId': contactId},
        'Take': 1,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/NoBoxCRM/Form/List',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        if (entities.isNotEmpty) {
          return ContactFormTemplate.fromJson(entities.first);
        }
      }

      return null;
    } catch (e) {
      print('Error fetching contact form template: $e');
      return null;
    }
  }

  Future<ContactFormResult?> getContactFormResult(String contactId) async {
    try {
      final requestData = {
        'EqualityFilter': {'CtId': contactId},
        'Take': 1,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/NoBoxCRM/Formresults/List',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        if (entities.isNotEmpty) {
          return ContactFormResult.fromJson(entities.first);
        }
      }

      return null;
    } catch (e) {
      print('Error fetching contact form result: $e');
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

  Future<bool> assignFunnelToContact(String contactId, String funnelId) async {
    try {
      print('Assigning funnel $funnelId to contact $contactId');
      
      final requestData = {
        'CtId': int.tryParse(contactId) ?? 0,
        'FnId': int.tryParse(funnelId) ?? 0,
      };

      print('Funnel assignment request data: $requestData');

      final response = await _dio.post(
        'Services/Chat/Chatrooms/AssignFunnel',
        data: requestData,
      );

      print('Funnel assignment response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        print('Successfully assigned funnel to contact');
        return true;
      }

      print('Assign Funnel API Error: ${response.data}');
      return false;
    } catch (e) {
      print('Error assigning funnel to contact: $e');
      return false;
    }
  }

  Future<bool> removeFunnelFromContact(String contactId) async {
    try {
      print('Removing funnel from contact $contactId');
      
      final requestData = {
        'CtId': int.tryParse(contactId) ?? 0,
        'FnId': null,
      };

      print('Remove funnel request data: $requestData');

      final response = await _dio.post(
        'Services/Chat/Chatrooms/RemoveFunnel',
        data: requestData,
      );

      print('Remove funnel response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        print('Successfully removed funnel from contact');
        return true;
      }

      print('Remove Funnel API Error: ${response.data}');
      return false;
    } catch (e) {
      print('Error removing funnel from contact: $e');
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
          'NeedReply': needReply ? 1 : 0,
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
}