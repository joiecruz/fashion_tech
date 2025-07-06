import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as AppUser;

class UserService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current user's role from Firestore
  static Future<AppUser.UserRole?> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data['role'] != null) {
          return AppUser.User.roleFromString(data['role']);
        }
      }
      
      // If no role found in Firestore, check email prefix for backward compatibility
      final email = user.email?.toLowerCase() ?? '';
      if (email.startsWith('admin')) {
        // Set the role in Firestore for future use
        await _firestore.collection('users').doc(user.uid).set({
          'role': 'admin',
          'email': user.email,
          'fullName': user.displayName ?? '',
          'username': user.email?.split('@')[0] ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'canAccessInventory': true,
        }, SetOptions(merge: true));
        
        return AppUser.UserRole.admin;
      }
      
      // Default role for new users
      return AppUser.UserRole.worker;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  /// Check if current user is admin
  static Future<bool> isCurrentUserAdmin() async {
    final role = await getCurrentUserRole();
    return role == AppUser.UserRole.admin;
  }

  /// Check if current user is admin or owner
  static Future<bool> isCurrentUserAdminOrOwner() async {
    final role = await getCurrentUserRole();
    return role == AppUser.UserRole.admin || role == AppUser.UserRole.owner;
  }

  /// Get current user data from Firestore
  static Future<AppUser.User?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          return AppUser.User.fromMap(user.uid, data);
        }
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  /// Update user role (admin only function)
  static Future<void> updateUserRole(String userId, AppUser.UserRole newRole) async {
    final currentUserRole = await getCurrentUserRole();
    if (currentUserRole != AppUser.UserRole.admin) {
      throw Exception('Only admins can update user roles');
    }

    await _firestore.collection('users').doc(userId).update({
      'role': AppUser.User.roleToString(newRole),
    });
  }

  /// Create user document in Firestore
  static Future<void> createUserDocument({
    required String userId,
    required String email,
    required String fullName,
    String? username,
    AppUser.UserRole role = AppUser.UserRole.worker,
  }) async {
    await _firestore.collection('users').doc(userId).set({
      'email': email,
      'fullName': fullName,
      'username': username ?? email.split('@')[0],
      'role': AppUser.User.roleToString(role),
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'canAccessInventory': role == AppUser.UserRole.admin || role == AppUser.UserRole.owner,
    });
  }
}
