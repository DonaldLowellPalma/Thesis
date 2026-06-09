class NotificationItem {
  final String id;
  final String sensorName;
  final String sensorIcon;
  final String message;
  final String severity; // 'danger', 'warning', 'info'
  final DateTime timestamp;
  bool isRead;
  bool isArchived;
  DateTime? snoozeUntil;

  NotificationItem({
    required this.id,
    required this.sensorName,
    required this.sensorIcon,
    required this.message,
    required this.severity,
    required this.timestamp,
    this.isRead = false,
    this.isArchived = false,
    this.snoozeUntil,
  });

  // Check if notification is snoozed
  bool isSnoozed() {
    if (snoozeUntil == null) return false;
    return DateTime.now().isBefore(snoozeUntil!);
  }

  // Mark as read
  void markAsRead() {
    isRead = true;
  }

  // Archive notification
  void archive() {
    isArchived = true;
  }

  // Unarchive notification
  void unarchive() {
    isArchived = false;
  }

  // Snooze for duration
  void snooze(Duration duration) {
    snoozeUntil = DateTime.now().add(duration);
  }

  // Remove snooze
  void removeSnooze() {
    snoozeUntil = null;
  }

  // Get time ago string
  String getTimeAgo() {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}
