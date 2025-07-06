import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, owner, worker }

class User {
  final String id;
  final String fullName;
  final String username;
  final String password; // This should be hashed in production
  final UserRole role;
  final bool canAccessInventory;
  final String email;
  final String? profileImageURL;
  final DateTime createdAt;
  final bool isActive;

  User({
    required this.id,
    required this.fullName,
    required this.username,
    required this.password,
    required this.role,
    required this.canAccessInventory,
    required this.email,
    this.profileImageURL,
    required this.createdAt,
    required this.isActive,
  });

  factory User.fromMap(String id, Map<String, dynamic> data) {
    return User(
      id: id,
      fullName: data['fullName'] ?? '',
      username: data['username'] ?? '',
      password: data['password'] ?? '',
      role: roleFromString(data['role'] ?? 'worker'),
      canAccessInventory: data['canAccessInventory'] ?? false,
      email: data['email'] ?? '',
      profileImageURL: data['profileImageURL'],
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'username': username,
      'password': password,
      'role': roleToString(role),
      'canAccessInventory': canAccessInventory,
      'email': email,
      'profileImageURL': profileImageURL,
      'createdAt': createdAt,
      'isActive': isActive,
    };
  }

  static UserRole roleFromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'owner':
        return UserRole.owner;
      case 'worker':
        return UserRole.worker;
      default:
        return UserRole.worker;
    }
  }

  static String roleToString(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.owner:
        return 'owner';
      case UserRole.worker:
        return 'worker';
    }
  }
}
