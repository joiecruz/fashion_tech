import 'package:cloud_firestore/cloud_firestore.dart';

Future<String> createFabricID() async {
  final snapshot = await FirebaseFirestore.instance.collection('fabrics').get();
  final count = snapshot.docs.length + 1;
  return 'fabric_${count.toString().padLeft(2, '0')}';
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
  final fabricID = await createFabricID();
  final now = DateTime.now();

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
}

