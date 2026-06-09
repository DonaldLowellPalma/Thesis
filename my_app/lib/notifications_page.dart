import 'package:flutter/material.dart';
import 'models/notification_model.dart';
import 'sensor_detail_page.dart';
import 'models/sensor_data.dart';
import 'widgets/sensor_icon.dart';

class NotificationsPage extends StatefulWidget {
  final List<NotificationItem> notifications;

  const NotificationsPage({super.key, required this.notifications});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late List<NotificationItem> notifications;
  String filterSeverity = 'all'; // 'all', 'danger', 'warning', 'info'
  String sortBy = 'newest'; // 'newest', 'oldest'
  bool showArchived = false;

  @override
  void initState() {
    super.initState();
    notifications = List.from(widget.notifications);
  }

  // Get filtered and sorted notifications
  List<NotificationItem> getFilteredNotifications() {
    var filtered = notifications.where((n) {
      if (n.isSnoozed()) return false;
      if (showArchived && !n.isArchived) return false;
      if (!showArchived && n.isArchived) return false;
      if (filterSeverity != 'all' && n.severity != filterSeverity) return false;
      return true;
    }).toList();

    // Sort
    if (sortBy == 'newest') {
      filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } else {
      filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    return filtered;
  }

  // Get statistics
  Map<String, int> getStatistics() {
    return {
      'total': notifications.where((n) => !n.isArchived).length,
      'unread': notifications.where((n) => !n.isRead && !n.isArchived).length,
      'danger': notifications
          .where((n) => n.severity == 'danger' && !n.isArchived)
          .length,
      'warning': notifications
          .where((n) => n.severity == 'warning' && !n.isArchived)
          .length,
      'archived': notifications.where((n) => n.isArchived).length,
      'snoozed': notifications.where((n) => n.isSnoozed()).length,
    };
  }

  // Mark all as read
  void markAllAsRead() {
    setState(() {
      for (var n in notifications) {
        if (!n.isArchived) n.markAsRead();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✓ All notifications marked as read')),
    );
  }

  // Clear all notifications
  void clearAllNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        title: const Text(
          'Clear All Notifications?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete all non-archived notifications.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                notifications.removeWhere((n) => !n.isArchived);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✓ Notifications cleared')),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  // Show snooze options
  void showSnoozeOptions(NotificationItem notification) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Snooze Notification',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text(
                '15 minutes',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                setState(
                  () => notification.snooze(const Duration(minutes: 15)),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('⏰ Snoozed for 15 minutes')),
                );
              },
            ),
            ListTile(
              title: const Text(
                '1 hour',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                setState(() => notification.snooze(const Duration(hours: 1)));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('⏰ Snoozed for 1 hour')),
                );
              },
            ),
            ListTile(
              title: const Text('1 day', style: TextStyle(color: Colors.white)),
              onTap: () {
                setState(() => notification.snooze(const Duration(days: 1)));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('⏰ Snoozed for 1 day')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color getSeverityColor(String severity) {
    switch (severity) {
      case 'danger':
        return Color(0xFFFF6B6B);
      case 'warning':
        return Color(0xFFFFD93D);
      default:
        return Color(0xFF6BCB77);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = getStatistics();
    final filtered = getFilteredNotifications();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        elevation: 0,
        title: const Text(
          '🔔 Notifications',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.white),
            tooltip: 'Mark all as read',
            onPressed: markAllAsRead,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: 'Clear all',
            onPressed: clearAllNotifications,
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/BackGround.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.5)),
          Column(
            children: [
              // Statistics Bar
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatBox('${stats['total']}', 'Total', Colors.white),
                    _buildStatBox(
                      '${stats['unread']}',
                      'Unread',
                      Color(0xFF6BCB77),
                    ),
                    _buildStatBox(
                      '${stats['danger']}',
                      'Danger',
                      Color(0xFFFF6B6B),
                    ),
                    _buildStatBox(
                      '${stats['snoozed']}',
                      'Snoozed',
                      Color(0xFFFFD93D),
                    ),
                  ],
                ),
              ),

              // Filter and Sort Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', 'all', filterSeverity, () {
                              setState(() => filterSeverity = 'all');
                            }),
                            _buildFilterChip(
                              'Danger',
                              'danger',
                              filterSeverity,
                              () {
                                setState(() => filterSeverity = 'danger');
                              },
                            ),
                            _buildFilterChip(
                              'Warning',
                              'warning',
                              filterSeverity,
                              () {
                                setState(() => filterSeverity = 'warning');
                              },
                            ),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => showArchived = !showArchived),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: showArchived
                                      ? Color(0xFF1B6CDF)
                                      : Colors.white.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: showArchived
                                        ? Color(0xFF1B6CDF)
                                        : Colors.white24,
                                  ),
                                ),
                                child: Text(
                                  showArchived ? 'Archived ✓' : 'Archived',
                                  style: TextStyle(
                                    color: showArchived
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    PopupMenuButton(
                      icon: const Icon(Icons.sort, color: Colors.white),
                      color: Colors.black.withValues(alpha: 0.9),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: const Text(
                            'Newest First',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () => setState(() => sortBy = 'newest'),
                        ),
                        PopupMenuItem(
                          child: const Text(
                            'Oldest First',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () => setState(() => sortBy = 'oldest'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Notifications List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              showArchived ? '📭' : '✓',
                              style: const TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              showArchived
                                  ? 'No archived notifications'
                                  : 'All caught up!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              showArchived
                                  ? 'Your archive is empty'
                                  : 'No new notifications',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final notification = filtered[index];
                          final color = getSeverityColor(notification.severity);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Dismissible(
                              key: Key(notification.id),
                              direction: DismissDirection.endToStart,
                              onDismissed: (direction) {
                                setState(() => notification.archive());
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Notification archived',
                                    ),
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      onPressed: () => setState(
                                        () => notification.unarchive(),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.redAccent,
                                ),
                                child: const Icon(
                                  Icons.archive,
                                  color: Colors.white,
                                ),
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => notification.markAsRead());
                                  final sensor = _getSensorFromNotification(
                                    notification,
                                  );
                                  Navigator.of(context).push(
                                    PageRouteBuilder(
                                      pageBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                          ) {
                                            return SensorDetailPage(
                                              sensor: sensor,
                                            );
                                          },
                                      transitionsBuilder:
                                          (
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
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.white.withValues(alpha: 0.1),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Left: Icon and sensor name
                                          Column(
                                            children: [
                                              SensorIcon(
                                                icon: notification.sensorIcon,
                                                size: 28,
                                                color: Colors.white,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      notification.sensorName,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: color
                                                            .withValues(alpha: 0.2),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        notification.severity
                                                            .toUpperCase(),
                                                        style: TextStyle(
                                                          color: color,
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    if (!notification.isRead)
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        margin:
                                                            const EdgeInsets.only(
                                                              left: 8,
                                                            ),
                                                        decoration:
                                                            const BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color: Colors
                                                                  .lightBlue,
                                                            ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  notification.message,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  notification.getTimeAgo(),
                                                  style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Right: Actions
                                          Column(
                                            children: [
                                              PopupMenuButton(
                                                icon: const Icon(
                                                  Icons.more_vert,
                                                  color: Colors.white70,
                                                  size: 18,
                                                ),
                                                color: Colors.black.withValues(alpha: 
                                                  0.9,
                                                ),
                                                itemBuilder: (context) => [
                                                  PopupMenuItem(
                                                    child: Row(
                                                      children: const [
                                                        Icon(
                                                          Icons.done,
                                                          color: Colors.white,
                                                          size: 16,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Mark as Read',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    onTap: () => setState(
                                                      () => notification
                                                          .markAsRead(),
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    child: Row(
                                                      children: const [
                                                        Icon(
                                                          Icons.schedule,
                                                          color: Colors.white,
                                                          size: 16,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Snooze',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    onTap: () =>
                                                        showSnoozeOptions(
                                                          notification,
                                                        ),
                                                  ),
                                                  PopupMenuItem(
                                                    child: Row(
                                                      children: const [
                                                        Icon(
                                                          Icons.archive,
                                                          color: Colors.white,
                                                          size: 16,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Archive',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    onTap: () => setState(
                                                      () => notification
                                                          .archive(),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  SensorData _getSensorFromNotification(NotificationItem notification) {
    // Match notification sensor name to actual sensor data
    switch (notification.sensorName.toLowerCase()) {
      case 'ph':
      case 'ph level':
        return SensorData(
          name: 'pH Level',
          value: 7.2,
          unit: 'pH',
          minSafe: 6.5,
          maxSafe: 8.5,
          icon: '⚗️',
          trend: 'stable',
          previousValue: 7.2,
        );
      case 'turbidity':
        return SensorData(
          name: 'Turbidity',
          value: 1.5,
          unit: 'NTU',
          minSafe: 0.0,
          maxSafe: 5.0,
          icon: '💧',
          trend: 'down',
          previousValue: 2.0,
        );
      case 'tds':
        return SensorData(
          name: 'TDS',
          value: 320,
          unit: 'mg/L',
          minSafe: 0.0,
          maxSafe: 500.0,
          icon: '📊',
          trend: 'stable',
          previousValue: 320,
        );
      case 'temperature':
        return SensorData(
          name: 'Temperature',
          value: 25.3,
          unit: '°C',
          minSafe: 15.0,
          maxSafe: 30.0,
          icon: '🌡️',
          trend: 'up',
          previousValue: 24.8,
        );
      default:
        return SensorData(
          name: 'pH Level',
          value: 7.2,
          unit: 'pH',
          minSafe: 6.5,
          maxSafe: 8.5,
          icon: '⚗️',
          trend: 'stable',
          previousValue: 7.2,
        );
    }
  }

  Widget _buildStatBox(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    String label,
    String? value,
    String? current,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    final isSelected = value != null ? value == current : isActive;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isSelected
                ? Color(0xFF1B6CDF)
                : Colors.white.withValues(alpha: 0.1),
            border: Border.all(
              color: isSelected ? Color(0xFF1B6CDF) : Colors.white24,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
