import 'package:cloud_firestore/cloud_firestore.dart';
import 'job_order_detail.dart';

class JobOrder {
  final String id;
  final String productID;
  final String fabricID;
  final int quantity;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime dueDate;
  final String acceptedBy;
  final String assignedTo;
  final List<JobOrderDetail> details;

  JobOrder({
    required this.id,
    required this.productID,
    required this.fabricID,
    required this.quantity,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.dueDate,
    required this.acceptedBy,
    required this.assignedTo,
    required this.details,
  });

  factory JobOrder.fromMap(String id, Map<String, dynamic> data) {
    return JobOrder(
      id: id,
      productID: data['productID'] ?? '',
      fabricID: data['fabricID'] ?? '',
      quantity: data['quantity'] ?? 0,
      status: data['status'] ?? '',
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now(),
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['updatedAt'].toString()) ?? DateTime.now(),
      dueDate: (data['dueDate'] is Timestamp)
          ? (data['dueDate'] as Timestamp).toDate()
          : DateTime.tryParse(data['dueDate'].toString()) ?? DateTime.now(),
      acceptedBy: data['acceptedBy'] ?? '',
      assignedTo: data['assignedTo'] ?? '',
      details: (data['details'] as List<dynamic>? ?? [])
          .map((d) => JobOrderDetail.fromMap('', d as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productID': productID,
      'fabricID': fabricID,
      'quantity': quantity,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'dueDate': dueDate,
      'acceptedBy': acceptedBy,
      'assignedTo': assignedTo,
      'details': details.map((d) => d.toMap()).toList(),
    };
  }
}
