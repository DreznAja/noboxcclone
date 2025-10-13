import 'package:flutter/material.dart';
import '../../core/models/contact_detail_models.dart';
import '../../core/theme/app_theme.dart';

class FunnelSelectionDialog extends StatefulWidget {
  final List<ContactFunnel> availableFunnels;
  final ContactFunnel? currentFunnel;
  final Function(String funnelId) onFunnelSelected;

  const FunnelSelectionDialog({
    super.key,
    required this.availableFunnels,
    this.currentFunnel,
    required this.onFunnelSelected,
  });

  @override
  State<FunnelSelectionDialog> createState() => _FunnelSelectionDialogState();
}

class _FunnelSelectionDialogState extends State<FunnelSelectionDialog> {
  String? _selectedFunnelId;
  final TextEditingController _searchController = TextEditingController();
  List<ContactFunnel> _filteredFunnels = [];

  @override
  void initState() {
    super.initState();
    _selectedFunnelId = widget.currentFunnel?.id;
    _filteredFunnels = widget.availableFunnels;
    _searchController.addListener(_filterFunnels);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFunnels() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFunnels = widget.availableFunnels;
      } else {
        _filteredFunnels = widget.availableFunnels.where((funnel) {
          return funnel.name.toLowerCase().contains(query) ||
                 (funnel.description?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  void _selectFunnel() {
    if (_selectedFunnelId != null) {
      widget.onFunnelSelected(_selectedFunnelId!);
      Navigator.of(context).pop();
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
        height: MediaQuery.of(context).size.height * 0.7,
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
                  'Select Funnel',
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

            const SizedBox(height: 16),

            // Search bar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search funnels...',
                  hintStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Funnel list
            Expanded(
              child: _filteredFunnels.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.filter_alt_off,
                            size: 48,
                            color: AppTheme.textSecondary,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No funnels found',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredFunnels.length,
                      itemBuilder: (context, index) {
                        final funnel = _filteredFunnels[index];
                        final isSelected = _selectedFunnelId == funnel.id;
                        
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedFunnelId = funnel.id;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                // Selection indicator
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                
                                const SizedBox(width: 12),
                                
                                // Funnel info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        funnel.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                      ),
                                      if (funnel.description != null && funnel.description!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          funnel.description!,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.textSecondary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedFunnelId != null ? _selectFunnel : null,
                    child: const Text('Select'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}