# ESP32 Troubleshooting Guide

## ✅ Pre-flight Checklist

### 1. Backend Server Status

Before testing ESP32, ensure your backend is running:

```powershell
# Start the backend server (in project directory)
npm start

# Should see:
# Server listening on http://localhost:4000
```

**Test backend health:**

```powershell
curl http://localhost:4000/health
# Expected: {"ok":true,"service":"waterguard-backend"}
```

### 2. Get Your Computer's Local IP Address

Your ESP32 needs to reach your computer on the local network.

```powershell
# Get your local IP address
ipconfig | Select-String "IPv4"

# Look for something like: 192.168.1.100 or 10.0.0.5
# This is what you'll use in BACKEND_URL
```

### 3. Get a Valid JWT Token

```powershell
# Register a test user (only once)
curl -X POST http://localhost:4000/api/auth/register `
  -H "Content-Type: application/json" `
  -d '{\"email\":\"esp32@test.com\",\"password\":\"Test@1234\"}'

# Login to get JWT token
curl -X POST http://localhost:4000/api/auth/login `
  -H "Content-Type: application/json" `
  -d '{\"email\":\"esp32@test.com\",\"password\":\"Test@1234\"}'

# Copy the "token" value from the response
```

### 4. Update ESP32 Code

Edit `waterguard_esp32_sensors.ino`:

```cpp
// Replace these with YOUR actual values:
#define WIFI_SSID "vivo@1920@30"              // e.g., "Home_WiFi"
#define WIFI_PASSWORD "102030405060708090"       // e.g., "password123"
#define BACKEND_URL "http://192.168.1.100:4000"  // YOUR computer's IP
#define JWT_TOKEN "eyJhbGciOiJIUzI1NiIsInR5cCI6..."  // Token from login
```

**⚠️ Important:**

- ESP32 and your computer MUST be on the same WiFi network
- Use `http://` not `https://`
- Use your computer's LOCAL IP, not `localhost`
- Port should be `4000` (default backend port)

---

## 🔍 Serial Monitor Checklist

### What to Look For

1. **Open Serial Monitor** in Arduino IDE
   - Set baud rate to **115200**
   - Upload your sketch and click "Serial Monitor"

### Expected Output at Startup

```
Started – Connecting to WiFi...
..........
WiFi connected!
IP address: 192.168.1.150
Turb: 0 NTU (Clear)   |   TDS: 0 ppm (Fresh)   |   pH: 7.00 (Neutral/Good)
```

✅ **GOOD SIGN:** WiFi connected and shows an IP address

### Expected Output Every ~30 Seconds

```
=== Updating Firebase ===
Sending to http://192.168.1.100:4000/api/sensors/turbidity/value: {"value":0.0}
HTTP Response: 200
Data sent successfully!
Sending to http://192.168.1.100:4000/api/sensors/tds/value: {"value":0.0}
HTTP Response: 200
Data sent successfully!
Sending to http://192.168.1.100:4000/api/sensors/ph-level/value: {"value":7.0}
HTTP Response: 200
Data sent successfully!
=== Update Complete ===
```

✅ **GOOD SIGN:** HTTP Response: 200 means data is being sent successfully

---

## ❌ Common Errors & Solutions

### Error 1: WiFi Failed to Connect

**Serial Output:**

```
Failed to connect to WiFi
WiFi Failed!
Running offline...
```

**Solutions:**

