import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_log.dart';

/// Service for managing user activity logs
class UserLogService {
  static const String _collection = 'userLogs';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Helper method to convert action type to string
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

  /// Create a new user log entry
  static Future<String> createUserLog(UserLog log) async {
    try {
      final docRef = await _firestore.collection(_collection).add(log.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating user log: $e');
      rethrow;
    }
  }

  /// Log user login
  static Future<void> logUserLogin({
    required String userID,
    String? ipAddress,
    String? userAgent,
    Map<String, dynamic>? metadata,
  }) async {
    final log = UserLog(
      id: '', // Will be set by Firestore
      userID: userID,
      actionType: UserActionType.login,
      action: 'User logged in',
      timestamp: DateTime.now(),
      ipAddress: ipAddress,
      userAgent: userAgent,
      metadata: metadata,
    );
    await createUserLog(log);
  }

  /// Log user logout
  static Future<void> logUserLogout({
    required String userID,
    String? ipAddress,
    String? userAgent,
    Map<String, dynamic>? metadata,
  }) async {
    final log = UserLog(
      id: '', // Will be set by Firestore
      userID: userID,
      actionType: UserActionType.logout,
      action: 'User logged out',
      timestamp: DateTime.now(),
      ipAddress: ipAddress,
      userAgent: userAgent,
      metadata: metadata,
    );
    await createUserLog(log);
  }

  /// Log resource creation
  static Future<void> logResourceCreation({
    required String userID,
    required String resourceType,
    required String resourceID,
    String? action,
    Map<String, dynamic>? metadata,
  }) async {
    final log = UserLog(
      id: '', // Will be set by Firestore
      userID: userID,
      actionType: UserActionType.create,
      action: action ?? 'Created $resourceType',
      targetResource: resourceType,
      targetResourceID: resourceID,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
    await createUserLog(log);
  }

  /// Log resource update
  static Future<void> logResourceUpdate({
    required String userID,
    required String resourceType,
    required String resourceID,
    String? action,
    Map<String, dynamic>? metadata,
  }) async {
    final log = UserLog(
      id: '', // Will be set by Firestore
      userID: userID,
      actionType: UserActionType.update,
      action: action ?? 'Updated $resourceType',
      targetResource: resourceType,
      targetResourceID: resourceID,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
    await createUserLog(log);
  }

  /// Log resource deletion
  static Future<void> logResourceDeletion({
    required String userID,
    required String resourceType,
    required String resourceID,
    String? action,
    Map<String, dynamic>? metadata,
  }) async {
    final log = UserLog(
      id: '', // Will be set by Firestore
      userID: userID,
      actionType: UserActionType.delete,
      action: action ?? 'Deleted $resourceType',
      targetResource: resourceType,
      targetResourceID: resourceID,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
    await createUserLog(log);
  }

  /// Log resource access/view
  static Future<void> logResourceAccess({
    required String userID,
    required String resourceType,
    required String resourceID,
    String? action,
    Map<String, dynamic>? metadata,
  }) async {
    final log = UserLog(
      id: '', // Will be set by Firestore
      userID: userID,
      actionType: UserActionType.access,
      action: action ?? 'Accessed $resourceType',
      targetResource: resourceType,
      targetResourceID: resourceID,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
    await createUserLog(log);
  }

  /// Get all logs for a specific user
  static Future<List<UserLog>> getUserLogs(String userID) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userID', isEqualTo: userID)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => UserLog.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching user logs: $e');
      return [];
    }
  }

  /// Get logs for a specific resource
  static Future<List<UserLog>> getResourceLogs(String resourceType, String resourceID) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('targetResource', isEqualTo: resourceType)
          .where('targetResourceID', isEqualTo: resourceID)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => UserLog.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching resource logs: $e');
      return [];
    }
  }

  /// Get logs within a date range
  static Future<List<UserLog>> getLogsInDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? userID,
    UserActionType? actionType,
  }) async {
    try {
      Query query = _firestore.collection(_collection);

      if (userID != null) {
        query = query.where('userID', isEqualTo: userID);
      }

      if (actionType != null) {
        query = query.where('actionType', isEqualTo: _actionTypeToString(actionType));
      }

      query = query
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .orderBy('timestamp', descending: true);

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => UserLog.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching logs in date range: $e');
      return [];
    }
  }

  /// Get all user logs with pagination
  static Future<List<UserLog>> getAllUserLogs({
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
          .map((doc) => UserLog.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching all user logs: $e');
      return [];
    }
  }

  /// Stream of user logs for real-time updates
  static Stream<List<UserLog>> streamUserLogs(String userID) {
    return _firestore
        .collection(_collection)
        .where('userID', isEqualTo: userID)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserLog.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Clean up old logs (for privacy/compliance)
  static Future<void> cleanUpOldLogs({
    required Duration maxAge,
    int? batchSize,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(maxAge);
      final query = _firestore
          .collection(_collection)
          .where('timestamp', isLessThan: cutoffDate)
          .limit(batchSize ?? 100);

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
        await cleanUpOldLogs(maxAge: maxAge, batchSize: batchSize);
      }
    } catch (e) {
      print('Error cleaning up old user logs: $e');
    }
  }
}
