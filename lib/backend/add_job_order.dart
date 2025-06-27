import '../models/job_order.dart';
import '../services/job_order_service.dart';

final _jobOrderService = JobOrderService();

Future<void> addJobOrder({
  required String productID,
  required int quantity,
  required String customerName,
  required JobOrderStatus status,
  required DateTime dueDate,
  required String createdBy,
  String? acceptedBy,
  String? assignedTo,
}) async {
  final jobOrderID = await _jobOrderService.createJobOrderID();
  final now = DateTime.now();
  final jobOrder = JobOrder(
    id: jobOrderID,
    productID: productID,
    quantity: quantity,
    customerName: customerName,
    status: status,
    dueDate: dueDate,
    acceptedBy: acceptedBy,
    assignedTo: assignedTo,
    createdBy: createdBy,
    createdAt: now,
    updatedAt: now,
  );
  await _jobOrderService.addJobOrder(jobOrder);
}
