# Device Token Implementation Guide

## Overview

The device token system provides **secure Firestore access for ESP32 devices** without exposing Firebase admin credentials. Instead of hard-coding access tokens, devices request short-lived tokens from the backend using a simple ID + secret authentication scheme.

## Architecture

```
ESP32 Device
    ↓ (POST /api/device/token with deviceId + deviceSecret)
Backend (validates credentials)
    ↓ (calls Firebase Admin SDK)
Backend mints custom Firebase token (1 hour validity)
    ↓ (returns token in response)
ESP32 Device (caches token)
    ↓ (uses token in Firestore REST API calls)
Firestore (validates token signature with Firebase public key)
    ↓ (accepts write if token is valid and signed by backend)
Document stored in raw_esp32 collection
```

## Configuration

### Backend Setup (.env)

Add device secrets to your `.env` file:

```bash
# Option 1: Single shared secret for all devices (simplest)
DEVICE_SECRET=waterguard-device-secret-123

# Option 2: Per-device secrets (more secure)
# DEVICE_SECRETS=device-001:secret1,device-002:secret2,device-003:secret3
```

**Note**: The shared secret option is fine for development/testing. For production, use per-device secrets.

### ESP32 Setup (sketch configuration)

At the top of your `waterguard_esp32_sensors_v2.ino` sketch, set:

```cpp
// Device authentication for token minting
#define DEVICE_ID "device-001"
#define DEVICE_SECRET "waterguard-device-secret-123"

// Backend token endpoint
#define BACKEND_TOKEN_ENDPOINT "/api/device/token"
```

Make sure these match the backend configuration.

## Testing

### 1. Start the Backend

```bash
cd waterguard_backend
npm start
```

You should see:

```
✓ Express listening on port 4000
✓ Firestore listener started
```

### 2. Test the Token Endpoint

Run the test script:

```bash
# Test with default values
node test-device-token.js

# Test with custom values
node test-device-token.js http://localhost:4000 device-001 waterguard-device-secret-123
```

Expected output:

```
🧪 Testing Device Token Endpoint

Base URL: http://localhost:4000
Device ID: device-001
Device Secret: waterguard-device-secret-123

Test 1: Valid credentials
POST http://localhost:4000/api/device/token
Status: 200
Response: {
  "ok": true,
  "token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600
}
✅ Token obtained successfully
Token length: 892 characters
Expires in: 3600 seconds

Test 2: Missing deviceId (should fail)
Status: 400
Response: {
  "ok": false,
  "message": "deviceId and deviceSecret required"
}
✅ Correctly rejected missing deviceId

Test 3: Invalid credentials (should fail)
Status: 401
Response: {
  "ok": false,
  "message": "Invalid device credentials"
}
✅ Correctly rejected invalid credentials

✅ All tests completed!
```

### 3. Manual API Test (with curl)

```bash
# Get a token
curl -X POST http://localhost:4000/api/device/token \
  -H "Content-Type: application/json" \
  -d '{
    "deviceId": "device-001",
    "deviceSecret": "waterguard-device-secret-123"
  }'

# Response:
# {
#   "ok": true,
#   "token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
#   "expiresIn": 3600
# }
```

## How It Works

### Step 1: ESP32 Requests Token

When the ESP32 boots or token is near expiration (within 5 minutes), it calls:

```cpp
String token = requestFirestoreToken();
```

This function:

1. Checks if cached token is still valid (more than 5 min remaining)
2. If valid, returns cached token
3. Otherwise, POSTs to `/api/device/token` with `{ deviceId, deviceSecret }`
4. Backend validates credentials and returns custom Firebase token
5. Token is cached with expiration time

### Step 2: Backend Validates & Mints Token

`src/routes/deviceToken.js` handles the request:

```javascript
POST /api/device/token
Content-Type: application/json

{
  "deviceId": "device-001",
  "deviceSecret": "waterguard-device-secret-123"
}
```

Backend:

