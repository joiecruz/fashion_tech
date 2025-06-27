import '../models/job_order.dart';
import '../models/job_order_detail.dart';
import '../services/job_order_service.dart';

final _jobOrderService = JobOrderService();

Future<void> addJobOrder({
  required String productID,
  required String fabricID,
  required int quantity,
  required String status,
  required DateTime dueDate,
  required String acceptedBy,
  required String assignedTo,
  required List<JobOrderDetail> details,
}) async {
  final jobOrderID = await _jobOrderService.createJobOrderID();
  final now = DateTime.now();
  final jobOrder = JobOrder(
    id: jobOrderID,
    productID: productID,
    fabricID: fabricID,
    quantity: quantity,
    status: status,
    createdAt: now,
    updatedAt: now,
    dueDate: dueDate,
    acceptedBy: acceptedBy,
    assignedTo: assignedTo,
    details: details,
  );
  await _jobOrderService.addJobOrder(jobOrder);
}
