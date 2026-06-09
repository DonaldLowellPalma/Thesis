import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

import '../models/sensor_data.dart';
import 'api_config.dart';
import 'auth_api_service.dart';
import 'demo_mode_config.dart';
import 'demo_data_service.dart';

class SensorHistoryPoint {
  final DateTime timestamp;
  final double value;

  const SensorHistoryPoint({required this.timestamp, required this.value});
}

class SensorApiService {
  SensorApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  List<SensorData>? _latestSensorData;
  Map<String, dynamic>? _latestWqiData;
  Map<String, dynamic>? _latestPredictionData;
  static final Map<String, List<SensorHistoryPoint>> _historyBySensor = {};
  static const Duration _historyRetention = Duration(days: 7);

  List<SensorData>? get latestSensorData => _latestSensorData;
  Map<String, dynamic>? get latestWqiData => _latestWqiData;
  Map<String, dynamic>? get latestPredictionData => _latestPredictionData;

  static List<SensorHistoryPoint> getHistory(
    String sensorName, {
    Duration? window,
  }) {
    final key = sensorName.trim().toLowerCase();
    final history = List<SensorHistoryPoint>.from(_historyBySensor[key] ?? []);

    if (window == null) {
      return history;
    }

    final cutoff = DateTime.now().subtract(window);
    return history.where((point) => point.timestamp.isAfter(cutoff)).toList();
  }

  Stream<List<SensorData>> streamSensorData() async* {
    // Check if demo mode is enabled
    if (DemoModeConfig.enableDemoMode) {
      // Emit initial demo data
      final demoSensors = DemoDataService.getDemoSensorData();
      _latestSensorData = demoSensors;
      _latestWqiData = DemoDataService.getDemoWQIData();
      _latestPredictionData = DemoDataService.getDemoPredictionData();
      _recordHistory(demoSensors);
      yield demoSensors;

      // Simulate periodic updates in demo mode
      var frame = 0;
      while (true) {
        await Future.delayed(
          Duration(
            seconds:
                DemoModeConfig.simulateSlowUpdates
                    ? DemoModeConfig.updateIntervalSeconds
                    : 2,
          ),
        );
        frame++;
        final updatedSensors = DemoDataService.getAnimatedSensorData(
          frame: frame,
        );
        _latestSensorData = updatedSensors;
        _recordHistory(updatedSensors);
        yield updatedSensors;
      }
    }

    // Always emit one immediate snapshot for first paint.
    yield await fetchSensorData();

    var retryAttempt = 0;
    while (true) {
      final token = AuthApiService.instance.token;
      final request = http.Request(
        'GET',
        Uri.parse('${ApiConfig.baseUrl}/api/sensors/stream'),
      );
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'text/event-stream';

      try {
        final response = await _client.send(request);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            'Failed to open sensor stream (${response.statusCode})',
          );
        }

        retryAttempt = 0;
        final dataLines = <String>[];

        await for (final line in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          if (line.isEmpty) {
            if (dataLines.isNotEmpty) {
              final payloadText = dataLines.join('\n');
              dataLines.clear();

              final decoded = jsonDecode(payloadText);
              if (decoded is List) {
                final sensors =
                    decoded
                        .whereType<Map<String, dynamic>>()
                        .map(SensorData.fromMap)
                        .toList();
                _latestSensorData = sensors;
                _recordHistory(sensors);
                yield sensors;
              } else if (decoded is Map<String, dynamic>) {
                final sensorsJson = decoded['sensors'];
                if (sensorsJson is List) {
                  final sensors =
                      sensorsJson
                          .whereType<Map<String, dynamic>>()
                          .map(SensorData.fromMap)
                          .toList();

                  final wqi = decoded['wqi'];
                  _latestWqiData =
                      wqi is Map ? Map<String, dynamic>.from(wqi) : null;

                  final prediction = decoded['prediction'];
                  _latestPredictionData =
                      prediction is Map
                          ? Map<String, dynamic>.from(prediction)
                          : null;

                  _latestSensorData = sensors;
                  _recordHistory(sensors);
                  yield sensors;
                }
              }
            }
            continue;
          }

          if (line.startsWith('data:')) {
            dataLines.add(line.substring(5).trimLeft());
          }
        }
      } on HandshakeException {
        // Stream unavailable, rethrow error
        rethrow;
      } catch (_) {
        // Stream disconnected, rethrow error
        rethrow;
      }

