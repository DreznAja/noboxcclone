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
  final String? contactImage;
  final String? linkImage;
  final bool isGroup;
  final bool isPinned;
  final bool isBlocked;
  final bool isMuteBot;
  final List<String> tags;
  final String? funnel;
  final String? funnelId;
  final List<String> tagIds;

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
    required this.channelId,
    required this.channelName,
    this.contactImage,
    this.linkImage,
    this.isGroup = false,
    this.isPinned = false,
    this.isBlocked = false,
    this.isMuteBot = false,
    this.tags = const [],
    this.funnel,
    this.funnelId,
    this.tagIds = const [],
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    print('Parsing room JSON: $json');
    
    return Room(
      id: json['Id']?.toString() ?? '',
      ctId: json['CtId']?.toString(),
      ctRealId: json['CtRealId']?.toString(),
      grpId: json['GrpId']?.toString(),
      name: json['CtRealNm'] ?? json['Ct'] ?? json['Grp'] ?? '',
      lastMessage: json['LastMsg'],
      lastMessageTime: json['TimeMsg'] != null ? DateTime.parse(json['TimeMsg']) : null,
      unreadCount: json['Uc'] ?? 0,
      status: json['St'] ?? 1,
      channelId: json['ChId'] ?? 0,
      channelName: json['ChAcc'] ?? '',
      contactImage: json['CtImg'],
      linkImage: json['LinkImg'],
      isGroup: json['IsGrp'] == 1,
      isPinned: json['IsPin'] == 2,
      isBlocked: json['CtIsBlock'] == 1,
      isMuteBot: json['IsMuteBot'] == 1,
      tags: (json['Tags'] as String?)?.split(',').where((t) => t.isNotEmpty).toList() ?? [],
      funnel: json['Fn'],
      funnelId: json['FnId']?.toString(),
      tagIds: (json['TagsIds'] as String?)?.split(',').where((t) => t.isNotEmpty).toList() ?? [],
    );
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
    
    return ChatMessage(
      id: json['Id']?.toString() ?? '',
      roomId: json['RoomId']?.toString() ?? '',
      from: json['From']?.toString() ?? '',
      to: json['To']?.toString(),
      agentId: _parseInt(json['AgentId']) ?? 0,
      type: _parseInt(json['Type']) ?? 1,
      message: json['Msg'],
      file: json['File'],
      files: json['Files'],
      timestamp: _parseDateTime(json['In']),
      ack: _parseInt(json['Ack']) ?? 1,
      replyId: json['ReplyId']?.toString(),
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