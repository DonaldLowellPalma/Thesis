# ESP32 Water Quality Sensor Setup Guide

## Hardware Requirements

- ESP32 Development Board
- SSD1306 OLED Display (128x64, I2C)
- Turbidity Sensor (Analog OUT to GPIO 34)
- TDS Sensor (Analog OUT to GPIO 35)
- pH Sensor (Analog OUT to GPIO 32)
- WiFi Router

## Step 1: Install Required Libraries in Arduino IDE

1. Open **Arduino IDE**
2. Go to **Sketch → Include Library → Manage Libraries**
3. Search and install these libraries:
   - **Adafruit GFX Library** (by Adafruit)
   - **Adafruit SSD1306** (by Adafruit)
   - **ArduinoJson** (by Bенjamin Sonntag)

## Step 2: Configure Your Code

Open `waterguard_esp32_sensors.ino` and update these constants:

### WiFi Configuration

```cpp
#define WIFI_SSID "YOUR_WIFI_SSID"           // Your WiFi network name
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"   // Your WiFi password
```

### Backend Configuration

```cpp
#define BACKEND_URL "http://YOUR_IP:4000"    // Your backend IP:port
#define JWT_TOKEN "YOUR_JWT_TOKEN_HERE"      // Get this from login
```

## Step 3: Get Your JWT Token

### Option A: Using POST Request (Recommended)

1. Open a terminal/PowerShell
2. Register a user first:

```bash
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"esp32@waterguard.com\",\"password\":\"Test@1234\"}"
```

3. Login to get JWT token:

```bash
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"esp32@waterguard.com\",\"password\":\"Test@1234\"}"
```

4. Copy the `token` from the response and paste it in the code:

```cpp
#define JWT_TOKEN "your_token_here"
```

## Step 4: Find Your Backend IP Address

### If running backend locally on Windows:

```bash
ipconfig
```

Look for your **IPv4 Address** (usually starts with 192.168.x.x)

Example: `192.168.1.100`

Then update:

```cpp
#define BACKEND_URL "http://192.168.1.100:4000"
```

### Important: The ESP32 must be on the same WiFi network as your backend

## Step 5: Upload to ESP32

1. Select **Tools → Board → ESP32 Dev Module**
2. Select the correct **COM Port** for your ESP32
3. Click **Upload**
4. Open **Tools → Serial Monitor** (set baud to 115200)

## Step 6: Verify Connection

Check Serial Monitor for:

```
Started – Connecting to WiFi...
WiFi connected!
IP address: 192.168.1.xxx

Turb: 45 NTU | TDS: 280 ppm | pH: 7.25 (Neutral/Good)
=== Updating Firebase ===
Sending to http://192.168.1.100:4000/api/sensors/turbidity/value: {"value":45}
HTTP Response: 200
Data sent successfully!
```

## Troubleshooting

### WiFi Connection Failed

- Check SSID and password spelling
- Ensure 2.4 GHz WiFi (most ESP32s don't support 5 GHz)
- Check WiFi router is on same network

### HTTP Errors

- **401 Unauthorized**: JWT token expired or invalid
- **404 Not Found**: Backend URL is wrong
- **Connection refused**: Backend not running or wrong IP

### Backend Not Responding

- Ensure Node.js backend is running: `npm start`
- Check backend is listening on port 4000
- Verify firewall allows port 4000

## Data Update Frequency

- **Display**: Updates every 3 seconds
- **Backend**: Sends data every 30 seconds (configurable)

Change this line to adjust:

```cpp
const unsigned long UPDATE_INTERVAL = 30000;  // milliseconds
```

## Real-Time Monitoring

Once connected, view your sensor data via:

- **Web Request**: `curl http://localhost:4000/api/sensors`
- **Backend REST API**: See API_DOCUMENTATION.md

## Notes

1. **Always calibrate your sensors** with known standards:
   - pH: Use pH 7.0 and pH 4.0 buffer solutions
   - TDS: Use known ppm solutions
   - Turbidity: Use known NTU standards

2. **Security**:
   - Don't hardcode tokens in production
   - Use environment variables for sensitive data
   - Regenerate tokens periodically

3. **Power**:
   - ESP32 needs stable 5V power
   - Use quality USB power supply for reliable operation
   - Add capacitors near power pins for stability

## Next Steps

- Integrate with Flutter mobile app for real-time monitoring
- Add data logging to SD card for historical analysis
- Set up alerts for out-of-range values
- Implement data visualization dashboard
