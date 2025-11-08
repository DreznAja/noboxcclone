import 'dart:convert';
import '../models/chat_models.dart';
import '../services/storage_service.dart';
import '../services/agent_cache_service.dart';

class MessageDetectionUtils {
  static final Map<String, bool> _learnedAgentNumbers = {};
  static bool _isInitialized = false;
  static final Set<String> _loggedNumbers = {}; // Track what we've already logged

  /// Initialize dengan data dari storage
  static void _initialize() {
    if (_isInitialized) return;
    
    final userData = StorageService.getUserData();
    final learnedAgents = userData?['learnedAgentNumbers'] as Map<String, dynamic>?;
    
    if (learnedAgents != null) {
      learnedAgents.forEach((number, isAgent) {
        _learnedAgentNumbers[number] = isAgent == true;
      });
    }
    
    _isInitialized = true;
    if (_learnedAgentNumbers.isNotEmpty) {
      print('🤖 Loaded ${_learnedAgentNumbers.length} learned agent numbers');
    }
  }

  /// Mendeteksi apakah pesan berasal dari agent (saya) atau customer
  static bool isAgentMessage(ChatMessage message) {
    _initialize();
    
    final from = message.from.toString();
    final agentId = message.agentId;
    
    // 1. Jika agentId > 0, PASTI dari agent (via app)
    if (agentId > 0) {
      _learnAgentNumber(from); // Simpan bahwa nomor ini adalah agent
      _logOnce(from, 'AGENT MESSAGE: agentId > 0 ($agentId)');
      return true;
    }
    
    // 2. Check if message is from any of the mapped agent account IDs
    final userData = StorageService.getUserData();
    final agentAccountIds = userData?['AgentAccountIds'] as List<dynamic>? ?? [];
    final isFromMappedAgent = agentAccountIds.any((id) => id.toString() == from);
    
    if (isFromMappedAgent) {
      _learnAgentNumber(from);
      _logOnce(from, 'AGENT MESSAGE: from mapped agent account');
      return true;
    }
    
    // 2. Cek nomor yang sudah dipelajari
    if (_learnedAgentNumbers.containsKey(from)) {
      final isAgent = _learnedAgentNumbers[from] == true;
      _logOnce(from, 'Learned: $from is ${isAgent ? 'AGENT' : 'CUSTOMER'}');
      return isAgent;
    }
    
    // 3. AUTO-LEARNING: Jika dari nomor yang sama ada yang agentId > 0 dan agentId = 0
    // Ini berarti nomor tersebut adalah agent WhatsApp
    if (_isPotentialWhatsAppAgent(from)) {
      _learnAgentNumber(from);
      _logOnce(from, 'AGENT MESSAGE: auto-learned WhatsApp agent');
      return true;
    }
    
    // 4. Cek signature NoBox (pesan dari app)
    final messageContent = message.message ?? '';
    if (messageContent.contains('Sent from NoBox.Ai') ||
        messageContent.contains('Sent by NoBox.Ai') ||
        messageContent.contains('Dikirim pakai NoBox.Ai')) {
      _learnAgentNumber(from);
      _logOnce(from, 'AGENT MESSAGE: NoBox signature found');
      return true;
    }
    
    // 5. DEFAULT: customer message
    _learnCustomerNumber(from);
    _logOnce(from, 'CUSTOMER MESSAGE: from customer');
    return false;
  }
  
  /// Log only once per number to reduce spam
  static void _logOnce(String number, String message) {
    final key = '$number:$message';
    if (!_loggedNumbers.contains(key)) {
      _loggedNumbers.add(key);
      print('🔍 $message ($number)');
      
      // Clear old logs periodically to prevent memory leak
      if (_loggedNumbers.length > 100) {
        _loggedNumbers.clear();
      }
    }
  }
  
  /// Mendeteksi apakah nomor berpotensi menjadi WhatsApp agent
  static bool _isPotentialWhatsAppAgent(String number) {
    // Logika: Jika nomor ini pernah mengirim pesan dengan agentId > 0
    // dan juga pernah dengan agentId = 0, maka ini WhatsApp agent
    final userData = StorageService.getUserData();
    final messageHistory = userData?['messageHistory'] as List<dynamic>?;
    
    if (messageHistory != null) {
      final hasAgentMessage = messageHistory.any((msg) =>
          msg['from'] == number && msg['agentId'] > 0);
      final hasCustomerMessage = messageHistory.any((msg) =>
          msg['from'] == number && msg['agentId'] == 0);
      
      return hasAgentMessage && hasCustomerMessage;
    }
    
    return false;
  }
  
  /// Simpan bahwa nomor ini adalah agent
  static void _learnAgentNumber(String number) {
    if (_learnedAgentNumbers[number] != true) {
      _learnedAgentNumbers[number] = true;
      _saveToStorage();
      print('📚 NEW LEARNING: $number is AGENT');
    }
  }
  
  /// Simpan bahwa nomor ini adalah customer
  static void _learnCustomerNumber(String number) {
    if (_learnedAgentNumbers[number] != false) {
      _learnedAgentNumbers[number] = false;
      _saveToStorage();
      print('📚 NEW LEARNING: $number is CUSTOMER');
    }
  }
  
  /// Simpan data ke storage
  static void _saveToStorage() {
    final userData = StorageService.getUserData() ?? {};
    userData['learnedAgentNumbers'] = _learnedAgentNumbers;
    StorageService.saveUserData(userData);
  }
  
  /// Method untuk manual override (jika auto-detection salah)
  static void markAsAgent(String number) {
    _initialize();
    _learnAgentNumber(number);
  }
  
  static void markAsCustomer(String number) {
    _initialize();
    _learnCustomerNumber(number);
  }
  
