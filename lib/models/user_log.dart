import 'package:cloud_firestore/cloud_firestore.dart';

enum UserActionType { login, logout, create, update, delete, access }

/// Model for user activity logs
class UserLog {
  final String id;
  final String userID;
  final UserActionType actionType;
  final String action;
  final String? targetResource; // what was acted upon (e.g., "product", "fabric", "jobOrder")
  final String? targetResourceID; // ID of the resource
  final Map<String, dynamic>? metadata; // additional context data
  final DateTime timestamp;
  final String? ipAddress;
  final String? userAgent;

  UserLog({
    required this.id,
    required this.userID,
    required this.actionType,
    required this.action,
    this.targetResource,
    this.targetResourceID,
    this.metadata,
    required this.timestamp,
    this.ipAddress,
    this.userAgent,
  });

  factory UserLog.fromMap(String id, Map<String, dynamic> data) {
    return UserLog(
      id: id,
      userID: data['userID'] ?? '',
      actionType: _actionTypeFromString(data['actionType'] ?? 'access'),
      action: data['action'] ?? '',
      targetResource: data['targetResource'],
      targetResourceID: data['targetResourceID'],
      metadata: data['metadata'] != null ? Map<String, dynamic>.from(data['metadata']) : null,
      timestamp: (data['timestamp'] is Timestamp)
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now(),
      ipAddress: data['ipAddress'],
      userAgent: data['userAgent'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userID': userID,
      'actionType': _actionTypeToString(actionType),
      'action': action,
      'targetResource': targetResource,
      'targetResourceID': targetResourceID,
      'metadata': metadata,
      'timestamp': timestamp,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
    };
  }

  static UserActionType _actionTypeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'login':
        return UserActionType.login;
      case 'logout':
        return UserActionType.logout;
      case 'create':
        return UserActionType.create;
      case 'update':
        return UserActionType.update;
      case 'delete':
        return UserActionType.delete;
      case 'access':
      default:
        return UserActionType.access;
    }
  }

  static String _actionTypeToString(UserActionType type) {
    switch (type) {
      case UserActionType.login:
        return 'login';
      case UserActionType.logout:
        return 'logout';
      case UserActionType.create:
        return 'create';
      case UserActionType.update:
        return 'update';
      case UserActionType.delete:
        return 'delete';
      case UserActionType.access:
        return 'access';
    }
  }
}
