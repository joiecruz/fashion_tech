import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// AddJobOrderModal: A modal bottom sheet for adding a new job order, based on the provided UI reference.
class AddJobOrderModal extends StatefulWidget {
  const AddJobOrderModal({Key? key}) : super(key: key);

  @override
  State<AddJobOrderModal> createState() => _AddJobOrderModalState();
}

class _AddJobOrderModalState extends State<AddJobOrderModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _orderDateController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _assignedToController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _specialInstructionsController = TextEditingController();
  bool _isUpcycled = false;
  String _jobStatus = 'In Progress';
  List<ProductVariant> _variants = [];

  // Fetches the user's actual fabrics from Firestore in initState and uses them for the fabric dropdowns in product variants. Shows a loading spinner while fetching.
  List<Map<String, dynamic>> _userFabrics = [];
  bool _loadingFabrics = true;

  @override
  void initState() {
    super.initState();
    _fetchUserFabrics();
  }

  Future<void> _fetchUserFabrics() async {
    final snapshot = await FirebaseFirestore.instance.collection('fabrics').get();
    setState(() {
      _userFabrics = snapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc['name'] ?? 'Unnamed',
        'quantity': (doc['quantity'] ?? 0) as num, // Add quantity for availability
      }).toList();
      _loadingFabrics = false;
    });
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _orderDateController.dispose();
    _dueDateController.dispose();
    _assignedToController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _specialInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFabrics) {
      return const Center(child: CircularProgressIndicator());
    }
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.95,
      minChildSize: 0.7,
      maxChildSize: 0.98,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Text('New Job Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
                  CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Text('FL', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Order Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const Spacer(),
                          Icon(Icons.edit, color: Colors.green[700], size: 20),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _productNameController,
                              decoration: const InputDecoration(labelText: 'Product Name', hintText: 'E.g., Summer Collection Dress'),
                              validator: (val) => val!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _orderDateController,
                                    readOnly: true,
                                    onTap: () => _pickDate(_orderDateController),
                                    decoration: const InputDecoration(
                                      labelText: 'Order Date',
                                      prefixIcon: Icon(Icons.calendar_today, size: 18),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _dueDateController,
                                    readOnly: true,
                                    onTap: () => _pickDate(_dueDateController),
                                    decoration: const InputDecoration(
                                      labelText: 'Due Date',
                                      prefixIcon: Icon(Icons.calendar_today, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _assignedToController,
                              decoration: const InputDecoration(labelText: 'Assigned To'),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _quantityController,
                                    decoration: const InputDecoration(labelText: 'Quantity'),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _priceController,
                                    decoration: const InputDecoration(labelText: 'Price'),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _specialInstructionsController,
                              decoration: const InputDecoration(labelText: 'Special Instructions', hintText: 'E.g., Custom embroidery on cuffs'),
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              value: _isUpcycled,
                              onChanged: (val) => setState(() => _isUpcycled = val),
                              title: const Text('Is Upcycled?'),
                              contentPadding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _jobStatus,
                              items: const [
                                DropdownMenuItem(value: 'Open', child: Text('Open')),
                                DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                                DropdownMenuItem(value: 'Done', child: Text('Done')),
                              ],
                              onChanged: (val) => setState(() => _jobStatus = val ?? 'In Progress'),
                              decoration: const InputDecoration(labelText: 'Job Status'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // --- Product Variants Section ---
              // Now: Inline editable variant cards, not a dialog
              const SizedBox(height: 24),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Product Variants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _variants.add(ProductVariant(
                                  size: 'Small',
                                  colorName: '',
                                  color: Colors.red,
                                  quantity: 0,
                                  fabrics: [],
                                ));
                              });
                            },
                            icon: const Icon(Icons.add, color: Colors.green),
                            label: const Text('Add New', style: TextStyle(color: Colors.green)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _variants.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('No variants added yet.'),
                            )
                          : Column(
                              children: _variants.asMap().entries.map((entry) {
                                int idx = entry.key;
                                ProductVariant variant = entry.value;
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: DropdownButtonFormField<String>(
                                                value: variant.size,
                                                items: const [
                                                  DropdownMenuItem(value: 'Small', child: Text('Small')),
                                                  DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                                                  DropdownMenuItem(value: 'Large', child: Text('Large')),
                                                ],
                                                onChanged: (val) {
                                                  setState(() {
                                                    _variants[idx].size = val ?? 'Small';
                                                  });
                                                },
                                                decoration: const InputDecoration(labelText: 'Size'),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: TextFormField(
                                                initialValue: variant.colorName,
                                                decoration: const InputDecoration(labelText: 'Color Name'),
                                                onChanged: (val) {
                                                  setState(() {
                                                    _variants[idx].colorName = val;
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Text('Color:'),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () async {
                                                // TODO: Implement color picker if needed
                                              },
                                              child: CircleAvatar(backgroundColor: variant.color, radius: 14),
                                            ),
                                            const Spacer(),
                                            SizedBox(
                                              width: 100,
                                              child: TextFormField(
                                                initialValue: variant.quantity == 0 ? '' : variant.quantity.toString(),
                                                decoration: const InputDecoration(labelText: 'Quantity'),
                                                keyboardType: TextInputType.number,
                                                onChanged: (val) {
                                                  setState(() {
                                                    _variants[idx].quantity = int.tryParse(val) ?? 0;
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Fabrics for this variant
                                        Row(
                                          children: [
                                            const Text('Fabrics', style: TextStyle(fontWeight: FontWeight.bold)),
                                            const Spacer(),
                                            TextButton.icon(
                                              onPressed: () {
                                                setState(() {
                                                  _variants[idx].fabrics.add(VariantFabric(
                                                    fabricId: _userFabrics.first['id']!,
                                                    fabricName: _userFabrics.first['name']!,
                                                    yardsRequired: 0,
                                                  ));
                                                });
                                              },
                                              icon: const Icon(Icons.add, size: 18),
                                              label: const Text('Add Fabric'),
                                            ),
                                          ],
                                        ),
                                        ...variant.fabrics.asMap().entries.map((fEntry) {
                                          int fIdx = fEntry.key;
                                          VariantFabric fabric = fEntry.value;
                                          return Card(
                                            margin: const EdgeInsets.symmetric(vertical: 4),
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: DropdownButtonFormField<String>(
                                                          value: fabric.fabricId,
                                                          items: _userFabrics.map((f) => DropdownMenuItem<String>(
                                                            value: f['id'] as String,
                                                            child: Text(f['name'] as String),
                                                          )).toList(),
                                                          onChanged: (val) {
                                                            setState(() {
                                                              final selected = _userFabrics.firstWhere((f) => f['id'] == val);
                                                              _variants[idx].fabrics[fIdx] = VariantFabric(
                                                                fabricId: val!,
                                                                fabricName: selected['name'] as String,
                                                                yardsRequired: fabric.yardsRequired,
                                                              );
                                                            });
                                                          },
                                                          decoration: const InputDecoration(labelText: 'Fabric'),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 80,
                                                        child: TextFormField(
                                                          initialValue: fabric.yardsRequired == 0 ? '' : fabric.yardsRequired.toString(),
                                                          decoration: const InputDecoration(labelText: 'Yards'),
                                                          keyboardType: TextInputType.number,
                                                          onChanged: (val) {
                                                            setState(() {
                                                              _variants[idx].fabrics[fIdx] = VariantFabric(
                                                                fabricId: fabric.fabricId,
                                                                fabricName: fabric.fabricName,
                                                                yardsRequired: double.tryParse(val) ?? 0,
                                                              );
                                                            });
                                                          },
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete, color: Colors.red),
                                                        onPressed: () {
                                                          setState(() {
                                                            _variants[idx].fabrics.removeAt(fIdx);
                                                          });
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  // --- Availability Bar ---
                                                  Builder(
                                                    builder: (context) {
                                                      final fabricData = _userFabrics.firstWhere(
                                                        (f) => f['id'] == fabric.fabricId,
                                                        orElse: () => {'quantity': 0, 'name': fabric.fabricName},
                                                      );
                                                      final available = (fabricData['quantity'] ?? 0) as num;
                                                      final requested = fabric.yardsRequired;
                                                      final ratio = available > 0 ? (requested / available).clamp(0.0, 1.0) : 0.0;
                                                      final enough = requested <= available;
                                                      return Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          const SizedBox(height: 6),
                                                          LinearProgressIndicator(
                                                            value: available > 0 ? ratio : 0.0,
                                                            minHeight: 8,
                                                            backgroundColor: Colors.grey[200],
                                                            color: enough ? Colors.green : Colors.red,
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            'Requested: ${requested.toStringAsFixed(2)} / Available: ${available.toStringAsFixed(2)} yds',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: enough ? Colors.green[700] : Colors.red[700],
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        if (variant.fabrics.isEmpty)
                                          const Text('No fabrics added yet.', style: TextStyle(color: Colors.grey)),
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            tooltip: 'Remove Variant',
                                            onPressed: () {
                                              setState(() {
                                                _variants.removeAt(idx);
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                );
                                }).toList(),
                            ),
                    ],
                  ),
                ),
              ),

              // --- Fabric & Inventory Section ---
              // TODO: The following fabric type, yards required, and inventory data are hardcoded for UI demo only.
              // Replace with dynamic fields and connect to Firestore inventory data.
              // Not connected to Firestore yet.
              const SizedBox(height: 24),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fabric & Inventory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        items: const [
                          DropdownMenuItem(value: 'Organic Cotton', child: Text('Organic Cotton')),
                          DropdownMenuItem(value: 'Polyester', child: Text('Polyester')),
                          DropdownMenuItem(value: 'Linen', child: Text('Linen')),
                        ],
                        onChanged: (val) {},
                        decoration: const InputDecoration(labelText: 'Fabric Type'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Yards Required'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      // Inventory progress bar (placeholder)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Inventory Available: 1000 Yards'), // TODO: Hardcoded
                          const SizedBox(height: 4),
                          LinearProgressIndicator(value: 0.5, minHeight: 8, backgroundColor: Colors.grey[200], color: Colors.blue), // TODO: Hardcoded
                          const SizedBox(height: 4),
                          const Text('500 of 1000 yards (50%)', style: TextStyle(fontSize: 12)), // TODO: Hardcoded
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Add another fabric logic
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Another Fabric'),
                      ),
                    ],
                  ),
                ),
              ),

              // --- Supplier Details Section ---
              // TODO: The following supplier details are hardcoded for UI demo only.
              // Replace with dynamic supplier selection and connect to Firestore supplier data.
              // Not connected to Firestore yet.
              const SizedBox(height: 24),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Supplier Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            child: const Icon(Icons.business, color: Colors.blue),
                          ),
                          const SizedBox(width: 12),
                          const Text('Global Fabrics Inc.', style: TextStyle(fontWeight: FontWeight.bold)), // TODO: Hardcoded
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('contact@globalfabrics.com'), // TODO: Hardcoded
                      const Text('+1 (555) 123-4567'), // TODO: Hardcoded
                      const Text('123 Textile Road, Weave City, TX'), // TODO: Hardcoded
                    ],
                  ),
                ),
              ),

              // --- Variant Breakdown Summary Section ---
              // TODO: The following bar chart and unit summary are hardcoded for UI demo only.
              // Replace with dynamic summary based on actual variants and quantities.
              // Not connected to Firestore yet.
              const SizedBox(height: 24),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Variant Breakdown Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 16),
                      // Placeholder for bar chart
                      Container(
                        height: 80,
                        color: Colors.green[50],
                        child: const Center(child: Text('Bar chart placeholder')), // TODO: Hardcoded
                      ),
                      const SizedBox(height: 16),
                      // Placeholder for unit summary
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          Chip(label: Text('Small - Scarlet Red: 1000 units')), // TODO: Hardcoded
                          Chip(label: Text('Medium - Ocean Blue: 800 units')), // TODO: Hardcoded
                          Chip(label: Text('Large - Forest Green: 700 units')), // TODO: Hardcoded
                          Chip(label: Text('Small - Deep Black: 500 units')), // TODO: Hardcoded
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // TODO: Save job order to Firestore
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Job Order', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Data model for a fabric selection in a variant
class VariantFabric {
  final String fabricId; // Firestore doc ID or unique identifier
  final String fabricName;
  final double yardsRequired;
  VariantFabric({
    required this.fabricId,
    required this.fabricName,
    required this.yardsRequired,
  });
}

// Variant data model for the modal
class ProductVariant {
  String size;
  String colorName;
  Color color;
  int quantity;
  List<VariantFabric> fabrics; // Now supports multiple fabrics per variant
  ProductVariant({
    required this.size,
    required this.colorName,
    required this.color,
    required this.quantity,
    required this.fabrics,
  });
}
