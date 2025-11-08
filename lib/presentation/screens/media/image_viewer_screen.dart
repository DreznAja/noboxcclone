import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';

class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String? caption;

  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.caption,
  });

  Map<String, String> _getAuthHeaders() {
    final token = StorageService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'User-Agent': 'NoboxChat/1.0',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Photo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Image viewer
          Expanded(
            child: PhotoView.customChild(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                httpHeaders: _getAuthHeaders(),
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.broken_image,
                        size: 64,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load image',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              backgroundDecoration: const BoxDecoration(
                color: Colors.black,
              ),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3.0,
              initialScale: PhotoViewComputedScale.contained,
              heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
            ),
          ),
          
          // Caption (if exists)
          if (caption != null && caption!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.black87,
              ),
              child: Text(
                caption!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}