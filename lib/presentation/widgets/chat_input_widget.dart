import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'voice_recorder_widget.dart';
import '../../core/models/chat_models.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/location_service.dart';
import '../screens/media/media_preview_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {}); // Rebuild to show correct button
    });
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

    // Clear input immediately for better UX
    _textController.clear();
    setState(() {
      _showAttachmentOptions = false;
      _showVoiceRecorder = false;
    });

    // Send message (this will handle optimistic updates internally)
    widget.onSendText(text);
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
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Getting your location...'),
            ],
          ),
          backgroundColor: AppTheme.primaryColor,
          duration: Duration(seconds: 5),
        ),
      );

      // Get current location
      final location = await LocationService.getCurrentLocation();
      
      // Hide loading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Validate replyId before sending
      String? validatedReplyId = widget.replyingTo?.id;
      if (validatedReplyId != null && validatedReplyId.isNotEmpty) {
        // Additional validation could be added here if needed
        print('✅ Sending location with ReplyId: $validatedReplyId');
      }
      
      // Send location using the chat provider
      final chatNotifier = ref.read(chatProvider.notifier);
      await chatNotifier.sendLocationMessage(
        location,
        replyId: validatedReplyId,
      );
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location sent successfully'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 2),
        ),
      );
      
    } catch (e) {
      // Hide loading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Show error message
      _showError('Failed to get location: $e');
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
    // If voice recorder is active, show it as overlay
    if (_showVoiceRecorder) {
      return VoiceRecorderWidget(
        onSendVoice: _sendVoiceNote,
        onCancel: _cancelVoiceRecording,
      );
    }
    
    return Column(
      children: [
        // Attachment options
        if (_showAttachmentOptions)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                _AttachmentOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
                _AttachmentOption(
                  icon: Icons.videocam,
                  label: 'Video',
                  onTap: _pickVideo,
                ),
                _AttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'Document',
                  onTap: _pickDocument,
                ),
                _AttachmentOption(
                  icon: Icons.location_on,
                  label: 'Location',
                  onTap: _sendLocation,
                ),
                _AttachmentOption(
                  icon: Icons.mic,
                  label: 'Voice',
                  onTap: _startVoiceRecording,
                ),
              ],
            ),
          ),
        
        // Input area
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          child: Row(
            children: [
              // Attachment button
              IconButton(
                icon: Icon(
                  _showAttachmentOptions ? Icons.close : Icons.attach_file,
                  color: AppTheme.primaryColor,
                ),
                onPressed: () {
                  setState(() {
                    _showAttachmentOptions = !_showAttachmentOptions;
                  });
                },
              ),
              
              // Text input
              Expanded(
                child: TextFormField(
                  controller: _textController,
                  focusNode: _focusNode,
                  style: const TextStyle(
                    color: AppTheme.textPrimary, // Added explicit text color
                  ),
                  decoration: InputDecoration(
                    hintText: widget.replyingTo != null 
                        ? 'Reply to message...' 
                        : 'Type a message...',
                    hintStyle: const TextStyle(
                      color: AppTheme.textSecondary, // Hint text color
                    ),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
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
                        color: AppTheme.primaryColor,
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
                        color: AppTheme.primaryColor,
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

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.onTap,
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
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}