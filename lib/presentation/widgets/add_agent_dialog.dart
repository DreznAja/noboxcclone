import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/agent_models.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_theme.dart';

class AddAgentDialog extends ConsumerStatefulWidget {
  final String roomId;
  final String? linkId;
  final int channelId;
  final Function(HumanAgent)? onAgentAdded;

  const AddAgentDialog({
    super.key,
    required this.roomId,
    this.linkId,
    required this.channelId,
    this.onAgentAdded,
  });

  @override
  ConsumerState<AddAgentDialog> createState() => _AddAgentDialogState();
}

class _AddAgentDialogState extends ConsumerState<AddAgentDialog> {
  List<HumanAgent> _agents = [];
  List<HumanAgent> _filteredAgents = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  Map<String, String> _getAuthHeaders() {
    final token = StorageService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'User-Agent': 'NoboxChat/1.0',
    };
  }

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAgents() async {
    setState(() => _isLoading = true);

    final response = await ApiService.getHumanAgents();

    if (mounted) {
      if (!response.isError && response.data != null) {
        setState(() {
          _agents = response.data!;
          _filteredAgents = _agents;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'Failed to load agents'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  void _filterAgents(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredAgents = _agents;
      } else {
        _filteredAgents = _agents.where((agent) {
          final nameLower = agent.displayName.toLowerCase();
          final emailLower = agent.email.toLowerCase();
          final queryLower = query.toLowerCase();
          return nameLower.contains(queryLower) || emailLower.contains(queryLower);
        }).toList();
      }
    });
  }

  Future<void> _addAgent(HumanAgent agent) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    // Get current user ID for HandId
    final userData = StorageService.getUserData();
    final currentUserId = userData?['UserId']?.toString();

    final request = AddAgentRequest(
      roomId: widget.roomId,
      userId: agent.userId.toString(),
      linkId: widget.linkId,
      displayName: agent.displayName,
      handId: currentUserId,
      channelId: widget.channelId.toString(),
    );

    final response = await ApiService.addAgentToConversation(request);

    if (mounted) {
      // Close loading dialog
      Navigator.pop(context);

      if (!response.isError) {
        // Close add agent dialog
        Navigator.pop(context);

        // Notify parent
        if (widget.onAgentAdded != null) {
          widget.onAgentAdded!(agent);
        }

        // Check if agent already exists
        final isAlreadyExists = response.message == 'AGENT_ALREADY_EXISTS';
        
        // Show appropriate message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAlreadyExists 
                ? '${agent.displayName} is already in this conversation'
                : '${agent.displayName} has been added to the conversation'
            ),
            backgroundColor: isAlreadyExists ? Colors.orange : AppTheme.successColor,
          ),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.error ?? 'Failed to add agent'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    
    return Dialog(
      backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkSurface : AppTheme.primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Add Human Agent',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: _filterAgents,
                style: TextStyle(
                  color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search agents...',
                  hintStyle: TextStyle(
                    color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _filterAgents('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDarkMode ? AppTheme.darkBackground : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDarkMode ? AppTheme.darkTextSecondary.withOpacity(0.3) : Colors.grey[300]!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDarkMode ? AppTheme.darkTextSecondary.withOpacity(0.3) : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // Agents list
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _filteredAgents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isEmpty
                                    ? Icons.people_outline
                                    : Icons.search_off,
                                size: 64,
                                color: isDarkMode 
                                    ? AppTheme.darkTextSecondary 
                                    : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No agents available'
                                    : 'No agents found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDarkMode 
                                      ? AppTheme.darkTextSecondary 
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredAgents.length,
                          itemBuilder: (context, index) {
                            final agent = _filteredAgents[index];
                            return _buildAgentItem(agent, isDarkMode);
                          },
                        ),
            ),

            // Footer info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkBackground : Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [ 
                  Icon(
                    Icons.info_outline, 
                    size: 16, 
                    color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_filteredAgents.length} agent${_filteredAgents.length != 1 ? 's' : ''} available',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey[600],
                      ),
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

  Widget _buildAgentItem(HumanAgent agent, bool isDarkMode) {
    return InkWell(
      onTap: () => _addAgent(agent),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDarkMode ? AppTheme.darkTextSecondary.withOpacity(0.2) : Colors.grey[200]!,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundImage: agent.userImage != null && agent.userImage!.isNotEmpty
                  ? CachedNetworkImageProvider(
                      agent.userImage!,
                      headers: _getAuthHeaders(),
                    )
                  : null,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: agent.userImage == null || agent.userImage!.isEmpty
                  ? Text(
                      agent.displayName.isNotEmpty
                          ? agent.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Agent info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    agent.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 14,
                        color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          agent.email,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Add button
            Icon(
              Icons.add_circle_outline,
              color: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
