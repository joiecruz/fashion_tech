import '../models/fabric.dart';
import '../services/fabric_service.dart';

final _fabricService = FabricService();

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
  final fabricID = await _fabricService.createFabricID();
  final now = DateTime.now();
  final fabric = Fabric(
    id: fabricID,
    name: name,
    minOrder: minOrder,
    type: type,
    color: color,
    qualityGrade: qualityGrade,
    quantity: quantity,
    swatchImageURL: swatchImageURL,
    isUpcycled: isUpcycled,
    expensePerYard: expensePerYard,
    createdAt: now,
    updatedAt: now,
  );
  await _fabricService.addFabric(fabric);
}

