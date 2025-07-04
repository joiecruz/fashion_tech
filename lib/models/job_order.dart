import 'package:cloud_firestore/cloud_firestore.dart';

enum JobOrderStatus { open, inProgress, done }

class JobOrder {
  final String id;
  final String productID;
  final String customerID; // New in ERDv9
  final String? linkedProductID; // New in ERDv9
  final int quantity;
  final String customerName;
  final JobOrderStatus status;
  final DateTime dueDate;
  final String? acceptedBy;
  final String? assignedTo;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String name; // New in ERDv9

  JobOrder({
    required this.id,
    required this.productID,
    required this.customerID,
    this.linkedProductID,
    required this.quantity,
    required this.customerName,
    required this.status,
    required this.dueDate,
    this.acceptedBy,
    this.assignedTo,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.name,
  });

  factory JobOrder.fromMap(String id, Map<String, dynamic> data) {
    return JobOrder(
      id: id,
      productID: data['productID'] ?? '',
      customerID: data['customerID'] ?? '',
      linkedProductID: data['linkedProductID'],
      quantity: data['quantity'] ?? 0,
      customerName: data['customerName'] ?? '',
      status: _statusFromString(data['status'] ?? 'open'),
      dueDate: (data['dueDate'] is Timestamp)
          ? (data['dueDate'] as Timestamp).toDate()
          : DateTime.tryParse(data['dueDate'].toString()) ?? DateTime.now(),
      acceptedBy: data['acceptedBy'],
      assignedTo: data['assignedTo'],
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now(),
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['updatedAt'].toString()) ?? DateTime.now(),
      name: data['name'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productID': productID,
      'customerID': customerID,
      'linkedProductID': linkedProductID,
      'quantity': quantity,
      'customerName': customerName,
      'status': _statusToString(status),
      'dueDate': dueDate,
      'acceptedBy': acceptedBy,
      'assignedTo': assignedTo,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'name': name,
    };
  }

  static JobOrderStatus _statusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return JobOrderStatus.open;
      case 'inprogress':
      case 'in progress':
        return JobOrderStatus.inProgress;
      case 'done':
        return JobOrderStatus.done;
      default:
        return JobOrderStatus.open;
    }
  }

  static String _statusToString(JobOrderStatus status) {
    switch (status) {
      case JobOrderStatus.open:
        return 'Open';
      case JobOrderStatus.inProgress:
        return 'In Progress';
      case JobOrderStatus.done:
        return 'Done';
    }
  }
}
