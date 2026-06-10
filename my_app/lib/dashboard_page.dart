import 'dart:async';

import 'package:flutter/material.dart';
import 'models/sensor_data.dart';
import 'models/notification_model.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'sensor_detail_page.dart';
import 'history_page.dart';
import 'services/auth_api_service.dart';
import 'services/sensor_firestore_service.dart';
import 'widgets/sensor_icon.dart';
import 'notifications_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final SensorApiService _sensorService = SensorApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Stream<List<SensorData>>? _sensorStream;

  Map<String, dynamic>? _wqiData;
  bool _wqiLoading = true;

  Map<String, dynamic>? _predictionData;
  bool _predictionLoading = true;

  String? _streamError;

  @override
  void initState() {
    super.initState();

    _initStream();

    _wqiData = _sensorService.latestWqiData;
    _predictionData = _sensorService.latestPredictionData;

    if (_wqiData != null) _wqiLoading = false;
    if (_predictionData != null) _predictionLoading = false;
  }

  void _initStream() {
    _sensorStream =
        _sensorService.streamSensorData().asBroadcastStream();
  }

  @override
  void dispose() {
    _sensorService.dispose();
    super.dispose();
  }

  // ---------------- STREAM HANDLER ----------------

  void _retryStream() {
    setState(() {
      _streamError = null;
      _initStream();
    });
  }

  void _handleRealtimeSensorsUpdate(List<SensorData> sensors) {
    if (!mounted || sensors.isEmpty) return;

    final wqiData = _sensorService.latestWqiData;
    final predictionData = _sensorService.latestPredictionData;

    setState(() {
      _streamError = null;
      if (wqiData != null) {
        _wqiData = wqiData;
        _wqiLoading = false;
      }
      if (predictionData != null) {
        _predictionData = predictionData;
        _predictionLoading = false;
      }
    });
  }

  // ---------------- FALLBACK DATA ----------------

  List<SensorData> getFallbackSensorData() {
    return [
      SensorData(
        name: 'Turbidity',
        value: 3.4,
        unit: 'NTU',
        minSafe: 0.0,
        maxSafe: 5.0,
        icon: '💧',
        trend: 'stable',
        previousValue: 3.4,
        lastUpdated: DateTime.now(),
      ),
      SensorData(
        name: 'TDS',
        value: 300,
        unit: 'ppm',
        minSafe: 0.0,
        maxSafe: 500,
        icon: '🧂',
        trend: 'stable',
        previousValue: 300,
        lastUpdated: DateTime.now(),
      ),
      SensorData(
        name: 'Temperature',
        value: 26.8,
        unit: '°C',
        minSafe: 15.0,
        maxSafe: 30.0,
        icon: '🌡️',
        trend: 'stable',
        previousValue: 26.8,
        lastUpdated: DateTime.now(),
      ),
      SensorData(
        name: 'pH',
        value: 7.2,
        unit: '',
        minSafe: 6.5,
        maxSafe: 8.5,
        icon: '⚗️',
        trend: 'stable',
        previousValue: 7.2,
        lastUpdated: DateTime.now(),
      ),
    ];
  }

  // ---------------- STATUS HELPERS ----------------

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

  String formatAgeLabel(SensorData sensor) {
    final seconds = sensor.ageInSeconds();
    if (seconds < 60) return '${seconds}s ago';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m ago';
    final hours = minutes ~/ 60;
    return '${hours}h ago';
  }

  String getFreshnessSummary(List<SensorData> sensors) {
    if (sensors.isEmpty) return 'No readings yet';

    final latest = sensors
        .map((sensor) => sensor.lastUpdated)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final age = DateTime.now().difference(latest).inSeconds;

    if (age < 5) return 'Updated just now';
    if (age < 60) return 'Updated ${age}s ago';
    return 'Updated ${(age ~/ 60)}m ago';
  }

  int getOverallWaterQualityScore(List<SensorData> sensors) {
    final onlineSensors =
        sensors.where((sensor) => !sensor.isOffline()).toList();
    if (onlineSensors.isEmpty) return 0;

    final totalScore = onlineSensors.fold<int>(
      0,
      (sum, sensor) => sum + sensor.getQualityScore(),
    );

    return (totalScore ~/ onlineSensors.length).clamp(0, 100);
  }

  String getOverallQualityLabel(int score, List<SensorData> sensors) {
    if (sensors.every((sensor) => sensor.isOffline())) return 'Offline';
    if (score >= 85) return 'Excellent';
    if (score >= 60) return 'Monitor';
    return 'Critical';
  }

  Color getOverallQualityColor(int score, List<SensorData> sensors) {
    if (sensors.every((sensor) => sensor.isOffline())) {
      return const Color(0xFF888888);
    }
    if (score >= 85) return const Color(0xFF6BCB77);
    if (score >= 60) return const Color(0xFFFFD93D);
    return const Color(0xFFFF6B6B);
  }

  String getSensorCoverageSummary(List<SensorData> sensors) {
    final online = sensors.where((sensor) => !sensor.isOffline()).length;
    return '$online of ${sensors.length} sensors online';
  }

  int getAlertCount(List<SensorData> sensors) {
    return sensors
        .where((sensor) => sensor.isOffline() || sensor.getStatus() != 'safe')
        .length;
  }

  List<SensorData> getAlertsensorData(List<SensorData> sensors) {
    return sensors
        .where((sensor) => sensor.isOffline() || sensor.getStatus() != 'safe')
        .toList();
  }

  // ---------------- NOTIFICATIONS ----------------

  List<NotificationItem> getNotifications(List<SensorData> sensors) {
    final now = DateTime.now();
    final notifications = <NotificationItem>[];

    for (var i = 0; i < sensors.length; i++) {
      final sensor = sensors[i];
      final status = sensor.getStatus();
      final desc = sensor.getStatusDescription();

      if (sensor.isOffline()) {
        notifications.add(
          NotificationItem(
            id: 'offline_${sensor.name}_$i',
            sensorName: sensor.name,
            sensorIcon: sensor.icon,
            message:
                '${sensor.name} is offline. Last value was ${sensor.previousValue.toString()} ${sensor.unit}.',
            severity: 'danger',
            timestamp: now.subtract(Duration(minutes: 2 + i)),
          ),
        );
        continue;
      }

      if (status == 'danger') {
        notifications.add(
          NotificationItem(
            id: 'danger_${sensor.name}_$i',
            sensorName: sensor.name,
            sensorIcon: sensor.icon,
            message:
                '${sensor.name} is ${desc.toLowerCase()} at ${sensor.value.toStringAsFixed(1)} ${sensor.unit}.',
            severity: 'danger',
            timestamp: now.subtract(Duration(minutes: 4 + i)),
          ),
        );
      } else if (status == 'warning') {
        notifications.add(
          NotificationItem(
            id: 'warning_${sensor.name}_$i',
            sensorName: sensor.name,
            sensorIcon: sensor.icon,
            message:
                '${sensor.name} is ${desc.toLowerCase()} (${sensor.value.toStringAsFixed(1)} ${sensor.unit}).',
            severity: 'warning',
            timestamp: now.subtract(Duration(minutes: 6 + i)),
          ),
        );
      } else {
        notifications.add(
          NotificationItem(
            id: 'info_${sensor.name}_$i',
            sensorName: sensor.name,
            sensorIcon: sensor.icon,
            message:
                '${sensor.name} is ${desc.toLowerCase()} at ${sensor.value.toStringAsFixed(1)} ${sensor.unit}.',
            severity: 'info',
            timestamp: now.subtract(Duration(minutes: 10 + i)),
            isRead: true,
          ),
        );
      }
    }

    if (notifications.isEmpty) {
      notifications.add(
        NotificationItem(
          id: 'system_empty',
          sensorName: 'System',
          sensorIcon: '⚙️',
          message: 'No sensor notifications yet.',
          severity: 'info',
          timestamp: now,
          isRead: true,
        ),
      );
    }

    return notifications;
  }

  void showNotifications(BuildContext context, List<SensorData> sensors) {
    final notifications = getNotifications(sensors);
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                NotificationsPage(notifications: notifications),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // ---------------- LOGOUT ----------------

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text('You will be returned to the login screen.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    AuthApiService.instance.logout();
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        opaque: true,
        pageBuilder:
            (routeContext, animation, secondaryAnimation) => const LoginPage(),
        transitionsBuilder: (routeContext, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  // ---------------- WQI HELPER ----------------

  Widget _buildQISensorRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF666666),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1E3A5F),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ---------------- DRAWER ----------------

  Widget _buildAppDrawer(BuildContext context, List<SensorData> sensors) {
    final isAuth = AuthApiService.instance.isAuthenticated;
    final profileName = AuthApiService.instance.fullName;
    final profileEmail = AuthApiService.instance.email;
    final displayName =
        (profileName ?? '').trim().isNotEmpty
            ? profileName!.trim()
            : (isAuth ? 'Signed in account' : 'Guest');
    final displayEmail =
        (profileEmail ?? '').trim().isNotEmpty
            ? profileEmail!.trim()
            : (isAuth ? 'Account email unavailable' : 'Not signed in');
    final avatarLetter =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1E3A5F)),
              accountName: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isAuth
                              ? const Color(0xFF6BCB77)
                              : const Color(0xFF888888))
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isAuth ? 'Logged in' : 'Guest',
                      style: TextStyle(
                        color:
                            isAuth
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFF555555),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              accountEmail: Text(
                displayEmail,
                style: const TextStyle(color: Color(0xFFE6EDF7)),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  avatarLetter,
                  style: const TextStyle(
                    fontSize: 24,
                    color: Color(0xFF1E3A5F),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              subtitle: const Text('View or edit your profile'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => ProfilePage(
                          displayName: displayName,
                          displayEmail: displayEmail,
                          isAuthenticated: isAuth,
                        ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.of(context).pop();
                showNotifications(context, sensors);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History'),
              subtitle: const Text('View sensor reading history'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryPage()),
                );
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: () => _handleLogout(context),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SensorData>>(
      stream: _sensorStream,
      builder: (context, snapshot) {
        // Use snapshot.hasError OR _streamError (fix from first file)
        if (snapshot.hasError || _streamError != null) {
          debugPrint("STREAM ERROR: ${snapshot.error}");
          return Scaffold(
            backgroundColor: const Color(0xFFB5D2E6),
            appBar: AppBar(
              title: const Text('WaterGuard'),
              backgroundColor: const Color(0xFF789CE6),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFFF6B6B),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Connection Error',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F2A44),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to fetch sensor data.\n\n${_streamError ?? snapshot.error.toString()}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF0F2A44),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _retryStream,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF789CE6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final sensors =
            snapshot.data?.isNotEmpty == true
                ? snapshot.data!
                : getFallbackSensorData();

        return Scaffold(
          key: _scaffoldKey,
          endDrawer: _buildAppDrawer(context, sensors),
          backgroundColor: const Color(0xFFB5D2E6),
          body: Column(
            children: [
              // Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF789CE6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 50,
                      width: 50,
                      fit: BoxFit.contain,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.menu,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed:
                          () => _scaffoldKey.currentState?.openEndDrawer(),
                    ),
                  ],
                ),
              ),
              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Banner Image
                      Container(
                        width: double.infinity,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/Savewater.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFFD5FCDD),
                                child: const Center(
                                  child: Text('Image not available'),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Prediction Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Predicted Water Quality',
                              style: TextStyle(
                                color: Color(0xFF1E3A5F),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_predictionLoading)
                              const Center(
                                child: SizedBox(
                                  height: 56,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              )
                            else if (_predictionData != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${_predictionData!['category'] ?? 'Unknown'}',
                                            style: const TextStyle(
                                              color: Color(0xFF1E3A5F),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Score: ${(_predictionData!['score'] ?? _predictionData!['risk'] ?? 0).toString()}',
                                            style: const TextStyle(
                                              color: Color(0xFF666666),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_predictionData!['classification'] !=
                                          null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF5F5F5),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _predictionData!['classification'] ??
                                                '',
                                            style: const TextStyle(
                                              color: Color(0xFF1E3A5F),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _predictionData!['explanation'] ??
                                        _predictionData!['recommendation'] ??
                                        'No details available.',
                                    style: const TextStyle(
                                      color: Color(0xFF444444),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              )
                            else
                              const Center(
                                child: Text(
                                  'No prediction available',
                                  style: TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // NSF-WQI Score Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Water Quality Index (NSF-WQI)',
                              style: TextStyle(
                                color: Color(0xFF1E3A5F),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_wqiLoading)
                              const Center(
                                child: SizedBox(
                                  height: 80,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              )
                            else if (_wqiData != null)
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: (Color(
                                          int.parse(
                                            (_wqiData!['color'] as String)
                                                .replaceFirst('#', '0xFF'),
                                          ),
                                        )).withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            (_wqiData!['wqiScore'] as num)
                                                .toStringAsFixed(1),
                                            style: TextStyle(
                                              color: Color(
                                                int.parse(
                                                  (_wqiData!['color'] as String)
                                                      .replaceFirst('#', '0xFF'),
                                                ),
                                              ),
                                              fontSize: 40,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_wqiData!['category'] ?? 'Unknown'}/100',
                                            style: TextStyle(
                                              color: Color(
                                                int.parse(
                                                  (_wqiData!['color'] as String)
                                                      .replaceFirst('#', '0xFF'),
                                                ),
                                              ),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'NSF-WQI Score',
                                            style: TextStyle(
                                              color: Color(0xFF666666),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5F5F5),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                          width: 1,
                                        ),
                                      ),
                                      child:
                                          _wqiData != null &&
                                                  _wqiData!['sensors'] != null
                                              ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Sensor Readings',
                                                    style: TextStyle(
                                                      color: Color(0xFF1E3A5F),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  _buildQISensorRow(
                                                    'Turbidity',
                                                    '${(_wqiData!['sensors']['turbidity'] as num).toString()} NTU',
                                                  ),
                                                  const SizedBox(height: 6),
                                                  _buildQISensorRow(
                                                    'pH',
                                                    (_wqiData!['sensors']['phLevel']
                                                            as num)
                                                        .toStringAsFixed(1),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  _buildQISensorRow(
                                                    'Temp',
                                                    '${(_wqiData!['sensors']['temperature'] as num).toStringAsFixed(1)}°C',
                                                  ),
                                                  const SizedBox(height: 6),
                                                  _buildQISensorRow(
                                                    'TDS',
                                                    '${(_wqiData!['sensors']['tds'] as num).toStringAsFixed(1)} ppm',
                                                  ),
                                                ],
                                              )
                                              : Center(
                                                child: Text(
                                                  'Loading sensor data...',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              const Center(
                                child: Text(
                                  'Unable to load WQI data',
                                  style: TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Sensor Grid
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.72,
                            ),
                        itemCount: sensors.length,
                        itemBuilder: (context, index) {
                          final sensor = sensors[index];
                          final sensorStatus =
                              sensor.isOffline()
                                  ? 'offline'
                                  : sensor.getStatus();
                          final sensorDesc =
                              sensor.isOffline()
                                  ? 'Offline'
                                  : sensor.getStatusDescription();
                          final statusColor = getStatusColor(sensorStatus);

                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  opaque: true,
                                  pageBuilder:
                                      (context, animation, secondaryAnimation) =>
                                          SensorDetailPage(sensor: sensor),
                                  transitionsBuilder: (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            },
                            child: IgnorePointer(
                              ignoring: sensor.isOffline(),
                              child: Opacity(
                                opacity: sensor.isOffline() ? 0.5 : 1.0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 0,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SensorIcon(
                                        icon: sensor.icon,
                                        size: 40,
                                        color: const Color(0xFF1E3A5F),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        sensor.name,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFF1E3A5F),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      RichText(
                                        textAlign: TextAlign.center,
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text:
                                                  sensor.isOffline()
                                                      ? 'N/A'
                                                      : sensor.value
                                                          .toStringAsFixed(1),
                                              style: const TextStyle(
                                                color: Color(0xFF1E3A5F),
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(
                                              text: ' ${sensor.unit}',
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          sensorDesc.toUpperCase(),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        sensor.isOffline()
                                            ? 'No fresh data'
                                            : 'Updated ${formatAgeLabel(sensor)}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFF666666),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}