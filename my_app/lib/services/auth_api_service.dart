import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'fcm_service.dart';
import 'firebase_service.dart';
import 'package:flutter/foundation.dart';

class AuthApiService {
  AuthApiService._();

  static final AuthApiService instance = AuthApiService._();

  final http.Client _client = http.Client();

  String? _token;
  String? _fullName;
  String? _email;

  static const String _tokenStorageKey = 'auth_token';
  static const String _fullNameStorageKey = 'auth_full_name';
  static const String _emailStorageKey = 'auth_email';

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenStorageKey);
    _fullName = prefs.getString(_fullNameStorageKey);
    _email = prefs.getString(_emailStorageKey);

    // Backfill profile fields for existing sessions that stored only a token.
    if ((_token ?? '').isNotEmpty &&
        ((_fullName ?? '').isEmpty || (_email ?? '').isEmpty)) {
      _hydrateProfileFromToken(_token!);

      if ((_fullName ?? '').isNotEmpty) {
        await prefs.setString(_fullNameStorageKey, _fullName!);
      }
      if ((_email ?? '').isNotEmpty) {
        await prefs.setString(_emailStorageKey, _email!);
      }
    }
  }

  bool get isAuthenticated => (_token ?? '').isNotEmpty;

  Future<void> login({required String email, required String password}) async {
    final response = await _postJson(
      path: '/api/auth/login',
      payload: {'email': email, 'password': password},
    );

    _token = _extractTokenOrThrow(response);
    _fullName = _extractUserField(response, 'fullName');
    _email = _extractUserField(response, 'email');

    // Keep profile available even if backend omits user object in some responses.
    if (((_fullName ?? '').isEmpty || (_email ?? '').isEmpty) &&
        (_token ?? '').isNotEmpty) {
      _hydrateProfileFromToken(_token!);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenStorageKey, _token!);
    if ((_fullName ?? '').isNotEmpty) {
      await prefs.setString(_fullNameStorageKey, _fullName!);
    } else {
      await prefs.remove(_fullNameStorageKey);
    }
    if ((_email ?? '').isNotEmpty) {
      await prefs.setString(_emailStorageKey, _email!);
    } else {
      await prefs.remove(_emailStorageKey);
    }

    // Register FCM token with backend
    try {
      Future.delayed(const Duration(milliseconds: 500), () {
        FCMService.registerTokenWithBackend();
      });
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  Future<void> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _postJson(
      path: '/api/auth/register',
      payload: {'fullName': name, 'email': email, 'password': password},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Extract user ID from response
      final body = jsonDecode(response.body);
      final userId = body['user']?['id'] as String?;

      // Save user data to Firebase
      if (userId != null) {
        try {
          await FirebaseService.instance.saveUserData(
            userId: userId,
            fullName: name,
            email: email,
          );
        } catch (firebaseError) {
          // Log Firebase error but don't fail signup
          debugPrint('Firebase save error: $firebaseError');
        }
      }

      // Signup successful - user will login on the login page
      return;
    }

    throw Exception(_extractErrorMessage(response));
  }

  Future<String?> requestPasswordReset({required String email}) async {
    final response = await _postJson(
      path: '/api/auth/forgot-password',
      payload: {'email': email},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response));
    }

    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        return body['resetToken']?.toString();
      }
    } catch (_) {
      // ignore
    }

    return null;
  }

  Future<bool> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    final response = await _postJson(
      path: '/api/auth/reset-password',
      payload: {
        'email': email,
        'resetToken': resetToken,
        'newPassword': newPassword,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response));
    }

    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        return body['emailSent'] == true;
      }
    } catch (_) {
      // ignore
    }

    return false;
  }

  Future<void> logout() async {
    // Unregister FCM token from backend
    try {
      FCMService.unregisterTokenFromBackend();
    } catch (e) {
      debugPrint('Error unregistering FCM token: $e');
    }

    _token = null;
    _fullName = null;
    _email = null;
    SharedPreferences.getInstance().then(
      (prefs) => prefs.remove(_tokenStorageKey),
    );
    SharedPreferences.getInstance().then(
      (prefs) => prefs.remove(_fullNameStorageKey),
    );
    SharedPreferences.getInstance().then(
      (prefs) => prefs.remove(_emailStorageKey),
    );
  }

  String? get token => _token;

  String? get fullName => _fullName;

  String? get email => _email;

  String _extractTokenOrThrow(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response));
    }

    final token = _extractToken(response);
    if ((token ?? '').isEmpty) {
      throw Exception('Login succeeded but no token was returned by backend');
    }
    return token!;
  }

  Future<http.Response> _postJson({
    required String path,
    required Map<String, dynamic> payload,
  }) async {
    try {
      return await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));
    } on HandshakeException {
      throw Exception(
        'TLS handshake failed when contacting ${ApiConfig.baseUrl}. Check that the API URL uses a valid HTTPS certificate, or use an HTTP URL that the device is allowed to reach.',
      );
    } on SocketException {
      throw Exception(
        'Cannot reach backend at ${ApiConfig.baseUrl}. Start the server and ensure API_BASE_URL is correct for your device.',
      );
    } on HttpException {
      throw Exception('Network error while contacting backend.');
    } on FormatException {
      throw Exception('Invalid response from backend.');
    } on TimeoutException {
      throw Exception('Request timed out. Check backend connectivity.');
    }
  }

  String? _extractToken(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final token =
            body['token'] ?? body['accessToken'] ?? body['access_token'];
        return token?.toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _extractUserField(http.Response response, String key) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final user = body['user'];
        if (user is Map<String, dynamic>) {
          final value = user[key];
          final text = value?.toString().trim();
          if (text != null && text.isNotEmpty) {
            return text;
          }
        }
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  void _hydrateProfileFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return;
      }

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final body = jsonDecode(decoded);
      if (body is! Map<String, dynamic>) {
        return;
      }

      final tokenName = body['fullName']?.toString().trim();
      final tokenEmail = body['email']?.toString().trim();

      if ((_fullName ?? '').isEmpty && (tokenName ?? '').isNotEmpty) {
        _fullName = tokenName;
      }
      if ((_email ?? '').isEmpty && (tokenEmail ?? '').isNotEmpty) {
        _email = tokenEmail;
      }
    } catch (_) {
      // Ignore malformed token payload and keep current values.
    }
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final message = body['message'] ?? body['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
    } catch (_) {
      // ignore
    }
    return 'Request failed (${response.statusCode})';
  }
}