      retryAttempt += 1;
      final backoffSeconds = min(20, max(2, retryAttempt * 2));
      await Future.delayed(Duration(seconds: backoffSeconds));
    }
  }

  Future<List<SensorData>> fetchSensorData() async {
    // Check if demo mode is enabled
    if (DemoModeConfig.enableDemoMode) {
      final demoSensors = DemoDataService.getDemoSensorData();
      _latestWqiData = DemoDataService.getDemoWQIData();
      _latestPredictionData = DemoDataService.getDemoPredictionData();
      _recordHistory(demoSensors);
      return demoSensors;
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/sensors');
    final token = AuthApiService.instance.token;
    late final http.Response response;

    try {
      response = await _client.get(
        uri,
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      );
    } on HandshakeException {
      throw Exception(
        'TLS handshake failed when contacting ${ApiConfig.baseUrl}. Check that the API URL uses a valid HTTPS certificate, or use an HTTP URL that the device is allowed to reach.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch sensor data (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid sensor payload format');
    }

    final sensors =
        decoded
            .whereType<Map<String, dynamic>>()
            .map(SensorData.fromMap)
            .toList();

    // Cache the successfully fetched data
    _latestSensorData = sensors;
    _recordHistory(sensors);
    return sensors;
  }

  /// Call backend /api/water-quality/assess using the latest sensor snapshot.
  /// The richer assessment route expects the full water sample, not a single reading.
  Future<Map<String, dynamic>> predictForSensor(SensorData sensor) async {
    final sensors = await fetchSensorData();
    return predictForSensors(sensors, fallbackSensor: sensor);
  }

  Future<Map<String, dynamic>> predictForSensors(
    List<SensorData> sensors, {
    SensorData? fallbackSensor,
  }) async {
    // Return demo prediction data in demo mode
    if (DemoModeConfig.enableDemoMode) {
      return DemoDataService.getDemoPredictionData();
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/water-quality/assess');
    final token = AuthApiService.instance.token;
    final payload = _buildAssessmentPayloadFromSensors(
      sensors,
      fallbackSensor: fallbackSensor,
    );

    late final http.Response response;

    try {
      response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
    } on HandshakeException {
      throw Exception(
        'TLS handshake failed when contacting ${ApiConfig.baseUrl}. Check that the API URL uses a valid HTTPS certificate, or use an HTTP URL that the device is allowed to reach.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Prediction failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final normalized = _normalizeAssessmentResponse(decoded);
    // Cache the successfully fetched prediction
    _latestPredictionData = normalized;
    return normalized;
  }

  Map<String, dynamic> _buildAssessmentPayloadFromSensors(
    List<SensorData> sensors, {
    SensorData? fallbackSensor,
  }) {
    final fallback = fallbackSensor;

    double ph = fallback?.value ?? 7.0;
    double turbidity = fallback?.value ?? 1.0;
    double tds = fallback?.value ?? 500.0;
    double temperature = fallback?.value ?? 25.0;

    for (final sensor in sensors) {
      final name = sensor.name.toLowerCase();
      if (name.contains('ph')) {
        ph = sensor.value;
        continue;
      }
      if (name.contains('turb') ||
          name.contains('ntu') ||
          name.contains('clar')) {
        turbidity = sensor.value;
        continue;
      }
      if (name.contains('tds') ||
          name.contains('salt') ||
          name.contains('salin')) {
        tds = sensor.value;
        continue;
      }
      if (name.contains('temp')) {
        temperature = sensor.value;
      }
    }

    return {
      'ph': ph,
      'turbidity': turbidity,
      'tds': tds,
      'temperature': temperature,
    };
  }

  Map<String, dynamic> _normalizeAssessmentResponse(Map<String, dynamic> body) {
    final category = body['category']?.toString().trim().toUpperCase();
    final score = body['score'];
    final description = body['description']?.toString().trim();
    final recommendation =
        (body['recommendations'] is List)
            ? (body['recommendations'] as List).whereType<String>().join('\n')
            : null;

    String classification = 'unknown';
    if (category == 'EXCELLENT' || category == 'DRINKABLE_WITH_TREATMENT') {
      classification = 'safe';
    } else if (category == 'SAFE_FOR_WASHING') {
      classification = 'warning';
    } else if (category == 'NOT_RECOMMENDED') {
      classification = 'unsafe';
    }

    return {
      ...body,
      'classification': classification,
      'score': score,
      'risk': score,
      'explanation': description,
      'recommendation':
          recommendation ?? description ?? 'No recommendation available.',
      'category': category ?? body['category'],
    };
  }

  static void _recordHistory(List<SensorData> sensors) {
    final now = DateTime.now();
    final retentionCutoff = now.subtract(_historyRetention);

    for (final sensor in sensors) {
      final key = sensor.name.trim().toLowerCase();
      final points = _historyBySensor.putIfAbsent(key, () => []);

      var pointTime = sensor.lastUpdated;
      if (pointTime.isBefore(DateTime(2000))) {
        pointTime = now;
      }

      if (points.isNotEmpty) {
        final last = points.last;
        if (last.timestamp == pointTime && last.value == sensor.value) {
          continue;
        }
      }

      points.add(SensorHistoryPoint(timestamp: pointTime, value: sensor.value));
      points.removeWhere((point) => point.timestamp.isBefore(retentionCutoff));
    }
  }

  /// Fetch NSF-WQI data from backend
  Future<Map<String, dynamic>> fetchQualityIndex() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/sensors/quality-index');
    final token = AuthApiService.instance.token;

    late final http.Response response;

    try {
      response = await _client.get(
        uri,
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      );
    } on HandshakeException {
      throw Exception(
        'TLS handshake failed when contacting ${ApiConfig.baseUrl}. Check that the API URL uses a valid HTTPS certificate, or use an HTTP URL that the device is allowed to reach.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch quality index (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  /// Fetch historical readings from backend for a sensor and date range.
  Future<List<Map<String, dynamic>>> fetchReadings({
    String? sensorId,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final fromIso = from?.toUtc().toIso8601String();
    final toIso = to?.toUtc().toIso8601String();
    final query = {
      if (sensorId != null) 'sensorId': sensorId,
      if (fromIso != null) 'from': fromIso,
      if (toIso != null) 'to': toIso,
      if (limit != null) 'limit': limit.toString(),
    };

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/sensors/readings',
    ).replace(queryParameters: query);
    final token = AuthApiService.instance.token;

    final response = await _client.get(
      uri,
      headers: token != null ? {'Authorization': 'Bearer $token'} : null,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch readings (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['readings'] is List) {
      return List<Map<String, dynamic>>.from(decoded['readings']);
    }

    if (decoded is List) {
      return List<Map<String, dynamic>>.from(decoded);
    }

    return [];
  }

  /// Fetch CSV for a query range and return CSV text.
  Future<String> fetchReadingsCsv({
    String? sensorId,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final fromIso = from?.toUtc().toIso8601String();
    final toIso = to?.toUtc().toIso8601String();
    final query = {
      if (sensorId != null) 'sensorId': sensorId,
      if (fromIso != null) 'from': fromIso,
      if (toIso != null) 'to': toIso,
      if (limit != null) 'limit': limit.toString(),
      'format': 'csv',
    };

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/sensors/readings',
    ).replace(queryParameters: query);
    final token = AuthApiService.instance.token;

    final response = await _client.get(
      uri,
      headers: token != null ? {'Authorization': 'Bearer $token'} : null,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch CSV (${response.statusCode})');
    }

    return response.body;
  }

  void dispose() {
    _client.close();
  }
}
