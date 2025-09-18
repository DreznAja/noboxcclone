import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      print('Starting to load filter data from APIs...');
      
      // Load data sequentially to avoid overwhelming the API
      _channels = await _apiService.getChannels();
      print('Loaded ${_channels.length} channels');
      
      _accounts = await _apiService.getAccounts();
      print('Loaded ${_accounts.length} accounts');
      
      _contacts = await _apiService.getContacts();
      print('Loaded ${_contacts.length} contacts');
      
      _links = await _apiService.getLinks();
      print('Loaded ${_links.length} links');
      
      _groups = await _apiService.getGroups();
      print('Loaded ${_groups.length} groups');
      
      _campaigns = await _apiService.getCampaigns();
      print('Loaded ${_campaigns.length} campaigns');
      
      _funnels = await _apiService.getFunnels();
      print('Loaded ${_funnels.length} funnels');
      
      _deals = await _apiService.getDeals();
      print('Loaded ${_deals.length} deals');
      
      _tags = await _apiService.getTags();
      print('Loaded ${_tags.length} tags');
      
      _humanAgents = await _apiService.getHumanAgents();
      print('Loaded ${_humanAgents.length} human agents');

      setState(() {
        _isLoadingData = false;
      });
      
      print('All filter data loaded successfully');
    } catch (e) {
      setState(() {
        _isLoadingData = false;
        _loadingError = 'Failed to load filter data: $e';
      });
      print('Error loading filter data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
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
                    color: AppTheme.primaryColor,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: AppTheme.primaryColor),
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
                  child: const Text('Reset'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),

            const SizedBox(height: 20),

            // Filter options
            Expanded(
              child: _isLoadingData
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading filter options...',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _loadingError != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                _loadingError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadApiData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              // Status
                              _buildDropdownField(
                                'Status',
                                _filters.status,
                                ['Assigned', 'Unassigned', 'Resolved'],
                                (value) => setState(() => _filters.status = value),
                              ),

                              // Is Mute AI Agent
                              _buildDropdownField(
                                'Is Mute Ai Agent',
                                _filters.isMuteAiAgent,
                                ['Active', 'Inactive'],
                                (value) => setState(() => _filters.isMuteAiAgent = value),
                              ),

                              // Read Status
                              _buildDropdownField(
                                'Read Status',
                                _filters.readStatus,
                                ['Is Read', 'Unread'],
                                (value) => setState(() => _filters.readStatus = value),
                              ),

                              // Channel
                              _buildApiDropdownField(
                                'Channel',
                                _filters.channelId,
                                _channels,
                                (value) => setState(() => _filters.channelId = value),
                              ),

                              // Chat
                              _buildDropdownField(
                                'Chat',
                                _filters.chatType,
                                ['Private', 'Group'],
                                (value) => setState(() => _filters.chatType = value),
                              ),

                              // Account
                              _buildApiDropdownField(
                                'Account',
                                _filters.accountId,
                                _accounts,
                                (value) => setState(() => _filters.accountId = value),
                              ),

                              // Contact
                              _buildApiDropdownField(
                                'Contact',
                                _filters.contactId,
                                _contacts,
                                (value) => setState(() => _filters.contactId = value),
                              ),

                              // Link
                              _buildApiDropdownField(
                                'Link',
                                _filters.linkId,
                                _links,
                                (value) => setState(() => _filters.linkId = value),
                              ),

                              // Group
                              _buildApiDropdownField(
                                'Group',
                                _filters.groupId,
                                _groups,
                                (value) => setState(() => _filters.groupId = value),
                              ),

                              // Campaign
                              _buildApiDropdownField(
                                'Campaign',
                                _filters.campaignId,
                                _campaigns,
                                (value) => setState(() => _filters.campaignId = value),
                              ),

                              // Funnel
                              _buildApiDropdownField(
                                'Funnel',
                                _filters.funnelId,
                                _funnels,
                                (value) => setState(() => _filters.funnelId = value),
                              ),

                              // Deal
                              _buildApiDropdownField(
                                'Deal',
                                _filters.dealId,
                                _deals,
                                (value) => setState(() => _filters.dealId = value),
                              ),

                              // Tags
                              _buildApiDropdownField(
                                'Tags',
                                _filters.tagId,
                                _tags,
                                (value) => setState(() => _filters.tagId = value),
                              ),

                              // Human Agents
                              _buildApiDropdownField(
                                'Human Agents',
                                _filters.humanAgentId,
                                _humanAgents,
                                (value) => setState(() => _filters.humanAgentId = value),
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
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: Colors.white, // Background dropdown menu
                ),
                child: DropdownButton<String>(
                  value: value,
                  hint: const Text(
                    '--select--',
                    style: TextStyle(color: Colors.grey),
                  ),
                  isExpanded: true,
                  underline: const SizedBox(),
                  iconEnabledColor: Colors.black,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                  ),
                  items: options.map((String option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(
                        option,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: onChanged,
                ),
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
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: Colors.white, // Background dropdown menu
                ),
                child: DropdownButton<String>(
                  value: value,
                  hint: Text(
                    options.isEmpty ? 'No data' : '--select--',
                    style: TextStyle(
                      color: options.isEmpty ? Colors.red : Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  isExpanded: true,
                  underline: const SizedBox(),
                  iconEnabledColor: Colors.black,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                  ),
                  items: options.map((FilterDataItem item) {
                    return DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(
                        item.name.isNotEmpty ? item.name : 'ID: ${item.id}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: options.isEmpty ? null : onChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}