import 'package:cloud_firestore/cloud_firestore.dart';

enum FabricChangeType { add, deduct, correction }
enum FabricLogSource { manual, jobOrder, adjustment }

class FabricLog {
  final String id;
  final String fabricID;
  final FabricChangeType changeType;
  final double quantityChanged;
  final FabricLogSource source;
  final String? remarks;
  final DateTime logDate;
  final DateTime createdAt;
  final String createdBy;

  FabricLog({
    required this.id,
    required this.fabricID,
    required this.changeType,
    required this.quantityChanged,
    required this.source,
    this.remarks,
    required this.logDate,
    required this.createdAt,
    required this.createdBy,
  });

  factory FabricLog.fromMap(String id, Map<String, dynamic> data) {
    return FabricLog(
      id: id,
      fabricID: data['fabricID'] ?? '',
      changeType: _changeTypeFromString(data['changeType'] ?? 'add'),
      quantityChanged: (data['quantityChanged'] ?? 0).toDouble(),
      source: _sourceFromString(data['source'] ?? 'manual'),
      remarks: data['remarks'],
      logDate: (data['logDate'] is Timestamp)
          ? (data['logDate'] as Timestamp).toDate()
          : DateTime.tryParse(data['logDate'].toString()) ?? DateTime.now(),
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fabricID': fabricID,
      'changeType': _changeTypeToString(changeType),
      'quantityChanged': quantityChanged,
      'source': _sourceToString(source),
      'remarks': remarks,
      'logDate': logDate,
      'createdAt': createdAt,
      'createdBy': createdBy,
    };
  }

  static FabricChangeType _changeTypeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'add':
        return FabricChangeType.add;
      case 'deduct':
        return FabricChangeType.deduct;
      case 'correction':
        return FabricChangeType.correction;
      default:
        return FabricChangeType.add;
    }
  }

  static String _changeTypeToString(FabricChangeType type) {
    switch (type) {
      case FabricChangeType.add:
        return 'add';
      case FabricChangeType.deduct:
        return 'deduct';
      case FabricChangeType.correction:
        return 'correction';
    }
  }

  static FabricLogSource _sourceFromString(String source) {
    switch (source.toLowerCase()) {
      case 'manual':
        return FabricLogSource.manual;
      case 'joborder':
        return FabricLogSource.jobOrder;
      case 'adjustment':
        return FabricLogSource.adjustment;
      default:
        return FabricLogSource.manual;
    }
  }

  static String _sourceToString(FabricLogSource source) {
    switch (source) {
      case FabricLogSource.manual:
        return 'manual';
      case FabricLogSource.jobOrder:
        return 'jobOrder';
      case FabricLogSource.adjustment:
        return 'adjustment';
    }
  }
}
