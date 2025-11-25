// lib/core/providers/new_conversation_cache_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/new_conversation_models.dart';

class NewConversationCacheState {
  final List<ChannelOption> channels;
  final Map<String, List<AccountOption>> accountsByChannel; // Cache per channel
  final List<ContactOption> contacts;
  final List<LinkOption> links;
  final List<GroupOption> groups;
  final bool isLoaded;
  final DateTime? lastUpdated;

  NewConversationCacheState({
    this.channels = const [],
    this.accountsByChannel = const {},
    this.contacts = const [],
    this.links = const [],
    this.groups = const [],
    this.isLoaded = false,
    this.lastUpdated,
  });

  NewConversationCacheState copyWith({
    List<ChannelOption>? channels,
    Map<String, List<AccountOption>>? accountsByChannel,
    List<ContactOption>? contacts,
    List<LinkOption>? links,
    List<GroupOption>? groups,
    bool? isLoaded,
    DateTime? lastUpdated,
  }) {
    return NewConversationCacheState(
      channels: channels ?? this.channels,
      accountsByChannel: accountsByChannel ?? this.accountsByChannel,
      contacts: contacts ?? this.contacts,
      links: links ?? this.links,
      groups: groups ?? this.groups,
      isLoaded: isLoaded ?? this.isLoaded,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class NewConversationCacheNotifier extends StateNotifier<NewConversationCacheState> {
  NewConversationCacheNotifier() : super(NewConversationCacheState());

  void setChannels(List<ChannelOption> channels) {
    state = state.copyWith(
      channels: channels,
      lastUpdated: DateTime.now(),
    );
    print('✅ Channels cached: ${channels.length} items');
  }

  void setAccountsForChannel(String channelId, List<AccountOption> accounts) {
    final updatedAccountsMap = Map<String, List<AccountOption>>.from(state.accountsByChannel);
    updatedAccountsMap[channelId] = accounts;
    
    state = state.copyWith(
      accountsByChannel: updatedAccountsMap,
      lastUpdated: DateTime.now(),
    );
    print('✅ Accounts cached for channel $channelId: ${accounts.length} items');
  }

  void setContacts(List<ContactOption> contacts) {
    state = state.copyWith(
      contacts: contacts,
      isLoaded: true,
      lastUpdated: DateTime.now(),
    );
    print('✅ Contacts cached: ${contacts.length} items');
  }

  void setLinks(List<LinkOption> links) {
    state = state.copyWith(
      links: links,
      lastUpdated: DateTime.now(),
    );
    print('✅ Links cached: ${links.length} items');
  }

  void setGroups(List<GroupOption> groups) {
    state = state.copyWith(
      groups: groups,
      lastUpdated: DateTime.now(),
    );
    print('✅ Groups cached: ${groups.length} items');
  }

  void clearCache() {
    state = NewConversationCacheState();
    print('🗑️ New conversation cache cleared');
  }

  bool shouldRefresh() {
    if (!state.isLoaded) return true;
    if (state.lastUpdated == null) return true;
    
    // Refresh jika data sudah lebih dari 5 menit
    final difference = DateTime.now().difference(state.lastUpdated!);
    return difference.inMinutes > 5;
  }

  List<AccountOption>? getAccountsForChannel(String channelId) {
    return state.accountsByChannel[channelId];
  }
}

final newConversationCacheProvider = 
    StateNotifierProvider<NewConversationCacheNotifier, NewConversationCacheState>((ref) {
  return NewConversationCacheNotifier();
});