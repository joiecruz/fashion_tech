import '../../../models/product_variant.dart';

// Temporary classes for the form to work with the current UI
class VariantFabric {
  String fabricId;
  String fabricName;
  double yardsRequired;
  
  VariantFabric({
    required this.fabricId,
    required this.fabricName,
    required this.yardsRequired,
  });
}

// Extended ProductVariant for form use
class FormProductVariant extends ProductVariant {
  List<VariantFabric> fabrics;
  
  FormProductVariant({
    required String id,
    required String productID,
    required String size,
    required String color,
    required int quantityInStock,
    required this.fabrics,
  }) : super(
    id: id,
    productID: productID,
    size: size,
    color: color,
    quantityInStock: quantityInStock,
  );
}
