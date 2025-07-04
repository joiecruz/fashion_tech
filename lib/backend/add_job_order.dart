import '../models/job_order.dart';
import '../services/job_order_service.dart';

final _jobOrderService = JobOrderService();

Future<void> addJobOrder({
  required String productID,
  required String customerID, // ERDv9: Added customerID parameter
  String? linkedProductID, // ERDv9: Added linkedProductID parameter
  required int quantity,
  required String customerName,
  required String name, // ERDv9: Added name parameter
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
    customerID: customerID, // ERDv9: Added customerID
    linkedProductID: linkedProductID, // ERDv9: Added linkedProductID
    quantity: quantity,
    customerName: customerName,
    status: status,
    dueDate: dueDate,
    acceptedBy: acceptedBy,
    assignedTo: assignedTo,
    createdBy: createdBy,
    createdAt: now,
    updatedAt: now,
    name: name, // ERDv9: Added name
  );
  await _jobOrderService.addJobOrder(jobOrder);
}
