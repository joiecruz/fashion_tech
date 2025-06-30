import '../models/fabric.dart';
import '../services/fabric_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

final _fabricService = FabricService();

Future<void> addFabric({
  required String name,
  required String type,
  required String color,
  required String qualityGrade,
  required double quantity,
  required double expensePerYard,
  String? swatchImageURL,
  required double minOrder,
  required bool isUpcycled,
}) async {
  final fabricID = await _fabricService.createFabricID();
  final now = DateTime.now();
  final currentUser = FirebaseAuth.instance.currentUser;
  
  final fabric = Fabric(
    id: fabricID,
    name: name,
    type: type,
    color: color,
    qualityGrade: qualityGrade,
    quantity: quantity,
    expensePerYard: expensePerYard,
    swatchImageURL: swatchImageURL,
    minOrder: minOrder,
    isUpcycled: isUpcycled,
    createdBy: currentUser?.uid ?? 'anonymous',
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
  );
  await _fabricService.addFabric(fabric);
}

