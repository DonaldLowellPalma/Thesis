# Demo Mode Setup Guide - WATERGUARD App

## Overview

The WATERGUARD app includes a **Demo Mode** that allows you to create tutorial and demo videos without requiring:

- Running ESP32 sensors
- Active backend server
- Internet connection (optional)

Demo Mode provides predetermined, realistic water quality data that simulates normal operation.

---

## Quick Start

### Method 1: Enable Demo Mode in Code (main.dart)

Add this at the start of your `main()` function in `lib/main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable demo mode for recording videos/tutorials
  DemoModeConfig.enable();
  // Alternatively: DemoModeConfig.enableDemoMode = true;

  await FirebaseService.initialize();
  await FCMService.initialize();
  // ... rest of main() function
}
```

### Method 2: Toggle Demo Mode at Runtime

Create a temporary debug button or use a settings option:

```dart
// Import the demo config
import 'services/demo_mode_config.dart';

// Toggle demo mode
DemoModeConfig.toggle();

// Or explicitly enable/disable
DemoModeConfig.enable();   // Enable demo mode
DemoModeConfig.disable();  // Disable demo mode
```

---

## Configuration Options

All configuration options are in `lib/services/demo_mode_config.dart`:

```dart
// Enable/disable demo mode
DemoModeConfig.enableDemoMode = true;

// Simulate slower sensor updates for better visibility during video recording
DemoModeConfig.simulateSlowUpdates = true;

// Set update interval in seconds (only when simulateSlowUpdates is true)
DemoModeConfig.updateIntervalSeconds = 3;

// Enable debug printing
DemoModeConfig.debugMode = true;
```

---

## Demo Data Available

The `demo_data_service.dart` provides several predefined scenarios:

### 1. **Standard Demo Data** (Default)

```dart
DemoDataService.getDemoSensorData()
```

- All sensors within safe ranges
- Realistic, balanced water quality
- Good for general tutorials

**Data included:**

- Water Clarity: 2.8 NTU ✅
- Temperature: 24.3°C ✅
- pH Level: 7.1 ✅
- Dissolved Oxygen: 7.2 mg/L ✅
- Conductivity: 485 μS/cm ✅
- Salinity: 3.2 ppt ✅
- Turbidity: 2.1 FNU ✅
- WQI Score: 78 (Good) ✅

### 2. **Emergency Scenario** (For Alert Demonstrations)

```dart
DemoDataService.getEmergencyScenarioData()
```

- Multiple sensors out of safe range
- High alerts and notifications
- Perfect for showing alert system

**Data included:**

- Water Clarity: 8.5 NTU ❌ (unsafe)
- Temperature: 35.2°C ❌ (too hot)
- Dissolved Oxygen: 2.1 mg/L ❌ (critically low)
- pH Level: 5.8 ❌ (too acidic)

### 3. **Optimal Scenario** (For Positive Examples)

```dart
DemoDataService.getGoodScenarioData()
```

- All sensors at optimal ranges
- Excellent water quality indicators
- Perfect for "best case" demonstrations

**Data included:**

- Water Clarity: 1.2 NTU ✅ (excellent)
- Temperature: 20.5°C ✅ (optimal)
- pH Level: 7.4 ✅ (ideal)
- Dissolved Oxygen: 8.9 mg/L ✅ (excellent)
- Conductivity: 520 μS/cm ✅

### 4. **Animated Data**

```dart
DemoDataService.getAnimatedSensorData(frame: 0)
```

- Smooth animations and transitions
- Simulates real-time data updates
- Automatically used by stream

### 5. **Historical Data**

```dart
DemoDataService.getDemoHistoricalData('Water Clarity')
```

- 48 hours of history
- One data point every 30 minutes
- Realistic trends for each sensor

### 6. **WQI Data**

```dart
DemoDataService.getDemoWQIData()
```

- Overall score: 78
- Rating: "Good"
- Breakdown of component scores

### 7. **Prediction Data**

```dart
DemoDataService.getDemoPredictionData()
```

