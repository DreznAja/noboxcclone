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

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Nm': name,
    };
  }
}

class TagState {
  final List<MessageTag> availableTags;
  final List<MessageTag> roomTags;
  final bool isLoadingAvailable;
  final bool isLoadingRoomTags;
  final String? error;

  TagState({
    this.availableTags = const [],
    this.roomTags = const [],
    this.isLoadingAvailable = false,
    this.isLoadingRoomTags = false,
    this.error,
  });

  TagState copyWith({
    List<MessageTag>? availableTags,
    List<MessageTag>? roomTags,
    bool? isLoadingAvailable,
    bool? isLoadingRoomTags,
    String? error,
  }) {
    return TagState(
      availableTags: availableTags ?? this.availableTags,
      roomTags: roomTags ?? this.roomTags,
      isLoadingAvailable: isLoadingAvailable ?? this.isLoadingAvailable,
      isLoadingRoomTags: isLoadingRoomTags ?? this.isLoadingRoomTags,
      error: error,
    );
  }
}