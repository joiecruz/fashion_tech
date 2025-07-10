import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupBackend {
  static Future<UserCredential> registerUser({
    required String username,
    required String email,
    required String fullname,
    required String password,
  }) async {
    // Create user account
    final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Update display name
    await userCredential.user?.updateDisplayName(username.trim());

    // Create user document in Firestore
    await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).set({
      'username': username.trim(),
      'fullname': fullname.trim(),
      'email': email.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'role': 'user',
      'isActive': true,
    });

    return userCredential;
  }
}