- Predicted score: 76
- Confidence: 92%
- Recommendations: "Water quality is good. Continue regular monitoring."

### 8. **Notifications**

```dart
DemoDataService.getDemoNotifications()
```

- Sample notifications for different alert types
- Info, Warning, and Danger levels

---

## Recording a Demo Video

### Step 1: Prepare Your Device

1. Open the app on your device/emulator
2. Log in with a test account
3. Enable demo mode using one of the methods above

### Step 2: Configuration

Edit `DemoModeConfig` for optimal video recording:

```dart
// For slower, more visible updates
DemoModeConfig.simulateSlowUpdates = true;
DemoModeConfig.updateIntervalSeconds = 3;  // 3 seconds between updates

// For debug visibility
DemoModeConfig.debugMode = true;
```

### Step 3: Recording Tips

**Dashboard Recording:**

1. Enable demo mode
2. Open the Dashboard
3. Watch as sensors update smoothly
4. No need to wait for real sensor data

**History Recording:**

1. Navigate to History tab
2. Demo data includes 48 hours of historical data
3. Charts and graphs will show realistic trends

**Alert Recording:**

1. Temporarily use emergency scenario data (modify `getDemoSensorData()` temporarily)
2. Or create a demo method that combines normal and alert data

**Notification Recording:**

1. Navigate to Notifications tab
2. Demo notifications are pre-created and ready

### Step 4: Video Recording

**Android/iOS Emulator:**

```bash
# iOS Simulator recording (built-in)
# Press Cmd+Shift+5 then record

# Android Emulator recording
# Use "Ctrl+Shift+R" or record via screen recording app
```

**Physical Device:**

- Use built-in screen recording (Settings → Screen Record)
- iOS: Control Center → Screen Record
- Android: Settings → Advanced → Screen Recorder

---

## Switching Between Scenarios

To switch between different demo scenarios during the same session:

```dart
// In any widget or page
import 'services/demo_data_service.dart';

// Get different scenarios
final standardData = DemoDataService.getDemoSensorData();
final emergencyData = DemoDataService.getEmergencyScenarioData();
final perfectData = DemoDataService.getGoodScenarioData();

// Manually update UI with different data
setState(() {
  currentSensorData = emergencyData; // Switch to emergency scenario
});
```

---

## Demo Mode Behavior

### Enabled vs Disabled

**When Demo Mode is ENABLED:**

- ✅ App fetches demo data instantly
- ✅ No network connection required
- ✅ No backend server required
- ✅ No sensors need to be active
- ✅ Data updates at configurable intervals
- ✅ Data is consistent and predetermined
- ✅ Perfect for tutorials and demos

**When Demo Mode is DISABLED:**

- ✅ App connects to real backend server
- ✅ Fetches actual sensor data from ESP32 devices
- ✅ Real-time updates from sensors
- ✅ Requires active internet connection
- ✅ Requires backend server to be running
- ✅ Requires ESP32 sensors to be active

---

## Creating Custom Demo Scenarios

To create your own demo scenario, add a method to `demo_data_service.dart`:

```dart
/// Custom demo scenario for specific use case
static List<SensorData> getCustomScenarioData() {
  final now = DateTime.now();
  return [
    SensorData(
      id: 'sensor_001',
      name: 'Water Clarity',
      value: 5.5,  // Just outside safe range
      unit: 'NTU',
      minSafe: 0.0,
      maxSafe: 5.0,
      icon: '💧',
      trend: 'up',
      previousValue: 4.8,
      lastUpdated: now,
    ),
    // Add more sensors...
  ];
}
```

Then use it:

```dart
final customData = DemoDataService.getCustomScenarioData();
```

---

## Troubleshooting

### Demo Data Not Showing

**Problem:** Demo mode is enabled but still showing "No data" or trying to connect

**Solution:**

1. Check that `DemoModeConfig.enableDemoMode == true`
2. Restart the app after enabling demo mode
3. Verify imports: `import 'services/demo_mode_config.dart';`

### Demo Updates Too Fast/Slow

**Problem:** Data updates are not at desired speed

