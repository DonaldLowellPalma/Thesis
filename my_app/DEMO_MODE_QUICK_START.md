# Demo Mode - Quick Reference

## TL;DR - Get Started in 30 Seconds

### Step 1: Enable Demo Mode

Add this to `lib/main.dart` at the start of `main()`:

```dart
import 'services/demo_mode_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DemoModeConfig.enable();  // ← Add this line
  // ... rest of code
}
```

### Step 2: Run the App

```bash
flutter run
```

### Step 3: Demo Data Appears Instantly

✅ No sensors needed  
✅ No backend server needed  
✅ No internet required  
✅ Predetermined, realistic data

---

## Configuration Cheat Sheet

```dart
import 'services/demo_mode_config.dart';

// Enable/disable
DemoModeConfig.enable();
DemoModeConfig.disable();
DemoModeConfig.toggle();

// Configure slow updates for video recording
DemoModeConfig.simulateSlowUpdates = true;
DemoModeConfig.updateIntervalSeconds = 3;  // 3 seconds between updates

// Enable debug output
DemoModeConfig.debugMode = true;
```

---

## Demo Data Scenarios

| Scenario      | Method                       | Use Case               |
| ------------- | ---------------------------- | ---------------------- |
| **Standard**  | `getDemoSensorData()`        | General tutorials      |
| **Emergency** | `getEmergencyScenarioData()` | Show alerts & warnings |
| **Optimal**   | `getGoodScenarioData()`      | Show best practices    |

---

## Demo Data Contents

### Standard Scenario (Default)

```
Water Clarity: 2.8 NTU ✅
Temperature: 24.3°C ✅
pH Level: 7.1 ✅
Dissolved Oxygen: 7.2 mg/L ✅
Conductivity: 485 μS/cm ✅
Salinity: 3.2 ppt ✅
Turbidity: 2.1 FNU ✅
WQI Score: 78 (Good)
```

### Emergency Scenario

```
Water Clarity: 8.5 NTU ❌
Temperature: 35.2°C ❌
Dissolved Oxygen: 2.1 mg/L ❌
pH Level: 5.8 ❌
(Perfect for demonstrating alerts!)
```

### Optimal Scenario

```
Water Clarity: 1.2 NTU ✅✅
Temperature: 20.5°C ✅✅
pH Level: 7.4 ✅✅
Dissolved Oxygen: 8.9 mg/L ✅✅
(Perfect for "ideal conditions" demos)
```

---

## Recording Video Tips

1. **Enable slow updates:**

   ```dart
   DemoModeConfig.simulateSlowUpdates = true;
   DemoModeConfig.updateIntervalSeconds = 3;
   ```

2. **Use emulator for clean recording:**
   - iOS Simulator: Cmd+Shift+5 to record
   - Android Emulator: Built-in recording available

3. **Follow the tutorial steps** exactly as in [TUTORIAL.md](TUTORIAL.md)

4. **All data is predetermined** - no waiting for real sensors!

---

## Troubleshooting

| Problem          | Solution                                                   |
| ---------------- | ---------------------------------------------------------- |
| No data showing  | Restart app after enabling demo mode                       |
| Updates too fast | Set `updateIntervalSeconds = 5` or higher                  |
| Need real data   | `DemoModeConfig.disable()` or set `enableDemoMode = false` |

---

## API Quick Reference

```dart
// Enable/disable
DemoModeConfig.enable()
DemoModeConfig.disable()
DemoModeConfig.toggle()

// Get data
DemoDataService.getDemoSensorData()
DemoDataService.getEmergencyScenarioData()
DemoDataService.getGoodScenarioData()
DemoDataService.getDemoWQIData()
DemoDataService.getDemoPredictionData()
DemoDataService.getDemoHistoricalData('Sensor Name')
DemoDataService.getDemoNotifications()
DemoDataService.getAnimatedSensorData(frame: 0)
```

---

## Files Modified

- `lib/main.dart` - Enable demo mode here
- `lib/services/demo_mode_config.dart` - NEW: Configuration file
- `lib/services/demo_data_service.dart` - NEW: Demo data provider
- `lib/services/sensor_firestore_service.dart` - Updated to use demo data

---

## Full Documentation

For complete details, see [DEMO_MODE_SETUP.md](DEMO_MODE_SETUP.md)

---

**Demo Mode is ready!** 🚀  
Start recording tutorials without any device setup.