1. Double-check WIFI_SSID and WIFI_PASSWORD (case-sensitive!)
2. Make sure ESP32 is within range of your WiFi router
3. Try restarting ESP32 (press reset button)
4. Check if your WiFi is 2.4 GHz (ESP32 doesn't support 5 GHz)

---

### Error 2: HTTP Response 401 (Unauthorized)

**Serial Output:**

```
Sending to http://192.168.1.100:4000/api/sensors/turbidity/value: {"value":0.0}
HTTP Response: 401
Response: {"message":"Unauthorized"}
```

**Solutions:**

1. Your JWT token is invalid or expired
2. Get a fresh token using the login command above
3. Copy the ENTIRE token (it's very long)
4. Make sure there are no spaces before/after the token

---

### Error 3: HTTP Response 404 (Not Found)

**Serial Output:**

```
Sending to http://192.168.1.100:4000/api/sensors/turbidity/value: {"value":0.0}
HTTP Response: 404
Response: {"message":"Sensor not found"}
```

**Solutions:**

1. The sensor IDs in your database might not match
2. Check your `db.json` file has sensors with IDs:
   - `turbidity`
   - `tds`
   - `ph-level`

---

### Error 4: HTTP Error -1 (Connection Failed)

**Serial Output:**

```
Sending to http://192.168.1.100:4000/api/sensors/turbidity/value: {"value":0.0}
HTTP Error: connection failed
```

**Solutions:**

1. **Backend not running** - Start your backend server!
2. **Wrong IP address** - Use `ipconfig` to get correct IP
3. **Firewall blocking** - Allow Node.js through Windows Firewall
4. **Different networks** - ESP32 and computer must be on same WiFi

**Test connection from ESP32's perspective:**

```powershell
# On your computer, test if port 4000 is accessible:
Test-NetConnection -ComputerName localhost -Port 4000
```

---

### Error 5: HTTP Response 500 (Server Error)

**Serial Output:**

```
HTTP Response: 500
Response: {"message":"Internal server error"}
```

**Solutions:**

1. Check your backend terminal for error logs
2. Make sure `db.json` exists and is valid JSON
3. Restart your backend server

---

## 🎯 Step-by-Step Verification

### Test 1: Verify Backend is Running

```powershell
# In your project directory
npm start

# In another PowerShell window/tab:
curl http://localhost:4000/health
```

**Expected:** `{"ok":true,"service":"waterguard-backend"}`

---

### Test 2: Test Sensor Endpoint Manually

```powershell
# First, get a token (if you haven't already)
$response = curl -X POST http://localhost:4000/api/auth/login `
  -H "Content-Type: application/json" `
  -d '{\"email\":\"esp32@test.com\",\"password\":\"Test@1234\"}' | ConvertFrom-Json

$token = $response.token
Write-Host "Token: $token"

# Test updating turbidity sensor
curl -X PATCH http://localhost:4000/api/sensors/turbidity/value `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer $token" `
  -d '{\"value\":15.5}'
```

**Expected:** JSON response with updated sensor data

---

### Test 3: Check Sensor IDs in Database

```powershell
# View your database
Get-Content db.json | ConvertFrom-Json | Select-Object -ExpandProperty sensors | Format-Table id, name
```

**Expected output:**

```
id         name
--         ----
turbidity  Turbidity
tds        TDS (Total Dissolved Solids)
ph-level   pH Level
```

✅ IDs must match exactly: `turbidity`, `tds`, `ph-level`

---

### Test 4: Monitor Backend Logs

When ESP32 sends data, you should see in your backend terminal:

```
PATCH /api/sensors/turbidity/value 200 - 15.234 ms
PATCH /api/sensors/tds/value 200 - 12.345 ms
PATCH /api/sensors/ph-level/value 200 - 11.234 ms
```

---

## 🔥 Quick Fix: Allow Through Firewall

If connection fails, Windows Firewall might be blocking:

```powershell
# Run as Administrator
New-NetFirewallRule -DisplayName "WaterGuard Backend" -Direction Inbound -LocalPort 4000 -Protocol TCP -Action Allow
```

---

## 📊 What Success Looks Like

### On Serial Monitor (every 3 seconds):

```
Turb: 25 NTU (Clear)   |   TDS: 150 ppm (Fresh)   |   pH: 7.25 (Neutral/Good)
```

### Every 30 seconds:

```
=== Updating Firebase ===
Sending to http://192.168.1.100:4000/api/sensors/turbidity/value: {"value":25.0}
HTTP Response: 200
Data sent successfully!
[... repeated for TDS and pH ...]
=== Update Complete ===
```

### On OLED Display:

```
Water Quality
WiFi: ON
Turb: 25 NTU
TDS: 150 ppm
pH: 7.25
Status: Updated!
```

### In Backend Terminal:

```
PATCH /api/sensors/turbidity/value 200 - 12.345 ms
PATCH /api/sensors/tds/value 200 - 11.234 ms
PATCH /api/sensors/ph-level/value 200 - 10.123 ms
```

---

## 🆘 Still Having Issues?

### Copy and paste this information:

1. **Serial Monitor Output** (first 50 lines after upload)
2. **Backend Terminal Output** (any error messages)
3. **Your Configuration** (hide sensitive info):

   ```
   WIFI_SSID: "Home_WiFi"
   BACKEND_URL: "http://192.168.1.100:4000"
   JWT_TOKEN: "eyJhb..." (first 10 characters)
   Computer IP: 192.168.1.100
   ESP32 IP: 192.168.1.150
   Same network: Yes/No
   Backend running: Yes/No
   ```

4. **Test Results:**

   ```powershell
   # Backend health check
   curl http://localhost:4000/health

   # Can ESP32 reach backend? (from computer)
   Test-NetConnection -ComputerName YOUR_IP -Port 4000
   ```

---

## 📝 Notes

- ESP32 sends data every **30 seconds** to conserve bandwidth
- Display updates every **3 seconds** for responsive feedback
- Sensor readings are averaged over **30 samples** for stability
- JWT tokens don't expire in this implementation (for development)

---

Happy monitoring! 💧🌊
