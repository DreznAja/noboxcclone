import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/theme_provider.dart';

class DealSelectionDialog extends ConsumerStatefulWidget {
  final String contactId;
  final Function(String dealId, String dealName, String? pipeline, String? stage) onDealSelected;

  const DealSelectionDialog({
    super.key,
    required this.contactId,
    required this.onDealSelected,
  });

  @override
  ConsumerState<DealSelectionDialog> createState() => _DealSelectionDialogState();
}

class _DealSelectionDialogState extends ConsumerState<DealSelectionDialog> {
  final ApiService _apiService = ApiService();
  
  List<Map<String, dynamic>> _pipelines = [];
  List<Map<String, dynamic>> _stages = [];
  List<Map<String, dynamic>> _deals = [];
  
  String? _selectedPipelineId;
  String? _selectedStageId;
  String? _selectedDealId;
  
  bool _isLoadingPipelines = true;
  bool _isLoadingStages = false;
  bool _isLoadingDeals = false;
  
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPipelines();
  }

  Future<void> _loadPipelines() async {
    try {
      setState(() {
        _isLoadingPipelines = true;
        _error = null;
      });

      final pipelines = await _apiService.getDealPipelines();
      
      setState(() {
        _pipelines = pipelines;
        _isLoadingPipelines = false;
      });
    } catch (e) {
      print('❌ Error loading pipelines: $e');
      setState(() {
        _error = e.toString();
        _isLoadingPipelines = false;
      });
    }
  }

Future<void> _loadStages() async {
  if (_selectedPipelineId == null) return;
  
  try {
    setState(() {
      _isLoadingStages = true;
      _error = null;
      _stages = [];
      _deals = [];
      _selectedStageId = null;
      _selectedDealId = null;
    });

    final allStages = await _apiService.getDealPipelineTypes();
    
    print('🔍 [Filter Stages] Selected Pipeline ID: $_selectedPipelineId');
    print('🔍 [Filter Stages] Total stages received: ${allStages.length}');
    
    // ✅ FILTER berdasarkan project_id (ini yang benar!)
    final filteredStages = allStages.where((stage) {
      final projectId = stage['project_id']?.toString();
      
      print('   Stage ${stage['Name']}: project_id=$projectId');
      
      return projectId == _selectedPipelineId;
    }).toList();
    
    setState(() {
      _stages = filteredStages;
      _isLoadingStages = false;
    });
    
    print('✅ Loaded ${filteredStages.length} stages for pipeline $_selectedPipelineId');
  } catch (e) {
    print('❌ Error loading stages: $e');
    setState(() {
      _error = e.toString();
      _isLoadingStages = false;
    });
  }
}

