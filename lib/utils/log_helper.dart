import 'package:cloud_firestore/cloud_firestore.dart';

/// General-purpose log helper for all entity logs.
///
/// [extraData] is a map of additional fields specific to the log type, such as:
///
/// fabricLogs: {
///   'fabricId': String,
///   'quantity': num,
///   'pricePerUnit': num,
///   'supplierID': String?,
///   'notes': String?,
/// }
/// productLogs: {
///   'productId': String,
///   'quantity': num,
///   'price': num,
///   'supplierID': String?,
///   'notes': String?,
/// }
/// jobOrderLogs: {
///   'jobOrderId': String,
///   'status': String,
///   'quantityChanged': num?,
///   'notes': String?,
/// }
/// transactionLogs: {
///   'transactionId': String,
///   'amount': num,
///   'relatedEntityId': String?,
///   'notes': String?,
/// }
/// supplierLogs: {
///   'supplierId': String,
///   'relatedEntityId': String?,
///   'notes': String?,
/// }
/// customerLogs: {
///   'customerId': String,
///   'relatedEntityId': String?,
///   'notes': String?,
/// }
///
/// Example usage:
///   await addLog(
///     collection: 'fabricLogs',
///     createdBy: userId,
///     remarks: 'Added fabric',
///     changeType: 'add',
///     extraData: {'fabricId': id, 'quantity': 10, ...},
///   );
Future<void> addLog({
  required String collection, // e.g. 'fabricLogs', 'productLogs', etc.
  required String createdBy,
  required String remarks,
  required String changeType, // e.g. 'add', 'edit', 'delete'
  required Map<String, dynamic> extraData,
}) async {
  await FirebaseFirestore.instance.collection(collection).add({
    'createdBy': createdBy,
    'createdAt': Timestamp.now(),
    'remarks': remarks,
    'changeType': changeType,
    ...extraData,
  });
}
