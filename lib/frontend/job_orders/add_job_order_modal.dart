import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fashion_tech/models/product_variant.dart';
import 'package:fashion_tech/models/variant_fabric.dart';

// ==========================
// AddJobOrderModal - Updated for New Schema
// ==========================

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

  List<Map<String, dynamic>> _userFabrics = [];
  bool _loadingFabrics = true;

  Map<String, dynamic>? _supplier;
  bool _loadingSupplier = true;

  Map<String, double> _fabricAllocated = {};

  @override
  void initState() {
    super.initState();
    _fetchUserFabrics();
    _fetchSupplier();
    _quantityController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _fetchUserFabrics() async {
    final snapshot = await FirebaseFirestore.instance.collection('fabrics').get();
    setState(() {
      _userFabrics = snapshot.docs.map((doc) => {
        'id': doc.id,
        'fabricID': doc.id,
        'name': doc['name'] ?? 'Unnamed',
        'type': doc['type'] ?? 'Unknown',
        'quantity': (doc['quantity'] ?? 0) as num,
        'color': doc['color'] ?? '#FF0000',
        'qualityGrade': doc['qualityGrade'] ?? 'Standard',
        'expensePerYard': (doc['expensePerYard'] ?? 0.0) as num,
        'swatchImageURL': doc['swatchImageURL'] ?? '',
      }).toList();
      _loadingFabrics = false;
    });
  }

  Future<void> _fetchSupplier() async {
    final snapshot = await FirebaseFirestore.instance.collection('suppliers').limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _supplier = snapshot.docs.first.data();
        _loadingSupplier = false;
      });
    } else {
      setState(() {
        _supplier = null;
        _loadingSupplier = false;
      });
    }
  }

  void _onFabricYardageChanged() {
    final Map<String, double> allocation = {};
    for (final variant in _variants) {
      for (final fabric in variant.fabrics) {
        allocation[fabric.fabricId] = (allocation[fabric.fabricId] ?? 0) + (fabric.yardsRequired);
      }
    }
    setState(() {
      _fabricAllocated = allocation;
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

  Future<void> _saveJobOrder() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;
    if (_variants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product variant.')),
      );
      return;
    }
    for (final variant in _variants) {
      if (variant.fabrics.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Each variant must have at least one fabric.')),
        );
        return;
      }
    }
    // --- Quantity sum validation ---
    int globalQty = int.tryParse(_quantityController.text) ?? 0;
    int sumVariants = _variants.fold(0, (sum, v) => sum + v.quantity);
    if (globalQty != sumVariants) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sum of variant quantities ($sumVariants) must equal global quantity ($globalQty).')),
      );
      return;
    }

    try {
      final productRef = FirebaseFirestore.instance.collection('products').doc();
      await productRef.set({
        'name': _productNameController.text,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'category': 'Custom',
        'isUpcycled': _isUpcycled,
        'isMade': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final jobOrderRef = FirebaseFirestore.instance.collection('joborders').doc();
      await jobOrderRef.set({
        'productID': productRef.id,
        'quantity': int.tryParse(_quantityController.text) ?? 0,
        'customerName': _assignedToController.text,
        'status': _jobStatus,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'dueDate': _dueDateController.text.isNotEmpty
            ? Timestamp.fromDate(DateTime.parse(_dueDateController.text))
            : FieldValue.serverTimestamp(),
        'assignedTo': _assignedToController.text,
        'createdBy': 'current_user_id', // Replace with actual user ID
        'supplierID': _supplier?['supplierID'] ?? '',
      });

      for (int i = 0; i < _variants.length; i++) {
        final variant = _variants[i];
        final variantRef = FirebaseFirestore.instance.collection('productvariants').doc();
        await variantRef.set({
          'productID': productRef.id,
          'size': variant.size,
          'color': variant.color,
          'quantityInStock': variant.quantityInStock,
        });

        for (final fabric in variant.fabrics) {
          final jobOrderDetailRef = FirebaseFirestore.instance.collection('joborderdetails').doc();
          await jobOrderDetailRef.set({
            'jobOrderID': jobOrderRef.id,
            'fabricID': fabric.fabricId,
            'yardageUsed': fabric.yardsRequired,
            'size': variant.size,
            'color': variant.color,
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job order saved!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving job order: $e')),
        );
      }
    }
  }

  Color _parseColor(String colorValue) {
    if (colorValue.startsWith('#') || RegExp(r'^[0-9A-Fa-f]{6,8}$').hasMatch(colorValue)) {
      try {
        String hex = colorValue.replaceAll('#', '');
        if (hex.length == 6) hex = 'FF$hex';
        return Color(int.parse(hex, radix: 16));
      } catch (e) {
        return Colors.grey;
      }
    }
    final Map<String, Color> colorNames = {
      'red': Colors.red,
      'green': Colors.green,
      'blue': Colors.blue,
      'yellow': Colors.yellow,
      'orange': Colors.orange,
      'purple': Colors.purple,
      'brown': Colors.brown,
      'black': Colors.black,
      'white': Colors.white,
      'grey': Colors.grey,
      'gray': Colors.grey,
      'pink': Colors.pink,
      'teal': Colors.teal,
      'cyan': Colors.cyan,
      'lime': Colors.lime,
      'indigo': Colors.indigo,
      'amber': Colors.amber,
      'cream': const Color(0xFFFFFDD0),
      'beige': const Color(0xFFF5F5DC),
      'navy': const Color(0xFF000080),
      'maroon': const Color(0xFF800000),
      'olive': const Color(0xFF808000),
      'silver': const Color(0xFFC0C0C0),
      'gold': const Color(0xFFFFD700),
    };
    final colorName = colorValue.toLowerCase().trim();
    return colorNames[colorName] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFabrics || _loadingSupplier) {
      return const Center(child: CircularProgressIndicator());
    }
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.95,
      minChildSize: 0.7,
      maxChildSize: 0.98,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Text('New Job Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // --- Order Details Card ---
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
                                      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                                      productID: 'temp_product',
                                      size: 'Small',
                                      color: 'Red',
                                      quantityInStock: 0,
                                      fabrics: [],
                                    ));
                                  });
                                },
                                icon: const Icon(Icons.add, color: Colors.green),
                                label: const Text('Add New', style: TextStyle(color: Colors.green)),
                              ),
                            ],
                          ),
                          // --- Quantity sum warning ---
                          Builder(
                            builder: (context) {
                              int globalQty = int.tryParse(_quantityController.text) ?? 0;
                              int sumVariants = _variants.fold(0, (sum, v) => sum + v.quantity);
                              if (_variants.isNotEmpty && globalQty != sumVariants) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                                  child: Text(
                                    'Sum of variant quantities ($sumVariants) must equal global quantity ($globalQty).',
                                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
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
                                    final List<Color> variantColors = [
                                      Colors.blue.shade50,
                                      Colors.green.shade50,
                                      Colors.orange.shade50,
                                      Colors.purple.shade50,
                                      Colors.teal.shade50,
                                      Colors.pink.shade50,
                                      Colors.indigo.shade50,
                                      Colors.amber.shade50,
                                    ];
                                    final variantColor = variantColors[idx % variantColors.length];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 6),
                                      color: variantColor,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              margin: const EdgeInsets.only(bottom: 12),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.8),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: variantColors[idx % variantColors.length].withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.category,
                                                    size: 16,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Variant ${idx + 1}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14,
                                                      color: Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                DropdownButtonFormField<String>(
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
                                                const SizedBox(height: 12),
                                                SizedBox(
                                                    width: double.infinity,
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
                                                const SizedBox(height: 12),
                                                // Variant Quantity Allocation Progress Card
                                                Builder(
                                                  builder: (context) {
                                                    int globalQty = int.tryParse(_quantityController.text) ?? 0;
                                                    int variantQty = variant.quantity;
                                                    int sumVariants = _variants.fold(0, (sum, v) => sum + v.quantity);
                                                    double progress = globalQty > 0 ? (variantQty / globalQty).clamp(0.0, 1.0) : 0.0;
                                                    bool isOverAllocated = sumVariants > globalQty;
                                                    bool isUnderAllocated = sumVariants < globalQty;
                                                    
                                                    return Container(
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(
                                                        color: isOverAllocated
                                                            ? Colors.red.shade50
                                                            : isUnderAllocated
                                                                ? Colors.orange.shade50
                                                                : Colors.green.shade50,
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(
                                                          color: isOverAllocated
                                                              ? Colors.red.shade200
                                                              : isUnderAllocated
                                                                  ? Colors.orange.shade200
                                                                  : Colors.green.shade200,
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Icon(
                                                                isOverAllocated
                                                                    ? Icons.warning_rounded
                                                                    : isUnderAllocated
                                                                        ? Icons.info_rounded
                                                                        : Icons.check_circle_rounded,
                                                                size: 16,
                                                                color: isOverAllocated
                                                                    ? Colors.red.shade600
                                                                    : isUnderAllocated
                                                                        ? Colors.orange.shade600
                                                                        : Colors.green.shade600,
                                                              ),
                                                              const SizedBox(width: 6),
                                                              Text(
                                                                'Quantity Allocation',
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.w600,
                                                                  fontSize: 14,
                                                                  color: Colors.grey.shade700,
                                                                ),
                                                              ),
                                                              const Spacer(),
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: isOverAllocated
                                                                      ? Colors.red.shade100
                                                                      : isUnderAllocated
                                                                          ? Colors.orange.shade100
                                                                          : Colors.green.shade100,
                                                                  borderRadius: BorderRadius.circular(12),
                                                                ),
                                                                child: Text(
                                                                  '${variantQty}/${globalQty}',
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: isOverAllocated
                                                                        ? Colors.red.shade700
                                                                        : isUnderAllocated
                                                                            ? Colors.orange.shade700
                                                                            : Colors.green.shade700,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 8),
                                                          ClipRRect(
                                                            borderRadius: BorderRadius.circular(6),
                                                            child: LinearProgressIndicator(
                                                              value: progress,
                                                              minHeight: 6,
                                                              backgroundColor: Colors.grey.shade200,
                                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                                isOverAllocated
                                                                    ? Colors.red.shade400
                                                                    : isUnderAllocated
                                                                        ? Colors.orange.shade400
                                                                        : Colors.green.shade400,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 6),
                                                          Text(
                                                            isOverAllocated
                                                                ? 'Over-allocated by ${sumVariants - globalQty} units'
                                                                : isUnderAllocated
                                                                    ? 'Under-allocated by ${globalQty - sumVariants} units'
                                                                    : 'Perfectly allocated',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w500,
                                                              color: isOverAllocated
                                                                  ? Colors.red.shade700
                                                                  : isUnderAllocated
                                                                      ? Colors.orange.shade700
                                                                      : Colors.green.shade700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (variant.fabrics.isNotEmpty) ...[
                                              Row(
                                                children: [
                                                  const Text('Colors Used:'),
                                                  const SizedBox(width: 8),
                                                  ...variant.fabrics.map((fabric) {
                                                    final fabricData = _userFabrics.firstWhere(
                                                      (f) => f['id'] == fabric.fabricId,
                                                      orElse: () => {'color': '#FF0000'},
                                                    );
                                                    final color = _parseColor(fabricData['color'] as String);
                                                    return Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 3),
                                                      child: Container(
                                                        width: 20,
                                                        height: 20,
                                                        decoration: BoxDecoration(
                                                          color: color,
                                                          shape: BoxShape.circle,
                                                          border: Border.all(
                                                            color: Colors.grey.shade300,
                                                            width: 1.5,
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.black.withOpacity(0.1),
                                                              blurRadius: 2,
                                                              offset: const Offset(0, 1),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                            ],
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
                                              final fabricData = _userFabrics.firstWhere(
                                                (f) => f['id'] == fabric.fabricId,
                                                orElse: () => {'color': '#FF0000'},
                                              );
                                              final available = (fabricData['quantity'] ?? 0) as num;
                                              final allocated = _fabricAllocated[fabric.fabricId] ?? 0;
                                              final otherAllocated = allocated - fabric.yardsRequired;
                                              final remaining = available - otherAllocated;
                                              final overAllocated = allocated > available;
                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
                                                    child: Text(
                                                      'Fabric ${fIdx + 1}',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      Builder(
                                                        builder: (context) {
                                                          final fabricData = _userFabrics.firstWhere(
                                                            (f) => f['id'] == fabric.fabricId,
                                                            orElse: () => {'color': '#FF0000'},
                                                          );
                                                          final color = _parseColor(fabricData['color'] as String);
                                                          return Container(
                                                            margin: const EdgeInsets.only(right: 12),
                                                            width: 24,
                                                            height: 24,
                                                            decoration: BoxDecoration(
                                                              color: color,
                                                              shape: BoxShape.circle,
                                                              border: Border.all(
                                                                color: Colors.grey.shade400,
                                                                width: 2,
                                                              ),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors.black.withOpacity(0.15),
                                                                  blurRadius: 4,
                                                                  offset: const Offset(0, 2),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                      ),
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
                                                              _onFabricYardageChanged();
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
                                                              double newYards = double.tryParse(val) ?? 0;
                                                              _variants[idx].fabrics[fIdx] = VariantFabric(
                                                                fabricId: fabric.fabricId,
                                                                fabricName: fabric.fabricName,
                                                                yardsRequired: newYards,
                                                              );
                                                              _onFabricYardageChanged();
                                                            });
                                                          },
                                                          enabled: remaining > 0 || fabric.yardsRequired > 0,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete, color: Colors.red),
                                                        tooltip: 'Remove Fabric',
                                                        onPressed: () {
                                                          setState(() {
                                                            _variants[idx].fabrics.removeAt(fIdx);
                                                            _onFabricYardageChanged();
                                                          });
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: overAllocated
                                                          ? Colors.red.shade50
                                                          : Colors.green.shade50,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: overAllocated
                                                            ? Colors.red.shade200
                                                            : Colors.green.shade200,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              overAllocated
                                                                  ? Icons.warning_rounded
                                                                  : Icons.inventory_rounded,
                                                              size: 16,
                                                              color: overAllocated
                                                                  ? Colors.red.shade600
                                                                  : Colors.green.shade600,
                                                            ),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              'Fabric Availability',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w600,
                                                                color: overAllocated
                                                                    ? Colors.red.shade800
                                                                    : Colors.green.shade800,
                                                              ),
                                                            ),
                                                            const Spacer(),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: overAllocated
                                                                    ? Colors.red.shade100
                                                                    : Colors.green.shade100,
                                                                borderRadius: BorderRadius.circular(12),
                                                              ),
                                                              child: Text(
                                                                '${allocated.toStringAsFixed(1)}/${available.toStringAsFixed(1)} yds',
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: overAllocated
                                                                      ? Colors.red.shade700
                                                                      : Colors.green.shade700,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 8),
                                                        ClipRRect(
                                                          borderRadius: BorderRadius.circular(6),
                                                          child: LinearProgressIndicator(
                                                            value: available > 0 ? (allocated / available).clamp(0.0, 1.0) : 0.0,
                                                            minHeight: 6,
                                                            backgroundColor: Colors.grey.shade200,
                                                            valueColor: AlwaysStoppedAnimation<Color>(
                                                              overAllocated
                                                                  ? Colors.red.shade400
                                                                  : Colors.green.shade400,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Text(
                                                          overAllocated
                                                              ? 'Over-allocated by ${(allocated - available).toStringAsFixed(1)} yards'
                                                              : '${(available - allocated).toStringAsFixed(1)} yards remaining',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: overAllocated
                                                                ? Colors.red.shade600
                                                                : Colors.green.shade600,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }).toList(),
                                            if (variant.fabrics.isEmpty)
                                              const Text('No fabrics added yet.', style: TextStyle(color: Colors.grey)),
                                            Align(
                                              alignment: Alignment.bottomRight,
                                              child: Padding(
                                                padding: const EdgeInsets.only(top: 8.0),
                                                child: OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                    side: const BorderSide(color: Colors.red),
                                                    minimumSize: const Size.fromHeight(40),
                                                  ),
                                                  icon: const Icon(Icons.delete),
                                                  label: const Text('Delete Variant'),
                                                  onPressed: () {
                                                    setState(() {
                                                      _variants.removeAt(idx);
                                                      _onFabricYardageChanged();
                                                    });
                                                  },
                                                ),
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
                  // --- Supplier Details Section ---
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
                          if (_supplier != null) ...[
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.grey.shade200,
                                  child: const Icon(Icons.business, color: Colors.blue),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _supplier!['supplierName'] ?? 'Unknown Supplier',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(_supplier!['email'] ?? 'No email'),
                            Text(_supplier!['contactNum'] ?? 'No contact'),
                            Text(_supplier!['location'] ?? 'No address'),
                          ] else ...[
                            const Text('No supplier found.'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // --- Variant Breakdown Summary Section ---
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
                          if (_variants.isNotEmpty) ...[
                            Container(
                              height: 120,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: _variants.asMap().entries.map((entry) {
                                    int idx = entry.key;
                                    ProductVariant variant = entry.value;
                                    int maxQty = _variants.map((v) => v.quantity).fold(0, (a, b) => a > b ? a : b);
                                    double percent = maxQty > 0 ? (variant.quantity / maxQty) : 0;
                                    final List<Color> barColors = [
                                      Colors.blue.shade600,
                                      Colors.green.shade600,
                                      Colors.orange.shade600,
                                      Colors.purple.shade600,
                                      Colors.teal.shade600,
                                      Colors.pink.shade600,
                                      Colors.indigo.shade600,
                                      Colors.amber.shade600,
                                    ];
                                    final barColor = barColors[idx % barColors.length];
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(bottom: 2),
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: barColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              variant.quantity.toString(),
                                              style: TextStyle(
                                                color: barColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 9,
                                              ),
                                            ),
                                          ),
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 600),
                                            height: (percent * 40 + 12).clamp(12.0, 52.0),
                                            width: 24,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [
                                                  barColor,
                                                  barColor.withOpacity(0.7),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(4),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: barColor.withOpacity(0.2),
                                                  blurRadius: 2,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          SizedBox(
                                            width: 36,
                                            child: Text(
                                              'V${idx + 1}',
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 9,
                                                color: barColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _variants.asMap().entries.map((entry) {
                                  int idx = entry.key;
                                  ProductVariant variant = entry.value;
                                  final List<Color> cardColors = [
                                    Colors.blue.shade600,
                                    Colors.green.shade600,
                                    Colors.orange.shade600,
                                    Colors.purple.shade600,
                                    Colors.teal.shade600,
                                    Colors.pink.shade600,
                                    Colors.indigo.shade600,
                                    Colors.amber.shade600,
                                  ];
                                  final cardColor = cardColors[idx % cardColors.length];
                                  return Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    width: 220,
                                    child: Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              cardColor.withOpacity(0.1),
                                              cardColor.withOpacity(0.05),
                                            ],
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    color: cardColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Variant ${idx + 1}',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
                                                          color: cardColor,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      Text(
                                                        'Size: ${variant.size}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey.shade600,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (variant.fabrics.isNotEmpty) ...[
                                              if (variant.fabrics.length == 1) ...[
                                                Row(
                                                  children: [
                                                    Builder(
                                                      builder: (context) {
                                                        final fabricData = _userFabrics.firstWhere(
                                                          (f) => f['id'] == variant.fabrics.first.fabricId,
                                                          orElse: () => {'name': 'Unknown', 'color': '#808080'},
                                                        );
                                                        final fabricColor = _parseColor(fabricData['color'] as String);
                                                        return Container(
                                                          width: 16,
                                                          height: 16,
                                                          decoration: BoxDecoration(
                                                            color: fabricColor,
                                                            shape: BoxShape.circle,
                                                            border: Border.all(color: Colors.white, width: 2),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Builder(
                                                        builder: (context) {
                                                          final fabricData = _userFabrics.firstWhere(
                                                            (f) => f['id'] == variant.fabrics.first.fabricId,
                                                            orElse: () => {'name': 'Unknown', 'color': '#808080'},
                                                          );
                                                          return Text(
                                                            fabricData['name'] ?? 'Unknown',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.grey.shade600,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ] else ...[
                                                Wrap(
                                                  spacing: 4,
                                                  runSpacing: 4,
                                                  children: variant.fabrics.take(3).map((variantFabric) {
                                                    final fabricData = _userFabrics.firstWhere(
                                                      (f) => f['id'] == variantFabric.fabricId,
                                                      orElse: () => {'name': 'Unknown', 'color': '#808080'},
                                                    );
                                                    final fabricColor = _parseColor(fabricData['color'] as String);
                                                    final fabricName = fabricData['name'] ?? 'Unknown';
                                                    return Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: fabricColor.withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: fabricColor.withOpacity(0.5), width: 1),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Container(
                                                            width: 8,
                                                            height: 8,
                                                            decoration: BoxDecoration(
                                                              color: fabricColor,
                                                              shape: BoxShape.circle,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            fabricName.length > 8 ? '${fabricName.substring(0, 8)}...' : fabricName,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: fabricColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList()
                                                    ..addAll(variant.fabrics.length > 3 ? [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey.shade200,
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          '+${variant.fabrics.length - 3}',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.grey.shade600,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ] : []),
                                                ),
                                              ],
                                            ] else ...[
                                              Text(
                                                'No fabric',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Text(
                                              '${variant.quantity} unit${variant.quantity == 1 ? '' : 's'}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  );
                                  }).toList(),
                                ),
                            )
                          ] else ...[
                            Container(
                              height: 80,
                              color: Colors.grey.shade100,
                              child: const Center(child: Text('No variants to summarize.')),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      await _saveJobOrder();
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
            ),
          ],
        );
      },
    );
  }
}

// ==========================
// DATA MODELS - Updated to match new schema
// ==========================
// All model classes have been moved to lib/models/. Please import them as needed.