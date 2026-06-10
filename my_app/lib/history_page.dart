import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/sensor_firestore_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

Map<String, List<Map<String, dynamic>>> groupReadings(
  List<Map<String, dynamic>> items,
) {
  final grouped = <String, List<Map<String, dynamic>>>{};

  for (var reading in items) {
    final sensorId = (reading['sensorId'] ?? '').toString();

    String name;

    switch (sensorId) {
      case 'ph-level':
        name = 'pH Level';
        break;
      case 'tds':
        name = 'TDS';
        break;
      case 'temperature':
        name = 'Temperature';
        break;
      case 'turbidity':
        name = 'Turbidity';
        break;
      default:
        name = 'Unknown';
    }

    grouped.putIfAbsent(name, () => []).add(reading);
  }

  return grouped;
}

class _HistoryPageState extends State<HistoryPage> {
  final SensorApiService _api = SensorApiService();

  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  late DateTime _to;
  bool _loading = false;
  bool _loadingReadings = false;
  String? _errorMessage;

  Map<String, List<Map<String, dynamic>>> _readingsBySensor = {};

  final List<String> _sensorNames = [
    'pH Level',
    'TDS',
    'Temperature',
    'Turbidity',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _loadReadings();
  }

  Future<void> _loadReadings() async {
    setState(() {
      _loadingReadings = true;
      _errorMessage = null;
    });

    try {
      final items = await _api.fetchReadings(
        from: _from,
        to: _to,
        limit: 200, // 🔥 IMPORTANT: DO NOT USE 20000
      );

      debugPrint('📡 Fetched ${items.length} raw readings');

      final grouped = await compute(groupReadings, items);

      setState(() {
        _readingsBySensor = grouped;
      });

      debugPrint('📊 Grouped sensors: ${grouped.keys.toList()}');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingReadings = false);
      }
    }
  }

  Future<void> _downloadCsv() async {
    setState(() => _loading = true);
    try {
      final csv = await _api.fetchReadingsCsv(
        from: _from,
        to: _to,
        limit: 200,
      );

      final filename = 'waterguard_readings_${_from.toIso8601String().split('T').first}_to_${_to.toIso8601String().split('T').first}.csv';
      final file = File('${Directory.systemTemp.path}/$filename');
      await file.writeAsString(csv);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ CSV saved to: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download CSV: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildSensorChart(String sensorName) {
    final readings = _readingsBySensor[sensorName] ?? [];

    if (readings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            'No readings found for this sensor in the selected range',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final spots = <FlSpot>[];

    // 🔥 IMPORTANT FIX: downsample to avoid lag
    final step = math.max(1, readings.length ~/ 100);

    for (int i = 0; i < readings.length; i += step) {
      final value = (readings[i]['value'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), value));
    }

    final minY = spots.map((s) => s.y).reduce(math.min);
    final maxY = spots.map((s) => s.y).reduce(math.max);

    // 🔥 safe padding (prevents crash)
    final padding = math.max(0.5, (maxY - minY) * 0.15);

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            horizontalInterval: (maxY - minY) / 5,
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < readings.length && index % 20 == 0) {
                    final ts =
                        readings[index]['timestamp']?.toString() ?? '';
                    return Text(
                      ts.split(' ').last.substring(0, 5),
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white60,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xFF1E3A5F)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF789CE6),
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF789CE6).withOpacity(0.18),
              ),
            ),
          ],
          minY: minY - padding,
          maxY: maxY + padding,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071428),
      appBar: AppBar(
        title: const Text('Sensor History'),
        backgroundColor: const Color(0xFF0F2A44),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range
            Card(
              color: const Color(0xFF0F2A44),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Date Range', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _from,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) setState(() => _from = picked);
                            },
                            child: Text(_from.toLocal().toString().split(' ')[0]),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _to,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => _to = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
                              }
                            },
                            child: Text(_to.toLocal().toString().split(' ')[0]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loadingReadings ? null : _loadReadings,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _downloadCsv,
                    icon: const Icon(Icons.download),
                    label: const Text('Download CSV'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (_errorMessage != null)
              Text('Error: $_errorMessage', style: const TextStyle(color: Colors.redAccent)),

            // 4 Charts
            ..._sensorNames.map((sensorName) {
              final readings = _readingsBySensor[sensorName] ?? [];
              return Card(
                color: const Color(0xFF0F2A44),
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(sensorName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('${readings.length} readings', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSensorChart(sensorName),
                    ],
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}