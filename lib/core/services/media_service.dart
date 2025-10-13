import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:nobox_chat/core/models/chat_models.dart';
import 'package:record/record.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../app_config.dart';
import 'api_service.dart';

class MediaService {
  static final ImagePicker _picker = ImagePicker();
  static final AudioRecorder _recorder = AudioRecorder();

  // Upload base64 file using the correct endpoint
  static Future<ApiResponse<UploadedFile>> uploadBase64({
    required String filename,
    required String mimetype,
    required String base64Data,
  }) async {
    try {
      final requestData = {
        'media': {
          'filename': filename,
          'mimetype': mimetype,
          'data': base64Data,
        },
      };

      print('Uploading file: $filename with mimetype: $mimetype');

      final response = await ApiService.dio.post(
        'Inbox/UploadFile/ConvertBase64ToFile',
        data: requestData,
      );

      print('Upload response: ${response.data}');

      if (response.statusCode == 200) {
        // Handle both boolean and null cases for IsError
        final isError = response.data['IsError'];
        final hasError = isError == true;
        
        if (!hasError && response.data['Data'] != null) {
          final data = response.data['Data'];
          final uploadedFile = UploadedFile.fromJson(data);
          
          return ApiResponse(
            isError: false,
            data: uploadedFile,
            statusCode: response.statusCode!,
          );
        } else {
          return ApiResponse(
            isError: true,
            error: response.data['Error'] ?? response.data['ErrorMessage'] ?? 'Upload failed',
            statusCode: response.statusCode!,
          );
        }
      } else {
        return ApiResponse(
          isError: true,
          error: 'Upload failed with status: ${response.statusCode}',
          statusCode: response.statusCode!,
        );
      }
    } catch (e) {
      print('Error in uploadBase64: $e');
      return ApiResponse(
        isError: true,
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  // Image picking
  static Future<String?> pickImageAsBase64(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        final bytes = await image.readAsBytes();
        return base64Encode(bytes);
      }
    } catch (e) {
      print('Error picking image: $e');
    }
    return null;
  }

  // Video picking
  static Future<String?> pickVideoAsBase64() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        final file = File(video.path);
        final bytes = await file.readAsBytes();
        
        // Check file size (30MB limit)
        if (bytes.length > AppConfig.maxFileSize) {
          throw Exception('File size exceeds 30MB limit');
        }
        
        return base64Encode(bytes);
      }
    } catch (e) {
      print('Error picking video: $e');
      rethrow;
    }
    return null;
  }

  // Document picking
  static Future<Map<String, String>?> pickDocumentAsBase64() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      
      if (result != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        
        // Check file size
        if (bytes.length > AppConfig.maxFileSize) {
          throw Exception('File size exceeds 30MB limit');
        }
        
        return {
          'data': base64Encode(bytes),
          'filename': result.files.single.name,
          'size': bytes.length.toString(),
        };
      }
    } catch (e) {
      print('Error picking document: $e');
      rethrow;
    }
    return null;
  }

  // Audio recording
  static Future<bool> startRecording() async {
    try {
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        throw Exception('Microphone permission denied');
      }

      await _recorder.start(const RecordConfig(), path: '');
      return true;
    } catch (e) {
      print('Error starting recording: $e');
      return false;
    }
  }

  static Future<String?> stopRecordingAsBase64() async {
    try {
      final path = await _recorder.stop();
      if (path != null) {
        final file = File(path);
        final bytes = await file.readAsBytes();
        await file.delete(); // Clean up temp file
        return base64Encode(bytes);
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
    return null;
  }

  static Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  // Location
  static Future<Map<String, double>?> getCurrentLocation() async {
    try {
      final permission = await Permission.location.request();
      if (!permission.isGranted) {
        throw Exception('Location permission denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      print('Error getting location: $e');
      rethrow;
    }
  }

  // Utility methods
  static String getMimeType(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/mov';
      case 'mp3':
        return 'audio/mp3';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  static bool isImageFile(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  static bool isVideoFile(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'flv', 'webm'].contains(extension);
  }

  static bool isAudioFile(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return ['mp3', 'wav', 'aac', 'ogg', 'm4a'].contains(extension);
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}