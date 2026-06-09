import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.rssi,
    this.secure = true,
  });

  final String ssid;
  final int rssi;
  final bool secure;

  factory WifiNetwork.fromMap(Map<String, dynamic> map) {
    return WifiNetwork(
      ssid: map['ssid']?.toString() ?? '',
      rssi: (map['rssi'] as num?)?.toInt() ?? -100,
      secure: map['secure'] as bool? ?? true,
    );
  }
}

class WifiConnectionStatus {
  const WifiConnectionStatus({
    required this.connected,
    required this.currentSsid,
    required this.savedSsid,
    required this.connecting,
    required this.connectingToSsid,
  });

  final bool connected;
  final String currentSsid;
  final String savedSsid;
  final bool connecting;
  final String connectingToSsid;

  factory WifiConnectionStatus.fromMap(Map<String, dynamic> map) {
    return WifiConnectionStatus(
      connected: map['connected'] as bool? ?? false,
      currentSsid: map['currentSsid']?.toString() ?? '',
      savedSsid: map['savedSsid']?.toString() ?? '',
      connecting: map['connecting'] as bool? ?? false,
      connectingToSsid: map['connectingToSsid']?.toString() ?? '',
    );
  }
}

class Esp32SetupService {
  Esp32SetupService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String _networkHint(String host) {
    return 'Cannot reach ESP32 at $host. Connect this device to WaterGuard-Setup or the same WiFi as ESP32, then try again.';
  }

  Future<http.Response> _getWithTimeout(Uri uri) async {
    try {
      return await _client.get(uri).timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw Exception(_networkHint(uri.host));
    } catch (_) {
      throw Exception(_networkHint(uri.host));
    }
  }

  Future<http.Response> _postWithTimeout(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    try {
      return await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw Exception(_networkHint(uri.host));
    } catch (_) {
      throw Exception(_networkHint(uri.host));
    }
  }

  Future<void> configureWifi({
    required String ssid,
    required String password,
    String host = '192.168.4.1',
  }) async {
    final uri = Uri.parse('http://$host/configure-wifi');

    final response = await _postWithTimeout(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ssid': ssid, 'password': password}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'ESP32 setup failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<void> startSetupMode({String host = '192.168.4.1'}) async {
    final uri = Uri.parse('http://$host/start-setup-mode');

    final response = await _postWithTimeout(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: '{}',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to trigger setup mode (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<List<WifiNetwork>> scanWifiNetworks({
    String host = '192.168.4.1',
  }) async {
    final uri = Uri.parse('http://$host/scan-wifi');
    final response = await _getWithTimeout(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to scan WiFi (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('Invalid scan response format');
    }

    final networks = body['networks'];
    if (networks is! List) {
      return const [];
    }

    final parsed = networks
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .map(WifiNetwork.fromMap)
        .where((network) => network.ssid.isNotEmpty)
        .toList();

    parsed.sort((a, b) => b.rssi.compareTo(a.rssi));
    return parsed;
  }

  Future<void> connectWifi({
    required String ssid,
    required String password,
    String host = '192.168.4.1',
  }) async {
    final uri = Uri.parse('http://$host/connect-wifi');
    final response = await _postWithTimeout(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ssid': ssid, 'password': password}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to connect WiFi (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<WifiConnectionStatus> getWifiStatus({
    String host = '192.168.4.1',
  }) async {
    final uri = Uri.parse('http://$host/wifi-status');
    final response = await _getWithTimeout(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to get WiFi status (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('Invalid WiFi status response format');
    }

    return WifiConnectionStatus.fromMap(body);
  }
}
