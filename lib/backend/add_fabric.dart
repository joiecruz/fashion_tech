import '../models/fabric.dart';
import '../services/fabric_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

final _fabricService = FabricService();

Future<void> addFabric({
  required String name,
  required String type,
  required String colorID, // ERDv9: Changed from color to colorID
  required String categoryID, // ERDv9: Added categoryID parameter
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
    colorID: colorID, // ERDv9: Changed from color to colorID
    categoryID: categoryID, // ERDv9: Added categoryID
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

