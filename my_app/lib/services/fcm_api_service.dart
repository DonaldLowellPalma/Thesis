import 'package:http/http.dart' as http;
import 'auth_api_service.dart';
import 'package:flutter/foundation.dart';

const String baseUrl = 'http://192.168.126.246:4000';

class FCMApiService {
  static final FCMApiService _instance = FCMApiService._internal();

  factory FCMApiService() {
    return _instance;
  }

  FCMApiService._internal();

  /// Register FCM token with the backend
  Future<void> registerFCMToken(String fcmToken) async {
    try {
      final token = AuthApiService.instance.token;
      if (token == null) {
        debugPrint('No auth token available');
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/fcm/register-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: '{"fcmToken": "$fcmToken"}',
      );

      if (response.statusCode == 200) {
        debugPrint('FCM token registered successfully');
      } else {
        debugPrint(
          'Failed to register FCM token: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  /// Unregister FCM token from the backend
  Future<void> unregisterFCMToken(String fcmToken) async {
    try {
      final token = AuthApiService.instance.token;
      if (token == null) {
        debugPrint('No auth token available');
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/fcm/unregister-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: '{"fcmToken": "$fcmToken"}',
      );

      if (response.statusCode == 200) {
        debugPrint('FCM token unregistered successfully');
      } else {
        debugPrint(
          'Failed to unregister FCM token: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error unregistering FCM token: $e');
    }
  }
}
