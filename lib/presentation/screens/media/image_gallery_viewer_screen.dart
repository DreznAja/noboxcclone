import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/storage_service.dart';

class ImageGalleryItem {
  final String imageUrl;
  final String? caption;
  final DateTime timestamp;

  ImageGalleryItem({
    required this.imageUrl,
    this.caption,
    required this.timestamp,
  });
}

class ImageGalleryViewerScreen extends StatefulWidget {
  final List<ImageGalleryItem> images;
  final int initialIndex;

  const ImageGalleryViewerScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<ImageGalleryViewerScreen> createState() => _ImageGalleryViewerScreenState();
}

class _ImageGalleryViewerScreenState extends State<ImageGalleryViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

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
    // Validasi initialIndex agar tidak out of bounds
    if (widget.images.isNotEmpty) {
      _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
      _pageController = PageController(initialPage: _currentIndex);
    } else {
      _currentIndex = 0;
      _pageController = PageController(initialPage: 0);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (index >= 0 && index < widget.images.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Validasi images tidak kosong
    if (widget.images.isEmpty) {
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
            'No Images',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: const Center(
          child: Text(
            'No images available',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ),
      );
    }
    
    // Validasi _currentIndex untuk safety
    final safeIndex = _currentIndex.clamp(0, widget.images.length - 1);
    final currentImage = widget.images[safeIndex];
    
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
        title: Text(
          '${safeIndex + 1} of ${widget.images.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Image gallery with swipe
          Expanded(
            child: PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                final item = widget.images[index];
                return PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(
                    item.imageUrl,
                    headers: _getAuthHeaders(),
                  ),
                  minScale: PhotoViewComputedScale.contained * 0.8,
                  maxScale: PhotoViewComputedScale.covered * 2.5,
                  initialScale: PhotoViewComputedScale.contained,
                  heroAttributes: PhotoViewHeroAttributes(tag: item.imageUrl),
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Colors.white54,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Failed to load image',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              itemCount: widget.images.length,
              loadingBuilder: (context, event) => Center(
                child: CircularProgressIndicator(
                  value: event == null
                      ? 0
                      : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              backgroundDecoration: const BoxDecoration(
                color: Colors.black,
              ),
              pageController: _pageController,
              onPageChanged: _onPageChanged,
              enableRotation: false,
            ),
          ),
          
          // Caption and page indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.black87,
            ),
            child: Column(
              children: [
                // Page indicator dots
                if (widget.images.length > 1) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.images.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: safeIndex == index
                              ? Colors.white
                              : Colors.white38,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Caption
                if (currentImage.caption != null && currentImage.caption!.isNotEmpty)
                  Text(
                    currentImage.caption!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
