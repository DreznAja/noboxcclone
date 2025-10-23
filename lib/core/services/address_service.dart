import 'package:dio/dio.dart';
import '../app_config.dart';
import '../models/location_models.dart';
import 'storage_service.dart';

class AddressService {
  static final AddressService _instance = AddressService._internal();
  factory AddressService() => _instance;

  late Dio _dio;

  AddressService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = StorageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        print('Location API Error: ${error.message}');
        handler.next(error);
      },
    ));
  }

  Future<List<Country>> getCountries() async {
    try {
      print('Fetching countries...');
      
      final requestData = {
        'Take': 300,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/Master/Countries/List',
        data: requestData,
      );

      print('Countries response: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        print('Found ${entities.length} countries');
        return entities.map((item) => Country.fromJson(item)).toList();
      }

      return [];
    } catch (e) {
      print('Error fetching countries: $e');
      return [];
    }
  }

  Future<List<StateRegion>> getStates(String countryId) async {
    try {
      print('Fetching states for country: $countryId');
      
      final requestData = {
        'EqualityFilter': {
          'CountryId': countryId,
        },
        'Take': 500,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/Master/States/List',
        data: requestData,
      );

      print('States response: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        print('Found ${entities.length} states for country $countryId');
        return entities.map((item) => StateRegion.fromJson(item)).toList();
      }

      return [];
    } catch (e) {
      print('Error fetching states: $e');
      return [];
    }
  }

  Future<List<City>> getCities(String stateId) async {
    try {
      print('Fetching cities for state: $stateId');
      
      final requestData = {
        'EqualityFilter': {
          'StateId': stateId,
        },
        'Take': 1000,
        'Skip': 0,
      };

      final response = await _dio.post(
        'Services/Master/Cities/List',
        data: requestData,
      );

      print('Cities response: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['IsError'] != true) {
        final List<dynamic> entities = response.data['Entities'] ?? [];
        print('Found ${entities.length} cities for state $stateId');
        return entities.map((item) => City.fromJson(item)).toList();
      }

      return [];
    } catch (e) {
      print('Error fetching cities: $e');
      return [];
    }
  }
}
