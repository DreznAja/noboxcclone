import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart';
import '../../core/models/contact_detail_models.dart';
import '../../core/theme/app_theme.dart';

class FunnelSelectionDialog extends ConsumerStatefulWidget {
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
  ConsumerState<FunnelSelectionDialog> createState() => _FunnelSelectionDialogState();
}

class _FunnelSelectionDialogState extends ConsumerState<FunnelSelectionDialog> {
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
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkSurface : Colors.white,
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
                    color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.primaryColor,
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
    color: isDarkMode ? AppTheme.darkBackground : const Color(0xFFF1F5F9), // ← UBAH INI
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade300 // ← UBAH INI
    ),
  ),
  child: TextField(
    controller: _searchController,
    style: TextStyle(color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black), // ← TAMBAHKAN INI
    decoration: InputDecoration(
      hintText: 'Search funnels...',
      hintStyle: TextStyle(
        color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey // ← UBAH INI
      ),
      prefixIcon: Icon(
        Icons.search, 
        color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey // ← UBAH INI
      ),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),
),

            const SizedBox(height: 16),

            // Funnel list
            Expanded(
              child: _filteredFunnels.isEmpty
                  ? Center(
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
                              color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
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
  style: OutlinedButton.styleFrom(
    foregroundColor: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.primaryColor, // ← UBAH INI
    side: BorderSide(
      color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.primaryColor // ← UBAH INI
    ),
    padding: const EdgeInsets.symmetric(vertical: 12),
  ),
  child: const Text('Cancel'),
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