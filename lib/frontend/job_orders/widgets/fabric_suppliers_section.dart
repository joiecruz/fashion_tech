import 'package:flutter/material.dart';
import '../models/form_models.dart';

class FabricSuppliersSection extends StatelessWidget {
  final List<FormProductVariant> variants;
  final List<Map<String, dynamic>> userFabrics;
  final Map<String, Map<String, dynamic>> fabricSuppliers;
  final bool loadingFabricSuppliers;
  final Function(String) parseColor;

  const FabricSuppliersSection({
    Key? key,
    required this.variants,
    required this.userFabrics,
    required this.fabricSuppliers,
    required this.loadingFabricSuppliers,
    required this.parseColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.business,
                  color: Colors.teal.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Fabric Suppliers',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              if (loadingFabricSuppliers)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (variants.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add variants to see suppliers',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Supplier information will be displayed based on fabrics used',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            _buildSuppliersList(),
        ],
      ),
    );
  }

  Widget _buildSuppliersList() {
    // Get unique fabric IDs used in all variants
    final Set<String> usedFabricIds = {};
    for (final variant in variants) {
      for (final fabric in variant.fabrics) {
        usedFabricIds.add(fabric.fabricId);
      }
    }
    
    print('Used fabric IDs: $usedFabricIds');
    print('Available fabric suppliers: ${fabricSuppliers.keys.toList()}');
    
    if (usedFabricIds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Add fabrics to variants to see supplier information',
                style: TextStyle(color: Colors.blue.shade700),
              ),
            ),
          ],
        ),
      );
    }
    
    // Group fabrics by supplier
    final Map<String, List<Map<String, dynamic>>> supplierFabrics = {};
    final List<Map<String, dynamic>> fabricsWithoutSuppliers = [];
    
    for (final fabricId in usedFabricIds) {
      final fabricData = userFabrics.firstWhere(
        (f) => f['id'] == fabricId,
        orElse: () => {'name': 'Unknown Fabric', 'color': '#FF0000'},
      );
      
      print('Processing fabric $fabricId: $fabricData');
      print('Available fabric fields: ${fabricData.keys.toList()}');
      print('Price fields check: pricePerUnit=${fabricData['pricePerUnit']}, price=${fabricData['price']}, cost=${fabricData['cost']}, pricePerYard=${fabricData['pricePerYard']}');
      
      if (fabricSuppliers.containsKey(fabricId)) {
        final supplier = fabricSuppliers[fabricId]!;
        print('Found supplier for fabric $fabricId: $supplier');
        
        final supplierKey = supplier['supplierID'] ?? 'unknown';
        print('Supplier key: $supplierKey');
        
        if (!supplierFabrics.containsKey(supplierKey)) {
          supplierFabrics[supplierKey] = [];
        }
        supplierFabrics[supplierKey]!.add({
          'fabricId': fabricId,
          'fabricName': fabricData['name'] ?? 'Unknown Fabric',
          'fabricColor': fabricData['color'] ?? '#FF0000',
          'fabricType': fabricData['type'] ?? 'Unknown',
          'qualityGrade': fabricData['qualityGrade'] ?? 'Standard',
          'pricePerUnit': (fabricData['pricePerUnit'] ?? 0).toDouble(),
          'supplier': supplier,
        });
      } else {
        print('No supplier found for fabric $fabricId');
        fabricsWithoutSuppliers.add({
          'fabricId': fabricId,
          'fabricName': fabricData['name'] ?? 'Unknown Fabric',
          'fabricColor': fabricData['color'] ?? '#FF0000',
          'fabricType': fabricData['type'] ?? 'Unknown',
        });
      }
    }
    
    print('Grouped supplier fabrics: $supplierFabrics');
    print('Fabrics without suppliers: $fabricsWithoutSuppliers');
    
    return Column(
      children: [
        if (supplierFabrics.isNotEmpty) ...[
          ...supplierFabrics.entries.map((entry) {
            final supplierData = entry.value.first['supplier'] as Map<String, dynamic>;
            final fabrics = entry.value;
            
            // Debug: Print supplier data structure
            print('Supplier data for display: $supplierData');
            print('Available keys: ${supplierData.keys.toList()}');
            
            // Extract supplier info with fallback field names
            final supplierName = supplierData['name'] ?? 
                                supplierData['supplierName'] ?? 
                                supplierData['supplier_name'] ?? 
                                supplierData['companyName'] ??
                                'Unknown Supplier';
            
            final contactNumber = supplierData['contactNumber'] ?? 
                                 supplierData['contact'] ?? 
                                 supplierData['phone'] ??
                                 supplierData['phoneNumber'];
            
            final email = supplierData['email'] ?? 
                         supplierData['emailAddress'];
            
            final location = supplierData['location'] ??
                            supplierData['address'];
            
            print('Extracted supplier info: name=$supplierName, contact=$contactNumber, email=$email, location=$location');
            
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade50, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.business,
                          color: Colors.teal.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supplierName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.teal.shade800,
                              ),
                            ),
                            if (contactNumber != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.phone, size: 14, color: Colors.teal.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    contactNumber,
                                    style: TextStyle(
                                      color: Colors.teal.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (email != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.email, size: 14, color: Colors.teal.shade600),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      email,
                                      style: TextStyle(
                                        color: Colors.teal.shade600,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (location != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 14, color: Colors.teal.shade600),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      location,
                                      style: TextStyle(
                                        color: Colors.teal.shade600,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Fabrics Supplied:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...fabrics.map((fabric) {
                    final color = parseColor(fabric['fabricColor'] as String);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fabric['fabricName'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        fabric['fabricType'] as String,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        fabric['qualityGrade'] as String,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₱${(fabric['pricePerUnit'] ?? 0).toDouble().toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                'per yard',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
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
            );
          }).toList(),
        ],
        if (fabricsWithoutSuppliers.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade600),
                    const SizedBox(width: 12),
                    Text(
                      'Fabrics without suppliers:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...fabricsWithoutSuppliers.map((fabric) {
                  final color = parseColor(fabric['fabricColor'] as String);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.orange.shade400),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fabric['fabricName'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            fabric['fabricType'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
