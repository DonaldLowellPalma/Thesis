import 'package:flutter/material.dart';

/// Maps sensor icon strings (emoji or icon names) to Material Icons
class SensorIcon extends StatelessWidget {
  const SensorIcon({super.key, required this.icon, this.size = 40, this.color});

  final String icon;
  final double size;
  final Color? color;

  static final Map<String, IconData> _iconMap = {
    // Emoji mappings
    '⚗️': Icons.science,
    '💧': Icons.water_drop,
    '📊': Icons.bar_chart,
    '🌡️': Icons.thermostat,
    '🌡': Icons.thermostat,
    '⚙️': Icons.settings,
    // Icon name mappings (for future backend compatibility)
    'science': Icons.science,
    'water_drop': Icons.water_drop,
    'bar_chart': Icons.bar_chart,
    'thermostat': Icons.thermostat,
    'ph': Icons.science,
    'turbidity': Icons.water_drop,
    'tds': Icons.bar_chart,
    'temperature': Icons.thermostat,
  };

  @override
  Widget build(BuildContext context) {
    final iconData = _iconMap[icon];

    if (iconData != null) {
      return Icon(iconData, size: size, color: color ?? Colors.white);
    }

    // Fallback: render as text (for unknown emojis/strings)
    return Text(
      icon,
      style: TextStyle(fontSize: size * 0.8, color: color),
    );
  }
}
