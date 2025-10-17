import 'dart:convert';

class MessageTag {
  final String id;
  final String name;

  MessageTag({
    required this.id,
    required this.name,
  });

  factory MessageTag.fromJson(Map<String, dynamic> json) {
    return MessageTag(
      id: json['Id']?.toString() ?? '',
      name: json['Nm']?.toString() ?? json['Name']?.toString() ?? '',
    );
  }
}

class Room {
  final String id;
  final String? ctId;
  final String? ctRealId;
  final String? grpId;
  final String name;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final int status; // 1: unassigned, 2: assigned, 3: resolved
  final int channelId;
  final String channelName;
  final String? accountName;
  final String? botName;
  final String? contactImage;
  final String? linkImage;
  final bool isGroup;
  final bool isPinned;
  final bool isBlocked;
  final bool isMuteBot;
  final List<String> tags;
  final List<MessageTag> messageTags;
  final String? funnel;
  final String? funnelId;
  final List<String> tagIds;
  final bool needReply;
  final int? lastUpdatedBy; // Agent ID who last updated the room (UpBy field)

  Room({
    required this.id,
    this.ctId,
    this.ctRealId,
    this.grpId,
    required this.name,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    required this.status,
    this.accountName,
    this.botName,
    required this.channelId,
    required this.channelName,
    this.contactImage,
    this.linkImage,
    this.isGroup = false,
    this.isPinned = false,
    this.isBlocked = false,
    this.isMuteBot = false,
    this.tags = const [],
    this.messageTags = const [],
    this.funnel,
    this.funnelId,
    this.tagIds = const [],
    this.needReply = false,
    this.lastUpdatedBy,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    // Parse ChAcc first as it's the primary bot/account name from home screen API
    final channelNameRaw = json['ChAcc'];
    
    // ChAcc is the account name - use it if AccNm is not available
    // Priority: AccNm > ChAcc (if not "Not Found") > null
    final accountName = json['AccNm'] ?? 
                       json['AccountName'] ?? 
                       (channelNameRaw != null && 
                        channelNameRaw.toString().isNotEmpty && 
                        channelNameRaw.toString() != 'Not Found' 
                        ? channelNameRaw.toString() 
                        : null);
    
    final botName = json['BotNm'] ?? json['BotName'];
    final contactName = json['CtRealNm'] ?? json['Ct'] ?? json['Grp'];
    
    // Enhanced debug logging
    print('📝 Parsing room: ${json['Id']}');
    print('  🤖 AccNm: ${json['AccNm']} -> accountName: $accountName');
    print('  🤖 BotNm: ${json['BotNm']} -> botName: $botName');
    print('  📶 ChAcc: $channelNameRaw, ChId: ${json['ChId']}');
    print('  👤 Contact: ${json['CtRealNm']} / ${json['Ct']} / ${json['Grp']} -> $contactName');
    print('  📈 Status: ${json['St']}');
    print('  🔔 IsMuteBot: ${json['IsMuteBot']} -> ${json['IsMuteBot'] == 1}');
    print('  📌 IsNeedReply: ${json['IsNeedReply']}, NeedReply: ${json['NeedReply']}');
    
    return Room(
      id: json['Id']?.toString() ?? '',
      ctId: json['CtId']?.toString(),
      ctRealId: json['CtRealId']?.toString(),
      grpId: json['GrpId']?.toString(),
      name: contactName ?? accountName ?? botName ?? 'Unknown',
      lastMessage: json['LastMsg'],
      lastMessageTime: json['TimeMsg'] != null ? DateTime.parse(json['TimeMsg']) : null,
      accountName: accountName,
      botName: botName,
      unreadCount: json['Uc'] ?? 0,
      status: json['St'] ?? 1,
      channelId: json['ChId'] ?? 0,
      // FIXED: Filter out "Not Found" and empty strings
      channelName: (channelNameRaw != null && 
                    channelNameRaw.toString().isNotEmpty && 
                    channelNameRaw.toString() != 'Not Found') 
          ? channelNameRaw.toString() 
          : '',
      contactImage: json['CtImg'],
      linkImage: json['LinkImg'],
      isGroup: json['IsGrp'] == 1,
      isPinned: json['IsPin'] == 2,
      isBlocked: json['CtIsBlock'] == 1,
      isMuteBot: json['IsMuteBot'] == 1,
      tags: (json['Tags'] as String?)?.split(',').where((t) => t.isNotEmpty).toList() ?? [],
      messageTags: _parseMessageTags(json),
      funnel: json['Fn'] ?? json['FnNm'], // Also check FnNm field
      funnelId: json['FnId']?.toString() ?? json['FunnelId']?.toString(), // Also check FunnelId field
      tagIds: (json['TagsIds'] as String?)?.split(',').where((t) => t.isNotEmpty).toList() ?? [],
      needReply: json['NeedReply'] == 1 || json['NeedReply'] == true || json['IsNeedReply'] == 1 || json['IsNeedReply'] == true,
      lastUpdatedBy: json['UpBy'] != null ? int.tryParse(json['UpBy'].toString()) : null,
    );
  }

  static List<MessageTag> _parseMessageTags(Map<String, dynamic> json) {
    try {
      // Enhanced parsing for TagsIds and Tags fields
      final tagIds = json['TagsIds'] as String?;
      final tagNames = json['Tags'] as String?;
      
      print('🏷️ Parsing message tags - TagsIds: $tagIds, Tags: $tagNames');
      
      if (tagIds != null && tagNames != null && tagIds.isNotEmpty && tagNames.isNotEmpty) {
        // Handle both comma-separated strings and JSON arrays
        List<String> idList = [];
        List<String> nameList = [];
        
        // Try to parse as JSON array first
        try {
          if (tagIds.startsWith('[') && tagIds.endsWith(']')) {
            final dynamic parsedIds = jsonDecode(tagIds);
            if (parsedIds is List) {
              idList = parsedIds.map((id) => id.toString().trim()).where((id) => id.isNotEmpty).toList();
            }
          } else {
            idList = tagIds.split(',').map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
          }
        } catch (e) {
          idList = tagIds.split(',').map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
        }
        
        try {
          if (tagNames.startsWith('[') && tagNames.endsWith(']')) {
            final dynamic parsedNames = jsonDecode(tagNames);
            if (parsedNames is List) {
              nameList = parsedNames.map((name) => name.toString().trim()).where((name) => name.isNotEmpty).toList();
            }
          } else {
            nameList = tagNames.split(',').map((name) => name.trim()).where((name) => name.isNotEmpty).toList();
          }
        } catch (e) {
          nameList = tagNames.split(',').map((name) => name.trim()).where((name) => name.isNotEmpty).toList();
        }
        
        print('🏷️ Parsed ID list: $idList');
        print('🏷️ Parsed name list: $nameList');
        
        final List<MessageTag> tags = [];
        for (int i = 0; i < idList.length && i < nameList.length; i++) {
          tags.add(MessageTag(
            id: idList[i],
            name: nameList[i],
          ));
        }
        
        print('🏷️ Created ${tags.length} message tags');
        return tags;
      }
    } catch (e) {
      print('Error parsing message tags: $e');
    }
    return [];
  }

  get chAcc => null;
}

class ChatMessage {
  final String id;
  final String roomId;
  final String from;
  final String? to;
  final int agentId;
  final int type;
  final String? message;
  final String? file;
  final String? files;
  final DateTime timestamp;
  final int ack; // 1: pending, 2: sent, 3: delivered, 4: failed, 5: read
  final String? replyId;
  final int? replyType;
  final String? replyFrom;
  final String? replyMessage;
  final String? replyFiles;
  final String? replyGrpMember;
  final bool isEdited;
  final String? note;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.from,
    this.to,
    required this.agentId,
    required this.type,
    this.message,
    this.file,
    this.files,
    required this.timestamp,
    this.ack = 1,
    this.replyId,
    this.replyType,
    this.replyFrom,
    this.replyMessage,
    this.replyFiles,
    this.replyGrpMember,
    this.isEdited = false,
    this.note,
  });

  // Helper method to convert to JSON for compatibility checks
  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'RoomId': roomId,
      'From': from,
      'To': to,
      'AgentId': agentId,
      'Type': type,
      'Msg': message,
      'File': file,
      'Files': files,
      'In': timestamp.toIso8601String(),
      'Ack': ack,
      'ReplyId': replyId,
      'ReplyType': replyType,
      'ReplyFrom': replyFrom,
      'ReplyMsg': replyMessage,
      'ReplyFiles': replyFiles,
      'ReplyGrpMember': replyGrpMember,
      'InteractiveType': isEdited ? 99 : null,
      'Note': note,
    };
  }
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    print('Parsing message: $json');
    
    // FIXED: Enhanced ReplyId validation during parsing
    String? validReplyId;
    final rawReplyId = json['ReplyId']?.toString()?.trim();
    if (rawReplyId != null && rawReplyId.isNotEmpty && !rawReplyId.startsWith('temp_')) {
      final numericReplyId = int.tryParse(rawReplyId);
      if (numericReplyId != null && numericReplyId > 0) {
        // CRITICAL FIX: Always store ReplyId as string format
        validReplyId = numericReplyId.toString();
        print('✅ Parsed valid ReplyId: $validReplyId');
      } else {
        print('⚠️ Invalid ReplyId format during parsing: $rawReplyId');
        validReplyId = null;
      }
    }
    
    return ChatMessage(
      id: json['Id']?.toString() ?? '',
      roomId: json['RoomId']?.toString() ?? '',
      from: json['From']?.toString() ?? '',
      to: json['To']?.toString(),
      agentId: _parseInt(json['AgentId']) ?? 0,
      type: _parseInt(json['Type']) ?? 1,
      message: (() {
        final raw = json['Msg'];
        if (raw != null && raw.toString().trim().isNotEmpty) return raw.toString();
        // Fallback: try to extract caption from File/Files JSON
        try {
          final fileField = json['File'];
          if (fileField != null) {
            if (fileField is String && (fileField.startsWith('[') || fileField.startsWith('{'))) {
              final dynamic parsed = jsonDecode(fileField);
              if (parsed is Map && parsed['Caption'] != null && parsed['Caption'].toString().trim().isNotEmpty) {
                return parsed['Caption'].toString().trim();
              }
              if (parsed is List && parsed.isNotEmpty && parsed[0] is Map && parsed[0]['Caption'] != null) {
                final cap = parsed[0]['Caption'].toString().trim();
                if (cap.isNotEmpty) return cap;
              }
            } else if (fileField is Map && fileField['Caption'] != null) {
              final cap = fileField['Caption'].toString().trim();
              if (cap.isNotEmpty) return cap;
            }
          }
          final filesField = json['Files'];
          if (filesField != null) {
            if (filesField is String && (filesField.startsWith('[') || filesField.startsWith('{'))) {
              final dynamic parsed = jsonDecode(filesField);
              if (parsed is Map && parsed['Caption'] != null && parsed['Caption'].toString().trim().isNotEmpty) {
                return parsed['Caption'].toString().trim();
              }
              if (parsed is List && parsed.isNotEmpty && parsed[0] is Map && parsed[0]['Caption'] != null) {
                final cap = parsed[0]['Caption'].toString().trim();
                if (cap.isNotEmpty) return cap;
              }
            } else if (filesField is Map && filesField['Caption'] != null) {
              final cap = filesField['Caption'].toString().trim();
              if (cap.isNotEmpty) return cap;
            }
          }
        } catch (_) {}
        return null;
      })(),
      file: json['File']?.toString(),
      files: json['Files']?.toString(),
      timestamp: _parseDateTime(json['In']),
      ack: _parseInt(json['Ack']) ?? 1,
      replyId: validReplyId,
      replyType: _parseInt(json['ReplyType']),
      replyFrom: json['ReplyFrom']?.toString(),
      replyMessage: json['ReplyMsg'],
      replyFiles: json['ReplyFiles'],
      replyGrpMember: json['ReplyGrpMember'],
      isEdited: json['InteractiveType'] == 99,
      note: json['Note'],
    );
  }
  
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        print('Error parsing int from string: $value, error: $e');
        return null;
      }
    }
    return null;
  }
  
  static DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    
    try {
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      } else if (dateValue is int) {
        // Handle Unix timestamp (milliseconds)
        return DateTime.fromMillisecondsSinceEpoch(dateValue);
      }
    } catch (e) {
      print('Error parsing date: $dateValue, error: $e');
    }
    
    return DateTime.now();
  }
}

class Contact {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? image;
  final String? address;
  final String? city;
  final String? country;

  Contact({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.image,
    this.address,
    this.city,
    this.country,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['Id']?.toString() ?? '',
      name: json['Name'] ?? '',
      email: json['Email'],
      phone: json['Phone'],
      image: json['Photo'],
      address: json['Address'],
      city: json['City'],
      country: json['Country'],
    );
  }
}

class Agent {
  final String id;
  final int userId;
  final String displayName;
  final String? userImage;

  Agent({
    required this.id,
    required this.userId,
    required this.displayName,
    this.userImage,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['Id']?.toString() ?? '',
      userId: json['UserId'] ?? 0,
      displayName: json['DisplayName'] ?? '',
      userImage: json['UserImage'],
    );
  }
}

class UploadedFile {
  final String filename;
  final String originalName;

  UploadedFile({
    required this.filename,
    required this.originalName,
  });

  factory UploadedFile.fromJson(Map<String, dynamic> json) {
    return UploadedFile(
      filename: json['Filename'] ?? json['filename'] ?? '',
      originalName: json['OriginalName'] ?? json['originalName'] ?? json['OriginalName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Filename': filename,
      'OriginalName': originalName,
    };
  }
}