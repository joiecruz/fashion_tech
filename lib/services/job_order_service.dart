import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/job_order.dart';

class JobOrderService {
  final _collection = FirebaseFirestore.instance.collection('job_orders');

  Future<List<JobOrder>> fetchJobOrders() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map((doc) => JobOrder.fromMap(doc.id, doc.data())).toList();
  }

  Future<void> addJobOrder(JobOrder jobOrder) async {
    await _collection.doc(jobOrder.id).set(jobOrder.toMap());
  }

  Future<String> createJobOrderID() async {
    final snapshot = await _collection.get();
    final count = snapshot.docs.length + 1;
    return 'joborder_${count.toString().padLeft(2, '0')}';
  }
}
