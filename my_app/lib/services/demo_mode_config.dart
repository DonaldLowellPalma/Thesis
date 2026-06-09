/// Demo Mode Configuration
///
/// Set [enableDemoMode] to true to use predetermined data for video tutorials/demos
/// without requiring the actual ESP32 sensors or backend server.

library;

class DemoModeConfig {
  /// Enable or disable demo mode globally
  static bool enableDemoMode = false;

  /// Simulate slow sensor updates (for demo purposes)
  static bool simulateSlowUpdates = true;

  /// Time delay between sensor updates in demo mode (in seconds)
  static int updateIntervalSeconds = 4;

  /// Print debug messages for demo mode
  static bool debugMode = true;

  // Demo credentials for Auth
  static const String demoEmail = "demo@waterguard.app";
  static const String demoPassword = "demo123";
  static const String demoFullName = "Demo User";

  static void enable() {
    enableDemoMode = true;
    if (debugMode) {
      print('[DEMO MODE] ✅ Demo mode ENABLED');
      print('   Login with: $demoEmail / $demoPassword');
    }
  }

  static void disable() {
    enableDemoMode = false;
    if (debugMode) {
      print('[DEMO MODE] ❌ Demo mode DISABLED');
    }
  }

  static void toggle() {
    enableDemoMode = !enableDemoMode;
    if (debugMode) {
      print('[DEMO MODE] Demo mode ${enableDemoMode ? 'ENABLED' : 'DISABLED'}');
    }
  }

  /// Skip real authentication in demo mode
  static bool get bypassAuth => enableDemoMode;
}