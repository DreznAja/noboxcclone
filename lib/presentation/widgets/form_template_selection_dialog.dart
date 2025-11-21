import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/theme_provider.dart';

class FormTemplateSelectionDialog extends ConsumerStatefulWidget {
  final String contactId;
  final Function(String formTemplateId, String formTemplateName, String? formResultId) onFormSelected;

  const FormTemplateSelectionDialog({
    super.key,
    required this.contactId,
    required this.onFormSelected,
  });

  @override
  ConsumerState<FormTemplateSelectionDialog> createState() => _FormTemplateSelectionDialogState();
}

class _FormTemplateSelectionDialogState extends ConsumerState<FormTemplateSelectionDialog> {
  final ApiService _apiService = ApiService();
  
  List<Map<String, dynamic>> _formTemplates = [];
  List<Map<String, dynamic>> _formResults = [];
  
  String? _selectedFormTemplateId;
  String? _selectedFormResultId;
  
  bool _isLoadingTemplates = true;
  bool _isLoadingResults = false;
  
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFormTemplates();
  }

  Future<void> _loadFormTemplates() async {
    try {
      setState(() {
        _isLoadingTemplates = true;
        _error = null;
      });

      final templates = await _apiService.getFormTemplates();
      
      setState(() {
        _formTemplates = templates;
        _isLoadingTemplates = false;
      });
    } catch (e) {
      print('❌ Error loading form templates: $e');
      setState(() {
        _error = e.toString();
        _isLoadingTemplates = false;
      });
    }
  }

  Future<void> _loadFormResults() async {
    try {
      setState(() {
        _isLoadingResults = true;
        _error = null;
      });

      final results = await _apiService.getFormResults();
      
      setState(() {
        _formResults = results;
        _isLoadingResults = false;
      });
    } catch (e) {
      print('❌ Error loading form results: $e');
      setState(() {
        _error = e.toString();
        _isLoadingResults = false;
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
                    Icons.description,
                    color: Color(0xFF1976D2),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Form Template',
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
                    // Form Template Dropdown
                    Text(
                      'Form Template',
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
                      child: _isLoadingTemplates
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            )
                          : DropdownButton<String>(
                              value: _selectedFormTemplateId,
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
                              items: _formTemplates.map((template) {
                                return DropdownMenuItem<String>(
                                  value: template['Id']?.toString(),
                                  child: Text(template['Name']?.toString() ?? 'Unnamed'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedFormTemplateId = value;
                                });
                              },
                            ),
                    ),

                    const SizedBox(height: 16),

                    // Form Result Dropdown
                    Text(
                      'Form Result',
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
                      child: Row(
                        children: [
                          Expanded(
                            child: _isLoadingResults
                                ? const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  )
                                : DropdownButton<String>(
                                    value: _selectedFormResultId,
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
                                    items: _formResults.map((result) {
                                      return DropdownMenuItem<String>(
                                        value: result['Id']?.toString(),
                                        child: Text(result['SenderNm']?.toString() ?? 
                                                   result['SenderName']?.toString() ?? 
                                                   'Unnamed'),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedFormResultId = value;
                                      });
                                    },
                                  ),
                          ),
                          if (!_isLoadingResults && _formResults.isEmpty)
                            TextButton.icon(
                              onPressed: _loadFormResults,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Load'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                foregroundColor: AppTheme.primaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDarkMode 
                            ? Colors.red.shade900.withOpacity(0.3)
                            : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDarkMode 
                              ? Colors.red.shade700
                              : Colors.red.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: isDarkMode ? Colors.red.shade300 : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: isDarkMode ? Colors.red.shade300 : Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                  onPressed: _selectedFormTemplateId == null
                      ? null
                      : () {
                          final selectedTemplate = _formTemplates.firstWhere(
                            (t) => t['Id']?.toString() == _selectedFormTemplateId,
                          );
                          
                          widget.onFormSelected(
                            _selectedFormTemplateId!,
                            selectedTemplate['Name']?.toString() ?? '',
                            _selectedFormResultId,
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