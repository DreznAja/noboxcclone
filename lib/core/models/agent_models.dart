class HumanAgent {
  final int userId;
  final String displayName;
  final String email;
  final String? userImage;

  HumanAgent({
    required this.userId,
    required this.displayName,
    required this.email,
    this.userImage,
  });

  factory HumanAgent.fromJson(Map<String, dynamic> json) {
    return HumanAgent(
      userId: json['UserId'] is int ? json['UserId'] : int.parse(json['UserId'].toString()),
      displayName: json['DisplayName']?.toString() ?? '',
      email: json['Email']?.toString() ?? json['Username']?.toString() ?? '',
      userImage: json['UserImage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'UserId': userId,
      'DisplayName': displayName,
      'Email': email,
      'UserImage': userImage,
    };
  }
}

class AddAgentRequest {
  final String roomId;
  final String userId;
  final int isHanded;

  AddAgentRequest({
    required this.roomId,
    required this.userId,
    this.isHanded = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'RoomId': roomId,
      'UserId': userId,
      'isHanded': isHanded,
    };
  }
}

class AddAgentResponse {
  final String roomId;
  final String userId;
  final MessageData? msg;
  final RoomAgentData? roomAgent;

  AddAgentResponse({
    required this.roomId,
    required this.userId,
    this.msg,
    this.roomAgent,
  });

  factory AddAgentResponse.fromJson(Map<String, dynamic> json) {
    return AddAgentResponse(
      roomId: json['RoomId']?.toString() ?? '',
      userId: json['UserId']?.toString() ?? '',
      msg: json['Msg'] != null ? MessageData.fromJson(json['Msg']) : null,
      roomAgent: json['RoomAgent'] != null 
          ? RoomAgentData.fromJson(json['RoomAgent']) 
          : null,
    );
  }
}

class MessageData {
  final int type;
  final String roomId;
  final String msg;

  MessageData({
    required this.type,
    required this.roomId,
    required this.msg,
  });

  factory MessageData.fromJson(Map<String, dynamic> json) {
    return MessageData(
      type: json['Type'] is int ? json['Type'] : int.parse(json['Type']?.toString() ?? '0'),
      roomId: json['RoomId']?.toString() ?? '',
      msg: json['Msg']?.toString() ?? '',
    );
  }
}

class RoomAgentData {
  final String userId;
  final String roomId;
  final String displayName;
  final String handId;
  final String chId;
  final String ctId;

  RoomAgentData({
    required this.userId,
    required this.roomId,
    required this.displayName,
    required this.handId,
    required this.chId,
    required this.ctId,
  });

  factory RoomAgentData.fromJson(Map<String, dynamic> json) {
    return RoomAgentData(
      userId: json['UserId']?.toString() ?? '',
      roomId: json['RoomId']?.toString() ?? '',
      displayName: json['DisplayName']?.toString() ?? '',
      handId: json['HandId']?.toString() ?? '',
      chId: json['ChId']?.toString() ?? '',
      ctId: json['CtId']?.toString() ?? '',
    );
  }
}
