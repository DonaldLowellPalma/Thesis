import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models/sensor_data.dart';
import 'services/sensor_firestore_service.dart';
import 'widgets/sensor_icon.dart';
import 'history_page.dart';

class SensorDetailPage extends StatefulWidget {
  final SensorData sensor;

  const SensorDetailPage({super.key, required this.sensor});

  @override
  State<SensorDetailPage> createState() => _SensorDetailPageState();
}

class _SensorDetailPageState extends State<SensorDetailPage> {
  late SensorData sensor;
  final SensorApiService _sensorApi = SensorApiService();

  List<SensorHistoryPoint> _trendPoints = const [];
  Duration _selectedWindow = const Duration(hours: 24);

  Map<String, dynamic>? _prediction;
  bool _loadingPrediction = false;

  Map<String, dynamic>? _wqiData;
  bool _loadingWQI = false;

  @override
  void initState() {
    super.initState();
    sensor = widget.sensor;
    _reloadTrendPoints();
    _loadPrediction();
    _loadWQI();
  }

  Future<void> _loadWQI() async {
    setState(() => _loadingWQI = true);
    try {
      final result = await _sensorApi.fetchQualityIndex();
      if (!mounted) return;
      setState(() => _wqiData = result);
    } catch (_) {
      // Keep UI responsive even when WQI fetch fails.
    } finally {
      if (mounted) {
        setState(() => _loadingWQI = false);
      }
    }
  }

  Future<void> _loadPrediction() async {
    setState(() => _loadingPrediction = true);
    try {
      final result = await _sensorApi.predictForSensor(sensor);
      if (!mounted) return;
      setState(() => _prediction = result);
    } catch (_) {
      // Keep UI responsive even when predictor fails.
    } finally {
      if (mounted) {
        setState(() => _loadingPrediction = false);
      }
    }
  }

