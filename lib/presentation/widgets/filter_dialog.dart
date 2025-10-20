import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart'; // TAMBAHKAN IMPORT INI
import '../../core/models/filter_models.dart';
import '../../core/services/filter_api_service.dart';
import '../../core/theme/app_theme.dart';

class FilterDialog extends ConsumerStatefulWidget {
  final FilterOptions initialFilters;
  final Function(FilterOptions) onApply;

  const FilterDialog({
    super.key,
    required this.initialFilters,
    required this.onApply,
  });

  @override
  ConsumerState<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends ConsumerState<FilterDialog> {
  late FilterOptions _filters;
  final FilterApiService _apiService = FilterApiService();

  // API data lists
  List<ChannelItem> _channels = [];
  List<AccountItem> _accounts = [];
  List<ContactItem> _contacts = [];
  List<LinkItem> _links = [];
  List<GroupItem> _groups = [];
  List<CampaignItem> _campaigns = [];
  List<FunnelItem> _funnels = [];
  List<DealItem> _deals = [];
  List<TagItem> _tags = [];
  List<HumanAgentItem> _humanAgents = [];

  bool _isLoadingData = true;
  String? _loadingError;

  @override
  void initState() {
    super.initState();
    _filters = FilterOptions(
      status: widget.initialFilters.status,
      isMuteAiAgent: widget.initialFilters.isMuteAiAgent,
      readStatus: widget.initialFilters.readStatus,
      channelId: widget.initialFilters.channelId,
      chatType: widget.initialFilters.chatType,
      accountId: widget.initialFilters.accountId,
      contactId: widget.initialFilters.contactId,
      linkId: widget.initialFilters.linkId,
      groupId: widget.initialFilters.groupId,
      campaignId: widget.initialFilters.campaignId,
      funnelId: widget.initialFilters.funnelId,
      dealId: widget.initialFilters.dealId,
      tagId: widget.initialFilters.tagId,
      humanAgentId: widget.initialFilters.humanAgentId,
    );
    _loadApiData();
  }

  Future<void> _loadApiData() async {
    setState(() {
      _isLoadingData = true;
      _loadingError = null;
    });

    try {
      _channels = await _apiService.getChannels();
      _accounts = await _apiService.getAccounts();
      _contacts = await _apiService.getContacts();
      _links = await _apiService.getLinks();
      _groups = await _apiService.getGroups();
      _campaigns = await _apiService.getCampaigns();
      _funnels = await _apiService.getFunnels();
      _deals = await _apiService.getDeals();
      _tags = await _apiService.getTags();
      _humanAgents = await _apiService.getHumanAgents();

      setState(() {
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingData = false;
        _loadingError = 'Failed to load filter data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode; // TAMBAHKAN INI
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkBackground : Colors.white, // UPDATE
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Conversation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode 
                      ? AppTheme.darkTextPrimary 
                      : AppTheme.primaryColor, // UPDATE
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close, 
                    color: isDarkMode 
                      ? AppTheme.darkTextPrimary 
                      : AppTheme.primaryColor, // UPDATE
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    print('Applying filters: ${_filters.toMap()}');
                    widget.onApply(_filters);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.filter_alt, size: 16),
                  label: const Text('Apply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _filters.reset();
                    });
                    print('Filters reset');
                  },
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      color: isDarkMode 
                        ? AppTheme.darkTextPrimary 
                        : AppTheme.primaryColor, // UPDATE
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDarkMode 
                        ? AppTheme.darkTextPrimary 
                        : AppTheme.primaryColor, // UPDATE
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),

            const SizedBox(height: 20),

            // Filter options
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Status
                    _buildDropdownField(
                      'Status',
                      _filters.status,
                      ['Assigned', 'Unassigned', 'Resolved'],
                      (value) => setState(() => _filters.status = value),
                      isDarkMode: isDarkMode, // TAMBAHKAN
                    ),

                    // Is Mute AI Agent
                    _buildDropdownField(
                      'Is Mute Ai Agent',
                      _filters.isMuteAiAgent,
                      ['Active', 'Inactive'],
                      (value) => setState(() => _filters.isMuteAiAgent = value),
                      isDarkMode: isDarkMode, // TAMBAHKAN
                    ),

                    // Read Status
                    _buildDropdownField(
                      'Read Status',
                      _filters.readStatus,
                      ['Is Read', 'Unread'],
                      (value) => setState(() => _filters.readStatus = value),
                      isDarkMode: isDarkMode, // TAMBAHKAN
                    ),

                    // Channel
                    _buildApiDropdownField(
                      'Channel',
                      _filters.channelId,
                      _channels,
                      (value) => setState(() => _filters.channelId = value),
                      isDarkMode: isDarkMode, // TAMBAHKAN
                    ),

                    // Chat
                    _buildDropdownField(
                      'Chat',
                      _filters.chatType,
                      ['Private', 'Group'],
                      (value) => setState(() => _filters.chatType = value),
                      isDarkMode: isDarkMode, // TAMBAHKAN
                    ),

                    // Account
                    _buildApiDropdownField(
                      'Account',
                      _filters.accountId,
                      _accounts,
                      (value) => setState(() => _filters.accountId = value),
                      isDarkMode: isDarkMode, // TAMBAHKAN
                    ),

                    // Contact
                    _buildApiDropdownField(
                      'Contact',
                      _filters.contactId,
                      _contacts,
                      (value) => setState(() => _filters.contactId = value),
                      isDarkMode: isDarkMode, // TAMBAHKAN
                    ),

                    // Link
                    _buildApiDropdownField(
                      'Link',
                      _filters.linkId,
                      _links,
                      (value) => setState(() => _filters.linkId = value),
                      isDarkMode: isDarkMode, // TAMBAHKAN
                    ),

                    // Group
                    _buildApiDropdownField(
                      'Group',
                      _filters.groupId,
                      _groups,
                      (value) => setState(() => _filters.groupId = value),
                      isDarkMode: isDarkMode, // TAMBAHKAN
                    ),

                    // Campaign
                    _buildApiDropdownField(
                      'Campaign',
                      _filters.campaignId,
                      _campaigns,
                      (value) => setState(() => _filters.campaignId = value),
                      isDarkMode: isDarkMode, // TAMBAHKAN
                    ),

                    // Funnel
                    _buildApiDropdownField(
                      'Funnel',
                      _filters.funnelId,
                      _funnels,
                      (value) => setState(() => _filters.funnelId = value),
                      isDarkMode: isDarkMode, // TAMBAHKAN
                    ),

                    // Deal
                    _buildApiDropdownField(
                      'Deal',
                      _filters.dealId,
                      _deals,
                      (value) => setState(() => _filters.dealId = value),
                      isDarkMode: isDarkMode, // TAMBAHKAN
                    ),

                    // Tags
                    _buildApiDropdownField(
                      'Tags',
                      _filters.tagId,
                      _tags,
                      (value) => setState(() => _filters.tagId = value),
                      isDarkMode: isDarkMode, // TAMBAHKAN
                    ),

                    // Human Agents
                    _buildApiDropdownField(
                      'Human Agents',
                      _filters.humanAgentId,
                      _humanAgents,
                      (value) => setState(() => _filters.humanAgentId = value),
                      isDarkMode: isDarkMode, // TAMBAHKAN
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> options,
    Function(String?) onChanged, {
    required bool isDarkMode, // TAMBAHKAN
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black, // UPDATE
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkSurface : Colors.white, // UPDATE
                border: Border.all(
                  color: isDarkMode 
                    ? Colors.grey.shade700 
                    : Colors.grey.shade300, // UPDATE
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: value,
                hint: Text(
                  '--select--',
                  style: TextStyle(
                    color: isDarkMode 
                      ? AppTheme.darkTextSecondary 
                      : Colors.grey, // UPDATE
                  ),
                ),
                isExpanded: true,
                underline: const SizedBox(),
                iconEnabledColor: isDarkMode 
                  ? AppTheme.darkTextPrimary 
                  : Colors.black, // UPDATE
                style: TextStyle(
                  color: isDarkMode 
                    ? AppTheme.darkTextPrimary 
                    : Colors.black, // UPDATE
                  fontSize: 14,
                ),
                dropdownColor: isDarkMode 
                  ? AppTheme.darkSurface 
                  : Colors.white, // TAMBAHKAN
                items: options.map((String option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      option,
                      style: TextStyle(
                        color: isDarkMode 
                          ? AppTheme.darkTextPrimary 
                          : Colors.black, // UPDATE
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiDropdownField(
    String label,
    String? value,
    List<FilterDataItem> options,
    Function(String?) onChanged, {
    required bool isDarkMode, // TAMBAHKAN
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black, // UPDATE
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkSurface : Colors.white, // UPDATE
                border: Border.all(
                  color: isDarkMode 
                    ? Colors.grey.shade700 
                    : Colors.grey.shade300, // UPDATE
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isLoadingData
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDarkMode 
                                ? AppTheme.darkTextPrimary 
                                : AppTheme.primaryColor, // UPDATE
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Loading...', 
                            style: TextStyle(
                              color: isDarkMode 
                                ? AppTheme.darkTextSecondary 
                                : Colors.grey, // UPDATE
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : DropdownButton<String>(
                      value: value,
                      hint: Text(
                        '--select--',
                        style: TextStyle(
                          color: isDarkMode 
                            ? AppTheme.darkTextSecondary 
                            : Colors.grey, // UPDATE
                          fontSize: 14,
                        ),
                      ),
                      isExpanded: true,
                      underline: const SizedBox(),
                      iconEnabledColor: isDarkMode 
                        ? AppTheme.darkTextPrimary 
                        : Colors.black, // UPDATE
                      style: TextStyle(
                        color: isDarkMode 
                          ? AppTheme.darkTextPrimary 
                          : Colors.black, // UPDATE
                        fontSize: 14,
                      ),
                      dropdownColor: isDarkMode 
                        ? AppTheme.darkSurface 
                        : Colors.white, // TAMBAHKAN
                      items: options.map((FilterDataItem item) {
                        return DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(
                            item.name.isNotEmpty ? item.name : 'ID: ${item.id}',
                            style: TextStyle(
                              color: isDarkMode 
                                ? AppTheme.darkTextPrimary 
                                : Colors.black, // UPDATE
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: onChanged,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}