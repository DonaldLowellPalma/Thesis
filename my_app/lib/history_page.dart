import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/sensor_data.dart';
import 'services/sensor_firestore_service.dart';

class HistoryPage extends StatefulWidget {
  final SensorData? initialSensor;

  const HistoryPage({super.key, this.initialSensor});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final SensorApiService _api = SensorApiService();

  List<SensorData> _sensors = [];
  String? _selectedId;
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  late DateTime _to;
  bool _loading = false;
  List<Map<String, dynamic>> _readings = [];
  bool _loadingReadings = false;

  @override
  void initState() {
    super.initState();
    // Set _to to end of today so today's readings are included
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _init();
  }

  String _getStorageKey(String sensorId) => 'sensor_history_$sensorId';

  Future<void> _saveReadingsLocally(
    String sensorId,
    List<Map<String, dynamic>> readings,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(sensorId);

      // Load existing readings
      final existingJson = prefs.getString(key);
      final existingReadings = existingJson != null
          ? List<Map<String, dynamic>>.from(jsonDecode(existingJson))
          : <Map<String, dynamic>>[];

      // Merge with new readings, avoiding duplicates
      final timestamps = existingReadings.map((r) => r['timestamp']).toSet();
      final newReadings = readings
          .where((r) => !timestamps.contains(r['timestamp']))
          .toList();

      // Combine and sort by timestamp
      final combined = [...existingReadings, ...newReadings];
      combined.sort((a, b) {
        final tA = a['timestamp']?.toString() ?? '';
        final tB = b['timestamp']?.toString() ?? '';
        return tA.compareTo(tB);
      });

      // Keep last 10000 readings to avoid excessive storage
      final trimmed = combined.length > 10000
          ? combined.sublist(combined.length - 10000)
          : combined;

      await prefs.setString(key, jsonEncode(trimmed));
    } catch (e) {
      // Silently fail - this is just local caching
      debugPrint('Failed to save readings locally: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _loadReadingsLocally(
    String sensorId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(sensorId);
      final json = prefs.getString(key);
      if (json != null) {
        return List<Map<String, dynamic>>.from(jsonDecode(json));
      }
    } catch (e) {
      debugPrint('Failed to load local readings: $e');
    }
    return [];
  }

  Future<void> _init() async {
    try {
      final sensors = await _api.fetchSensorData();
      if (!mounted) return;
      setState(() {
        _sensors = sensors;
        _selectedId =
            widget.initialSensor?.id ??
            widget.initialSensor?.name ??
            (sensors.isNotEmpty
                ? sensors.first.id ?? sensors.first.name
                : null);
      });
      await _loadReadings();
    } catch (_) {}
  }

  Future<void> _loadReadings() async {
    if (_selectedId == null) return;
    setState(() => _loadingReadings = true);
    try {
      // Load from local storage first
      final localReadings = await _loadReadingsLocally(_selectedId!);
      debugPrint('Local readings loaded: ${localReadings.length}');

      // Fetch from API
      debugPrint(
        'Fetching readings for sensorId=$_selectedId, from=$_from, to=$_to',
      );
      final items = await _api.fetchReadings(
        sensorId: _selectedId,
        from: _from,
        to: _to,
        limit: 20000,
      );
      debugPrint('API returned ${items.length} readings');

      // Save new readings locally
      if (items.isNotEmpty) {
        await _saveReadingsLocally(_selectedId!, items);
        debugPrint('Saved ${items.length} readings to local storage');
      }

      if (!mounted) return;

      // Merge local and API data
      final timestamps = items.map((r) => r['timestamp']).toSet();
      final localOnly = localReadings
          .where((r) => !timestamps.contains(r['timestamp']))
          .toList();
      final combined = [...items, ...localOnly];

      debugPrint('Combined data: ${combined.length} readings');

      // Sort by timestamp
      combined.sort((a, b) {
        final tA = a['timestamp']?.toString() ?? '';
        final tB = b['timestamp']?.toString() ?? '';
        return tA.compareTo(tB);
      });

      setState(() {
        _readings = combined;
      });
    } catch (e) {
      // If API fails, still show local data
      debugPrint('Error fetching readings: $e');
      final localReadings = await _loadReadingsLocally(_selectedId!);
      if (!mounted) return;

      if (localReadings.isEmpty) {
        // Only show error if there's no cache either
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load readings: $e')));
      }

      setState(() {
        _readings = localReadings;
      });
    } finally {
      if (mounted) setState(() => _loadingReadings = false);
    }
  }

