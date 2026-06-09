import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      return configured.replaceFirst(RegExp(r'/+$'), '');
    }

    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        final host = uri.host.toLowerCase();
        if (host != 'localhost' && host != '127.0.0.1') {
          return uri.origin;
        }
      }

      return 'http://localhost:4000';
    }

    // Android builds use the deployed backend by default.
    if (Platform.isAndroid) {
      return 'https://waterguard-server.onrender.com';
    }

    // Windows/macOS/Linux and iOS simulator should use localhost.
    return 'http://localhost:4000';
  }
}
