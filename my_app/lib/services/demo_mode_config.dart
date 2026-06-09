/// Demo Mode Configuration
///
/// Set [enableDemoMode] to true to use predetermined data for video tutorials/demos
/// without requiring the actual ESP32 sensors or backend server to be running.
///
/// Usage:
///   DemoModeConfig.enableDemoMode = true;  // Enable demo mode
///   DemoModeConfig.enableDemoMode = false; // Disable demo mode (use real data)
library;

class DemoModeConfig {
  /// Enable or disable demo mode globally
  static bool enableDemoMode = false;

  /// Simulate slow sensor updates (for demo purposes)
  /// When enabled, sensors will update at a slower rate to make the demo more visible
  static bool simulateSlowUpdates = false;

  /// Time delay between sensor updates in demo mode (in seconds)
  static int updateIntervalSeconds = 3;

  /// Print debug messages for demo mode
  static bool debugMode = false;

  static void enable() {
    enableDemoMode = true;
    if (debugMode) {
      print('[DEMO MODE] Demo mode ENABLED');
    }
  }

  static void disable() {
    enableDemoMode = false;
    if (debugMode) {
      print('[DEMO MODE] Demo mode DISABLED');
    }
  }

  static void toggle() {
    enableDemoMode = !enableDemoMode;
    if (debugMode) {
      print('[DEMO MODE] Demo mode ${enableDemoMode ? 'ENABLED' : 'DISABLED'}');
    }
  }
}
