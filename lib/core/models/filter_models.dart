class FilterOptions {
  String? status;
  String? isMuteAiAgent;
  String? readStatus;
  String? channelId;
  String? chatType;
  String? accountId;
  String? contactId;
  String? linkId;
  String? groupId;
  String? campaignId;
  String? funnelId;
  String? dealId;
  String? tagId;
  String? humanAgentId;

  FilterOptions({
    this.status,
    this.isMuteAiAgent,
    this.readStatus,
    this.channelId,
    this.chatType,
    this.accountId,
    this.contactId,
    this.linkId,
    this.groupId,
    this.campaignId,
    this.funnelId,
    this.dealId,
    this.tagId,
    this.humanAgentId,
  });

  bool get hasActiveFilters {
    return status != null ||
        isMuteAiAgent != null ||
        readStatus != null ||
        channelId != null ||
        chatType != null ||
        accountId != null ||
        contactId != null ||
        linkId != null ||
        groupId != null ||
        campaignId != null ||
        funnelId != null ||
        dealId != null ||
        tagId != null ||
        humanAgentId != null;
  }

  void reset() {
    status = null;
    isMuteAiAgent = null;
    readStatus = null;
    channelId = null;
    chatType = null;
    accountId = null;
    contactId = null;
    linkId = null;
    groupId = null;
    campaignId = null;
    funnelId = null;
    dealId = null;
    tagId = null;
    humanAgentId = null;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> filters = {};
    
    // Convert filter values to appropriate API format
    if (status != null) {
      switch (status) {
        case 'Unassigned':
          filters['St'] = [1];
          break;
        case 'Assigned':
          filters['St'] = [2];
          break;
        case 'Resolved':
          filters['St'] = [3];
          break;
      }
    }
    
    if (isMuteAiAgent != null) {
      filters['IsMuteBot'] = isMuteAiAgent == 'Active' ? [1] : [0];
    }
    
    if (readStatus != null) {
      // FIXED: ReadStatus menggunakan client-side filtering
      // Backend ReadStatus filter kadang trigger action "mark as read"
      // Jadi kita filter di client side aja seperti Private chat
      // Is Read = percakapan yang udah dibaca (unreadCount = 0)
      // Unread = percakapan yang belum dibaca (unreadCount > 0)
      filters['ReadStatusFilter'] = readStatus; // Temporary flag untuk client-side filtering
      print('📝 [FilterOptions] Read status filter: $readStatus (will filter client-side)');
    }
    
    if (channelId != null) filters['ChId'] = [int.parse(channelId!)];
    // Chat Type filter: Group or Private
    if (chatType != null) {
      if (chatType == 'Group') {
        // For Group chats, send IsGrp=[1] to backend
        filters['IsGrp'] = [1];
        print('📝 [FilterOptions] Chat type filter: Group (IsGrp=[1])');
      } else if (chatType == 'Private') {
        // FIXED: For Private chats, use client-side filtering
        // Backend doesn't support IsGrp=[0] properly, so we add a temporary flag
        // that chat_provider will use for client-side filtering
        filters['ChatTypeFilter'] = 'Private';
        print('📝 [FilterOptions] Chat type filter: Private (will filter client-side)');
      }
    }
    // FIXED: Account filter using ChAccId (Channel Account ID)
    // Web version uses ChAccId in EqualityFilter
    if (accountId != null) {
      try {
        // Send as string, not int array - web sends "706026840646405"
        filters['ChAccId'] = accountId;
        print('📝 [FilterOptions] Account filter added: ChAccId = $accountId');
      } catch (e) {
        print('⚠️ [FilterOptions] Failed to set Account filter: $e');
      }
    }
    // TESTING: Try CtRealId instead of CtId for contact filter
    // Backend might use CtRealId as the primary contact identifier
    if (contactId != null) {
      // Try CtRealId first (Real Contact ID)
      filters['CtRealId'] = [int.parse(contactId!)];
      print('📝 [FilterOptions] Contact filter added: CtRealId = ${contactId!}');
      
      // Alternative if CtRealId doesn't work:
      // filters['CtId'] = [int.parse(contactId!)];
    }
    if (linkId != null) filters['LinkId'] = [int.parse(linkId!)];
    if (groupId != null) filters['GrpId'] = [int.parse(groupId!)];
    if (campaignId != null) filters['CampaignId'] = [int.parse(campaignId!)];
    
    // FIXED: FunnelId menggunakan client-side filtering
    // Backend FunnelId filter menyebabkan error 500
    if (funnelId != null) {
      filters['FunnelIdFilter'] = funnelId; // Temporary flag untuk client-side filtering
      print('📝 [FilterOptions] Funnel filter: $funnelId (will filter client-side)');
    }
    
    if (dealId != null) filters['DealId'] = [int.parse(dealId!)];
    
    // FIXED: TagId menggunakan client-side filtering
    // Backend TagId filter menyebabkan error 500
    if (tagId != null) {
      filters['TagIdFilter'] = tagId; // Temporary flag untuk client-side filtering
      print('📝 [FilterOptions] Tag filter: $tagId (will filter client-side)');
    }
    
    // FIXED: HumanAgentId menggunakan client-side filtering
    // Backend AgentId filter menyebabkan error 500
    if (humanAgentId != null) {
      filters['HumanAgentIdFilter'] = humanAgentId; // Temporary flag untuk client-side filtering
      print('📝 [FilterOptions] Human Agent filter: $humanAgentId (will filter client-side)');
    }
    
    return filters;
  }
}

