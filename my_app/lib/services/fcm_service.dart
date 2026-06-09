import 'package:firebase_messaging/firebase_messaging.dart';
import 'fcm_api_service.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static late String fcmToken;
  static final FCMApiService _fcmApiService = FCMApiService();

  /// Initialize FCM and request permissions
  static Future<void> initialize() async {
    try {
      // Request notification permissions (iOS)
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted permission for notifications');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('User granted provisional permission for notifications');
      } else {
        debugPrint('User denied notification permission');
      }

      // Get FCM token
      fcmToken = await _firebaseMessaging.getToken() ?? '';
      debugPrint('FCM Token: $fcmToken');

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        fcmToken = newToken;
        debugPrint('FCM Token refreshed: $newToken');
        // Register new token with backend
        _fcmApiService.registerFCMToken(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Message received in foreground');
        debugPrint('Title: ${message.notification?.title}');
        debugPrint('Body: ${message.notification?.body}');
        debugPrint('Data: ${message.data}');
        // TODO: Show local notification or update UI here
      });

      // Handle when app is opened from notification (when it was terminated)
      FirebaseMessaging.instance.getInitialMessage().then((
        RemoteMessage? message,
      ) {
        if (message != null) {
          debugPrint('App launched from notification');
          debugPrint('Title: ${message.notification?.title}');
          debugPrint('Body: ${message.notification?.body}');
          // TODO: Navigate to relevant page based on notification
        }
      });

      // Handle when app is opened from notification (when it was in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened from background notification');
        debugPrint('Title: ${message.notification?.title}');
        debugPrint('Body: ${message.notification?.body}');
        // TODO: Navigate to relevant page based on notification
      });
    } catch (e) {
      debugPrint('Error initializing FCM: $e');
    }
  }

  /// Get the current FCM token
  static String getToken() {
    return fcmToken;
  }

  /// Register token with backend after user login
  static void registerTokenWithBackend() {
    _fcmApiService.registerFCMToken(fcmToken);
  }

  /// Unregister token from backend before logout
  static void unregisterTokenFromBackend() {
    _fcmApiService.unregisterFCMToken(fcmToken);
  }
}
