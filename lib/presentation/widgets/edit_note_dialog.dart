import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart';
import '../../core/theme/app_theme.dart';

class EditNoteDialog extends ConsumerStatefulWidget {
  final String initialContent;
  final Function(String) onSave;

  const EditNoteDialog({
    super.key,
    required this.initialContent,
    required this.onSave,
  });

  @override
  ConsumerState<EditNoteDialog> createState() => _EditNoteDialogState();
}

class _EditNoteDialogState extends ConsumerState<EditNoteDialog> {
  late TextEditingController _contentController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      // Select all text for easy editing
      _contentController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _contentController.text.length,
      );
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    final content = _contentController.text.trim();
    if (content.isNotEmpty) {
      widget.onSave(content);
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
                  'Edit Note',
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

            // Content input
            Container(
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkBackground : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade300
                ),
              ),
              child: TextField(
  controller: _contentController,
  focusNode: _focusNode,
  maxLines: 5,
  minLines: 3,
  style: TextStyle(
    fontSize: 16,
    color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
  ),
  decoration: InputDecoration(
    hintText: 'Enter your note...',
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
  textInputAction: TextInputAction.newline,
),
            ),

            const SizedBox(height: 20),

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
                    onPressed: _save,
                    child: const Text('Save'),
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