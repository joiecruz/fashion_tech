import '../../../models/product_variant.dart';

/*
 * IMPORTANT: This file contains form models for the Job Order creation modal.
 * 
 * The "Product Variants" section in the Add Job Order Modal creates JobOrderDetails records, 
 * NOT ProductVariant collection records. This is a key distinction for ERDv8 compliance.
 * 
 * - FormProductVariant: Used for UI form handling and creates JobOrderDetails
 * - ProductVariant: The actual collection model (separate from job orders)
 * 
 * No ProductVariant collection data should be created from this modal.
 */

// Temporary classes for the form to work with the current UI
class VariantFabric {
  String fabricId;
  String fabricName;
  double yardageUsed; // ERDv8 compliant field name
  
  VariantFabric({
    required this.fabricId,
    required this.fabricName,
    required this.yardageUsed, // ERDv8 compliant field name
  });
}

// Extended ProductVariant for form use - creates JobOrderDetails, NOT ProductVariants
class FormProductVariant extends ProductVariant {
  List<VariantFabric> fabrics;
  int quantity; // Quantity for JobOrderDetails (ERDv8 requirement)
  
  FormProductVariant({
    required String id,
    required String productID,
    required String size,
    required String color,
    required int quantityInStock,
    required this.quantity, // ERDv8: required for JobOrderDetails
    required this.fabrics,
  }) : super(
    id: id,
    productID: productID,
    size: size,
    color: color,
    quantityInStock: quantityInStock,
  );
}
