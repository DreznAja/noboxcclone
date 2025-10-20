import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart';
import '../../core/theme/app_theme.dart';

class AddFunnelDialog extends ConsumerStatefulWidget { // ← UBAH INI
  final Function(String) onSave;

  const AddFunnelDialog({
    super.key,
    required this.onSave,
  });

  @override
  ConsumerState<AddFunnelDialog> createState() => _AddFunnelDialogState(); // ← UBAH INI
}

class _AddFunnelDialogState extends ConsumerState<AddFunnelDialog> { // ← UBAH INI
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      widget.onSave(name);
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Funnel',
                  style: TextStyle(
                    fontSize: 18,
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

            const SizedBox(height: 20),

            // Name input
Container(
  decoration: BoxDecoration(
    color: isDarkMode ? AppTheme.darkBackground : const Color(0xFFF1F5F9), // ← UBAH INI
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade300 // ← UBAH INI
    ),
  ),
  child: TextField(
  controller: _nameController,
  focusNode: _focusNode,
  maxLines: 1,
  style: TextStyle(
    fontSize: 16,
    color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
  ),
  decoration: InputDecoration(
    hintText: 'Enter funnel name...',
    hintStyle: TextStyle(
      color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
      fontSize: 16,
    ),
    filled: true,
    fillColor: isDarkMode ? AppTheme.darkBackground : const Color(0xFFF1F5F9),
    contentPadding: const EdgeInsets.all(16),
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
  textInputAction: TextInputAction.done,
  onSubmitted: (_) => _save(),
),
),

            const SizedBox(height: 20),

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
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Add'),
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