Future<void> _loadDeals() async {
  if (_selectedPipelineId == null || _selectedStageId == null) {
    print('⚠️ Cannot load deals: Pipeline or Stage not selected');
    return;
  }
  
  try {
    setState(() {
      _isLoadingDeals = true;
      _error = null;
      _deals = [];
      _selectedDealId = null;
    });

    final allDeals = await _apiService.getDeals();
    
    print('🔍 [Filter Deals] Selected Pipeline ID: $_selectedPipelineId');
    print('🔍 [Filter Deals] Selected Stage ID: $_selectedStageId');
    print('🔍 [Filter Deals] Total deals received: ${allDeals.length}');
    
    // ✅ FILTER deals berdasarkan berbagai kemungkinan field
    final filteredDeals = allDeals.where((deal) {
      // Kemungkinan field untuk pipeline
      final pipelineId = deal['PipelineId']?.toString();
      final projectId = deal['project_id']?.toString();
      
      // Kemungkinan field untuk stage
      final stageId = deal['StageId']?.toString();
      final stageIdField = deal['stage_id']?.toString();
      
      print('   Deal ${deal['Name'] ?? deal['Nm']}: PipelineId=$pipelineId, project_id=$projectId, StageId=$stageId, stage_id=$stageIdField');
      
      final matchPipeline = pipelineId == _selectedPipelineId || projectId == _selectedPipelineId;
      final matchStage = stageId == _selectedStageId || stageIdField == _selectedStageId;
      
      return matchPipeline && matchStage;
    }).toList();
    
    setState(() {
      _deals = filteredDeals;
      _isLoadingDeals = false;
    });
    
    print('✅ Loaded ${filteredDeals.length} deals for pipeline $_selectedPipelineId and stage $_selectedStageId');
  } catch (e) {
    print('❌ Error loading deals: $e');
    setState(() {
      _error = e.toString();
      _isLoadingDeals = false;
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
      constraints: const BoxConstraints(maxHeight: 600),
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
                  Icons.handshake,
                  color: Color(0xFF1976D2),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Select Deal',
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
                  // Pipeline Dropdown
                  Text(
                    'Pipeline',
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
                    child: _isLoadingPipelines
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          )
                        : DropdownButton<String>(
                            value: _selectedPipelineId,
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
                            items: _pipelines.map((pipeline) {
  return DropdownMenuItem<String>(
    value: pipeline['Id']?.toString(),
    child: Text(
      pipeline['Nm']?.toString() ?? 
      pipeline['Name']?.toString() ?? 
      'Unnamed'
    ),
  );
}).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedPipelineId = value;
                                _selectedStageId = null;
                                _selectedDealId = null;
                                _stages = [];
                                _deals = [];
                              });
                              if (value != null) {
                                _loadStages();
                              }
                            },
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Stage Dropdown
                  Text(
                    'Stage',
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
                    child: _isLoadingStages
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          )
                        : DropdownButton<String>(
                            value: _selectedStageId,
                            hint: Text(
                              _selectedPipelineId == null
                                  ? '--select pipeline first--'
                                  : _stages.isEmpty
                                      ? '--no stages available--'
                                      : '--select--',
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
items: _stages.map((stage) {
  return DropdownMenuItem<String>(
    value: stage['Id']?.toString(),
    child: Text(
      stage['Name']?.toString() ?? 
      stage['Nm']?.toString() ?? 
      'Unnamed'
    ),
  );
}).toList(),
                            onChanged: _selectedPipelineId == null
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedStageId = value;
                                      _selectedDealId = null;
                                      _deals = [];
                                    });
                                    if (value != null) {
                                      _loadDeals();
                                    }
                                  },
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Deal Dropdown
                  Text(
                    'Deal',
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
                    child: _isLoadingDeals
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          )
                        : DropdownButton<String>(
                            value: _selectedDealId,
                            hint: Text(
                              _selectedPipelineId == null || _selectedStageId == null
                                  ? '--select pipeline & stage first--'
                                  : _deals.isEmpty
                                      ? '--no deals available--'
                                      : '--select--',
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
                            items: _deals.map((deal) {
                              return DropdownMenuItem<String>(
                                value: deal['Id']?.toString(),
                                child: Text(deal['Name']?.toString() ?? 'Unnamed'),
                              );
                            }).toList(),
                            onChanged: _selectedPipelineId == null || _selectedStageId == null
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedDealId = value;
                                    });
                                  },
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
  onPressed: _selectedDealId == null
      ? null
      : () {
          final selectedDeal = _deals.firstWhere(
            (d) => d['Id']?.toString() == _selectedDealId,
          );
          final selectedPipeline = _pipelines.firstWhere(
            (p) => p['Id']?.toString() == _selectedPipelineId,
            orElse: () => {},
          );
          final selectedStage = _stages.firstWhere(
            (s) => s['Id']?.toString() == _selectedStageId,
            orElse: () => {},
          );
          
          widget.onDealSelected(
            _selectedDealId!,
            selectedDeal['Name']?.toString() ?? 
            selectedDeal['Nm']?.toString() ?? '',
            selectedPipeline['Nm']?.toString() ?? 
            selectedPipeline['Name']?.toString(), // ✅ Cek Nm dulu
            selectedStage['Name']?.toString() ?? 
            selectedStage['Nm']?.toString(), // ✅ Cek Nm dulu
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