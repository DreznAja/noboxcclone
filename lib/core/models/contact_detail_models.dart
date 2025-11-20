class ContactDetail {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? category;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? zipCode;
  final String? image;
  final bool isBlocked;
  final String? linkId;
  final int channelId;
  final String channelName;
  final bool isGroup;
  final String? description;
  final String? groupId;
  final String? externalId;
  final List<GroupAgent>? agents;

  ContactDetail({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.category,
    this.address,
    this.city,
    this.state,
    this.country,
    this.zipCode,
    this.image,
    this.isBlocked = false,
    this.linkId,
    required this.channelId,
    required this.channelName,
    this.isGroup = false,
    this.description,
    this.groupId,
    this.externalId,
    this.agents,
  });

  // ✅ COPYWITH METHOD - INI YANG KURANG!
  ContactDetail copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? category,
    String? address,
    String? city,
    String? state,
    String? country,
    String? zipCode,
    String? image,
    bool? isBlocked,
    String? linkId,
    int? channelId,
    String? channelName,
    bool? isGroup,
    String? description,
    String? groupId,
    String? externalId,
    List<GroupAgent>? agents,
  }) {
    return ContactDetail(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      category: category ?? this.category,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      zipCode: zipCode ?? this.zipCode,
      image: image ?? this.image,
      isBlocked: isBlocked ?? this.isBlocked,
      linkId: linkId ?? this.linkId,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      isGroup: isGroup ?? this.isGroup,
      description: description ?? this.description,
      groupId: groupId ?? this.groupId,
      externalId: externalId ?? this.externalId,
      agents: agents ?? this.agents,
    );
  }

  factory ContactDetail.fromJson(Map<String, dynamic> json) {
    print('Parsing contact detail JSON: $json');
    
    List<GroupAgent>? agents;
    if (json['SelectAgents'] != null && json['SelectAgents'] is List) {
      agents = (json['SelectAgents'] as List)
          .map((agent) => GroupAgent.fromJson(agent))
          .toList();
    } else if (json['RoomAgents'] != null && json['RoomAgents'] is List) {
      agents = (json['RoomAgents'] as List)
          .map((agent) => GroupAgent.fromJson(agent))
          .toList();
    }
    
    return ContactDetail(
      id: json['Id']?.toString() ?? '',
      name: json['Name'] ?? json['GrpName'] ?? json['Grp'] ?? '',
      phone: json['Phone'],
      email: json['Email'],
      category: json['Category'],
      address: json['Address'],
      city: json['City'],
      state: json['State'],
      country: json['Country'],
      zipCode: json['Postal'] ?? json['ZipCode'],
      image: json['Photo'] ?? json['Image'] ?? json['GrpImage'],
      isBlocked: json['IsBlock'] == 1 || json['IsBlocked'] == true,
      linkId: json['LinkId']?.toString() ?? json['CtId']?.toString(),
      channelId: json['ChannelId'] ?? json['ChId'] ?? json['Channel'] ?? 0,
      channelName: json['ChannelName'] ?? json['ChAcc'] ?? json['ChannelNm'] ?? '',
      isGroup: json['IsGrp'] == 1 || json['IsGroup'] == true,
      description: json['Description'] ?? json['Desc'],
      groupId: json['GrpId']?.toString(),
      externalId: json['ExtId'] ?? json['GrpExtId'],
      agents: agents,
    );
  }
}

class ConversationHistory {
  final String id;
  final String name;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int status;
  final int channelId;
  final String channelName;
  final bool isPinned;
  final List<String> tags;
  final String? funnel;

  ConversationHistory({
    required this.id,
    required this.name,
    this.lastMessage,
    this.lastMessageTime,
    required this.status,
    required this.channelId,
    required this.channelName,
    this.isPinned = false,
    this.tags = const [],
    this.funnel,
  });

  factory ConversationHistory.fromJson(Map<String, dynamic> json) {
    return ConversationHistory(
      id: json['Id']?.toString() ?? '',
      name: json['CtRealNm'] ?? json['Ct'] ?? json['Grp'] ?? '',
      lastMessage: json['LastMsg'],
      lastMessageTime: json['TimeMsg'] != null ? DateTime.parse(json['TimeMsg']) : null,
      status: json['St'] ?? 1,
      channelId: json['ChId'] ?? 0,
      channelName: json['ChAcc'] ?? '',
      isPinned: json['IsPin'] == 2,
      tags: (json['Tags'] as String?)?.split(',').where((t) => t.isNotEmpty).toList() ?? [],
      funnel: json['Fn'],
    );
  }
}

class ContactNote {
  final String id;
  final String content;
  final DateTime createdAt;
  final String createdBy;

  ContactNote({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.createdBy,
  });

