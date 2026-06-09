# Push Notifications Setup Guide

This document outlines the push notification infrastructure that has been set up for WaterGuard.

## What's Been Implemented

### 1. Flutter App (my_app)

- **Firebase Cloud Messaging (FCM)** integration via `firebase_messaging: ^14.8.0` package
- **Automatic permission requests** for iOS notifications
- **Foreground message handling** - notifications show when app is in focus
- **Background message handling** - notifications processed when app is minimized
- **Message handlers** for when notifications are tapped (navigate to relevant pages)
- **FCM token management**:
  - Token automatically registered with backend on user login
  - Token automatically unregistered from backend on user logout
  - Handles token refresh and re-registration

### 2. Backend (waterguard_backend)

- **FCM token registration endpoints**:
  - `POST /api/fcm/register-token` - Save device token for authenticated user
  - `POST /api/fcm/unregister-token` - Remove device token
- **Notification service** (`notification_service.js`):
  - `sendNotification()` - Send to single device
  - `sendMulticastNotification()` - Send to multiple devices
  - Uses Firebase Admin SDK for actual message delivery

### 3. Services Created

- `lib/services/fcm_service.dart` - FCM initialization, permission requests, message handlers
- `lib/services/fcm_api_service.dart` - HTTP API calls to register/unregister tokens
- `src/services/notification_service.js` - Backend notification sending

## What Still Needs Configuration

### In Firebase Console

1. **Enable Cloud Messaging**:
   - Go to Firebase Console → Project Settings → Cloud Messaging tab
   - Ensure Firebase Cloud Messaging API is enabled

2. **iOS Configuration**:
   - Upload Apple Push Notification (APN) certificate
   - In Firebase Console → Project Settings → Cloud Messaging → iOS app configuration
   - Upload the APNs certificate or key from Apple Developer Account

3. **Android Configuration**:
   - Add Firebase project's Sender ID and Server API Key to Android native configuration
   - This is typically auto-configured by Firebase when you add google-services.json

### iOS App Setup

- **In Runner.pbxproj** (or via XCode):
  - Enable "Push Notifications" capability
  - Enable "Background Modes" with "Remote notifications" checked

### Android App Setup

- **Already configured** - google-services.json should handle most setup
- May need to ensure AndroidManifest.xml has proper permissions (usually auto-added by Flutter)

## How to Send Push Notifications

Once everything is configured, the backend can send notifications like this:

```javascript
const { sendNotification } = require("./src/services/notification_service");

// Get user's device tokens from Firestore
const tokens = await db
  .collection("users")
  .doc(userId)
  .collection("deviceTokens")
  .get();

// Send notification to all user's devices
for (const tokenDoc of tokens.docs) {
  await sendNotification(
    tokenDoc.data().token,
    "Water Alert",
    "pH level out of range: 8.5",
    { sensorId: "sensor-123", value: "8.5" },
  );
}
```

## Integration with Sensor Alerts

To automatically send notifications when sensors trigger alerts:

1. **In the backend sensor ingestion endpoint** (`/api/sensors/ingest`):

   ```javascript
   // After analyzing sensor data
   if (sensorStatus === "danger" || sensorStatus === "warning") {
     // Get user's device tokens
     // Send push notification via FCMService
   }
   ```

2. **The notification will then**:
   - Show on user's lock screen (if app is closed)
   - Show in notification drawer
   - Display in-app if user is actively using the app
   - Can include tap actions to navigate to sensor details

## Testing Push Notifications

### Firebase Console Test

1. Go to Firebase Console → Cloud Messaging
2. Create a test message
3. Select your app and device
4. Send test notification
5. Check if it arrives on device

### Backend Test

```bash
# From Node.js backend
const admin = require('firebase-admin');
await admin.messaging().send({
  token: 'device-token-here',
  notification: {
    title: 'Test',
    body: 'Test notification'
  }
});
```

## Environment Variables Needed

Backend (.env):

- `FIREBASE_PROJECT_ID` - Your Firebase project ID
- `FIREBASE_PRIVATE_KEY` - Private key from Firebase service account
- `FIREBASE_CLIENT_EMAIL` - Service account email

(These may already be configured if Firebase Admin SDK is initialized)

## Current Status

✓ Firebase Cloud Messaging package added to pubspec.yaml
✓ FCM service created and initialized in main.dart
✓ Notification permissions requested on app startup
✓ Foreground and background message handling
✓ FCM token registration/unregistration with backend
✓ Backend endpoints for token management
✓ Backend notification sending service

⚠️ Still needed:

- iOS APNs certificate upload to Firebase
- Android google-services.json configuration verification
- Sensor data ingestion → push notification integration
- Testing on physical devices (both iOS and Android)
- Navigation handling when notifications are tapped

## Key Files Modified

- `pubspec.yaml` - Added firebase_messaging dependency
- `lib/main.dart` - Initialized FCM and background message handler
- `lib/services/fcm_service.dart` - FCM initialization and message handling
- `lib/services/fcm_api_service.dart` - Token registration API calls
- `lib/services/auth_api_service.dart` - Token registration on login/logout
- `waterguard_backend/package.json` - Already had firebase-admin
- `src/routes/fcm.js` - New FCM token management endpoints
- `src/services/notification_service.js` - New push notification service
- `src/server.js` - Added FCM routes
