import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/job_order_log.dart';

/// Service for managing job order logs
class JobOrderLogService {
  static const String _collection = 'jobOrderLogs';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new job order log entry
  static Future<String> createJobOrderLog(JobOrderLog log) async {
    try {
      final docRef = await _firestore.collection(_collection).add(log.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating job order log: $e');
      rethrow;
    }
  }

  /// Log a status update for a job order
  static Future<void> logStatusUpdate({
    required String jobOrderID,
    required String previousStatus,
    required String newStatus,
    required String changedBy,
    String? notes,
  }) async {
    final log = JobOrderLog(
      id: '', // Will be set by Firestore
      jobOrderID: jobOrderID,
      changeType: JobOrderChangeType.statusUpdate,
      previousValue: previousStatus,
      newValue: newStatus,
      notes: notes ?? 'Status changed from $previousStatus to $newStatus',
      changedBy: changedBy,
      timestamp: DateTime.now(),
    );
    await createJobOrderLog(log);
  }

  /// Log a reassignment of a job order
  static Future<void> logReassignment({
    required String jobOrderID,
    required String previousAssignee,
    required String newAssignee,
    required String changedBy,
    String? notes,
  }) async {
    final log = JobOrderLog(
      id: '', // Will be set by Firestore
      jobOrderID: jobOrderID,
      changeType: JobOrderChangeType.reassign,
      previousValue: previousAssignee,
      newValue: newAssignee,
      notes: notes ?? 'Reassigned from $previousAssignee to $newAssignee',
      changedBy: changedBy,
      timestamp: DateTime.now(),
    );
    await createJobOrderLog(log);
  }

  /// Log an edit to a job order
  static Future<void> logEdit({
    required String jobOrderID,
    required String fieldChanged,
    String? previousValue,
    required String newValue,
    required String changedBy,
    String? notes,
  }) async {
    final log = JobOrderLog(
      id: '', // Will be set by Firestore
      jobOrderID: jobOrderID,
      changeType: JobOrderChangeType.edit,
      previousValue: previousValue,
      newValue: newValue,
      notes: notes ?? 'Updated $fieldChanged',
      changedBy: changedBy,
      timestamp: DateTime.now(),
    );
    await createJobOrderLog(log);
  }

  /// Get all logs for a specific job order
  static Future<List<JobOrderLog>> getJobOrderLogs(String jobOrderID) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('jobOrderID', isEqualTo: jobOrderID)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => JobOrderLog.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching job order logs: $e');
      return [];
    }
  }

  /// Get all logs with pagination
  static Future<List<JobOrderLog>> getAllJobOrderLogs({
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
          .map((doc) => JobOrderLog.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching all job order logs: $e');
      return [];
    }
  }

  /// Stream of job order logs for real-time updates
  static Stream<List<JobOrderLog>> streamJobOrderLogs(String jobOrderID) {
    return _firestore
        .collection(_collection)
        .where('jobOrderID', isEqualTo: jobOrderID)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JobOrderLog.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Delete all logs for a job order (used when job order is permanently deleted)
  static Future<void> deleteJobOrderLogs(String jobOrderID) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('jobOrderID', isEqualTo: jobOrderID)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error deleting job order logs: $e');
    }
  }
}
