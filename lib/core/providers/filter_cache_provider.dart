// lib/core/providers/filter_cache_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/filter_models.dart';

class FilterCacheState {
  final List<ChannelItem> channels;
  final List<AccountItem> accounts;
  final List<ContactItem> contacts;
  final List<LinkItem> links;
  final List<GroupItem> groups;
  final List<CampaignItem> campaigns;
  final List<FunnelItem> funnels;
  final List<DealItem> deals;
  final List<TagItem> tags;
  final List<HumanAgentItem> humanAgents;
  final bool isLoaded;
  final DateTime? lastUpdated;

  FilterCacheState({
    this.channels = const [],
    this.accounts = const [],
    this.contacts = const [],
    this.links = const [],
    this.groups = const [],
    this.campaigns = const [],
    this.funnels = const [],
    this.deals = const [],
    this.tags = const [],
    this.humanAgents = const [],
    this.isLoaded = false,
    this.lastUpdated,
  });

  FilterCacheState copyWith({
    List<ChannelItem>? channels,
    List<AccountItem>? accounts,
    List<ContactItem>? contacts,
    List<LinkItem>? links,
    List<GroupItem>? groups,
    List<CampaignItem>? campaigns,
    List<FunnelItem>? funnels,
    List<DealItem>? deals,
    List<TagItem>? tags,
    List<HumanAgentItem>? humanAgents,
    bool? isLoaded,
    DateTime? lastUpdated,
  }) {
    return FilterCacheState(
      channels: channels ?? this.channels,
      accounts: accounts ?? this.accounts,
      contacts: contacts ?? this.contacts,
      links: links ?? this.links,
      groups: groups ?? this.groups,
      campaigns: campaigns ?? this.campaigns,
      funnels: funnels ?? this.funnels,
      deals: deals ?? this.deals,
      tags: tags ?? this.tags,
      humanAgents: humanAgents ?? this.humanAgents,
      isLoaded: isLoaded ?? this.isLoaded,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class FilterCacheNotifier extends StateNotifier<FilterCacheState> {
  FilterCacheNotifier() : super(FilterCacheState());

  void setFilterData({
    required List<ChannelItem> channels,
    required List<AccountItem> accounts,
    required List<ContactItem> contacts,
    required List<LinkItem> links,
    required List<GroupItem> groups,
    required List<CampaignItem> campaigns,
    required List<FunnelItem> funnels,
    required List<DealItem> deals,
    required List<TagItem> tags,
    required List<HumanAgentItem> humanAgents,
  }) {
    state = state.copyWith(
      channels: channels,
      accounts: accounts,
      contacts: contacts,
      links: links,
      groups: groups,
      campaigns: campaigns,
      funnels: funnels,
      deals: deals,
      tags: tags,
      humanAgents: humanAgents,
      isLoaded: true,
      lastUpdated: DateTime.now(),
    );
    print('✅ Filter cache updated at ${state.lastUpdated}');
  }

  void clearCache() {
    state = FilterCacheState();
    print('🗑️ Filter cache cleared');
  }

  bool shouldRefresh() {
    if (!state.isLoaded) return true;
    if (state.lastUpdated == null) return true;
    
    // Refresh jika data sudah lebih dari 5 menit
    final difference = DateTime.now().difference(state.lastUpdated!);
    return difference.inMinutes > 5;
  }
}

final filterCacheProvider = StateNotifierProvider<FilterCacheNotifier, FilterCacheState>((ref) {
  return FilterCacheNotifier();
});