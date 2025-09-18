import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/account_service.dart';
import '../../../core/theme/app_theme.dart';

class WhatsAppDebugScreen extends ConsumerStatefulWidget {
  const WhatsAppDebugScreen({super.key});

  @override
  ConsumerState<WhatsAppDebugScreen> createState() => _WhatsAppDebugScreenState();
}

class _WhatsAppDebugScreenState extends ConsumerState<WhatsAppDebugScreen> {
  final _linkIdController = TextEditingController(text: '710968507777029');
  final _messageController = TextEditingController(text: 'Test message from debug');
  final _accountIdController = TextEditingController();
  
  String _debugOutput = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentAccountId();
  }

  void _loadCurrentAccountId() {
    final accountService = AccountService();
    
    // Try to get WhatsApp Business account ID first
    String? accountId = accountService.getAccountIdForChannel(1561);
    
    // Fallback to WhatsApp account ID
    accountId ??= accountService.getAccountIdForChannel(1);
    
    // Show all available accounts for debugging
    final userAccounts = accountService.getUserAccounts();
    final availableChannels = accountService.getAvailableChannels();
    
    if (accountId != null) {
      _accountIdController.text = accountId;
      _addDebugOutput('✅ Loaded account ID: $accountId');
    } else {
      _addDebugOutput('❌ No account ID found');
    }
    
    _addDebugOutput('📊 Available channels: $availableChannels');
    _addDebugOutput('📊 Total user accounts: ${userAccounts.length}');
    
    for (final account in userAccounts) {
      _addDebugOutput('  - Channel ${account.channelId}: ${account.id} (${account.name})');
    }
  }
  @override
  void dispose() {
    _linkIdController.dispose();
    _messageController.dispose();
    _accountIdController.dispose();
    super.dispose();
  }

  Future<void> _testWhatsAppMessage() async {
    setState(() {
      _isLoading = true;
      _debugOutput = 'Testing WhatsApp Business API...\n\n';
    });

    try {
      // Test message data
      final messageData = {
        'LinkId': int.tryParse(_linkIdController.text) ?? 0,
        'ChannelId': 1561, // WhatsApp Business
        'AccountIds': _accountIdController.text,
        'BodyType': 1,
        'Body': _messageController.text,
        'Attachment': '',
      };

      _addDebugOutput('Request Data:');
      _addDebugOutput('LinkId: ${messageData['LinkId']}');
      _addDebugOutput('ChannelId: ${messageData['ChannelId']}');
      _addDebugOutput('AccountIds: ${messageData['AccountIds']}');
      _addDebugOutput('Body: "${messageData['Body']}"');
      _addDebugOutput('');

      final response = await ApiService.sendMessage(messageData);
      
      _addDebugOutput('API Response:');
      _addDebugOutput('IsError: ${response.isError}');
      _addDebugOutput('StatusCode: ${response.statusCode}');
      _addDebugOutput('Data: ${response.data}');
      _addDebugOutput('Error: ${response.error}');
      
      if (!response.isError) {
        _addDebugOutput('\n✅ Message sent successfully!');
        _addDebugOutput('Check your WhatsApp to see if the message arrived.');
      } else {
        _addDebugOutput('\n❌ Message failed to send.');
        _addDebugOutput('Error: ${response.error}');
      }

    } catch (e) {
      _addDebugOutput('\n💥 Exception occurred:');
      _addDebugOutput(e.toString());
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _testAccountList() async {
    setState(() {
      _isLoading = true;
      _debugOutput = 'Testing Account List API...\n\n';
    });

    try {
      final accountService = AccountService();
      
      _addDebugOutput('Fetching all user accounts...');
      
      final allAccounts = await accountService.getAllAccounts();
      
      if (allAccounts.isNotEmpty) {
        _addDebugOutput('✅ Found ${allAccounts.length} accounts for user:');
        
        // Group by channel for better display
        final Map<int, List<AccountData>> accountsByChannel = {};
        for (final account in allAccounts) {
          if (!accountsByChannel.containsKey(account.channelId)) {
            accountsByChannel[account.channelId] = [];
          }
          accountsByChannel[account.channelId]!.add(account);
        }
        
        for (final entry in accountsByChannel.entries) {
          final channelId = entry.key;
          final accounts = entry.value;
          
          _addDebugOutput('\nChannel $channelId:');
          for (final account in accounts) {
            _addDebugOutput('  - ${account.id}: ${account.name}');
          }
        }
        
        // Test refreshing mappings
        _addDebugOutput('\nRefreshing account mappings...');
        await accountService.refreshAccountMappings();
        _addDebugOutput('✅ Account mappings refreshed');
        
      } else {
        _addDebugOutput('❌ No accounts found for user');
      }

    } catch (e) {
      _addDebugOutput('Exception: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _addDebugOutput(String text) {
    setState(() {
      _debugOutput += '$text\n';
    });
  }

  void _clearOutput() {
    setState(() {
      _debugOutput = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Debug'),
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input fields
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Parameters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _linkIdController,
                      decoration: const InputDecoration(
                        labelText: 'Link ID',
                        hintText: 'WhatsApp contact link ID',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _accountIdController,
                      decoration: const InputDecoration(
                        labelText: 'Account ID',
                        hintText: 'WhatsApp Business account ID',
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Test Message',
                        hintText: 'Message to send',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testWhatsAppMessage,
                    icon: const Icon(Icons.send),
                    label: const Text('Test Send Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testAccountList,
                    icon: const Icon(Icons.account_circle),
                    label: const Text('Test Accounts'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _clearOutput,
              icon: const Icon(Icons.clear),
              label: const Text('Clear Output'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Debug output
            Expanded(
              child: Card(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  child: SingleChildScrollView(
                    child: _isLoading
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Testing...'),
                              ],
                            ),
                          )
                        : Text(
                            _debugOutput.isEmpty 
                                ? 'Debug output will appear here...' 
                                : _debugOutput,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}