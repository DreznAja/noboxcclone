class ChannelOption {
  final String id;
  final String name;

  ChannelOption({
    required this.id,
    required this.name,
  });

  factory ChannelOption.fromJson(Map<String, dynamic> json) {
    return ChannelOption(
      id: json['Id']?.toString() ?? '',
      name: json['Nm']?.toString() ?? json['Name']?.toString() ?? '',
    );
  }
}

class AccountOption {
  final String id;
  final String name;

  AccountOption({
    required this.id,
    required this.name,
  });

  factory AccountOption.fromJson(Map<String, dynamic> json) {
    return AccountOption(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['DisplayName']?.toString() ?? '',
    );
  }
}

class ContactOption {
  final String id;
  final String name;

  ContactOption({
    required this.id,
    required this.name,
  });

  factory ContactOption.fromJson(Map<String, dynamic> json) {
    return ContactOption(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['DisplayName']?.toString() ?? '',
    );
  }
}

class LinkOption {
  final String id;
  final String name;

  LinkOption({
    required this.id,
    required this.name,
  });

  factory LinkOption.fromJson(Map<String, dynamic> json) {
    return LinkOption(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['DisplayName']?.toString() ?? '',
    );
  }
}

class GroupOption {
  final String id;
  final String name;

  GroupOption({
    required this.id,
    required this.name,
  });

  factory GroupOption.fromJson(Map<String, dynamic> json) {
    return GroupOption(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['DisplayName']?.toString() ?? '',
    );
  }
}

class RoomDetail {
  final String id;
  final String name;
  final String? contactId;
  final String? linkId;
  final String? groupId;

  RoomDetail({
    required this.id,
    required this.name,
    this.contactId,
    this.linkId,
    this.groupId,
  });

  factory RoomDetail.fromJson(Map<String, dynamic> json) {
    return RoomDetail(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      contactId: json['CtId']?.toString(),
      linkId: json['LinkId']?.toString(),
      groupId: json['GrpId']?.toString(),
    );
  }
}