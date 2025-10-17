import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';

class DealSelectionDialog extends StatefulWidget {
  final String contactId;
  final Function(String dealId, String dealName, String? pipeline, String? stage) onDealSelected;

  const DealSelectionDialog({
    super.key,
    required this.contactId,
    required this.onDealSelected,
  });

  @override
  State<DealSelectionDialog> createState() => _DealSelectionDialogState();
}

class _DealSelectionDialogState extends State<DealSelectionDialog> {
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
      });

      final stages = await _apiService.getDealPipelineTypes();
      
      setState(() {
        _stages = stages;
        _isLoadingStages = false;
      });
    } catch (e) {
      print('❌ Error loading stages: $e');
      setState(() {
        _error = e.toString();
        _isLoadingStages = false;
      });
    }
  }

  Future<void> _loadDeals() async {
    try {
      setState(() {
        _isLoadingDeals = true;
        _error = null;
      });

      final deals = await _apiService.getDeals();
      
      setState(() {
        _deals = deals;
        _isLoadingDeals = false;
      });
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
    return Dialog(
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
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.handshake,
                    color: Color(0xFF1976D2),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Select Deal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
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
                    const Text(
                      'Pipeline',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isLoadingPipelines
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : DropdownButton<String>(
                              value: _selectedPipelineId,
                              hint: const Text('--select--'),
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: _pipelines.map((pipeline) {
                                return DropdownMenuItem<String>(
                                  value: pipeline['Id']?.toString(),
                                  child: Text(pipeline['Name']?.toString() ?? 'Unnamed'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedPipelineId = value;
                                  _selectedStageId = null;
                                  _stages = [];
                                });
                                _loadStages();
                              },
                            ),
                    ),

                    const SizedBox(height: 16),

                    // Stage Dropdown
                    const Text(
                      'Stage',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isLoadingStages
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : DropdownButton<String>(
                              value: _selectedStageId,
                              hint: const Text('--select--'),
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: _stages.map((stage) {
                                return DropdownMenuItem<String>(
                                  value: stage['Id']?.toString(),
                                  child: Text(stage['Name']?.toString() ?? 'Unnamed'),
                                );
                              }).toList(),
                              onChanged: _selectedPipelineId == null
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedStageId = value;
                                      });
                                    },
                            ),
                    ),

                    const SizedBox(height: 16),

                    // Deal Dropdown
                    const Text(
                      'Deal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _isLoadingDeals
                                ? const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: Center(child: CircularProgressIndicator()),
                                  )
                                : DropdownButton<String>(
                                    value: _selectedDealId,
                                    hint: const Text('--select--'),
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    items: _deals.map((deal) {
                                      return DropdownMenuItem<String>(
                                        value: deal['Id']?.toString(),
                                        child: Text(deal['Name']?.toString() ?? 'Unnamed'),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedDealId = value;
                                      });
                                    },
                                  ),
                          ),
                          if (!_isLoadingDeals && _deals.isEmpty)
                            TextButton.icon(
                              onPressed: _loadDeals,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Load'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
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
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red, fontSize: 12),
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
                            selectedDeal['Name']?.toString() ?? '',
                            selectedPipeline['Name']?.toString(),
                            selectedStage['Name']?.toString(),
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
