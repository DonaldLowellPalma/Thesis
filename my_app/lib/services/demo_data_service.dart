import 'dart:math';
import '../models/sensor_data.dart';

/// Demo Data Service
///
/// Provides predetermined, realistic water quality sensor data for tutorials and demos
/// without requiring actual ESP32 sensors or backend servers.

class DemoDataService {
  static final Random _random = Random(42); // Fixed seed for reproducibility

  /// Returns a predetermined list of sensor data for demo purposes
  static List<SensorData> getDemoSensorData() {
    final now = DateTime.now();
    return [
      SensorData(
        id: 'sensor_001',
        name: 'Water Clarity',
        value: 2.8,
        unit: 'NTU',
        minSafe: 0.0,
        maxSafe: 5.0,
        icon: '💧',
        trend: 'stable',
        previousValue: 2.9,
        lastUpdated: now,
      ),
      SensorData(
        id: 'sensor_002',
        name: 'Temperature',
        value: 24.3,
        unit: '°C',
        minSafe: 10.0,
        maxSafe: 30.0,
        icon: '🌡️',
        trend: 'up',
        previousValue: 24.1,
        lastUpdated: now,
      ),
      SensorData(
        id: 'sensor_003',
        name: 'pH Level',
        value: 7.1,
        unit: 'pH',
        minSafe: 6.5,
        maxSafe: 8.5,
        icon: '⚗️',
        trend: 'stable',
        previousValue: 7.1,
        lastUpdated: now,
      ),
      SensorData(
        id: 'sensor_004',
        name: 'Dissolved Oxygen',
        value: 7.2,
        unit: 'mg/L',
        minSafe: 6.0,
        maxSafe: 10.0,
        icon: '💨',
        trend: 'stable',
        previousValue: 7.1,
        lastUpdated: now,
      ),
      SensorData(
        id: 'sensor_005',
        name: 'Conductivity',
        value: 485.0,
        unit: 'μS/cm',
        minSafe: 200.0,
        maxSafe: 1000.0,
        icon: '⚡',
        trend: 'stable',
        previousValue: 480.0,
        lastUpdated: now,
      ),
      SensorData(
        id: 'sensor_006',
        name: 'Salinity',
        value: 3.2,
        unit: 'ppt',
        minSafe: 0.0,
        maxSafe: 10.0,
        icon: '🧂',
        trend: 'stable',
        previousValue: 3.1,
        lastUpdated: now,
      ),
      SensorData(
        id: 'sensor_007',
        name: 'Turbidity',
        value: 2.1,
        unit: 'FNU',
        minSafe: 0.0,
        maxSafe: 5.0,
        icon: '🌊',
        trend: 'down',
        previousValue: 2.4,
        lastUpdated: now,
      ),
    ];
  }

  /// Returns demo WQI (Water Quality Index) data
  static Map<String, dynamic> getDemoWQIData() {
    return {
      'wqiScore': 78,
      'rating': 'Good',
      'color': '#4CAF50',
      'timestamp': DateTime.now().toIso8601String(),
      'factors': {
        'clarity': 85,
        'temperature': 80,
        'ph': 88,
        'dissolved_oxygen': 75,
        'conductivity': 72,
      },
    };
  }

  /// Returns demo water quality prediction data
  static Map<String, dynamic> getDemoPredictionData() {
    return {
      'prediction': 'Stable',
      'confidence': 0.92,
      'predicted_score': 76,
      'trend': 'Slight Improvement',
      'recommendation': 'Water quality is good. Continue regular monitoring.',
      'next_update': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
    };
  }

  /// Returns demo historical data for a specific sensor
  static List<Map<String, dynamic>> getDemoHistoricalData(String sensorName) {
    final now = DateTime.now();
    final historicalPoints = <Map<String, dynamic>>[];

    // Generate 48 hours of historical data points (every 30 minutes)
    for (int i = 0; i < 96; i++) {
      final timestamp = now.subtract(Duration(minutes: 30 * (96 - i)));
      final value = _getHistoricalValue(sensorName, i);

      historicalPoints.add({
        'timestamp': timestamp.toIso8601String(),
        'value': value,
      });
    }

    return historicalPoints;
  }

  /// Helper function to generate realistic historical values for each sensor
  static double _getHistoricalValue(String sensorName, int dataPointIndex) {
    // Normalize index to 0-1 range
    final normalized = dataPointIndex / 96.0;

    switch (sensorName.toLowerCase()) {
      case 'water clarity':
      case 'turbidity':
        // Slight downward trend with small variations
        return 3.5 - (normalized * 0.8) + (_random.nextDouble() * 0.5);

      case 'temperature':
        // Cyclic pattern (daily temperature variation)
        return 22.0 +
            (sin(normalized * 2 * pi) * 3.0) +
            (_random.nextDouble() * 0.5);

      case 'ph level':
        // Stable around 7.1 with small variations
        return 7.1 + (_random.nextDouble() * 0.3 - 0.15);

      case 'dissolved oxygen':
        // Slight upward trend
        return 6.8 + (normalized * 0.6) + (_random.nextDouble() * 0.3);

      case 'conductivity':
        // Stable around 480-490
        return 480.0 + (_random.nextDouble() * 30.0 - 15.0);

      case 'salinity':
        // Stable around 3.0-3.3
        return 3.0 + (_random.nextDouble() * 0.4);

      default:
        return 0.0;
    }
  }

