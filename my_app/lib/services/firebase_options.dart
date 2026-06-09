import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBE76kP1EXlEKItN6nxE7VLCtBbcgDaH9U',
    appId: '1:692831002533:android:e7acd28826d54d2c9d524c',
    messagingSenderId: '692831002533',
    projectId: 'waterguard-e1a02',
    storageBucket: 'waterguard-e1a02.firebasestorage.app',
  );
}
