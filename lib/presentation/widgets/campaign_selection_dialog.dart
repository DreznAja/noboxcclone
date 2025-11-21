import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/theme_provider.dart';

class CampaignSelectionDialog extends ConsumerStatefulWidget {
  final String contactId;
  final Function(String campaignId, String campaignName) onCampaignSelected;

  const CampaignSelectionDialog({
    super.key,
    required this.contactId,
    required this.onCampaignSelected,
  });

  @override
  ConsumerState<CampaignSelectionDialog> createState() => _CampaignSelectionDialogState();
}

class _CampaignSelectionDialogState extends ConsumerState<CampaignSelectionDialog> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _campaigns = [];
  String? _selectedCampaignId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final campaigns = await _apiService.getCampaignsListActive();
      
      setState(() {
        _campaigns = campaigns;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading campaigns: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    return Dialog(
      backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode 
                      ? const Color(0xFF1976D2).withOpacity(0.2)
                      : const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.campaign,
                    color: Color(0xFF1976D2),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Select Campaign',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDarkMode ? AppTheme.darkTextSecondary : Colors.black,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Campaign Dropdown
                    Text(
                      'Campaign',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDarkMode ? AppTheme.darkBackground : Colors.white,
                        border: Border.all(
                          color: isDarkMode 
                            ? Colors.white.withOpacity(0.2)
                            : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            )
                          : _error != null
                              ? Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: isDarkMode ? Colors.red.shade300 : Colors.red,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Failed to load',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDarkMode ? Colors.red.shade300 : Colors.red,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: _loadCampaigns,
                                        icon: const Icon(Icons.refresh, size: 16),
                                        label: const Text('Retry'),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          foregroundColor: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _campaigns.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Center(
                                        child: Text(
                                          'No campaigns available',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    )
                                  : DropdownButton<String>(
                                      value: _selectedCampaignId,
                                      hint: Text(
                                        '--select--',
                                        style: TextStyle(
                                          color: isDarkMode 
                                            ? AppTheme.darkTextSecondary 
                                            : Colors.grey,
                                        ),
                                      ),
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      dropdownColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
                                      style: TextStyle(
                                        color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                                      ),
                                      items: _campaigns.map((campaign) {
                                        return DropdownMenuItem<String>(
                                          value: campaign['Id']?.toString(),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                campaign['Name']?.toString() ?? 'Unnamed Campaign',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (campaign['Description'] != null &&
                                                  campaign['Description'].toString().isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  campaign['Description'].toString(),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDarkMode 
                                                      ? AppTheme.darkTextSecondary 
                                                      : Colors.grey,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedCampaignId = value;
                                        });
                                      },
                                    ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: isDarkMode 
                      ? AppTheme.darkTextSecondary 
                      : Colors.grey.shade700,
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selectedCampaignId == null
                      ? null
                      : () {
                          final selectedCampaign = _campaigns.firstWhere(
                            (c) => c['Id']?.toString() == _selectedCampaignId,
                          );
                          
                          widget.onCampaignSelected(
                            _selectedCampaignId!,
                            selectedCampaign['Name']?.toString() ?? '',
                          );
                          Navigator.of(context).pop();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}