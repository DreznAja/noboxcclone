import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart';
import '../../core/models/tag_models.dart';
import '../../core/providers/tag_provider.dart';
import '../../core/theme/app_theme.dart';

class TagSelectionDialog extends ConsumerStatefulWidget {
  final String roomId;
  final List<MessageTag> currentTags;
  final Function(List<String>) onTagsSelected;

  const TagSelectionDialog({
    super.key,
    required this.roomId,
    required this.currentTags,
    required this.onTagsSelected,
  });

  @override
  ConsumerState<TagSelectionDialog> createState() => _TagSelectionDialogState();
}

class _TagSelectionDialogState extends ConsumerState<TagSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  Set<String> _selectedTagIds = {};
  List<MessageTag> _filteredTags = [];

  @override
  void initState() {
    super.initState();
    
    // Initialize selected tags with current tags
    _selectedTagIds = widget.currentTags.map((tag) => tag.id).toSet();
    
    _searchController.addListener(_filterTags);
    
    // Load available tags if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tagState = ref.read(tagProvider);
      if (tagState.availableTags.isEmpty) {
        ref.read(tagProvider.notifier).loadAvailableTags();
      }
      _filterTags();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterTags() {
    final tagState = ref.read(tagProvider);
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _filteredTags = tagState.availableTags;
      } else {
        _filteredTags = tagState.availableTags.where((tag) {
          return tag.name.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _toggleTagSelection(String tagId) {
    setState(() {
      if (_selectedTagIds.contains(tagId)) {
        _selectedTagIds.remove(tagId);
      } else {
        _selectedTagIds.add(tagId);
      }
    });
  }

  void _saveSelection() {
    widget.onTagsSelected(_selectedTagIds.toList());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tagState = ref.watch(tagProvider);
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
                  'Message Tags',
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
                color: isDarkMode ? AppTheme.darkBackground : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade300
                ),
              ),
              child: TextField(
  controller: _searchController,
  style: TextStyle(
    color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
  ),
  decoration: InputDecoration(
    hintText: 'Search or create new tag...',
    hintStyle: TextStyle(
      color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
    ),
    prefixIcon: Icon(
      Icons.search, 
      color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
    ),
    filled: true,
    fillColor: isDarkMode ? AppTheme.darkBackground : const Color(0xFFF1F5F9),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: AppTheme.primaryColor,
        width: 2,
      ),
    ),
  ),
),
            ),

            const SizedBox(height: 16),

            // Selected count
            if (_selectedTagIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_selectedTagIds.length} tag${_selectedTagIds.length > 1 ? 's' : ''} selected',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Tag list
            Expanded(
              child: tagState.isLoadingAvailable
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredTags.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_offer_outlined,
                                size: 48,
                                color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No tags found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredTags.length,
                          itemBuilder: (context, index) {
                            final tag = _filteredTags[index];
                            final isSelected = _selectedTagIds.contains(tag.id);
                            
                            return _TagSelectionItem(
                              tag: tag,
                              isSelected: isSelected,
                              onTap: () => _toggleTagSelection(tag.id),
                              isDarkMode: isDarkMode,
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
                      foregroundColor: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.primaryColor,
                      side: BorderSide(
                        color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.primaryColor
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveSelection,
                    child: Text('Save (${_selectedTagIds.length})'),
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

class _TagSelectionItem extends StatelessWidget {
  final MessageTag tag;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _TagSelectionItem({
    required this.tag,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Selection checkbox
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected 
                    ? AppTheme.primaryColor 
                    : (isDarkMode ? Colors.white.withOpacity(0.3) : Colors.grey.shade400),
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
            
            // Tag info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tag.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: ${tag.id}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}