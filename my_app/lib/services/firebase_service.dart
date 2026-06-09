import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveUserData({
    required String userId,
    required String fullName,
    required String email,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'fullName': fullName,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to save user data to Firebase: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      throw Exception('Failed to fetch user data from Firebase: $e');
    }
  }

  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update user data in Firebase: $e');
    }
  }
}
