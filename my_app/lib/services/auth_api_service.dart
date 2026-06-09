import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'fcm_service.dart';
import 'firebase_service.dart';
import 'demo_mode_config.dart';
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

  // Demo credentials
  static const String _demoEmail = "demo@waterguard.app";
  static const String _demoPassword = "demo123";
  static const String _demoFullName = "Demo User";

  Future<void> restoreSession() async {
    if (DemoModeConfig.enableDemoMode) {
      _token = "demo-token-12345";
      _fullName = _demoFullName;
      _email = _demoEmail;
      debugPrint('[DEMO MODE] Session restored with demo user');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenStorageKey);
    _fullName = prefs.getString(_fullNameStorageKey);
    _email = prefs.getString(_emailStorageKey);

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
    if (DemoModeConfig.enableDemoMode) {
      await Future.delayed(const Duration(milliseconds: 800));

      if (email.trim().toLowerCase() == _demoEmail && password == _demoPassword) {
        _token = "demo-token-12345";
        _fullName = _demoFullName;
        _email = _demoEmail;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenStorageKey, _token!);
        await prefs.setString(_fullNameStorageKey, _fullName!);
        await prefs.setString(_emailStorageKey, _email!);

        debugPrint('[DEMO MODE] Login successful');
        return;
      } else {
        throw Exception('Invalid credentials.\n\nUse demo account:\nEmail: $_demoEmail\nPassword: $_demoPassword');
      }
    }

    // =============== REAL LOGIN ===============
    final response = await _postJson(
      '/api/auth/login',
      {'email': email, 'password': password},
    );

    _token = _extractTokenOrThrow(response);
    _fullName = _extractUserField(response, 'fullName');
    _email = _extractUserField(response, 'email');

    if (((_fullName ?? '').isEmpty || (_email ?? '').isEmpty) &&
        (_token ?? '').isNotEmpty) {
      _hydrateProfileFromToken(_token!);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenStorageKey, _token!);
    if ((_fullName ?? '').isNotEmpty) {
      await prefs.setString(_fullNameStorageKey, _fullName!);
    }
    if ((_email ?? '').isNotEmpty) {
      await prefs.setString(_emailStorageKey, _email!);
    }

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
    if (DemoModeConfig.enableDemoMode) {
      await Future.delayed(const Duration(milliseconds: 1000));
      debugPrint('[DEMO MODE] Signup successful (simulated)');
      return;
    }

    // =============== REAL SIGNUP ===============
    final response = await _postJson(
      '/api/auth/register',
      {'fullName': name, 'email': email, 'password': password},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body);
      final userId = body['user']?['id'] as String?;

      if (userId != null) {
        try {
          await FirebaseService.instance.saveUserData(
            userId: userId,
            fullName: name,
            email: email,
          );
        } catch (firebaseError) {
          debugPrint('Firebase save error: $firebaseError');
        }
      }
      return;
    }

    throw Exception(_extractErrorMessage(response));
  }

  Future<String?> requestPasswordReset({required String email}) async {
    if (DemoModeConfig.enableDemoMode) {
      debugPrint('[DEMO MODE] Password reset requested');
      return "demo-reset-token-xyz";
    }

    final response = await _postJson(
      '/api/auth/forgot-password',
      {'email': email},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response));
    }

    try {
      final body = jsonDecode(response.body);
      return body['resetToken']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    if (DemoModeConfig.enableDemoMode) {
      debugPrint('[DEMO MODE] Password reset successful');
      return true;
    }

    final response = await _postJson(
      '/api/auth/reset-password',
      {
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
      return body['emailSent'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    if (DemoModeConfig.enableDemoMode) {
      _token = null;
      _fullName = null;
      _email = null;
      debugPrint('[DEMO MODE] Logged out');
      return;
    }

    try {
      FCMService.unregisterTokenFromBackend();
    } catch (e) {
      debugPrint('Error unregistering FCM token: $e');
    }

    _token = null;
    _fullName = null;
    _email = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenStorageKey);
    await prefs.remove(_fullNameStorageKey);
    await prefs.remove(_emailStorageKey);
  }

  String? get token => _token;
  String? get fullName => _fullName;
  String? get email => _email;

  // ==================== PRIVATE HELPERS ====================

  String _extractTokenOrThrow(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response));
    }

    final token = _extractToken(response);
    if ((token ?? '').isEmpty) {
      throw Exception('Login succeeded but no token was returned');
    }
    return token!;
  }

  Future<http.Response> _postJson(String path, Map<String, dynamic> payload) async {
    try {
      return await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));
    } on HandshakeException {
      throw Exception('TLS handshake failed when contacting ${ApiConfig.baseUrl}');
    } on SocketException {
      throw Exception('Cannot reach backend at ${ApiConfig.baseUrl}');
    } on TimeoutException {
      throw Exception('Request timed out');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  String? _extractToken(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        return body['token'] ?? body['accessToken'] ?? body['access_token']?.toString();
      }
    } catch (_) {}
    return null;
  }

  String? _extractUserField(http.Response response, String key) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final user = body['user'];
        if (user is Map<String, dynamic>) {
          return user[key]?.toString().trim();
        }
      }
    } catch (_) {}
    return null;
  }

  void _hydrateProfileFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return;

      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final body = jsonDecode(decoded);

      if (body is Map<String, dynamic>) {
        if ((_fullName ?? '').isEmpty) {
          _fullName = body['fullName']?.toString().trim();
        }
        if ((_email ?? '').isEmpty) {
          _email = body['email']?.toString().trim();
        }
      }
    } catch (_) {}
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final msg = body['message'] ?? body['error'];
        if (msg != null) return msg.toString();
      }
    } catch (_) {}
    return 'Request failed (${response.statusCode})';
  }
}