  Future<void> _downloadCsv() async {
    if (_selectedId == null) return;
    setState(() => _loading = true);
    try {
      final csv = await _api.fetchReadingsCsv(
        sensorId: _selectedId,
        from: _from,
        to: _to,
        limit: 20000,
      );

      final filename =
          'sensor_readings_${_selectedId}_${_from.toIso8601String().replaceAll(':', '-')}_${_to.toIso8601String().replaceAll(':', '-')}.csv';
      final tmp = Directory.systemTemp;
      final file = File('${tmp.path}/$filename');
      await file.writeAsString(csv);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV saved to ${file.path}')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to download CSV: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF789CE6),
              surface: Color(0xFF0F2A44),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _from) {
      setState(() => _from = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF789CE6),
              surface: Color(0xFF0F2A44),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _to) {
      setState(
        () => _to = DateTime(picked.year, picked.month, picked.day, 23, 59, 59),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'danger':
        return const Color(0xFFFF6B6B);
      case 'warning':
        return const Color(0xFFFFA500);
      case 'safe':
      default:
        return const Color(0xFF6BCB77);
    }
  }

  String _getTrendIcon(String trend) {
    switch (trend) {
      case 'up':
        return '↑';
      case 'down':
        return '↓';
      case 'stable':
      default:
        return '→';
    }
  }

  String _determineTrend(int index) {
    if (index == 0) return 'stable';

    final currentValue = (_readings[index]['value'] as num?)?.toDouble() ?? 0;
    final previousValue =
        (_readings[index - 1]['value'] as num?)?.toDouble() ?? 0;

    if (currentValue > previousValue) {
      return 'up';
    } else if (currentValue < previousValue) {
      return 'down';
    }
    return 'stable';
  }

  String _getStatus(double value, double minSafe, double maxSafe) {
    if (value < minSafe || value > maxSafe) {
      return 'danger';
    } else if ((value > minSafe && value < minSafe + 1) ||
        (value > maxSafe - 1 && value < maxSafe)) {
      return 'warning';
    }
    return 'safe';
  }

  LineChartData _buildChartData() {
    if (_readings.isEmpty) {
      return LineChartData(lineBarsData: [], titlesData: FlTitlesData());
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < _readings.length; i++) {
      final value = _readings[i]['value'] as dynamic;
      if (value != null) {
        spots.add(FlSpot(i.toDouble(), (value as num).toDouble()));
      }
    }

    if (spots.isEmpty) {
      return LineChartData(lineBarsData: [], titlesData: FlTitlesData());
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;

    // Get safe zone boundaries
    double? minSafe, maxSafe;
    if (_readings.isNotEmpty) {
      minSafe = (_readings[0]['minSafe'] as num?)?.toDouble();
      maxSafe = (_readings[0]['maxSafe'] as num?)?.toDouble();
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: (maxY - minY) / 5,
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < _readings.length && index % 5 == 0) {
                final timestamp =
                    _readings[index]['timestamp']?.toString() ?? '';
                final parts = timestamp.split(' ');
                return Text(
                  parts.length > 1 ? parts[1].substring(0, 5) : '',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                );
              }
              return const Text('');
            },
            reservedSize: 30,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toStringAsFixed(1),
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              );
            },
            reservedSize: 40,
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(
        show: true,
        border: const Border(
          bottom: BorderSide(color: Color(0xFF1E3A5F), width: 1),
          left: BorderSide(color: Color(0xFF1E3A5F), width: 1),
          right: BorderSide(color: Colors.transparent),
          top: BorderSide(color: Colors.transparent),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: const Color(0xFF789CE6),
          barWidth: 2,
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFF789CE6).withValues(alpha: 0.2),
          ),
          dotData: const FlDotData(show: false),
        ),
      ],
      minY: minY - padding,
      maxY: maxY + padding,
      rangeAnnotations: RangeAnnotations(
        horizontalRangeAnnotations: [
          if (minSafe != null && maxSafe != null)
            HorizontalRangeAnnotation(
              y1: minSafe,
              y2: maxSafe,
              color: const Color(0xFF6BCB77).withValues(alpha: 0.1),
            ),
        ],
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
        elevation: 2,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sensor selector card
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
                    const Text(
                      'Select Sensor',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedId,
                      items: _sensors
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id ?? s.name,
                              child: Text(
                                s.name,
                                style: const TextStyle(color: Colors.black),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null && v != _selectedId) {
                          setState(() => _selectedId = v);
                          _loadReadings();
                        }
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Debug info card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: const Color(0xFF0F2A44),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sensor: $_selectedId',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Readings: ${_readings.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Date Range: ${_from.toLocal().toString().split('.')[0]} to ${_to.toLocal().toString().split('.')[0]}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Date range card
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
                    const Text(
                      'Date Range',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickFromDate,
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              _from
                                  .toLocal()
                                  .toIso8601String()
                                  .split('T')
                                  .first,
                              style: const TextStyle(fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF789CE6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickToDate,
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              _to.toLocal().toIso8601String().split('T').first,
                              style: const TextStyle(fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF789CE6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: const Color(0xFF0F2A44),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loadingReadings ? null : _loadReadings,
                        icon: _loadingReadings
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text('Load'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF789CE6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _downloadCsv,
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.download),
                        label: const Text('Download CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6BCB77),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Chart card
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
                    const Text(
                      'Readings Graph',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 250,
                      child: _loadingReadings
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(
                                  Color(0xFF789CE6),
                                ),
                              ),
                            )
                          : _readings.isEmpty
                          ? Center(
                              child: Text(
                                'Load readings to view the graph.',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : LineChart(_buildChartData()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Readings list card
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
                      'Readings (${_readings.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 400,
                      child: _loadingReadings
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(
                                  Color(0xFF789CE6),
                                ),
                              ),
                            )
                          : _readings.isEmpty
                          ? Center(
                              child: Text(
                                'No readings found for the selected range.',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                children: [
                                  // Table Header
                                  Container(
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color(0xFF1E3A5F),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                              horizontal: 8,
                                            ),
                                            child: Text(
                                              'Timestamp',
                                              style: const TextStyle(
                                                color: Color(0xFF789CE6),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                              horizontal: 8,
                                            ),
                                            child: Text(
                                              'Value',
                                              style: const TextStyle(
                                                color: Color(0xFF789CE6),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                              horizontal: 8,
                                            ),
                                            child: Text(
                                              'Trend',
                                              style: const TextStyle(
                                                color: Color(0xFF789CE6),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                              horizontal: 8,
                                            ),
                                            child: Text(
                                              'Status',
                                              style: const TextStyle(
                                                color: Color(0xFF789CE6),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Table Rows
                                  ...List.generate(_readings.length, (index) {
                                    final r = _readings[index];
                                    final value =
                                        (r['value'] as num?)?.toDouble() ?? 0;
                                    final minSafe =
                                        (r['minSafe'] as num?)?.toDouble() ?? 0;
                                    final maxSafe =
                                        (r['maxSafe'] as num?)?.toDouble() ?? 0;
                                    final unit = r['unit'] ?? '';
                                    final status = _getStatus(
                                      value,
                                      minSafe,
                                      maxSafe,
                                    );
                                    final trend = _determineTrend(index);
                                    final trendIcon = _getTrendIcon(trend);
                                    final statusColor = _getStatusColor(status);

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        border: const Border(
                                          bottom: BorderSide(
                                            color: Color(0xFF1E3A5F),
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Timestamp
                                          Expanded(
                                            flex: 3,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 8,
                                                  ),
                                              child: Text(
                                                r['timestamp']?.toString() ??
                                                    '',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          // Value
                                          Expanded(
                                            flex: 2,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 8,
                                                  ),
                                              child: Text(
                                                '${value.toStringAsFixed(2)} $unit',
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          // Trend
                                          Expanded(
                                            flex: 1,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 8,
                                                  ),
                                              child: Text(
                                                trendIcon,
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          // Status
                                          Expanded(
                                            flex: 2,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 8,
                                                  ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: statusColor,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  status.toUpperCase(),
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
