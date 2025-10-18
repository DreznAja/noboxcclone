import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart';
import 'dart:io';
import 'voice_recorder_widget.dart';
import 'quick_reply_overlay.dart';
import '../../core/models/chat_models.dart';
import '../../core/models/quick_reply_models.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/providers/quick_reply_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/location_service.dart';
import '../screens/media/media_preview_screen.dart';
import 'package:latlong2/latlong.dart';
import '../screens/location/location_picker_screen.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class ChatInputWidget extends ConsumerStatefulWidget {
  final Function(String) onSendText;
  final Function(String type, String data, String filename) onSendMedia;
  final ChatMessage? replyingTo;

  const ChatInputWidget({
    super.key,
    required this.onSendText,
    required this.onSendMedia,
    this.replyingTo,
  });

  @override
  ConsumerState<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends ConsumerState<ChatInputWidget> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showAttachmentOptions = false;
  bool _showVoiceRecorder = false;
  bool _showQuickReply = false;
  bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    // Load quick reply templates on init
    Future.microtask(() => ref.read(quickReplyProvider.notifier).loadTemplates());
  }

  void _onTextChanged() {
    final text = _textController.text;
    
    // Check if user typed "/" to trigger quick reply
    if (text.startsWith('/')) {
      if (!_showQuickReply) {
        setState(() {
          _showQuickReply = true;
        });
      }
      // Search templates based on command
      ref.read(quickReplyProvider.notifier).searchTemplates(text);
    } else {
      if (_showQuickReply) {
        setState(() {
          _showQuickReply = false;
        });
        ref.read(quickReplyProvider.notifier).clearSearch();
      }
    }
    
    setState(() {}); // Rebuild to show correct button
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    print('Sending text message: "$text"');

    // Clear input but keep reply preview until message is processed
    _textController.clear();
    setState(() {
      _showAttachmentOptions = false;
      _showVoiceRecorder = false;
      _showQuickReply = false;
      _showEmojiPicker = false;
    });

    // Send message with reply info
    widget.onSendText(text);
  }

  void _onQuickReplySelected(QuickReplyTemplate template) {
    // Replace the text with template content
    _textController.text = template.content;
    
    // Hide quick reply
    setState(() {
      _showQuickReply = false;
    });
    ref.read(quickReplyProvider.notifier).clearSearch();
    
    // Focus back on input
    _focusNode.requestFocus();
  }

  void _onEmojiSelected(Emoji emoji) {
    final text = _textController.text;
    final selection = _textController.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji.emoji,
    );
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.emoji.length,
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      
      if (image != null) {
        final imageFile = File(image.path);
        
        // Navigate to preview screen
        final result = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (context) => MediaPreviewScreen(
              mediaFile: imageFile,
              mediaType: 'image',
              replyId: widget.replyingTo?.id,
            ),
          ),
        );
        
        // If user confirmed sending, process the media
        if (result != null) {
          // Show sending feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['caption']?.isNotEmpty == true 
                  ? 'Sending image with caption...' 
                  : 'Sending image...'),
              duration: const Duration(seconds: 2),
            ),
          );
          
          final chatNotifier = ref.read(chatProvider.notifier);
          await chatNotifier.sendMediaMessage(
            type: result['type'],
            filename: result['filename'],
            base64Data: result['base64Data'],
            caption: result['caption']?.isNotEmpty == true ? result['caption'] : null,
            replyId: result['replyId'],
          );
        }
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
    
    setState(() {
      _showAttachmentOptions = false;
      _showVoiceRecorder = false;
    });
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      
      if (result != null) {
        final documentFile = File(result.files.single.path!);
        
        // Navigate to preview screen
        final previewResult = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (context) => MediaPreviewScreen(
              mediaFile: documentFile,
              mediaType: 'document',
              replyId: widget.replyingTo?.id,
            ),
          ),
        );
        
        // If user confirmed sending, process the document
        if (previewResult != null) {
          // Show sending feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(previewResult['caption']?.isNotEmpty == true 
                  ? 'Sending document with message...' 
                  : 'Sending document...'),
              duration: const Duration(seconds: 2),
            ),
          );
          
          final chatNotifier = ref.read(chatProvider.notifier);
          await chatNotifier.sendMediaMessage(
            type: previewResult['type'],
            filename: previewResult['filename'],
            base64Data: previewResult['base64Data'],
            caption: previewResult['caption']?.isNotEmpty == true ? previewResult['caption'] : null,
            replyId: previewResult['replyId'],
          );
        }
      }
    } catch (e) {
      _showError('Failed to pick document: $e');
    }
    
    setState(() {
      _showAttachmentOptions = false;
      _showVoiceRecorder = false;
    });
  }

  Future<void> _pickVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      
      if (video != null) {
        final videoFile = File(video.path);
        
        // Check file size (30MB limit)
        final fileSize = await videoFile.length();
        if (fileSize > 30 * 1024 * 1024) {
          _showError('Video file size exceeds 30MB limit');
          return;
        }
        
        // Navigate to preview screen
        final result = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (context) => MediaPreviewScreen(
              mediaFile: videoFile,
              mediaType: 'video',
              replyId: widget.replyingTo?.id,
            ),
          ),
        );
        
        // If user confirmed sending, process the video
        if (result != null) {
          // Show sending feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['caption']?.isNotEmpty == true 
                  ? 'Sending video with caption...' 
                  : 'Sending video...'),
              duration: const Duration(seconds: 3),
            ),
          );
          
          final chatNotifier = ref.read(chatProvider.notifier);
          await chatNotifier.sendMediaMessage(
            type: result['type'],
            filename: result['filename'],
            base64Data: result['base64Data'],
            caption: result['caption']?.isNotEmpty == true ? result['caption'] : null,
            replyId: result['replyId'],
          );
        }
      }
    } catch (e) {
      _showError('Failed to pick video: $e');
    }
    
    setState(() {
      _showAttachmentOptions = false;
      _showVoiceRecorder = false;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  Future<void> _sendLocation() async {
    // Show dialog to choose between current location or select location
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.location_on,
                color: Color(0xFF1976D2),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Send Location',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.my_location,
                  color: Colors.blue.shade700,
                ),
              ),
              title: const Text('Current Location'),
              subtitle: const Text('Send your current GPS location'),
              onTap: () => Navigator.of(context).pop('current'),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.map,
                  color: Colors.green.shade700,
                ),
              ),
              title: const Text('Select Location'),
              subtitle: const Text('Choose location from map'),
              onTap: () => Navigator.of(context).pop('select'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) {
      setState(() {
        _showAttachmentOptions = false;
      });
      return;
    }

    if (choice == 'current') {
      await _sendCurrentLocation();
    } else if (choice == 'select') {
      await _selectAndSendLocation();
    }
  }

  Future<void> _sendCurrentLocation() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Getting your location...'),
            ],
          ),
          backgroundColor: AppTheme.primaryColor,
          duration: Duration(seconds: 5),
        ),
      );

      final location = await LocationService.getCurrentLocation();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      final chatNotifier = ref.read(chatProvider.notifier);
      await chatNotifier.sendLocationMessage(
        location,
        replyId: widget.replyingTo?.id,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location sent successfully'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showError('Failed to get location: $e');
    }
    
    setState(() {
      _showAttachmentOptions = false;
      _showVoiceRecorder = false;
    });
  }

  Future<void> _selectAndSendLocation() async {
    try {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => const LocationPickerScreen(),
        ),
      );

      if (result == null) {
        setState(() {
          _showAttachmentOptions = false;
        });
        return;
      }

      final lat = result['latitude'] as double;
      final lng = result['longitude'] as double;
      final address = result['address'] as String;

      final chatNotifier = ref.read(chatProvider.notifier);
      await chatNotifier.sendLocationMessage(
        {'latitude': lat, 'longitude': lng, 'address': address},
        replyId: widget.replyingTo?.id,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location sent successfully'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _showError('Failed to send location: $e');
    }
    
    setState(() {
      _showAttachmentOptions = false;
      _showVoiceRecorder = false;
    });
  }

  Future<void> _startVoiceRecording() async {
    setState(() {
      _showAttachmentOptions = false;
      _showVoiceRecorder = true;
    });
  }

  Future<void> _sendVoiceNote(String base64Data, String filename) async {
    try {
      final chatNotifier = ref.read(chatProvider.notifier);
      await chatNotifier.sendMediaMessage(
        type: '2', // Audio type
        filename: filename,
        base64Data: base64Data,
        replyId: widget.replyingTo?.id,
      );
      
      setState(() {
        _showVoiceRecorder = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice note sent successfully'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _showError('Failed to send voice note: $e');
    }
  }

  void _cancelVoiceRecording() {
    setState(() {
      _showVoiceRecorder = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    
    // If voice recorder is active, show it as overlay
  if (_showVoiceRecorder) {
    return VoiceRecorderWidget(
      onSendVoice: _sendVoiceNote,
      onCancel: _cancelVoiceRecording, 
      onComplete: (String path, String filename) {  },
    );
  }

    
return Column(
    children: [
      // Quick Reply Overlay
      if (_showQuickReply)
        QuickReplyOverlay(
          onTemplateSelected: _onQuickReplySelected,
          maxHeight: 300,
        ),
      
      // Emoji Picker
      if (_showEmojiPicker)
        SizedBox(
          height: 350,
          child: EmojiPicker(
            onEmojiSelected: (category, emoji) {
              _onEmojiSelected(emoji);
            },
            config: Config(
              height: 350,
              checkPlatformCompatibility: true,
              emojiViewConfig: EmojiViewConfig(
                columns: 8,
                emojiSizeMax: 28,
                verticalSpacing: 0,
                horizontalSpacing: 0,
                gridPadding: EdgeInsets.zero,
                backgroundColor: isDarkMode 
                  ? AppTheme.darkSurface 
                  : const Color(0xFFF8FAFC), // UPDATE INI
                buttonMode: ButtonMode.MATERIAL,
                recentsLimit: 28,
              ),
              skinToneConfig: SkinToneConfig(
                enabled: true,
                dialogBackgroundColor: isDarkMode 
                  ? AppTheme.darkSurface 
                  : Colors.white, // UPDATE INI
              ),
              categoryViewConfig: CategoryViewConfig(
                initCategory: Category.RECENT,
                backgroundColor: isDarkMode 
                  ? AppTheme.darkSurface 
                  : const Color(0xFFF8FAFC), // UPDATE INI
                indicatorColor: AppTheme.primaryColor,
                iconColorSelected: AppTheme.primaryColor,
                iconColor: isDarkMode 
                  ? AppTheme.darkTextSecondary 
                  : const Color(0xFF94A3B8), // UPDATE INI
                categoryIcons: const CategoryIcons(),
              ),
              bottomActionBarConfig: BottomActionBarConfig(
                enabled: true,
                backgroundColor: isDarkMode 
                  ? AppTheme.darkBackground 
                  : Colors.white, // UPDATE INI
                buttonColor: Colors.transparent,
                buttonIconColor: isDarkMode 
                  ? AppTheme.darkTextSecondary 
                  : const Color(0xFF64748B), // UPDATE INI
              ),
              searchViewConfig: SearchViewConfig(
                backgroundColor: isDarkMode 
                  ? AppTheme.darkSurface 
                  : const Color(0xFFF8FAFC), // UPDATE INI
                buttonIconColor: isDarkMode 
                  ? AppTheme.darkTextSecondary 
                  : const Color(0xFF64748B), // UPDATE INI
              ),
            ),
          ),
        ),
      
      // Attachment options
      if (_showAttachmentOptions)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode 
              ? AppTheme.darkSurface 
              : const Color(0xFFF8FAFC), // UPDATE INI
            border: Border(
              top: BorderSide(
                color: isDarkMode 
                  ? Colors.white.withOpacity(0.1)
                  : const Color(0xFFE2E8F0), // UPDATE INI
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachmentOption(
                icon: Icons.camera_alt,
                label: 'Camera',
                onTap: () => _pickImage(ImageSource.camera),
                isDarkMode: isDarkMode, // Pass isDarkMode
              ),
              _AttachmentOption(
                icon: Icons.photo_library,
                label: 'Gallery',
                onTap: () => _pickImage(ImageSource.gallery),
                isDarkMode: isDarkMode, // Pass isDarkMode
              ),
              _AttachmentOption(
                icon: Icons.videocam,
                label: 'Video',
                onTap: _pickVideo,
                isDarkMode: isDarkMode, // Pass isDarkMode
              ),
              _AttachmentOption(
                icon: Icons.insert_drive_file,
                label: 'Document',
                onTap: _pickDocument,
                isDarkMode: isDarkMode, // Pass isDarkMode
              ),
              _AttachmentOption(
                icon: Icons.location_on,
                label: 'Location',
                onTap: _sendLocation,
                isDarkMode: isDarkMode, // Pass isDarkMode
              ),
            ],
          ),
        ),
      
      // Input area
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode 
            ? AppTheme.darkBackground 
            : Colors.white, // UPDATE INI
          border: Border(
            top: BorderSide(
              color: isDarkMode 
                ? Colors.white.withOpacity(0.1)
                : const Color(0xFFE2E8F0), // UPDATE INI
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Attachment button
            IconButton(
              icon: Icon(
                _showAttachmentOptions ? Icons.close : Icons.attach_file,
                color: AppTheme.primaryColor, // Tetap biru
              ),
              onPressed: () {
                setState(() {
                  _showAttachmentOptions = !_showAttachmentOptions;
                  _showEmojiPicker = false;
                });
              },
            ),
            
            // Emoji button
            IconButton(
              icon: Icon(
                _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
                color: AppTheme.primaryColor, // Tetap biru
              ),
              onPressed: () {
                setState(() {
                  _showEmojiPicker = !_showEmojiPicker;
                  _showAttachmentOptions = false;
                  if (_showEmojiPicker) {
                    _focusNode.unfocus();
                  } else {
                    _focusNode.requestFocus();
                  }
                });
              },
            ),
            
            // Text input
            Expanded(
              child: TextFormField(
                controller: _textController,
                focusNode: _focusNode,
                style: TextStyle(
                  color: isDarkMode 
                    ? AppTheme.darkTextPrimary 
                    : AppTheme.textPrimary, // UPDATE INI
                ),
                decoration: InputDecoration(
                  hintText: widget.replyingTo != null 
                      ? 'Reply to message...' 
                      : 'Type a message...',
                  hintStyle: TextStyle(
                    color: isDarkMode 
                      ? AppTheme.darkTextSecondary 
                      : AppTheme.textSecondary, // UPDATE INI
                  ),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDarkMode 
                    ? AppTheme.darkSurface 
                    : const Color(0xFFF1F5F9), // UPDATE INI
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                maxLines: 5,
                minLines: 1,
                onFieldSubmitted: (_) => _sendTextMessage(),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Send button or Voice button
            _textController.text.trim().isNotEmpty
                ? Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor, // Tetap biru
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                      ),
                      onPressed: _sendTextMessage,
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor, // Tetap biru
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.mic,
                        color: Colors.white,
                      ),
                      onPressed: _startVoiceRecording,
                    ),
                  ),
          ],
        ),
      ),
    ],
  );
}
  }


// Update _AttachmentOption class untuk support dark mode:
class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDarkMode; // TAMBAHKAN INI

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDarkMode, // TAMBAHKAN INI
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1), // Tetap sama
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor, // Tetap biru
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode 
                ? AppTheme.darkTextSecondary 
                : AppTheme.textSecondary, // UPDATE INI
            ),
          ),
        ],
      ),
    );
  }
}