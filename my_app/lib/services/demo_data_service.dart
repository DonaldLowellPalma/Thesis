import 'dart:math';
import '../models/sensor_data.dart';

/// Demo Data Service
///
/// Provides predetermined, realistic water quality sensor data for tutorials and demos.
/// **Only 4 sensors** are used as requested.

class DemoDataService {
  static final Random _random = Random(42); // Fixed seed for reproducibility

  /// Returns exactly 4 sensors for the system
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
    ];
  }

  /// Returns demo WQI (Water Quality Index) data
  static Map<String, dynamic> getDemoWQIData() {
    return {
      'wqiScore': 85,
      'rating': 'Good',
      'color': '#4CAF50',
      'timestamp': DateTime.now().toIso8601String(),
      'factors': {
        'clarity': 88,
        'temperature': 82,
        'ph': 90,
        'dissolved_oxygen': 84,
      },
    };
  }

  /// Returns demo water quality prediction data
  static Map<String, dynamic> getDemoPredictionData() {
    return {
      'category': 'EXCELLENT',
      'score': 87,
      'description': 'Good water quality. Safe for most uses.',
      'recommendation': 'Water quality is good. Continue regular monitoring.',
      'prediction': 'Stable',
    };
  }

  /// Simulated animated updates (only 4 sensors)
  static List<SensorData> getAnimatedSensorData({int frame = 0}) {
    final baseSensors = getDemoSensorData();
    final variation = (sin(frame * 0.1) * 0.5) + 0.5;

    return baseSensors.map((sensor) {
      double newValue = sensor.value;

      switch (sensor.name.toLowerCase()) {
        case 'temperature':
          newValue = sensor.value + (variation * 0.4);
          break;
        case 'dissolved oxygen':
          newValue = sensor.value + (variation * 0.25);
          break;
        case 'ph level':
          newValue = sensor.value + ((variation - 0.5) * 0.12);
          break;
        case 'water clarity':
          newValue = sensor.value + ((variation - 0.5) * 0.3);
          break;
      }

      return SensorData(
        id: sensor.id,
        name: sensor.name,
        value: newValue.clamp(sensor.minSafe ?? 0, sensor.maxSafe ?? 100),
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

  /// Emergency scenario (only 4 sensors)
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
    ];
  }

  /// Good scenario (only 4 sensors)
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
        value: 22.5,
        unit: '°C',
        minSafe: 10.0,
        maxSafe: 30.0,
        icon: '🌡️',
        trend: 'stable',
        previousValue: 22.4,
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
        value: 8.7,
        unit: 'mg/L',
        minSafe: 6.0,
        maxSafe: 10.0,
        icon: '💨',
        trend: 'stable',
        previousValue: 8.6,
        lastUpdated: now,
      ),
    ];
  }

  // Optional: Keep historical data if needed
  static List<Map<String, dynamic>> getDemoHistoricalData(String sensorName) {
    // ... you can keep or simplify this if not heavily used
    final now = DateTime.now();
    return List.generate(48, (i) {
      return {
        'timestamp': now.subtract(Duration(minutes: 30 * i)).toIso8601String(),
        'value': _getHistoricalValue(sensorName, i),
      };
    });
  }

  static double _getHistoricalValue(String sensorName, int index) {
    final normalized = index / 48.0;
    switch (sensorName.toLowerCase()) {
      case 'water clarity':
        return 2.5 + (normalized * 0.6) + (_random.nextDouble() * 0.5);
      case 'temperature':
        return 23.0 + (sin(normalized * 2 * pi) * 2.5);
      case 'ph level':
        return 7.1 + (_random.nextDouble() * 0.3 - 0.15);
      case 'dissolved oxygen':
        return 7.0 + (normalized * 0.8);
      default:
        return 5.0;
    }
  }
}