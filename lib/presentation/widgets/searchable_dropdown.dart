import 'package:flutter/material.dart';
import 'package:nobox_chat/core/theme/app_theme.dart';

class SearchableDropdown<T> extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isDarkMode;
  final String? value;
  final List<T> items;
  final String Function(T) itemLabelBuilder;
  final String Function(T) itemValueBuilder;
  final void Function(String?)? onChanged;
  final bool isLoading;
  final String hint;
  final int itemCount;
  final bool enabled;

  const SearchableDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.isDarkMode,
    required this.value,
    required this.items,
    required this.itemLabelBuilder,
    required this.itemValueBuilder,
    required this.onChanged,
    required this.isLoading,
    required this.hint,
    required this.itemCount,
    this.enabled = true,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showDropdown() {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _removeOverlay,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 4),
              child: GestureDetector(
                onTap: () {}, // Prevent tap from propagating to parent
                child: Container(
                  width: size.width,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    color: widget.isDarkMode ? AppTheme.darkSurface : Colors.white,
                    child: _SearchableMenu<T>(
                      items: widget.items,
                      itemLabelBuilder: widget.itemLabelBuilder,
                      itemValueBuilder: widget.itemValueBuilder,
                      isDarkMode: widget.isDarkMode,
                      currentValue: widget.value,
                      onSelected: (value) {
                        _removeOverlay();
                        if (widget.onChanged != null) {
                          widget.onChanged!(value);
                        }
                      },
                      onClose: _removeOverlay,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  String? _getDisplayText() {
    if (widget.value == null) return null;
    
    try {
      final item = widget.items.firstWhere(
        (item) => widget.itemValueBuilder(item) == widget.value,
      );
      return widget.itemLabelBuilder(item);
    } catch (e) {
      return widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
            if (widget.itemCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.itemCount}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        CompositedTransformTarget(
          link: _layerLink,
          child: InkWell(
            onTap: widget.enabled && !widget.isLoading && widget.items.isNotEmpty
                ? () {
                    if (_overlayEntry == null) {
                      _showDropdown();
                    } else {
                      _removeOverlay();
                    }
                  }
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: widget.isDarkMode 
                  ? AppTheme.darkBackground.withOpacity(0.5)
                  : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isDarkMode 
                    ? Colors.white.withOpacity(0.1) 
                    : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  widget.isLoading 
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor,
                          ),
                        ),
                      )
                    : Icon(
                        widget.icon,
                        color: widget.isDarkMode 
                          ? AppTheme.darkTextSecondary.withOpacity(0.7)
                          : Colors.grey.shade500,
                        size: 20,
                      ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getDisplayText() ?? widget.hint,
                      style: TextStyle(
                        fontSize: 15,
                        color: _getDisplayText() != null
                          ? (widget.isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary)
                          : (widget.isDarkMode 
                              ? AppTheme.darkTextSecondary.withOpacity(0.5)
                              : Colors.grey.shade400),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: widget.isDarkMode ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchableMenu<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) itemLabelBuilder;
  final String Function(T) itemValueBuilder;
  final bool isDarkMode;
  final String? currentValue;
  final void Function(String) onSelected;
  final VoidCallback onClose;

  const _SearchableMenu({
    required this.items,
    required this.itemLabelBuilder,
    required this.itemValueBuilder,
    required this.isDarkMode,
    required this.currentValue,
    required this.onSelected,
    required this.onClose,
  });

  @override
  State<_SearchableMenu<T>> createState() => _SearchableMenuState<T>();
}

class _SearchableMenuState<T> extends State<_SearchableMenu<T>> {
  final TextEditingController _searchController = TextEditingController();
  List<T> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          final label = widget.itemLabelBuilder(item).toLowerCase();
          return label.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(
                fontSize: 15,
                color: widget.isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(
                  color: widget.isDarkMode 
                    ? AppTheme.darkTextSecondary.withOpacity(0.5)
                    : Colors.grey.shade400,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: widget.isDarkMode ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: widget.isDarkMode ? AppTheme.darkTextSecondary : Colors.grey,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _filterItems('');
                      },
                    )
                  : null,
                filled: true,
                fillColor: widget.isDarkMode 
                  ? AppTheme.darkBackground.withOpacity(0.5)
                  : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _filterItems,
            ),
          ),
          
          Divider(
            height: 1,
            color: widget.isDarkMode 
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.shade200,
          ),
          
          // Items List
          Flexible(
            child: _filteredItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: widget.isDarkMode 
                            ? AppTheme.darkTextSecondary.withOpacity(0.5)
                            : Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No results found',
                          style: TextStyle(
                            fontSize: 14,
                            color: widget.isDarkMode 
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    final value = widget.itemValueBuilder(item);
                    final label = widget.itemLabelBuilder(item);
                    final isSelected = value == widget.currentValue;

                    return ListTile(
                      title: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          color: widget.isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: AppTheme.primaryColor,
                            size: 22,
                          )
                        : null,
                      selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
                      selected: isSelected,
                      onTap: () {
                        widget.onSelected(value);
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}