  /// Returns demo notifications
  static List<Map<String, dynamic>> getDemoNotifications() {
    final now = DateTime.now();
    return [
      {
        'id': 'notif_001',
        'sensorName': 'Water Clarity',
        'sensorIcon': '💧',
        'message': 'Water clarity improved to 2.8 NTU - Excellent condition!',
        'severity': 'info',
        'timestamp': now.subtract(const Duration(hours: 2)).toIso8601String(),
        'read': true,
      },
      {
        'id': 'notif_002',
        'sensorName': 'Temperature',
        'sensorIcon': '🌡️',
        'message': 'Temperature rising: 24.3°C (trending up)',
        'severity': 'warning',
        'timestamp': now
            .subtract(const Duration(minutes: 45))
            .toIso8601String(),
        'read': false,
      },
      {
        'id': 'notif_003',
        'sensorName': 'Dissolved Oxygen',
        'sensorIcon': '💨',
        'message': 'Dissolved oxygen at good levels: 7.2 mg/L',
        'severity': 'info',
        'timestamp': now
            .subtract(const Duration(minutes: 30))
            .toIso8601String(),
        'read': false,
      },
    ];
  }

  /// Returns simulated sensor updates with slight variations for animation purposes
  static List<SensorData> getAnimatedSensorData({int frame = 0}) {
    final baseSensors = getDemoSensorData();
    final variation =
        (sin(frame * 0.1) * 0.5) + 0.5; // Oscillates between 0 and 1

    return baseSensors.map((sensor) {
      double newValue = sensor.value;

      // Add slight variations to make it look like real updates
      switch (sensor.name.toLowerCase()) {
        case 'temperature':
          newValue = sensor.value + (variation * 0.3);
          break;
        case 'dissolved oxygen':
          newValue = sensor.value + (variation * 0.2);
          break;
        case 'pH level':
          newValue = sensor.value + ((variation - 0.5) * 0.1);
          break;
      }

      return SensorData(
        id: sensor.id,
        name: sensor.name,
        value: newValue,
        unit: sensor.unit,
        minSafe: sensor.minSafe,
        maxSafe: sensor.maxSafe,
        icon: sensor.icon,
        trend: sensor.trend,
        previousValue: sensor.value,
        lastUpdated: DateTime.now(),
      );
    }).toList();
  }

  /// Returns emergency scenario demo data (all values out of range)
  static List<SensorData> getEmergencyScenarioData() {
    final now = DateTime.now();
    return [
      SensorData(
        id: 'sensor_001',
        name: 'Water Clarity',
        value: 8.5,
        unit: 'NTU',
        minSafe: 0.0,
        maxSafe: 5.0,
        icon: '💧',
        trend: 'up',
        previousValue: 6.2,
        lastUpdated: now,
      ),
      SensorData(
        id: 'sensor_002',
        name: 'Temperature',
        value: 35.2,
        unit: '°C',
        minSafe: 10.0,
        maxSafe: 30.0,
        icon: '🌡️',
        trend: 'up',
        previousValue: 32.1,
        lastUpdated: now,
      ),
      SensorData(
        id: 'sensor_004',
        name: 'Dissolved Oxygen',
        value: 2.1,
        unit: 'mg/L',
        minSafe: 6.0,
        maxSafe: 10.0,
        icon: '💨',
        trend: 'down',
        previousValue: 3.5,
        lastUpdated: now,
      ),
      SensorData(
        id: 'sensor_003',
        name: 'pH Level',
        value: 5.8,
        unit: 'pH',
        minSafe: 6.5,
        maxSafe: 8.5,
        icon: '⚗️',
        trend: 'down',
        previousValue: 6.1,
        lastUpdated: now,
      ),
    ];
  }

  /// Returns good scenario demo data (all values optimal)
  static List<SensorData> getGoodScenarioData() {
    final now = DateTime.now();
    return [
      SensorData(
        id: 'sensor_001',
        name: 'Water Clarity',
        value: 1.2,
        unit: 'NTU',
        minSafe: 0.0,
        maxSafe: 5.0,
        icon: '💧',
        trend: 'stable',
        previousValue: 1.1,
        lastUpdated: now,
      ),
      SensorData(
        id: 'sensor_002',
        name: 'Temperature',
        value: 20.5,
        unit: '°C',
        minSafe: 10.0,
        maxSafe: 30.0,
        icon: '🌡️',
        trend: 'stable',
        previousValue: 20.4,
        lastUpdated: now,
      ),
      SensorData(
        id: 'sensor_003',
        name: 'pH Level',
        value: 7.4,
        unit: 'pH',
        minSafe: 6.5,
        maxSafe: 8.5,
        icon: '⚗️',
        trend: 'stable',
        previousValue: 7.4,
        lastUpdated: now,
      ),
      SensorData(
        id: 'sensor_004',
        name: 'Dissolved Oxygen',
        value: 8.9,
        unit: 'mg/L',
        minSafe: 6.0,
        maxSafe: 10.0,
        icon: '💨',
        trend: 'stable',
        previousValue: 8.8,
        lastUpdated: now,
      ),
      SensorData(
        id: 'sensor_005',
        name: 'Conductivity',
        value: 520.0,
        unit: 'μS/cm',
        minSafe: 200.0,
        maxSafe: 1000.0,
        icon: '⚡',
        trend: 'stable',
        previousValue: 518.0,
        lastUpdated: now,
      ),
    ];
  }
}
