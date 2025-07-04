import 'package:cloud_firestore/cloud_firestore.dart';

enum JobOrderChangeType { statusUpdate, reassign, edit }

class JobOrderLog {
  final String id;
  final String jobOrderID;
  final JobOrderChangeType changeType;
  final String? previousValue;
  final String newValue;
  final String? notes;
  final String changedBy;
  final DateTime timestamp;

  JobOrderLog({
    required this.id,
    required this.jobOrderID,
    required this.changeType,
    this.previousValue,
    required this.newValue,
    this.notes,
    required this.changedBy,
    required this.timestamp,
  });

  factory JobOrderLog.fromMap(String id, Map<String, dynamic> data) {
    return JobOrderLog(
      id: id,
      jobOrderID: data['jobOrderID'] ?? '',
      changeType: _changeTypeFromString(data['changeType'] ?? 'edit'),
      previousValue: data['previousValue'],
      newValue: data['newValue'] ?? '',
      notes: data['notes'],
      changedBy: data['changedBy'] ?? '',
      timestamp: (data['timestamp'] is Timestamp)
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jobOrderID': jobOrderID,
      'changeType': _changeTypeToString(changeType),
      'previousValue': previousValue,
      'newValue': newValue,
      'notes': notes,
      'changedBy': changedBy,
      'timestamp': timestamp,
    };
  }

  static JobOrderChangeType _changeTypeFromString(String changeType) {
    switch (changeType.toLowerCase()) {
      case 'statusupdate':
      case 'status_update':
        return JobOrderChangeType.statusUpdate;
      case 'reassign':
        return JobOrderChangeType.reassign;
      case 'edit':
        return JobOrderChangeType.edit;
      default:
        return JobOrderChangeType.edit;
    }
  }

  static String _changeTypeToString(JobOrderChangeType changeType) {
    switch (changeType) {
      case JobOrderChangeType.statusUpdate:
        return 'statusUpdate';
      case JobOrderChangeType.reassign:
        return 'reassign';
      case JobOrderChangeType.edit:
        return 'edit';
    }
  }
}
