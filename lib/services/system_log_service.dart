import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/system_log.dart';

/// Service for managing system logs
class SystemLogService {
  static const String _collection = 'systemLogs';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new system log entry
  static Future<String> createSystemLog(SystemLog log) async {
    try {
      final docRef = await _firestore.collection(_collection).add(log.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating system log: $e');
      rethrow;
    }
  }

  /// Log an info message
  static Future<void> logInfo({
    required String message,
    required SystemLogCategory category,
    String? component,
    Map<String, dynamic>? metadata,
    String? userID,
    String? sessionID,
  }) async {
    final log = SystemLog(
      id: '', // Will be set by Firestore
      level: SystemLogLevel.info,
      category: category,
      message: message,
      component: component,
      metadata: metadata,
      timestamp: DateTime.now(),
      userID: userID,
      sessionID: sessionID,
    );
    await createSystemLog(log);
  }

  /// Log a warning message
  static Future<void> logWarning({
    required String message,
    required SystemLogCategory category,
    String? component,
    Map<String, dynamic>? metadata,
    String? userID,
    String? sessionID,
  }) async {
    final log = SystemLog(
      id: '', // Will be set by Firestore
      level: SystemLogLevel.warning,
      category: category,
      message: message,
      component: component,
      metadata: metadata,
      timestamp: DateTime.now(),
      userID: userID,
      sessionID: sessionID,
    );
    await createSystemLog(log);
  }

  /// Log an error message
  static Future<void> logError({
    required String message,
    required SystemLogCategory category,
    String? component,
    String? errorDetails,
    Map<String, dynamic>? metadata,
    String? userID,
    String? sessionID,
  }) async {
    final log = SystemLog(
      id: '', // Will be set by Firestore
      level: SystemLogLevel.error,
      category: category,
      message: message,
      component: component,
      errorDetails: errorDetails,
      metadata: metadata,
      timestamp: DateTime.now(),
      userID: userID,
      sessionID: sessionID,
    );
    await createSystemLog(log);
  }

  /// Log a critical error message
  static Future<void> logCritical({
    required String message,
    required SystemLogCategory category,
    String? component,
    String? errorDetails,
    Map<String, dynamic>? metadata,
    String? userID,
    String? sessionID,
  }) async {
    final log = SystemLog(
      id: '', // Will be set by Firestore
      level: SystemLogLevel.critical,
      category: category,
      message: message,
      component: component,
      errorDetails: errorDetails,
      metadata: metadata,
      timestamp: DateTime.now(),
      userID: userID,
      sessionID: sessionID,
    );
    await createSystemLog(log);
  }

  /// Log a debug message
  static Future<void> logDebug({
    required String message,
    required SystemLogCategory category,
    String? component,
    Map<String, dynamic>? metadata,
    String? userID,
    String? sessionID,
  }) async {
    final log = SystemLog(
      id: '', // Will be set by Firestore
      level: SystemLogLevel.debug,
      category: category,
      message: message,
      component: component,
      metadata: metadata,
      timestamp: DateTime.now(),
      userID: userID,
      sessionID: sessionID,
    );
    await createSystemLog(log);
  }

  /// Get logs by level
  static Future<List<SystemLog>> getLogsByLevel(SystemLogLevel level) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('level', isEqualTo: _levelToString(level))
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => SystemLog.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching logs by level: $e');
      return [];
    }
  }

  /// Get logs by category
  static Future<List<SystemLog>> getLogsByCategory(SystemLogCategory category) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('category', isEqualTo: _categoryToString(category))
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => SystemLog.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching logs by category: $e');
      return [];
    }
  }

  /// Get logs by component
  static Future<List<SystemLog>> getLogsByComponent(String component) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('component', isEqualTo: component)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => SystemLog.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching logs by component: $e');
      return [];
    }
  }

  /// Get logs within a date range
  static Future<List<SystemLog>> getLogsInDateRange({
    required DateTime startDate,
    required DateTime endDate,
    SystemLogLevel? level,
    SystemLogCategory? category,
  }) async {
    try {
      Query query = _firestore.collection(_collection);

      if (level != null) {
        query = query.where('level', isEqualTo: _levelToString(level));
      }

      if (category != null) {
        query = query.where('category', isEqualTo: _categoryToString(category));
      }

      query = query
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .orderBy('timestamp', descending: true);

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => SystemLog.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching logs in date range: $e');
      return [];
    }
  }

  /// Get all system logs with pagination
  static Future<List<SystemLog>> getAllSystemLogs({
    int? limit,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .orderBy('timestamp', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => SystemLog.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching all system logs: $e');
      return [];
    }
  }

  /// Stream of system logs for real-time monitoring
  static Stream<List<SystemLog>> streamSystemLogs({
    SystemLogLevel? level,
    SystemLogCategory? category,
    int? limit,
  }) {
    Query query = _firestore.collection(_collection);

    if (level != null) {
      query = query.where('level', isEqualTo: _levelToString(level));
    }

    if (category != null) {
      query = query.where('category', isEqualTo: _categoryToString(category));
    }

    query = query.orderBy('timestamp', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => SystemLog.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList());
  }

  /// Clean up old logs (for storage management)
  static Future<void> cleanUpOldLogs({
    required Duration maxAge,
    int? batchSize,
    SystemLogLevel? minLevel, // only clean logs below this level
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(maxAge);
      Query query = _firestore
          .collection(_collection)
          .where('timestamp', isLessThan: cutoffDate);

      // If minLevel is specified, only clean logs below that level
      if (minLevel != null) {
        final levelsToClean = <String>[];
        for (final level in SystemLogLevel.values) {
          if (level.index < minLevel.index) {
            levelsToClean.add(_levelToString(level));
          }
        }
        if (levelsToClean.isNotEmpty) {
          query = query.where('level', whereIn: levelsToClean);
        }
      }

      query = query.limit(batchSize ?? 100);

      final querySnapshot = await query.get();
      
      if (querySnapshot.docs.isEmpty) {
        return; // No old logs to delete
      }

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // If we got a full batch, there might be more to delete
      if (querySnapshot.docs.length == (batchSize ?? 100)) {
        await cleanUpOldLogs(maxAge: maxAge, batchSize: batchSize, minLevel: minLevel);
      }
    } catch (e) {
      print('Error cleaning up old system logs: $e');
    }
  }

  /// Helper methods for string conversion
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