**Solution:**

```dart
// Increase update interval
DemoModeConfig.updateIntervalSeconds = 5;  // Slower updates

// Or enable simulated slow updates
DemoModeConfig.simulateSlowUpdates = true;
```

### Demo Data Not Realistic

**Problem:** Data seems inconsistent or unrealistic

**Solution:**

- Use the predefined scenarios (`getGoodScenarioData()`, `getEmergencyScenarioData()`)
- These are carefully tuned to be realistic
- Avoid mixing data from different scenarios

### Notification Issues in Demo Mode

**Problem:** Notifications not showing with demo data

**Solution:**

1. Navigate to the Notifications page
2. Demo notifications are automatically generated
3. If still not showing, check notification permissions

---

## Integration with Tutorial

The demo mode integrates seamlessly with [TUTORIAL.md](../TUTORIAL.md):

1. **Enable demo mode**
2. **Follow the tutorial steps** exactly as written
3. **All steps will work with predetermined data**
4. **Record video demonstrations without any setup**

---

## Disabling Demo Mode for Production

Before building for production:

```dart
// In main.dart - ensure demo mode is DISABLED
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Make sure this is disabled or not set to true
  // DemoModeConfig.enableDemoMode = false;  // Explicitly disable

  await FirebaseService.initialize();
  // ... rest of code
}
```

Alternatively, use environment variables:

```bash
# For production builds
flutter run --dart-define=ENABLE_DEMO_MODE=false

# For demo/tutorial builds
flutter run --dart-define=ENABLE_DEMO_MODE=true
```

---

## API Reference

### DemoModeConfig

```dart
// Static properties
static bool enableDemoMode;        // Master on/off switch
static bool simulateSlowUpdates;   // Slow down updates for visibility
static int updateIntervalSeconds;  // Time between updates
static bool debugMode;             // Print debug messages

// Static methods
static void enable();     // Turn on demo mode
static void disable();    // Turn off demo mode
static void toggle();     // Toggle on/off
```

### DemoDataService

```dart
// Get preset data
static List<SensorData> getDemoSensorData();           // Standard scenario
static List<SensorData> getEmergencyScenarioData();    // Emergency scenario
static List<SensorData> getGoodScenarioData();         // Optimal scenario

// Get supporting data
static Map<String, dynamic> getDemoWQIData();          // WQI score
static Map<String, dynamic> getDemoPredictionData();   // AI predictions
static List<Map<String, dynamic>> getDemoHistoricalData(String sensorName);
static List<Map<String, dynamic>> getDemoNotifications();

// Get animated data
static List<SensorData> getAnimatedSensorData({int frame = 0});
```

---

## Example: Complete Demo Video Script

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable demo mode
  DemoModeConfig.enable();
  DemoModeConfig.simulateSlowUpdates = true;
  DemoModeConfig.updateIntervalSeconds = 3;

  await FirebaseService.initialize();
  await FCMService.initialize();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await AuthApiService.instance.restoreSession();

  runApp(const MyApp());
}
```

**Video Flow:**

1. App starts → shows splash screen
2. Auto-loads demo account (or show login with test credentials)
3. Dashboard loads with live-updating demo data
4. Navigate to History tab → shows trends
5. Navigate to Notifications → shows sample alerts
6. Navigate to Profile → shows user settings
7. All with predetermined, beautiful data!

---

## Additional Resources

- [Tutorial](../TUTORIAL.md) - User tutorial (uses demo mode data)
- [API Documentation](../API_DOCUMENTATION.md) - Backend API details
- [README.md](../README.md) - General project info
- [ESP32 Setup Guide](../ESP32_SETUP_GUIDE.md) - Actual sensor setup (not needed for demo)

---

## Support

For issues with demo mode:

1. Check the Troubleshooting section above
2. Verify `DemoModeConfig` settings
3. Ensure demo imports are correct
4. Check debug output with `DemoModeConfig.debugMode = true`
5. Review the demo data files for expectations

---

**Last Updated:** June 2026  
**Demo Mode Version:** 1.0