  void _reloadTrendPoints() {
    final history = SensorApiService.getHistory(
      sensor.name,
      window: _selectedWindow,
    );

    if (history.isEmpty) {
      _trendPoints = [
        SensorHistoryPoint(timestamp: sensor.lastUpdated, value: sensor.value),
      ];
      return;
    }

    _trendPoints = history;
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'offline':
        return const Color(0xFF888888);
      case 'danger':
        return const Color(0xFFFF6B6B);
      case 'warning':
        return const Color(0xFFFFD93D);
      default:
        return const Color(0xFF6BCB77);
    }
  }

  String getSensorDescription() {
    switch (sensor.name) {
      case 'pH':
      case 'pH Level':
        return 'Measures acidity/alkalinity of water (0-14 scale)';
      case 'Turbidity':
      case 'Water Clarity':
        return 'Measures water clarity/cloudiness (NTU)';
      case 'TDS':
      case 'Saltiness':
        return 'Total dissolved solids in water';
      case 'Temperature':
      case 'Water Temperature':
        return 'Water temperature in degrees Celsius';
      default:
        return 'Sensor measurement';
    }
  }

  String getFriendlyStatus() {
    if (sensor.isOffline()) return 'Offline - Waiting for fresh data';
    return sensor.getStatusDescription();
  }

  String getInterpretation() {
    if (sensor.isOffline()) {
      return 'This sensor has not reported recent readings. Check device power, connectivity, or backend.';
    }

    final desc = sensor.getStatusDescription();
    final status = sensor.getStatus();

    // Provide concise interpretation based on sensor type and descriptive label.
    final nameLower = sensor.name.toLowerCase();
    if (nameLower.contains('ph')) {
      if (status == 'danger') return 'pH is $desc — treat before use.';
      if (status == 'warning') {
        return 'pH is $desc — monitor and adjust if needed.';
      }
      return 'pH is $desc — acceptable for typical use.';
    }

    if (nameLower.contains('turb') || nameLower.contains('clar')) {
      if (status == 'danger') {
        return 'Water is $desc — filtration or settling recommended.';
      }
      if (status == 'warning') return 'Water is $desc — consider filtration.';
      return 'Water is $desc.';
    }

    if (nameLower.contains('tds') || nameLower.contains('salt')) {
      if (status == 'danger') return 'TDS is $desc — purification required.';
      if (status == 'warning') return 'TDS is $desc — consider treatment.';
      return 'TDS is $desc — within acceptable range.';
    }

    if (nameLower.contains('temp')) {
      if (status == 'danger') {
        return 'Temperature is $desc — check source immediately.';
      }
      if (status == 'warning') return 'Temperature is $desc — monitor changes.';
      return 'Temperature is $desc.';
    }

    // Generic fallback
    if (status == 'danger') return '$desc — action recommended.';
    if (status == 'warning') return '$desc — monitor closely.';
    return '$desc — within expected range.';
  }

  String getUpdatedLabel() {
    final seconds = sensor.ageInSeconds();
    if (seconds < 60) return 'Updated ${seconds}s ago';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return 'Updated ${minutes}m ago';
    final hours = minutes ~/ 60;
    return 'Updated ${hours}h ago';
  }

  String getPredictionClassification() {
    final value = _prediction?['classification']?.toString().trim();
    if (value == null || value.isEmpty) {
      return 'unknown';
    }
    return value.toLowerCase();
  }

  double? getPredictionScore() {
    final raw = _prediction?['risk'] ?? _prediction?['score'];
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw);
    }
    return null;
  }

  String getPredictionExplanation() {
    final value = _prediction?['explanation']?.toString().trim();
    if (value == null || value.isEmpty) {
      return 'The backend model returned a classification for the current readings.';
    }
    return value;
  }

  String getPredictionRecommendation() {
    final value = _prediction?['recommendation']?.toString().trim();
    if (value == null || value.isEmpty) {
      return 'No recommendation available.';
    }
    return value;
  }

  Color getPredictionColor() {
    switch (getPredictionClassification()) {
      case 'safe':
        return const Color(0xFF6BCB77);
      case 'warning':
        return const Color(0xFFFFD93D);
      case 'unsafe':
      case 'danger':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFF789CE6);
    }
  }

  double getProgressValue() {
    final range = sensor.maxSafe - sensor.minSafe;
    if (range <= 0) return 0.5;
    final progress = (sensor.value - sensor.minSafe) / range;
    return progress.clamp(0.0, 1.0);
  }

  double _avgValue(List<SensorHistoryPoint> points) {
    if (points.isEmpty) return sensor.value;
    return points.fold<double>(0.0, (sum, point) => sum + point.value) /
        points.length;
  }

  double _minValue(List<SensorHistoryPoint> points) {
    if (points.isEmpty) return sensor.value;
    return points.map((point) => point.value).reduce(math.min);
  }

  double _maxValue(List<SensorHistoryPoint> points) {
    if (points.isEmpty) return sensor.value;
    return points.map((point) => point.value).reduce(math.max);
  }

  String getTrendDescription(List<SensorHistoryPoint> points) {
    if (points.length < 3) return 'Not enough data to determine trend.';

    final third = (points.length / 3).ceil();
    final firstSlice = points.sublist(0, math.min(third, points.length));
    final lastSlice = points.sublist(math.max(0, points.length - third));

    double avg(List<SensorHistoryPoint> slice) =>
        slice.fold<double>(0, (s, p) => s + p.value) / slice.length;

    final firstAvg = avg(firstSlice);
    final lastAvg = avg(lastSlice);
    final diff = lastAvg - firstAvg;
    final pct = firstAvg.abs() < 0.0001 ? diff * 100 : (diff / firstAvg) * 100;

    final mean = (firstAvg + lastAvg) / 2;
    double variance(List<SensorHistoryPoint> slice) {
      final m = slice.fold<double>(0, (s, p) => s + p.value) / slice.length;
      return slice.fold<double>(
            0,
            (s, p) => s + (p.value - m) * (p.value - m),
          ) /
          slice.length;
    }

    final vol = math.sqrt((variance(firstSlice) + variance(lastSlice)) / 2);

    const pctSmall = 3.0;
    const pctMedium = 10.0;

    String direction;
    if (pct.abs() < pctSmall) {
      direction = 'stable';
    } else if (pct.abs() < pctMedium) {
      direction = diff > 0 ? 'increasing' : 'decreasing';
    } else {
      direction = diff > 0 ? 'rapidly increasing' : 'rapidly decreasing';
    }

    if (vol > (mean.abs() * 0.08 + 0.0001) && pct.abs() < pctMedium) {
      return 'Values are fluctuating with no clear trend.';
    }

    switch (sensor.name) {
      case 'Turbidity':
      case 'Water Clarity':
        if (direction == 'stable') return 'Water clarity is stable.';
        if (direction == 'increasing') {
          return 'Water is getting steadily dirtier.';
        }
        if (direction == 'rapidly increasing') {
          return 'Water turbidity is rising rapidly — water is getting much dirtier.';
        }
        if (direction == 'decreasing') {
          return 'Water is getting clearer over time.';
        }
        return 'Water turbidity is falling quickly — clarity improving.';
      case 'pH':
      case 'pH Level':
        if (direction == 'stable') return 'pH levels are stable.';
        return direction == 'increasing'
            ? 'pH is rising (becoming more alkaline).'
            : 'pH is falling (becoming more acidic).';
      case 'TDS':
      case 'Saltiness':
        if (direction == 'stable') return 'Dissolved solids are stable.';
        return direction == 'increasing'
            ? 'Dissolved solids are increasing (salt content rising).'
            : 'Dissolved solids are decreasing.';
      case 'Temperature':
      case 'Water Temperature':
        if (direction == 'stable') return 'Temperature is steady.';
        return direction == 'increasing'
            ? 'Water is warming gradually.'
            : 'Water is cooling gradually.';
      default:
        if (direction == 'stable') return 'Measurements are stable.';
        return 'Values are $direction.';
    }
  }

  Widget _buildWQISensorContribution(
    String label,
    String value,
    String unit,
    int weight,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$value $unit',
                style: const TextStyle(color: Color(0xFF789CE6), fontSize: 10),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            'Weight: $weight%',
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = getStatusColor(
      sensor.isOffline() ? 'offline' : sensor.getStatus(),
    );

    final average = _avgValue(_trendPoints);
    final minimum = _minValue(_trendPoints);
    final maximum = _maxValue(_trendPoints);

    return Scaffold(
      backgroundColor: const Color(0xFF071428),
      appBar: AppBar(
        title: Text(sensor.name),
        backgroundColor: const Color(0xFF0F2A44),
        elevation: 2,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'History',
            onPressed: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  opaque: true,
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      HistoryPage(initialSensor: sensor),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                ),
              );
            },
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            // Header Info
            Text(
              sensor.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              getSensorDescription(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              getUpdatedLabel(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: sensor.isOffline()
                    ? const Color(0xFFFFD93D)
                    : Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),

            // MAIN VALUE CARD (Large and Prominent)
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: const Color(0xFF0F2A44),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    SensorIcon(icon: sensor.icon, size: 60),
                    const SizedBox(height: 20),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: sensor.value.toStringAsFixed(1),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ' ${sensor.unit}',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        getFriendlyStatus(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ML PREDICTION CARD
            if (_prediction != null)
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: getPredictionColor().withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Water Quality Assessment',
                            style: TextStyle(
                              color: getPredictionColor(),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (getPredictionScore() != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: getPredictionColor(),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${(getPredictionScore()! * 100).round()}%',
                                style: const TextStyle(
                                  color: Color(0xFF071428),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        getPredictionClassification().toUpperCase(),
                        style: TextStyle(
                          color: getPredictionColor(),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        getPredictionExplanation(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: getPredictionColor().withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: getPredictionColor().withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: getPredictionColor(),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                getPredictionRecommendation(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 1.4,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_loadingPrediction) ...[
              const SizedBox(height: 18),
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: const Color(0xFF0F2A44),
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: SizedBox(
                    height: 60,
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF789CE6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // NSF-WQI BREAKDOWN CARD
            if (_wqiData != null) ...[
              const SizedBox(height: 18),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: const Color(0xFF0F2A44),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Water Quality Index (NSF-WQI)',
                        style: TextStyle(
                          color: Color(
                            int.parse(
                              (_wqiData!['color'] as String).replaceFirst(
                                '#',
                                '0xFF',
                              ),
                            ),
                          ),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(_wqiData!['wqiScore'] as num).toStringAsFixed(1)}/100',
                            style: TextStyle(
                              color: Color(
                                int.parse(
                                  (_wqiData!['color'] as String).replaceFirst(
                                    '#',
                                    '0xFF',
                                  ),
                                ),
                              ),
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Color(
                                int.parse(
                                  (_wqiData!['color'] as String).replaceFirst(
                                    '#',
                                    '0xFF',
                                  ),
                                ),
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Color(
                                  int.parse(
                                    (_wqiData!['color'] as String).replaceFirst(
                                      '#',
                                      '0xFF',
                                    ),
                                  ),
                                ),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _wqiData!['category'] ?? 'Unknown',
                              style: TextStyle(
                                color: Color(
                                  int.parse(
                                    (_wqiData!['color'] as String).replaceFirst(
                                      '#',
                                      '0xFF',
                                    ),
                                  ),
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Sensor Contribution to Index:',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            _buildWQISensorContribution(
                              'Turbidity',
                              (_wqiData!['sensors']['turbidity'] as num)
                                  .toString(),
                              'NTU',
                              25,
                            ),
                            const SizedBox(height: 8),
                            _buildWQISensorContribution(
                              'pH',
                              (_wqiData!['sensors']['phLevel'] as num)
                                  .toStringAsFixed(1),
                              'pH',
                              25,
                            ),
                            const SizedBox(height: 8),
                            _buildWQISensorContribution(
                              'Temperature',
                              (_wqiData!['sensors']['temperature'] as num)
                                  .toStringAsFixed(1),
                              '°C',
                              15,
                            ),
                            const SizedBox(height: 8),
                            _buildWQISensorContribution(
                              'TDS',
                              (_wqiData!['sensors']['tds'] as num)
                                  .toStringAsFixed(1),
                              'ppm',
                              35,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_loadingWQI) ...[
              const SizedBox(height: 18),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: const Color(0xFF0F2A44),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    height: 100,
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF789CE6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 18),

            // STATUS INTERPRETATION CARD
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: statusColor.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Details',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      getInterpretation(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // SAFE RANGE CARD
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: const Color(0xFF789CE6).withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Safe Range',
                      style: const TextStyle(
                        color: Color(0xFF789CE6),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          sensor.minSafe.toString(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: getProgressValue(),
                              minHeight: 12,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                statusColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          sensor.maxSafe.toString(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Current: ${sensor.value.toStringAsFixed(1)} ${sensor.unit}',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // TRENDS CARD
            _TrendCard(
              points: _trendPoints,
              statusColor: statusColor,
              selectedWindow: _selectedWindow,
              onWindowChanged: (window) {
                setState(() {
                  _selectedWindow = window;
                  _reloadTrendPoints();
                });
              },
              unit: sensor.unit,
              average: average,
              minimum: minimum,
              maximum: maximum,
              trendDescription: getTrendDescription(_trendPoints),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class SensorTrendChart extends StatelessWidget {
  final List<SensorHistoryPoint> points;
  final Color lineColor;
  final double height;

  const SensorTrendChart({
    super.key,
    required this.points,
    this.lineColor = const Color(0xFF6BCB77),
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Collecting trend data...',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _TrendPainter(points: points, lineColor: lineColor),
        size: Size.infinite,
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<SensorHistoryPoint> points;
  final Color lineColor;

  const _TrendPainter({required this.points, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 12.0;
    final chartWidth = size.width - (padding * 2);
    final chartHeight = size.height - (padding * 2);
    if (chartWidth <= 0 || chartHeight <= 0 || points.length < 2) return;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final y = padding + (chartHeight * (i / 3));
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    final minValue = points.map((point) => point.value).reduce(math.min);
    final maxValue = points.map((point) => point.value).reduce(math.max);
    final valueRange = (maxValue - minValue).abs() < 0.0001
        ? 1.0
        : (maxValue - minValue);

    final minTime = points.first.timestamp.millisecondsSinceEpoch.toDouble();
    final maxTime = points.last.timestamp.millisecondsSinceEpoch.toDouble();
    final timeRange = (maxTime - minTime).abs() < 1
        ? (points.length - 1).toDouble()
        : (maxTime - minTime);

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final timestamp = point.timestamp.millisecondsSinceEpoch.toDouble();
      final xFactor = (maxTime - minTime).abs() < 1
          ? (i / math.max(1, points.length - 1))
          : ((timestamp - minTime) / timeRange).clamp(0.0, 1.0);
      final yFactor = ((point.value - minValue) / valueRange).clamp(0.0, 1.0);

      final x = padding + (xFactor * chartWidth);
      final y = (size.height - padding) - (yFactor * chartHeight);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.lineColor != lineColor;
  }
}

class _TrendCard extends StatelessWidget {
  final List<SensorHistoryPoint> points;
  final Color statusColor;
  final Duration selectedWindow;
  final ValueChanged<Duration> onWindowChanged;
  final String unit;
  final double average;
  final double minimum;
  final double maximum;
  final String? trendDescription;

  const _TrendCard({
    required this.points,
    required this.statusColor,
    required this.selectedWindow,
    required this.onWindowChanged,
    required this.unit,
    required this.average,
    required this.minimum,
    required this.maximum,
    this.trendDescription,
  });

  @override
  Widget build(BuildContext context) {
    final windows = <Duration>[
      const Duration(hours: 1),
      const Duration(hours: 24),
      const Duration(days: 7),
    ];

    String labelFor(Duration window) {
      if (window.inHours == 1) return '1H';
      if (window.inHours == 24) return '24H';
      return '7D';
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF0F2A44),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Historical Trend',
              style: TextStyle(
                color: statusColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            if (trendDescription != null) ...[
              const SizedBox(height: 10),
              Text(
                trendDescription!,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Wrap(
                spacing: 6,
                children: windows.map((window) {
                  final selected = window == selectedWindow;
                  return ChoiceChip(
                    label: Text(labelFor(window)),
                    selected: selected,
                    onSelected: (_) => onWindowChanged(window),
                    selectedColor: statusColor.withValues(alpha: 0.8),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: _TrendChart(points: points, lineColor: statusColor),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _StatCell(label: 'Avg', value: average, unit: unit),
                ),
                Expanded(
                  child: _StatCell(label: 'Min', value: minimum, unit: unit),
                ),
                Expanded(
                  child: _StatCell(label: 'Max', value: maximum, unit: unit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final double value;
  final String unit;

  const _StatCell({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Text(
          '${value.toString()} $unit',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<SensorHistoryPoint> points;
  final Color lineColor;

  const _TrendChart({required this.points, required this.lineColor});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Collecting trend data...',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _TrendChartPainter(points: points, lineColor: lineColor),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<SensorHistoryPoint> points;
  final Color lineColor;

  const _TrendChartPainter({required this.points, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 12.0;
    final chartWidth = size.width - (padding * 2);
    final chartHeight = size.height - (padding * 2);
    if (chartWidth <= 0 || chartHeight <= 0 || points.length < 2) return;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final y = padding + (chartHeight * (i / 3));
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    final minValue = points.map((point) => point.value).reduce(math.min);
    final maxValue = points.map((point) => point.value).reduce(math.max);
    final valueRange = (maxValue - minValue).abs() < 0.0001
        ? 1.0
        : (maxValue - minValue);

    final minTime = points.first.timestamp.millisecondsSinceEpoch.toDouble();
    final maxTime = points.last.timestamp.millisecondsSinceEpoch.toDouble();
    final timeRange = (maxTime - minTime).abs() < 1
        ? (points.length - 1).toDouble()
        : (maxTime - minTime);

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final timestamp = point.timestamp.millisecondsSinceEpoch.toDouble();
      final xFactor = (maxTime - minTime).abs() < 1
          ? (i / math.max(1, points.length - 1))
          : ((timestamp - minTime) / timeRange).clamp(0.0, 1.0);
      final yFactor = ((point.value - minValue) / valueRange).clamp(0.0, 1.0);

      final x = padding + (xFactor * chartWidth);
      final y = (size.height - padding) - (yFactor * chartHeight);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = lineColor;
    final lastPoint = points.last;
    final lastYFactor = ((lastPoint.value - minValue) / valueRange).clamp(
      0.0,
      1.0,
    );
    final lastX = size.width - padding;
    final lastY = (size.height - padding) - (lastYFactor * chartHeight);
    canvas.drawCircle(Offset(lastX, lastY), 3.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.lineColor != lineColor;
  }
}
