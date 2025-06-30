import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fashion_tech/models/product_variant.dart';

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

class AddJobOrderModal extends StatefulWidget {
  const AddJobOrderModal({Key? key}) : super(key: key);

  @override
  State<AddJobOrderModal> createState() => _AddJobOrderModalState();
}

class _AddJobOrderModalState extends State<AddJobOrderModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _orderDateController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _assignedToController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _specialInstructionsController = TextEditingController();
  bool _isUpcycled = false;
  String _jobStatus = 'In Progress';
  List<FormProductVariant> _variants = [];

  List<Map<String, dynamic>> _userFabrics = [];
  bool _loadingFabrics = true;

  // Store supplier-fabric relationships for display
  Map<String, Map<String, dynamic>> _fabricSuppliers = {};
  bool _loadingFabricSuppliers = true;

  Map<String, double> _fabricAllocated = {};

  @override
  void initState() {
    super.initState();
    _fetchUserFabrics();
    _fetchFabricSuppliers();
    _quantityController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _fetchUserFabrics() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fabrics')
          .get()
          .timeout(Duration(seconds: 10));
      
      setState(() {
        _userFabrics = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'fabricID': doc.id,
            'name': data['name'] ?? '',
            'type': data['type'] ?? '',
            'quantity': data['quantity'] ?? 0,
            'color': data['color'] ?? '#FF0000',
            'qualityGrade': data['qualityGrade'] ?? '',
            'expensePerYard': data['expensePerYard'] ?? 0.0,
            'swatchImageURL': data['swatchImageURL'] ?? '',
          };
        }).toList();
        _loadingFabrics = false;
      });
    } catch (e) {
      print('Error fetching fabrics: $e');
      setState(() {
        _loadingFabrics = false;
      });
    }
  }

  Future<void> _fetchFabricSuppliers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('suppliersFabric')
          .get()
          .timeout(Duration(seconds: 10));
      
      final Map<String, Map<String, dynamic>> suppliers = {};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final fabricId = data['fabricID'] as String?;
        if (fabricId != null) {
          suppliers[fabricId] = data;
        }
      }
      
      setState(() {
        _fabricSuppliers = suppliers;
        _loadingFabricSuppliers = false;
      });
    } catch (e) {
      print('Error fetching fabric suppliers: $e');
      setState(() {
        _loadingFabricSuppliers = false;
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
    _customerNameController.dispose();
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

  Color _parseColor(String colorString) {
    try {
      if (colorString.startsWith('#')) {
        return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
      }
      return Colors.grey;
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFabrics || _loadingFabricSuppliers) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading fabrics and suppliers...'),
            SizedBox(height: 8),
            Text(
              _loadingFabrics ? 'Fetching fabrics...' : 'Fabrics loaded ✓',
              style: TextStyle(
                color: _loadingFabrics ? Colors.grey : Colors.green,
                fontSize: 12,
              ),
            ),
            Text(
              _loadingFabricSuppliers ? 'Fetching fabric suppliers...' : 'Fabric suppliers loaded ✓',
              style: TextStyle(
                color: _loadingFabricSuppliers ? Colors.grey : Colors.green,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (_userFabrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Fabrics Available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Please add some fabrics before creating a job order.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _userFabrics = [
                    {
                      'id': 'test_fabric',
                      'fabricID': 'test_fabric',
                      'name': 'Test Fabric',
                      'type': 'Cotton',
                      'quantity': 100,
                      'color': '#FF0000',
                      'qualityGrade': 'Standard',
                      'expensePerYard': 10.0,
                      'swatchImageURL': '',
                    }
                  ];
                });
              },
              child: Text('Continue with Test Data'),
            ),
          ],
        ),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.95,
      minChildSize: 0.7,
      maxChildSize: 0.98,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade600,
                      Colors.blue.shade700,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade200,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.work_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Job Order',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Create a custom production order',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Basic Information Section
                    _buildSection(
                      title: 'Basic Information',
                      icon: Icons.info_outline,
                      color: Colors.blue,
                      children: [
                        _buildTextField(
                          controller: _productNameController,
                          label: 'Product Name',
                          hint: 'E.g., Summer Collection Dress',
                          icon: Icons.inventory_2,
                          validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _customerNameController,
                          label: 'Customer Name',
                          hint: 'E.g., John Doe',
                          icon: Icons.person,
                          validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Timeline Section
                    _buildSection(
                      title: 'Timeline',
                      icon: Icons.schedule,
                      color: Colors.green,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildDateField(
                                controller: _orderDateController,
                                label: 'Order Date',
                                icon: Icons.event,
                                validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDateField(
                                controller: _dueDateController,
                                label: 'Due Date',
                                icon: Icons.schedule,
                                validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Assignment & Quantities Section
                    _buildSection(
                      title: 'Assignment & Quantities',
                      icon: Icons.work,
                      color: Colors.orange,
                      children: [
                        _buildTextField(
                          controller: _assignedToController,
                          label: 'Assigned To',
                          hint: 'E.g., Maria Santos',
                          icon: Icons.person_outline,
                          validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _quantityController,
                                label: 'Total Quantity',
                                hint: 'E.g., 10',
                                icon: Icons.numbers,
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  if (val?.isEmpty ?? true) return 'Required';
                                  final n = int.tryParse(val!);
                                  if (n == null || n <= 0) return 'Must be positive';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _priceController,
                                label: 'Price (₱)',
                                hint: 'E.g., 1500.00',
                                icon: Icons.attach_money,
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  if (val?.isEmpty ?? true) return 'Required';
                                  final n = double.tryParse(val!);
                                  if (n == null || n < 0) return 'Must be valid';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Additional Details Section
                    _buildSection(
                      title: 'Additional Details',
                      icon: Icons.settings,
                      color: Colors.purple,
                      children: [
                        _buildTextField(
                          controller: _specialInstructionsController,
                          label: 'Special Instructions',
                          hint: 'E.g., Custom embroidery, specific requirements...',
                          icon: Icons.notes,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        _buildSwitchTile(
                          title: 'Upcycled Product',
                          subtitle: 'Mark if using recycled materials',
                          value: _isUpcycled,
                          onChanged: (val) => setState(() => _isUpcycled = val),
                          icon: Icons.recycling,
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          value: _jobStatus,
                          label: 'Job Status',
                          icon: Icons.flag,
                          items: ['Open', 'In Progress', 'Done'],
                          onChanged: (val) => setState(() => _jobStatus = val ?? 'In Progress'),
                          validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Product Variants Section
              _buildVariantsSection(),
              
              const SizedBox(height: 24),
              
              // Fabric Suppliers Section
              _buildSuppliersSection(),
              
              const SizedBox(height: 24),
              
              // Variant Breakdown Summary Section
              _buildVariantBreakdownSection(),
              
              const SizedBox(height: 24),
              
              // Save Button
              ElevatedButton(
                onPressed: _saveJobOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Save Job Order',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
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
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
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
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDate(controller),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
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
      ),
      validator: validator,
    );
  }

  Widget _buildDropdownField({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item),
      )).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
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
      ),
      validator: validator,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: value ? Colors.green.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: value ? Colors.green.shade600 : Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.green.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildVariantsSection() {
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
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.category,
                  color: Colors.indigo.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Product Variants',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _variants.add(FormProductVariant(
                      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                      productID: 'temp_product',
                      size: 'Small',
                      color: 'Red',
                      quantityInStock: 0,
                      fabrics: [],
                    ));
                  });
                },
                icon: Icon(Icons.add, size: 18),
                label: Text('Add Variant'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_variants.isEmpty)
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
                      Icons.category_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No variants added yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add product variants to specify sizes and fabrics',
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
            Column(
              children: _variants.asMap().entries.map((entry) {
                int idx = entry.key;
                FormProductVariant variant = entry.value;
                return _buildVariantCard(variant, idx);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildVariantCard(FormProductVariant variant, int index) {
    final colors = [
      Colors.blue.shade50,
      Colors.green.shade50,
      Colors.orange.shade50,
      Colors.purple.shade50,
      Colors.teal.shade50,
    ];
    final bgColor = colors[index % colors.length];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Variant ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  setState(() {
                    _variants.removeAt(index);
                    _onFabricYardageChanged();
                  });
                },
                icon: Icon(Icons.delete, color: Colors.red.shade400),
                tooltip: 'Remove Variant',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: variant.size,
                  items: ['Small', 'Medium', 'Large', 'XL', 'XXL'].map((size) => 
                    DropdownMenuItem(value: size, child: Text(size))
                  ).toList(),
                  onChanged: (val) {
                    setState(() {
                      _variants[index].size = val ?? 'Small';
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Size',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: variant.quantity == 0 ? '' : variant.quantity.toString(),
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    setState(() {
                      _variants[index].quantity = int.tryParse(val) ?? 0;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
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
          
          const SizedBox(height: 16),
          
          // Display fabric colors if any fabrics are added
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
                  final luminance = color.computeLuminance();
                  final isLightColor = luminance > 0.5;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isLightColor 
                              ? Colors.grey.shade600 
                              : Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 3,
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
              Text(
                'Fabrics',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _userFabrics.isEmpty ? null : () {
                  setState(() {
                    _variants[index].fabrics.add(VariantFabric(
                      fabricId: _userFabrics.first['id']!,
                      fabricName: _userFabrics.first['name']!,
                      yardsRequired: 0,
                    ));
                  });
                },
                icon: Icon(Icons.add, size: 16),
                label: Text('Add Fabric'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (variant.fabrics.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade400, size: 20),
                  const SizedBox(width: 12),
                  Text('No fabrics added yet', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            )
          else
            Column(
              children: variant.fabrics.asMap().entries.map((fabricEntry) {
                int fabricIndex = fabricEntry.key;
                VariantFabric fabric = fabricEntry.value;
                return _buildFabricRow(fabric, index, fabricIndex);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildFabricRow(VariantFabric fabric, int variantIndex, int fabricIndex) {
    final fabricData = _userFabrics.firstWhere(
      (f) => f['id'] == fabric.fabricId,
      orElse: () => {'color': '#FF0000', 'name': 'Unknown', 'quantity': 0},
    );
    final color = _parseColor(fabricData['color'] as String);
    final luminance = color.computeLuminance();
    final isLightColor = luminance > 0.5;
    
    final available = (fabricData['quantity'] ?? 0) as num;
    final allocated = _fabricAllocated[fabric.fabricId] ?? 0;
    final otherAllocated = allocated - fabric.yardsRequired;
    final remaining = available - otherAllocated;
    final overAllocated = allocated > available;
    
    return Column(
      children: [
        Container(
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
                  border: Border.all(
                    color: isLightColor 
                        ? Colors.grey.shade600 
                        : Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: fabric.fabricId,
                  items: _userFabrics.map((f) => DropdownMenuItem<String>(
                    value: f['id'] as String,
                    child: Text(f['name'] as String, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      final selected = _userFabrics.firstWhere((f) => f['id'] == val);
                      _variants[variantIndex].fabrics[fabricIndex] = VariantFabric(
                        fabricId: val!,
                        fabricName: selected['name'] as String,
                        yardsRequired: fabric.yardsRequired,
                      );
                      _onFabricYardageChanged();
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Fabric',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: fabric.yardsRequired == 0 ? '' : fabric.yardsRequired.toString(),
                  decoration: InputDecoration(
                    labelText: 'Yards',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    setState(() {
                      double newYards = double.tryParse(val) ?? 0;
                      _variants[variantIndex].fabrics[fabricIndex] = VariantFabric(
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
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _variants[variantIndex].fabrics.removeAt(fabricIndex);
                    _onFabricYardageChanged();
                  });
                },
                icon: Icon(Icons.delete, color: Colors.red.shade400, size: 20),
                tooltip: 'Remove Fabric',
              ),
            ],
          ),
        ),
        
        // Fabric Availability Tracker
        Container(
          margin: const EdgeInsets.only(bottom: 12),
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
  }

  Widget _buildSuppliersSection() {
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
              if (_loadingFabricSuppliers)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_variants.isEmpty)
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
    for (final variant in _variants) {
      for (final fabric in variant.fabrics) {
        usedFabricIds.add(fabric.fabricId);
      }
    }
    
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
    final List<String> fabricsWithoutSuppliers = [];
    
    for (final fabricId in usedFabricIds) {
      final fabricData = _userFabrics.firstWhere(
        (f) => f['id'] == fabricId,
        orElse: () => {'name': 'Unknown Fabric'},
      );
      
      if (_fabricSuppliers.containsKey(fabricId)) {
        final supplier = _fabricSuppliers[fabricId]!;
        final supplierKey = supplier['supplierID'] ?? 'unknown';
        
        if (!supplierFabrics.containsKey(supplierKey)) {
          supplierFabrics[supplierKey] = [];
        }
        supplierFabrics[supplierKey]!.add({
          'fabricId': fabricId,
          'fabricName': fabricData['name'] ?? 'Unknown Fabric',
          'fabricColor': fabricData['color'] ?? '#FF0000',
          'supplier': supplier,
        });
      } else {
        fabricsWithoutSuppliers.add(fabricData['name'] ?? 'Unknown Fabric');
      }
    }
    
    return Column(
      children: [
        if (supplierFabrics.isNotEmpty) ...[
          ...supplierFabrics.entries.map((entry) {
            final supplierData = entry.value.first['supplier'] as Map<String, dynamic>;
            final fabrics = entry.value;
            
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
                              supplierData['supplierName'] ?? 'Unknown Supplier',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.teal.shade800,
                              ),
                            ),
                            if (supplierData['contactNumber'] != null)
                              Text(
                                supplierData['contactNumber'],
                                style: TextStyle(
                                  color: Colors.teal.shade600,
                                  fontSize: 14,
                                ),
                              ),
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: fabrics.map((fabric) {
                      final color = _parseColor(fabric['fabricColor'] as String);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              fabric['fabricName'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
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
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: fabricsWithoutSuppliers.map((fabricName) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(
                        fabricName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVariantBreakdownSection() {
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
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.analytics,
                  color: Colors.purple.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Variant Breakdown Summary',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_variants.isNotEmpty) ...[
            // Horizontal scrollable variant cards
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
                  children: _variants.asMap().entries.map((entry) {
                    int idx = entry.key;
                    FormProductVariant variant = entry.value;
                    final variantColors = [
                      Colors.blue.shade100,
                      Colors.green.shade100,
                      Colors.orange.shade100,
                      Colors.purple.shade100,
                      Colors.teal.shade100,
                    ];
                    final cardColor = variantColors[idx % variantColors.length];
                    
                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      width: 140,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Variant ${idx + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            variant.size,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (variant.fabrics.isNotEmpty) ...[
                            Row(
                              children: [
                                ...(variant.fabrics.take(3).map((fabric) {
                                  final fabricData = _userFabrics.firstWhere(
                                    (f) => f['id'] == fabric.fabricId,
                                    orElse: () => {'color': '#FF0000'},
                                  );
                                  final color = _parseColor(fabricData['color'] as String);
                                  return Container(
                                    margin: const EdgeInsets.only(right: 2),
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1),
                                    ),
                                  );
                                }).toList()),
                                if (variant.fabrics.length > 3) ...[
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '+${variant.fabrics.length - 3}',
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ] else ...[
                            Text(
                              'No fabric',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            '${variant.quantity} unit${variant.quantity == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
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
            
            // Summary stats
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSummaryCard(
                    'Total Variants',
                    '${_variants.length}',
                    Icons.category,
                    Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'Total Fabrics',
                    '${_variants.fold(0, (sum, v) => sum + v.fabrics.length)}',
                    Icons.palette,
                    Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'Total Yards',
                    '${_variants.fold(0.0, (sum, v) => sum + v.fabrics.fold(0.0, (s, f) => s + f.yardsRequired)).toStringAsFixed(1)}',
                    Icons.straighten,
                    Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Builder(
                    builder: (context) {
                      int globalQty = int.tryParse(_quantityController.text) ?? 0;
                      int sumVariants = _variants.fold(0, (sum, v) => sum + v.quantity);
                      bool isBalanced = globalQty == sumVariants;
                      return _buildSummaryCard(
                        'Quantity Status',
                        isBalanced ? 'Balanced' : 'Unbalanced',
                        isBalanced ? Icons.check_circle : Icons.warning,
                        isBalanced ? Colors.green : Colors.red,
                      );
                    },
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No variants to summarize.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color.shade600,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _saveJobOrder() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }
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
    int globalQty = int.tryParse(_quantityController.text) ?? 0;
    int sumVariants = _variants.fold(0, (sum, v) => sum + v.quantity);
    if (globalQty != sumVariants) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sum of variant quantities ($sumVariants) must equal global quantity ($globalQty).')),
      );
      return;
    }

    try {
      // Save product
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

      // Save job order
      final jobOrderRef = FirebaseFirestore.instance.collection('jobOrders').doc();
      await jobOrderRef.set({
        'productID': productRef.id,
        'quantity': globalQty,
        'customerName': _customerNameController.text,
        'status': _jobStatus,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'dueDate': (_dueDateController.text.isNotEmpty)
            ? Timestamp.fromDate(DateTime.tryParse(_dueDateController.text) ?? DateTime.now())
            : FieldValue.serverTimestamp(),
        'assignedTo': _assignedToController.text,
        'createdBy': 'current_user_id',
        'specialInstructions': _specialInstructionsController.text,
        'orderDate': (_orderDateController.text.isNotEmpty)
            ? Timestamp.fromDate(DateTime.tryParse(_orderDateController.text) ?? DateTime.now())
            : FieldValue.serverTimestamp(),
      });

      // Save variants
      for (final variant in _variants) {
        final variantRef = FirebaseFirestore.instance.collection('productVariants').doc();
        await variantRef.set({
          'productID': productRef.id,
          'size': variant.size,
          'color': variant.color,
          'quantityInStock': variant.quantity,
          'fabrics': variant.fabrics.map((f) => {
            'fabricId': f.fabricId,
            'fabricName': f.fabricName,
            'yardsRequired': f.yardsRequired,
          }).toList(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job order saved successfully!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving job order: $e')),
      );
    }
  }
}
