import '../models/fabric.dart';
import '../services/fabric_service.dart';

final _fabricService = FabricService();

Future<void> addFabric({
  required String name,
  required String type,
  required String color,
  required String qualityGrade,
  required double quantity,
  required double expensePerYard,
  String? swatchImageURL,
}) async {
  final fabricID = await _fabricService.createFabricID();
  final now = DateTime.now();
  final fabric = Fabric(
    id: fabricID,
    name: name,
    type: type,
    color: color,
    qualityGrade: qualityGrade,
    quantity: quantity,
    expensePerYard: expensePerYard,
    swatchImageURL: swatchImageURL,
    createdAt: now,
    updatedAt: now,
  );
  await _fabricService.addFabric(fabric);
}

