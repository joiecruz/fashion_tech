import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';

class LoginBackend {
  /// Sign in using email and password
  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Create a new user with email and password
  static Future<UserCredential> createUserWithEmail({
    required String email,
    required String password,
  }) async {
    return await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign out the current user
  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  /// Get the current user
  static User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }

  /// Send password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  /// Check if user is signed in
  static bool isUserSignedIn() {
    return FirebaseAuth.instance.currentUser != null;
  }

  /// Sign in with Google (To be implemented when Google Sign-In is configured)
  static Future<UserCredential?> signInWithGoogle() async {
    throw UnimplementedError('Google sign-in not yet configured');
  }

  /// Sign in with Apple (To be implemented when Apple Sign-In is configured)
  static Future<UserCredential?> signInWithApple() async {
    throw UnimplementedError('Apple sign-in not yet configured');
  }
}
