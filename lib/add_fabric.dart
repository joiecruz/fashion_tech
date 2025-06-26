import 'package:cloud_firestore/cloud_firestore.dart';

Future<String> createFabricID() async {
  final snapshot = await FirebaseFirestore.instance.collection('fabrics').get();
  int max = 0;
  for (var doc in snapshot.docs) {
    final id = doc.id;
    final match = RegExp(r'^fabric_(\d+)$').firstMatch(id);
    if (match != null) {
      final num = int.tryParse(match.group(1) ?? '0') ?? 0;
      if (num > max) max = num;
    }
  }
  return 'fabric_${(max + 1).toString().padLeft(2, '0')}';
}

Future<void> addFabric({
  required String name,
  required int minOrder,
  required String type,
  required String color,
  required String qualityGrade,
  required double quantity,
  required String swatchImageURL,
  required bool isUpcycled,
  required double expensePerYard,
}) async {
  try {
    final fabricID = await createFabricID();
    final now = DateTime.now();
    print('Adding fabric with ID: $fabricID');
    await FirebaseFirestore.instance.collection('fabrics').doc(fabricID).set({
      'name': name,
      'minOrder': minOrder,
      'type': type,
      'color': color,
      'isUpcycled': isUpcycled,
      'qualityGrade': qualityGrade,
      'quantity': quantity,
      'swatchImageURL': swatchImageURL,
      'expensePerYard': expensePerYard,
      'createdAt': now,
      'updatedAt': now,
    });
    print('Fabric added in Firestore!');
  } catch (e) {
    print('Error in addFabric: $e');
    rethrow;
  }
}