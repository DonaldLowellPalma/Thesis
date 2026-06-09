class SensorData {
  final String? id;
  final String name;
  final double value;
  final String unit;
  final double minSafe;
  final double maxSafe;
  final String icon;
  final String trend; // 'up', 'down', 'stable'
  final double previousValue;
  final DateTime lastUpdated;

  SensorData({
    this.id,
    required this.name,
    required this.value,
    required this.unit,
    required this.minSafe,
    required this.maxSafe,
    required this.icon,
    this.trend = 'stable',
    this.previousValue = 0,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  static DateTime _parseTimestamp(dynamic value) {
    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed.toLocal();
      }
    }

    if (value is num) {
      final raw = value.toInt();
      // Ignore relative millis-like values (for example MCU uptime millis)
      // and only trust Unix epoch-like timestamps.
      if (raw > 946684800000) {
        return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true).toLocal();
      }
    }

    return DateTime.now();
  }

  factory SensorData.fromMap(Map<String, dynamic> map) {
    double toDouble(dynamic value) {
      if (value is num) {
        return value.toDouble();
      }
      return double.tryParse('$value') ?? 0;
    }

    return SensorData(
      id: map['id']?.toString(),
      name: map['name']?.toString() ?? 'Unknown',
      value: toDouble(map['value']),
      unit: map['unit']?.toString() ?? '',
      minSafe: toDouble(map['minSafe']),
      maxSafe: toDouble(map['maxSafe']),
      icon: map['icon']?.toString() ?? '📊',
      trend: map['trend']?.toString() ?? 'stable',
      previousValue: toDouble(map['previousValue']),
      lastUpdated: _parseTimestamp(map['updatedAt'] ?? map['lastUpdated']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'value': value,
      'unit': unit,
      'minSafe': minSafe,
      'maxSafe': maxSafe,
      'icon': icon,
      'trend': trend,
      'previousValue': previousValue,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  // Determine status based on value
  String getStatus() {
    if (value < minSafe || value > maxSafe) {
      return 'danger';
    } else if ((value > minSafe && value < minSafe + 1) ||
        (value > maxSafe - 1 && value < maxSafe)) {
      return 'warning';
    }
    return 'safe';
  }

  // Human-friendly status description based on sensor type and value.
  // Falls back to generic 'Safe/Warning/Danger' when no sensor-specific rule applies.
  String getStatusDescription() {
    final nameLower = name.toLowerCase();

    try {
      // Temperature (°C)
      if (nameLower.contains('temp') || nameLower.contains('temperature')) {
        // Adjusted thresholds: <18 Cold, 18-24 Mild, 24-29 Warm, >=30 Hot
        if (value < 18.0) return 'Cold';
        if (value < 24.0) return 'Mild';
        if (value < 30.0) return 'Warm';
        return 'Hot';
      }

      // Turbidity (NTU)
      if (nameLower.contains('turb') ||
          nameLower.contains('ntu') ||
          nameLower.contains('clarity') ||
          nameLower.contains('clar')) {
        // Adjusted thresholds: <0.5 Clear, 0.5-4.9 Slightly Turbid, >=5 Murky
        if (value < 0.5) return 'Clear';
        if (value < 5.0) return 'Slightly Turbid';
        return 'Murky';
      }

      // pH
      if (nameLower.contains('ph')) {
        // Adjusted thresholds: <6.8 Acidic, 6.8-8.2 Near-neutral, >8.2 Alkaline
        if (value < 6.8) return 'Acidic';
        if (value <= 8.2) return 'Near-neutral';
        return 'Alkaline';
      }

      // TDS / Salinity (ppm)
      if (nameLower.contains('tds') ||
          nameLower.contains('salt') ||
          nameLower.contains('salin')) {
        // Adjusted thresholds: <500 Low, 500-999 Moderate, >=1000 High
        if (value < 500.0) return 'Low Salinity';
        if (value < 1000.0) return 'Moderate Salinity';
        return 'High Salinity';
      }
    } catch (_) {
      // Fall through to generic mapping
    }

    // Generic fallback based on safety bands
    final status = getStatus();
    if (status == 'safe') return 'Safe';
    if (status == 'warning') return 'Warning';
    return 'Danger';
  }

  // Get color based on status
  String getStatusColor() {
    final status = getStatus();
    if (status == 'danger') return 'FF6B6B';
    if (status == 'warning') return 'FFD93D';
    return '6BCB77';
  }

  // Get trend emoji
  String getTrendEmoji() {
    switch (trend) {
      case 'up':
        return '📈';
      case 'down':
        return '📉';
      default:
        return '→';
    }
  }

  // Calculate quality score (0-100) for this sensor
  int getQualityScore() {
    final status = getStatus();
    if (status == 'safe') return 100;
    if (status == 'warning') return 60;
    return 20;
  }

  // Check if sensor is stale/offline based on latest backend timestamp.
  bool isOffline({int timeoutSeconds = 45}) {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated).inSeconds;
    return difference > timeoutSeconds;
  }

  int ageInSeconds() {
    return DateTime.now().difference(lastUpdated).inSeconds;
  }

  // Create a copy of this sensor with updated values and refresh timestamp
  SensorData copyWith({
    String? name,
    double? value,
    String? unit,
    double? minSafe,
    double? maxSafe,
    String? icon,
    String? trend,
    double? previousValue,
    DateTime? lastUpdated,
  }) {
    return SensorData(
      name: name ?? this.name,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      minSafe: minSafe ?? this.minSafe,
      maxSafe: maxSafe ?? this.maxSafe,
      icon: icon ?? this.icon,
      trend: trend ?? this.trend,
      previousValue: previousValue ?? this.previousValue,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SensorData &&
        other.id == id &&
        other.name == name &&
        other.unit == unit;
  }

  @override
  int get hashCode => Object.hash(id, name, unit);
}