  /// Reset learned data
  static void resetLearning() {
    _learnedAgentNumbers.clear();
    _loggedNumbers.clear();
    final userData = StorageService.getUserData() ?? {};
    userData.remove('learnedAgentNumbers');
    StorageService.saveUserData(userData);
    print('🔄 Reset learned agent numbers');
  }

  /// Mendeteksi apakah pesan adalah system message
  static bool isSystemMessage(ChatMessage message) {
    final content = message.message ?? '';
    return content.contains('"msg":"Site.Inbox.') ||
           content.contains('HasAsign') ||
           content.contains('HasAssign') ||
           content.contains('MuteBot') ||
           content.contains('UnmuteBot');
  }
  
  /// Parse system message JSON ke human-readable format
  static String parseSystemMessage(String jsonString) {
    try {
      // Try to parse as JSON
      final json = _tryParseJson(jsonString);
      if (json == null) return jsonString;
      
      final msg = json['msg'] as String?;
      final user = json['user'];
      final userHandle = json['userHandle']?.toString();
      final userId = json['userId']?.toString();
      final byUserId = json['byUserId']?.toString();
      final agentId = json['agentId']?.toString();
      
      if (msg == null) return jsonString;
      
      // Get agent names from cache (sync, no API call in message parsing)
      final agentCache = AgentCacheService();
      
      // Parse different system messages with proper formatting
      if (msg == 'Site.Inbox.HasResolveBy' || msg.contains('ResolveBy')) {
        final agentName = _resolveAgentName(agentCache, byUserId ?? userId ?? agentId) ?? user ?? 'Agent';
        return '$agentName resolved this conversation';
      } else if (msg == 'Site.Inbox.HasArchiveBy' || msg.contains('ArchiveBy')) {
        final agentName = _resolveAgentName(agentCache, byUserId ?? userId ?? agentId) ?? user ?? 'Agent';
        return '$agentName archived this conversation';
      } else if (msg == 'Site.Inbox.HasRestoreBy' || msg.contains('RestoreBy')) {
        final agentName = _resolveAgentName(agentCache, byUserId ?? userId ?? agentId) ?? user ?? 'Agent';
        return '$agentName restored this conversation';
      } else if (msg == 'Site.Inbox.HasAssignBySystem') {
        return 'Conversation assigned by system';
      } else if (msg.contains('HasAsign') || msg.contains('HasAssign')) {
        print('🔍 [Assign Message Debug]');
        print('   userId: $userId');
        print('   byUserId: $byUserId');
        print('   userHandle: $userHandle');
        print('   agentId: $agentId');
        print('   user: $user');
        
        // Support both formats:
        // Format 1 (new): userId (target agent), byUserId (assigner)
        // Format 2 (legacy): userHandle (target agent), user (assigner)
        final targetAgentId = userId ?? userHandle ?? agentId;
        final assignerAgentId = byUserId ?? user?.toString();
        
        print('   targetAgentId: $targetAgentId');
        print('   assignerAgentId: $assignerAgentId');
        
        final targetAgentName = _resolveAgentName(agentCache, targetAgentId) ?? targetAgentId ?? 'Agent';
        final byAgentName = _resolveAgentName(agentCache, assignerAgentId);
        
        print('   targetAgentName resolved: $targetAgentName');
        print('   byAgentName resolved: $byAgentName');
        
        if (byAgentName != null) {
          return '$targetAgentName has been assigned to this conversation by $byAgentName';
        } else {
          return '$targetAgentName has been assigned to this conversation';
        }
      } else if (msg.contains('AgentOutBy') || msg.contains('HasRemove')) {
        final removedAgentName = _resolveAgentName(agentCache, userId ?? agentId) ?? user ?? 'Agent';
        final byAgentName = _resolveAgentName(agentCache, byUserId);
        
        if (byAgentName != null) {
          return '$removedAgentName has been removed from this conversation by $byAgentName';
        } else {
          return '$removedAgentName has been removed from this conversation';
        }
      } else if (msg.contains('MuteBot')) {
        final agentName = _resolveAgentName(agentCache, byUserId ?? userId ?? agentId) ?? user ?? 'Agent';
        return '$agentName muted the bot for this conversation';
      } else if (msg.contains('UnmuteBot')) {
        final agentName = _resolveAgentName(agentCache, byUserId ?? userId ?? agentId) ?? user ?? 'Agent';
        return '$agentName unmuted the bot for this conversation';
      }
      
      // Default: return cleaned message
      return msg.replaceAll('Site.Inbox.', '').replaceAll('_', ' ');
      
    } catch (e) {
      print('⚠️ Failed to parse system message: $e');
      return jsonString;
    }
  }
  
  /// Helper to resolve agent ID to agent name
  static String? _resolveAgentName(AgentCacheService agentCache, String? agentId) {
    if (agentId == null || agentId.isEmpty) return null;
    return agentCache.getAgentNameSync(agentId);
  }
  
  /// Helper to safely try parse JSON
  static Map<String, dynamic>? _tryParseJson(String str) {
    try {
      final decoded = jsonDecode(str);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      return null;
    }
  }
  
  /// Membersihkan pesan dari signature NoBox dan parse system messages
  static String cleanMessageContent(String content) {
    // First check if it's a system message (JSON format)
    if (content.trim().startsWith('{') && content.trim().endsWith('}')) {
      final parsed = parseSystemMessage(content);
      if (parsed != content) {
        return parsed; // Return parsed system message
      }
    }
    
    // Regular message cleaning
    return content
        .replaceAll('\n\nSent from NoBox.Ai trial account', '')
        .replaceAll('\n\nSent by NoBox.Ai', '')
        .replaceAll('\n\nDikirim pakai NoBox.Ai', '')
        .trim();
  }
}