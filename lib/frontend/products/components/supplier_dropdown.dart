import 'package:flutter/material.dart';

class SupplierDropdown extends StatelessWidget {
  final String? selectedSupplierID;
  final List<Map<String, dynamic>> suppliers;
  final bool loadingSuppliers;
  final Function(String?) onSupplierChanged;

  const SupplierDropdown({
    super.key,
    required this.selectedSupplierID,
    required this.suppliers,
    required this.loadingSuppliers,
    required this.onSupplierChanged,
  });

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
            Text(
              'Supplier/Source - Optional',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            loadingSuppliers
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : DropdownButtonFormField<String>(
                    value: selectedSupplierID,
                    decoration: InputDecoration(
                      hintText: 'Select a supplier',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blue[600]!),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('No supplier selected'),
                      ),
                      ...suppliers.map((supplier) {
                        return DropdownMenuItem<String>(
                          value: supplier['supplierID'],
                          child: Text(
                            supplier['supplierName'] ?? 'Unknown Supplier',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: onSupplierChanged,
                  ),
            if (suppliers.isEmpty && !loadingSuppliers) ...[
              const SizedBox(height: 8),
              Text(
                'No suppliers found. You can add suppliers from the Suppliers page.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
