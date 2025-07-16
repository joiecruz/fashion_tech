import 'package:flutter/material.dart';
import '../../../utils/size_utils.dart';
import '../../common/color_selector.dart';
import '../../common/simple_color_dropdown.dart';

class ProductVariantInput {
  String size;
  String color;
  int quantityInStock;

  ProductVariantInput({
    required this.size,
    required this.color,
    required this.quantityInStock,
  });
}

class ProductVariantsSection extends StatelessWidget {
  final List<ProductVariantInput> variants;
  final Function(ProductVariantInput) onAddVariant;
  final Function(int) onRemoveVariant;
  final Function(int, String, String, int) onUpdateVariant;

  // Add a static fallback color list (should match ColorSelector fallback)
  static const List<String> fallbackColorIds = [
    'Black',
    'White',
    'Red',
    'Blue',
    'Green',
    'Yellow'
  ];

  const ProductVariantsSection({
    super.key,
    required this.variants,
    required this.onAddVariant,
    required this.onRemoveVariant,
    required this.onUpdateVariant,
  });

  String getDefaultColorId() {
    // Use the first fallback color as default
    return fallbackColorIds.first;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Product Variants',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    onAddVariant(ProductVariantInput(
                      size: SizeUtils.sizeOptions.first,
                      color: getDefaultColorId(), // Use valid color ID
                      quantityInStock: 0,
                    ));
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Variant'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (variants.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Center(
                  child: Text(
                    'No variants added yet.\nAdd variants to specify size, color, and stock quantities.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...variants.asMap().entries.map((entry) {
                final index = entry.key;
                final variant = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Prevent overflow
                    children: [
                      Row(
                        children: [
                          Text(
                            'Variant ${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () => onRemoveVariant(index),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Use IntrinsicHeight to allow dropdowns to open over modal
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Size Dropdown
                            Expanded(
                              flex: 2, // Give more space to the size dropdown
                              child: SizedBox(
                                width: 180, // Set a fixed width for both fields
                                child: DropdownButtonFormField<String>(
                                  value: variant.size,
                                  isExpanded: true,
                                  menuMaxHeight: 350, // Prevents dropdown from overflowing modal
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    labelText: 'Size',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    hintText: 'Select a size',
                                  ),
                                  items: SizeUtils.buildSizeDropdownItems(showDescriptions: true),
                                  selectedItemBuilder: (context) => SizeUtils.buildConstrainedSizeSelectedItems(
                                    context,
                                    compact: true,
                                    maxWidth: 160, // Increased width for logo/label
                                  ),
                                  validator: (value) => value == null || value.isEmpty ? 'Please select a size' : null,
                                  onChanged: (value) {
                                    onUpdateVariant(index, value!, variant.color, variant.quantityInStock);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Color Dropdown (replace ColorSelector with SimpleColorDropdown)
                            Expanded(
                              child: SizedBox(
                                width: 180, // Set a fixed width for both fields
                                child: SimpleColorDropdown(
                                  selectedColor: variant.color,
                                  onChanged: (colorName) {
                                    onUpdateVariant(index, variant.size, colorName ?? '', variant.quantityInStock);
                                  },
                                  isRequired: true,
                                  validator: (val) {
                                    if (val == null || val.isEmpty) return 'Please select a color';
                                    return null;
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Quantity
                          Expanded(
                            child: TextFormField(
                              initialValue: variant.quantityInStock.toString(),
                              decoration: const InputDecoration(
                                labelText: 'Quantity in Stock',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                final qty = int.tryParse(value);
                                if (qty == null || qty < 0) {
                                  return 'Valid qty';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                final qty = int.tryParse(value) ?? 0;
                                onUpdateVariant(index, variant.size, variant.color, qty);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}