// API Response Models
class FilterDataItem {
  final String id;
  final String name;
  final String? description;

  FilterDataItem({
    required this.id,
    required this.name,
    this.description,
  });

  factory FilterDataItem.fromJson(Map<String, dynamic> json) {
    return FilterDataItem(
      id: json['Id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['Nm']?.toString() ?? 
            json['Name']?.toString() ?? 
            json['name']?.toString() ?? 
            json['DisplayName']?.toString() ??
            json['title']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }
}

class ChannelItem extends FilterDataItem {
  ChannelItem({required super.id, required super.name});

  factory ChannelItem.fromJson(Map<String, dynamic> json) {
    return ChannelItem(
      id: json['Id']?.toString() ?? '',
      name: json['Nm']?.toString() ?? json['Name']?.toString() ?? '',
    );
  }
}

class AccountItem extends FilterDataItem {
  AccountItem({required super.id, required super.name});

  factory AccountItem.fromJson(Map<String, dynamic> json) {
    return AccountItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['DisplayName']?.toString() ?? '',
    );
  }
}

class ContactItem extends FilterDataItem {
  ContactItem({required super.id, required super.name});

  factory ContactItem.fromJson(Map<String, dynamic> json) {
    return ContactItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['DisplayName']?.toString() ?? '',
    );
  }
}

class LinkItem extends FilterDataItem {
  LinkItem({required super.id, required super.name});

  factory LinkItem.fromJson(Map<String, dynamic> json) {
    return LinkItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['DisplayName']?.toString() ?? '',
    );
  }
}

class GroupItem extends FilterDataItem {
  GroupItem({required super.id, required super.name});

  factory GroupItem.fromJson(Map<String, dynamic> json) {
    return GroupItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['DisplayName']?.toString() ?? '',
    );
  }
}

class CampaignItem extends FilterDataItem {
  CampaignItem({required super.id, required super.name});

  factory CampaignItem.fromJson(Map<String, dynamic> json) {
    return CampaignItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['DisplayName']?.toString() ?? '',
    );
  }
}

class FunnelItem extends FilterDataItem {
  FunnelItem({required super.id, required super.name});

  factory FunnelItem.fromJson(Map<String, dynamic> json) {
    // Debug print untuk melihat data yang diterima
    print('FunnelItem.fromJson: $json');
    
    return FunnelItem(
      id: json['Id']?.toString() ?? '',
      // Coba berbagai kemungkinan field name untuk funnel
      name: json['Name']?.toString() ?? 
            json['DisplayName']?.toString() ?? 
            json['Title']?.toString() ?? 
            json['Nm']?.toString() ?? 
            json['FunnelName']?.toString() ?? 
            json['Label']?.toString() ?? 
            'Funnel ${json['Id']}', // Fallback dengan ID
    );
  }
}

class DealItem extends FilterDataItem {
  DealItem({required super.id, required super.name});

  factory DealItem.fromJson(Map<String, dynamic> json) {
    return DealItem(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['DisplayName']?.toString() ?? '',
    );
  }
}

class TagItem extends FilterDataItem {
  TagItem({required super.id, required super.name});

  factory TagItem.fromJson(Map<String, dynamic> json) {
    // Debug print untuk melihat data yang diterima
    print('TagItem.fromJson: $json');
    
    return TagItem(
      id: json['Id']?.toString() ?? '',
      // Coba berbagai kemungkinan field name untuk tag
      name: json['Name']?.toString() ?? 
            json['DisplayName']?.toString() ?? 
            json['TagName']?.toString() ?? 
            json['Title']?.toString() ?? 
            json['Nm']?.toString() ?? 
            json['Label']?.toString() ?? 
            'Tag ${json['Id']}', // Fallback dengan ID
    );
  }
}

class HumanAgentItem extends FilterDataItem {
  HumanAgentItem({required super.id, required super.name});

  factory HumanAgentItem.fromJson(Map<String, dynamic> json) {
    return HumanAgentItem(
      id: json['Id']?.toString() ?? json['UserId']?.toString() ?? '',
      name: json['DisplayName']?.toString() ?? json['Name']?.toString() ?? json['Username']?.toString() ?? '',
    );
  }
}