  factory ContactNote.fromJson(Map<String, dynamic> json) {
    print('Parsing ContactNote JSON: $json');
    
    return ContactNote(
      id: json['Id']?.toString() ?? json['id']?.toString() ?? '',
      content: json['Cnt'] ?? json['Content'] ?? json['content'] ?? '',
      createdAt: json['In'] != null 
          ? DateTime.parse(json['In']) 
          : (json['createdAt'] != null 
              ? DateTime.parse(json['createdAt']) 
              : DateTime.now()),
      createdBy: json['InBy']?.toString() ?? json['createdBy']?.toString() ?? json['CreatedBy']?.toString() ?? '',
    );
  }
}

class ContactCampaign {
  final String id;
  final String name;
  final int status;
  final String? description;

  ContactCampaign({
    required this.id,
    required this.name,
    required this.status,
    this.description,
  });

  factory ContactCampaign.fromJson(Map<String, dynamic> json) {
    return ContactCampaign(
      id: json['Id']?.toString() ?? '',
      name: json['Name'] ?? '',
      status: json['Status'] ?? 1,
      description: json['Description'],
    );
  }
}

class ContactDeal {
  final String id;
  final String name;
  final String? pipeline;
  final String? stage;
  final double? value;

  ContactDeal({
    required this.id,
    required this.name,
    this.pipeline,
    this.stage,
    this.value,
  });

  factory ContactDeal.fromJson(Map<String, dynamic> json) {
    return ContactDeal(
      id: json['Id']?.toString() ?? '',
      name: json['Name'] ?? '',
      pipeline: json['Pipeline'],
      stage: json['Stage'],
      value: json['Value']?.toDouble(),
    );
  }
}

class ContactFormTemplate {
  final String id;
  final String name;
  final String? description;

  ContactFormTemplate({
    required this.id,
    required this.name,
    this.description,
  });

  factory ContactFormTemplate.fromJson(Map<String, dynamic> json) {
    return ContactFormTemplate(
      id: json['Id']?.toString() ?? '',
      name: json['Name'] ?? '',
      description: json['Description'],
    );
  }
}

class ContactFormResult {
  final String id;
  final String senderName;
  final DateTime? submittedAt;

  ContactFormResult({
    required this.id,
    required this.senderName,
    this.submittedAt,
  });

  factory ContactFormResult.fromJson(Map<String, dynamic> json) {
    return ContactFormResult(
      id: json['Id']?.toString() ?? '',
      senderName: json['SenderNm'] ?? json['SenderName'] ?? '',
      submittedAt: json['In'] != null ? DateTime.parse(json['In']) : null,
    );
  }
}

class ContactFunnel {
  final String id;
  final String name;
  final String? description;

  ContactFunnel({
    required this.id,
    required this.name,
    this.description,
  });

// contact_detail_models.dart - Perbaikan di ContactFunnel.fromJson

factory ContactFunnel.fromJson(Map<String, dynamic> json) {
  print('ContactFunnel JSON: $json');
  
  String displayName = '';
  
  // ✅ PERBAIKAN: Coba semua field name yang mungkin
  final nameFields = [
    'Nm',           // ← PRIORITASKAN INI DULU (field asli dari Chatfunnels table)
    'Name',
    'name', 
    'DisplayName', 
    'Title', 
    'title', 
    'FunnelName', 
    'Label', 
    'label'
  ];
  
  for (final field in nameFields) {
    if (json[field] != null && json[field].toString().trim().isNotEmpty) {
      displayName = json[field].toString().trim();
      print('✅ Found funnel name in field "$field": $displayName');
      break;
    }
  }
  
  // ✅ PERBAIKAN: Jika masih kosong, gunakan ID saja (jangan buat fallback name palsu)
  if (displayName.isEmpty) {
    displayName = json['Id']?.toString() ?? json['id']?.toString() ?? '';
    print('⚠️ No name found for funnel, using ID only: $displayName');
  }
  
  String? description;
  final descFields = ['Description', 'description', 'Desc', 'desc'];
  for (final field in descFields) {
    if (json[field] != null && json[field].toString().trim().isNotEmpty) {
      description = json[field].toString().trim();
      break;
    }
  }
  
  return ContactFunnel(
    id: json['Id']?.toString() ?? json['id']?.toString() ?? '',
    name: displayName,
    description: description,
  );
}
}

class GroupAgent {
  final String id; // ID from chatroomagents table
  final String userId;
  final String displayName;
  final String email;
  final String? userImage;
  final DateTime? lastLogin;

  GroupAgent({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.email,
    this.userImage,
    this.lastLogin,
  });

  factory GroupAgent.fromJson(Map<String, dynamic> json) {
    return GroupAgent(
      id: json['Id']?.toString() ?? '', // This is the chatroomagents record ID
      userId: json['UserId']?.toString() ?? '',
      displayName: json['DisplayName'] ?? json['Username'] ?? '',
      email: json['Email'] ?? json['UserEmail'] ?? json['Username'] ?? '',
      userImage: json['UserImage'],
      lastLogin: json['LastLogin'] != null ? DateTime.parse(json['LastLogin']) : null,
    );
  }
}