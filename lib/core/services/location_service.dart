import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static Future<bool> requestLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable location services in your device settings.');
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied. Please grant location permission to send your location.');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied. Please enable location permission in app settings.');
      }

      return true;
    } catch (e) {
      print('Location permission error: $e');
      rethrow;
    }
  }

  static Future<Map<String, double>> getCurrentLocation() async {
    try {
      // Request permission first
      await requestLocationPermission();

      // Get current position with high accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
      };
    } catch (e) {
      print('Error getting location: $e');
      rethrow;
    }
  }

  static String formatLocationMessage(Map<String, double> location) {
    final lat = location['latitude']!.toStringAsFixed(6);
    final lng = location['longitude']!.toStringAsFixed(6);
    
    return 'Location: $lat, $lng\n'
           'https://maps.google.com/maps?q=$lat,$lng';
  }

  static String getGoogleMapsUrl(double latitude, double longitude) {
    return 'https://maps.google.com/maps?q=$latitude,$longitude';
  }

  static String getLocationDisplayText(double latitude, double longitude) {
    return 'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
  }
}