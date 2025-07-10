import 'package:cloud_firestore/cloud_firestore.dart';

enum SystemLogLevel { info, warning, error, critical, debug }
enum SystemLogCategory { database, authentication, backup, performance, security, integration }

/// Model for system logs
class SystemLog {
  final String id;
  final SystemLogLevel level;
  final SystemLogCategory category;
  final String message;
  final String? component; // which part of the system generated the log
  final Map<String, dynamic>? metadata; // additional context data
  final String? errorDetails; // for errors, stack trace or detailed error info
  final DateTime timestamp;
  final String? userID; // if related to a specific user action
  final String? sessionID; // if related to a specific session

  SystemLog({
    required this.id,
    required this.level,
    required this.category,
    required this.message,
    this.component,
    this.metadata,
    this.errorDetails,
    required this.timestamp,
    this.userID,
    this.sessionID,
  });

  factory SystemLog.fromMap(String id, Map<String, dynamic> data) {
    return SystemLog(
      id: id,
      level: _levelFromString(data['level'] ?? 'info'),
      category: _categoryFromString(data['category'] ?? 'database'),
      message: data['message'] ?? '',
      component: data['component'],
      metadata: data['metadata'] != null ? Map<String, dynamic>.from(data['metadata']) : null,
      errorDetails: data['errorDetails'],
      timestamp: (data['timestamp'] is Timestamp)
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now(),
      userID: data['userID'],
      sessionID: data['sessionID'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'level': _levelToString(level),
      'category': _categoryToString(category),
      'message': message,
      'component': component,
      'metadata': metadata,
      'errorDetails': errorDetails,
      'timestamp': timestamp,
      'userID': userID,
      'sessionID': sessionID,
    };
  }

  static SystemLogLevel _levelFromString(String level) {
    switch (level.toLowerCase()) {
      case 'info':
        return SystemLogLevel.info;
      case 'warning':
        return SystemLogLevel.warning;
      case 'error':
        return SystemLogLevel.error;
      case 'critical':
        return SystemLogLevel.critical;
      case 'debug':
        return SystemLogLevel.debug;
      default:
        return SystemLogLevel.info;
    }
  }

  static String _levelToString(SystemLogLevel level) {
    switch (level) {
      case SystemLogLevel.info:
        return 'info';
      case SystemLogLevel.warning:
        return 'warning';
      case SystemLogLevel.error:
        return 'error';
      case SystemLogLevel.critical:
        return 'critical';
      case SystemLogLevel.debug:
        return 'debug';
    }
  }

  static SystemLogCategory _categoryFromString(String category) {
    switch (category.toLowerCase()) {
      case 'database':
        return SystemLogCategory.database;
      case 'authentication':
        return SystemLogCategory.authentication;
      case 'backup':
        return SystemLogCategory.backup;
      case 'performance':
        return SystemLogCategory.performance;
      case 'security':
        return SystemLogCategory.security;
      case 'integration':
        return SystemLogCategory.integration;
      default:
        return SystemLogCategory.database;
    }
  }

  static String _categoryToString(SystemLogCategory category) {
    switch (category) {
      case SystemLogCategory.database:
        return 'database';
      case SystemLogCategory.authentication:
        return 'authentication';
      case SystemLogCategory.backup:
        return 'backup';
      case SystemLogCategory.performance:
        return 'performance';
      case SystemLogCategory.security:
        return 'security';
      case SystemLogCategory.integration:
        return 'integration';
    }
  }
}
