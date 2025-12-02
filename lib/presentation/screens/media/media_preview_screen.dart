import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart'; // TAMBAHKAN INI
import 'package:nobox_chat/presentation/screens/media/video_player_screen.dart';
import 'dart:io';
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/media_service.dart';

class MediaPreviewScreen extends ConsumerStatefulWidget {
  final File mediaFile;
  final String mediaType; // 'image', 'video', 'document'
  final String? replyId;

  const MediaPreviewScreen({
    super.key,
    required this.mediaFile,
    required this.mediaType,
    this.replyId,
  });

  @override
  ConsumerState<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends ConsumerState<MediaPreviewScreen> {
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocusNode = FocusNode();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captionFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocusNode.dispose();
    super.dispose();
  }

  String _getMediaTypeString() {
    switch (widget.mediaType) {
      case 'image':
        return '3';
      case 'video':
        return '4';
      case 'document':
        return '5';
      default:
        return '5';
    }
  }

  Future<void> _sendMedia() async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final bytes = await widget.mediaFile.readAsBytes();
      final base64Data = base64Encode(bytes);
      final filename = widget.mediaFile.path.split('/').last;

      Navigator.of(context).pop({
        'type': _getMediaTypeString(),
        'base64Data': base64Data,
        'filename': filename,
        'caption': _captionController.text.trim(),
        'replyId': widget.replyId,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process media: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Widget _buildMediaPreview(bool isDarkMode) { // TAMBAHKAN PARAMETER
    switch (widget.mediaType) {
      case 'image':
        return _buildImagePreview();
      case 'video':
        return _buildVideoPreview();
      case 'document':
        return _buildDocumentPreview(isDarkMode); // PASS PARAMETER
      default:
        return _buildDocumentPreview(isDarkMode); // PASS PARAMETER
    }
  }

  Widget _buildImagePreview() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          widget.mediaFile,
          fit: BoxFit.contain,
          width: double.infinity,
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videoUrl: widget.mediaFile.path,
              caption: _captionController.text.trim().isNotEmpty 
                  ? _captionController.text.trim() 
                  : null,
            ),
          ),
        );
      },
      child: Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow,
                size: 40,
                color: Colors.white,
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Video Preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Tap to preview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentPreview(bool isDarkMode) { // TAMBAHKAN PARAMETER
    final filename = widget.mediaFile.path.split('/').last;
    final fileSize = widget.mediaFile.lengthSync();
    final fileSizeText = MediaService.formatFileSize(fileSize);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : AppTheme.neutralLight, // UPDATE
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode 
            ? Colors.white.withOpacity(0.1) 
            : Colors.grey.shade300, // UPDATE
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getDocumentIcon(filename),
              size: 32,
              color: AppTheme.primaryColor,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode 
                      ? AppTheme.darkTextPrimary 
                      : AppTheme.textPrimary, // UPDATE
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  fileSizeText,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode 
                      ? AppTheme.darkTextSecondary 
                      : AppTheme.textSecondary, // UPDATE
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDocumentIcon(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode; // TAMBAHKAN INI
    
    return Scaffold(
      backgroundColor: Colors.black, // Tetap hitam untuk media preview
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.mediaType == 'image' 
              ? 'Send Photo'
              : widget.mediaType == 'video'
                  ? 'Send Video'
                  : 'Send Document',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Media Preview
          Expanded(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              child: Center(
                child: _buildMediaPreview(isDarkMode), // PASS PARAMETER
              ),
            ),
          ),
          
          // Caption Input and Send Button
          Container(
            color: isDarkMode ? AppTheme.darkBackground : Colors.white, // UPDATE
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Column(  
              children: [
                // // Caption Input - FIXED: Gunakan border di InputDecoration
                // TextField(
                //   controller: _captionController,
                //   focusNode: _captionFocusNode,
                //   maxLines: 4,
                //   minLines: 1,
                //   style: TextStyle(
                //     fontSize: 16,
                //     color: isDarkMode 
                //       ? AppTheme.darkTextPrimary 
                //       : AppTheme.textPrimary, // UPDATE
                //   ),
                //   decoration: InputDecoration(
                //     hintText: widget.mediaType == 'document' 
                //         ? 'Add a message...'
                //         : 'Add a caption...',
                //     hintStyle: TextStyle(
                //       color: isDarkMode 
                //         ? AppTheme.darkTextSecondary 
                //         : AppTheme.textSecondary, // UPDATE
                //       fontSize: 16,
                //     ),
                //     filled: true,
                //     fillColor: isDarkMode 
                //       ? AppTheme.darkSurface 
                //       : Color(0xFFF1F5F9), // UPDATE
                //     contentPadding: EdgeInsets.symmetric(
                //       horizontal: 20,
                //       vertical: 14,
                //     ),
                //     enabledBorder: OutlineInputBorder(
                //       borderRadius: BorderRadius.circular(24),
                //       borderSide: BorderSide(
                //         color: isDarkMode 
                //           ? Colors.white.withOpacity(0.1) 
                //           : Colors.grey.shade300, // UPDATE
                //         width: 1,
                //       ),
                //     ),
                //     focusedBorder: OutlineInputBorder(
                //       borderRadius: BorderRadius.circular(24),
                //       borderSide: BorderSide(
                //         color: AppTheme.primaryColor,
                //         width: 2,
                //       ),
                //     ),
                //   ),
                //   textInputAction: TextInputAction.newline,
                // ),
                
                // SizedBox(height: 16),
                
                // Send Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _sendMedia,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: Colors.grey[400],
                    ),
                    child: _isSending
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Send ${widget.mediaType == 'image' ? 'Photo' : widget.mediaType == 'video' ? 'Video' : 'Document'}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper extension for file size formatting
extension FileSizeExtension on MediaService {
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}