class AppConfig {
  static const String baseUrl = 'https://id.nobox.ai/';
  static const String apiUrl = '${baseUrl}Services/';
  static const String authUrl = '${baseUrl}AccountAPI/';
  static const String inboxUrl = '${baseUrl}Inbox/';
  static const String signalRUrl = '${baseUrl}messagehub';
  static const String uploadUrl = '${baseUrl}upload/';
  
  // API Endpoints
  static const String generateTokenEndpoint = 'AccountAPI/GenerateToken';
  static const String contactListEndpoint = 'Services/Nobox/Contact/List';
  static const String channelListEndpoint = 'Services/Master/Channel/List';
  static const String accountListEndpoint = 'Services/Nobox/Account/List';
  static const String inboxSendEndpoint = 'Inbox/Send';
  static const String uploadBase64Endpoint = 'Inbox/UploadFile/ConvertBase64ToFile';
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String settingsKey = 'app_settings';
  
  // App Constants
  static const int messagePageSize = 20;
  static const int maxFileSize = 30 * 1024 * 1024; // 30MB
  static const int maxMessageLength = 2000;
  
  // Message Types
  static const Map<String, int> messageTypes = {
    'text': 1,
    'audio': 2,
    'image': 3,
    'video': 4,
    'document': 5,
    'system': 6,
    'sticker': 7,
    'location': 9,
    'order': 10,
    'catalog': 11,
    'contact': 12,
    'contactMulti': 13,
    'interactiveOrder': 14,
    'polling': 15,
    'unsupported': 16,
    'limitStorage': 17,
    'limitChannel': 18,
    'interactiveList': 19,
    'interactiveButton': 21,
    'post': 24,
    'profile': 25,
    'stickerNotSupported': 26,
    'template': 27,
  };
  
  // Channel IDs
  static const Map<String, int> channelIds = {
    'whatsapp': 1,
    'whatsappBusiness': 1561, // WhatsApp Business API channel ID
    'telegram': 2,
    'instagram': 3,
    'messenger': 4,
    'tiktok': 6,
    'email': 19,
    'bukalapak': 1492,
    'blibli': 1502,
    'lazada': 1503,
    'shopee': 1504,
    'tokopedia': 1505,
    'olx': 1532,
    'blibliseller': 1556,
    'tokopediaSeller': 1562,
    'noboxchat': 1569,
  };
}