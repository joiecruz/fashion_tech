import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fabric.dart';

class FabricService {
  final _collection = FirebaseFirestore.instance.collection('fabrics');

  Future<List<Fabric>> fetchFabrics() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map((doc) => Fabric.fromMap(doc.id, doc.data())).toList();
  }

  Future<void> addFabric(Fabric fabric) async {
    await _collection.doc(fabric.id).set(fabric.toMap());
  }

  Future<String> createFabricID() async {
    final snapshot = await _collection.get();
    final count = snapshot.docs.length + 1;
    return 'fabric_${count.toString().padLeft(2, '0')}';
  }
}