1. Validates `deviceId` and `deviceSecret` match environment configuration
2. Calls `admin.auth().createCustomToken(deviceId, claims)`
3. Firebase signs token with backend's service account private key
4. Returns token with 1-hour expiration

### Step 3: ESP32 Uses Token

When writing to Firestore, ESP32:

```cpp
String token = requestFirestoreToken();
http.addHeader("Authorization", "Bearer " + token);
// POST to Firestore with token in Authorization header
```

### Step 4: Firestore Validates

Firestore validates token:

1. Verifies JWT signature using Firebase public key
2. Confirms token is signed by the service account (backend)
3. Checks expiration time
4. Allows write if all checks pass

## Security Properties

✅ **No hardcoded credentials** - Only device ID and secret are configured  
✅ **Short-lived tokens** - Tokens expire after 1 hour  
✅ **Firebase validation** - Tokens are cryptographically signed by backend  
✅ **Automatic refresh** - ESP32 refreshes token before expiration (5 min margin)  
✅ **Per-device secrets** - Can configure different secrets for different devices  
✅ **Graceful fallback** - ESP32 retries with stale token if token request fails

## Troubleshooting

### Token request fails with "Invalid device credentials"

**Check**:

- `DEVICE_ID` in sketch matches one of the device IDs in backend config
- `DEVICE_SECRET` in sketch matches backend config
- Backend `.env` has `DEVICE_SECRET` or `DEVICE_SECRETS` set

### Token request times out

**Check**:

- Backend is running: `npm start`
- ESP32 can reach backend (WiFi connected, firewall rules)
- Check ESP32 serial output for connection details

### Firestore write fails even with token

**Check**:

- Token is being requested (check Serial output: "Firestore token obtained")
- Firestore security rules allow writes from devices with `isDevice: true` claim
- `raw_esp32` collection exists (auto-created on first write)

### Multiple devices with different secrets

Use `DEVICE_SECRETS` format in .env:

```bash
DEVICE_SECRETS=device-001:secret1,device-002:secret2,device-003:secret3
```

Each device must set its own `DEVICE_ID` and `DEVICE_SECRET` in the sketch.

## Next Steps

1. ✅ Backend token endpoint implemented
2. ✅ ESP32 token request & caching implemented
3. ✅ Configuration documented
4. **→ Test with real ESP32 hardware** (flash updated sketch, monitor Serial)
5. **→ Monitor Firestore** for incoming documents in `raw_esp32`
6. **→ Verify backend listener** processes documents correctly
7. **→ Check sensor_data** collection for normalized values

## Implementation Details

### Token Endpoint (`src/routes/deviceToken.js`)

- **Route**: `POST /api/device/token`
- **Input**: `{ deviceId: string, deviceSecret: string }`
- **Output**: `{ ok: boolean, token: string, expiresIn: number }`
- **Auth modes**:
  - `DEVICE_SECRET`: Single shared secret for all devices
  - `DEVICE_SECRETS`: Comma-separated `deviceId:secret` pairs

### ESP32 Token Request (`waterguard_esp32_sensors_v2.ino`)

- **Function**: `requestFirestoreToken()`
- **Caching**: Stores token with expiration time
- **Refresh margin**: 5 minutes (refreshes token when within 5 min of expiration)
- **Fallback**: Returns stale token if request fails
- **Safety checks**: Validates WiFi connection and heap space before requesting

### Firestore Security Rules

The token includes custom claims that can be used in security rules:

```javascript
// In Firestore rules, validate device writes:
match /raw_esp32/{document=**} {
  allow write: if request.auth != null &&
               request.auth.token.isDevice == true &&
               request.auth.uid == request.resource.data.deviceId;
}
```

## References

- Firebase Custom Tokens: https://firebase.google.com/docs/auth/admin/create-custom-tokens
- Firestore REST API: https://cloud.google.com/firestore/docs/reference/rest
- Firestore Security Rules: https://firebase.google.com/docs/firestore/security/start
