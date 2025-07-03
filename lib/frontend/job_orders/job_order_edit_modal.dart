import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../utils/color_utils.dart';
import '../../utils/size_utils.dart';
import 'models/form_models.dart';
import 'widgets/variant_card.dart';
import 'widgets/variant_breakdown_summary.dart';
import 'widgets/fabric_suppliers_section.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JobOrderEditModal extends StatefulWidget {
  final String jobOrderId;

  const JobOrderEditModal({Key? key, required this.jobOrderId}) : super(key: key);

  @override
  State<JobOrderEditModal> createState() => _JobOrderEditModalState();
}

class FormVariantFabric {
  final String fabricId;
  final double yardageUsed;

  FormVariantFabric({
    required this.fabricId,
    required this.yardageUsed,
  });
}

class _JobOrderEditModalState extends State<JobOrderEditModal>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _variantsSectionKey = GlobalKey();
  final GlobalKey _basicInfoSectionKey = GlobalKey();
  final GlobalKey _timelineSectionKey = GlobalKey();
  final GlobalKey _assignmentSectionKey = GlobalKey();
  final GlobalKey _additionalDetailsSectionKey = GlobalKey();
  final TextEditingController _jobOrderNameController = TextEditingController();
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

  Map<String, Map<String, dynamic>> _fabricSuppliers = {};
  bool _loadingFabricSuppliers = true;

  Map<String, double> _fabricAllocated = {};

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _loadingJobOrder = true;
  bool _saving = false;

  // Example options for size and color (replace with your actual options)
  final List<String> _sizeOptions = ['S', 'M', 'L', 'XL'];
  final List<String> _colorOptions = ['Red', 'Blue', 'Green', 'Black', 'White'];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fetchUserFabrics();
    _fetchFabricSuppliers();
    _fetchJobOrderData();

    _quantityController.addListener(() {
      setState(() {});
    });

    _animationController.forward();
  }

  Future<void> _fetchUserFabrics() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fabrics')
          .get()
          .timeout(const Duration(seconds: 10));
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
            'pricePerUnit': data['pricePerUnit'] ?? 0.0,
            'swatchImageURL': data['swatchImageURL'] ?? '',
          };
        }).toList();
        _loadingFabrics = false;
      });
    } catch (e) {
      setState(() {
        _loadingFabrics = false;
      });
    }
  }

  Future<void> _fetchFabricSuppliers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('supplierFabrics')
          .get()
          .timeout(const Duration(seconds: 10));
      final Map<String, Map<String, dynamic>> suppliers = {};
      final Set<String> supplierIds = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final fabricId = data['fabricID'] as String?;
        final supplierId = data['supplierID'] as String?;
        if (fabricId != null && supplierId != null) {
          suppliers[fabricId] = data;
          supplierIds.add(supplierId);
        }
      }
      final Map<String, Map<String, dynamic>> supplierDetails = {};
      if (supplierIds.isNotEmpty) {
        final supplierSnapshot = await FirebaseFirestore.instance
            .collection('suppliers')
            .get()
            .timeout(const Duration(seconds: 10));
        for (final doc in supplierSnapshot.docs) {
          final data = doc.data();
          final supplierId = doc.id;
          if (supplierIds.contains(supplierId)) {
            supplierDetails[supplierId] = data;
          }
        }
      }
      for (final fabricId in suppliers.keys) {
        final fabricSupplierData = suppliers[fabricId]!;
        final supplierId = fabricSupplierData['supplierID'] as String?;
        if (supplierId != null && supplierDetails.containsKey(supplierId)) {
          fabricSupplierData.addAll(supplierDetails[supplierId]!);
        }
      }
      setState(() {
        _fabricSuppliers = suppliers;
        _loadingFabricSuppliers = false;
      });
    } catch (e) {
      setState(() {
        _loadingFabricSuppliers = false;
      });
    }
  }

  Future<void> _fetchJobOrderData() async {
    try {
      final jobOrderDoc = await FirebaseFirestore.instance
          .collection('jobOrders')
          .doc(widget.jobOrderId)
          .get();
      final jobOrder = jobOrderDoc.data();
      if (jobOrder == null) {
        setState(() {
          _loadingJobOrder = false;
        });
        return;
      }
      _jobOrderNameController.text = jobOrder['name'] ?? '';
      _customerNameController.text = jobOrder['customerName'] ?? '';
      _orderDateController.text = _timestampToDateString(jobOrder['orderDate']);
      _dueDateController.text = _timestampToDateString(jobOrder['dueDate']);
      _assignedToController.text = jobOrder['assignedTo'] ?? '';
      _quantityController.text = (jobOrder['quantity'] ?? '').toString();
      _priceController.text = (jobOrder['price'] ?? '').toString();
      _specialInstructionsController.text = jobOrder['specialInstructions'] ?? '';
      _isUpcycled = jobOrder['isUpcycled'] ?? false;
      _jobStatus = jobOrder['status'] ?? 'In Progress';

      // Fetch all jobOrderDetails for this job order
      final detailsSnapshot = await FirebaseFirestore.instance
          .collection('jobOrderDetails')
          .where('jobOrderID', isEqualTo: widget.jobOrderId)
          .get();

      // Group details by (size, color, quantity) to support multiple fabrics per variant
      final Map<String, FormProductVariant> variantMap = {};
      for (final doc in detailsSnapshot.docs) {
        final data = doc.data();
        final size = data['size'] ?? '';
        final color = data['color'] ?? '';
        final quantity = data['quantity'] ?? 0;
        final key = '$size|$color|$quantity';

        final fabric = VariantFabric(
          fabricId: data['fabricID'] ?? '',
          fabricName: data['fabricName'] ?? '',
          yardageUsed: (data['yardageUsed'] ?? 0).toDouble(),
        );

        if (!variantMap.containsKey(key)) {
          variantMap[key] = FormProductVariant(
            id: doc.id,
            productID: jobOrder['productID'] ?? '',
            size: size,
            color: color,
            quantityInStock: 0,
            quantity: quantity,
            fabrics: [fabric],
          );
        } else {
          variantMap[key]!.fabrics.add(fabric);
        }
      }

      setState(() {
        _variants = variantMap.values.toList();
        _loadingJobOrder = false;
      });
    } catch (e) {
      setState(() {
        _loadingJobOrder = false;
      });
    }
  }

  String _timestampToDateString(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime? date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp);
    }
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _jobOrderNameController.dispose();
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

  @override
  Widget build(BuildContext context) {
    if (_loadingFabrics || _loadingFabricSuppliers || _loadingJobOrder) {
      return Center(child: CircularProgressIndicator());
    }
    if (_userFabrics.isEmpty) {
      return Center(child: Text('No Fabrics Available'));
    }
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: DraggableScrollableSheet(
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
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildBasicInfoSection(),
                        const SizedBox(height: 20),
                        _buildTimelineSection(),
                        const SizedBox(height: 20),
                        _buildAssignmentSection(),
                        const SizedBox(height: 20),
                        _buildAdditionalDetailsSection(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildVariantsSection(),
                  const SizedBox(height: 24),
                  FabricSuppliersSection(
                    variants: _variants,
                    userFabrics: _userFabrics,
                    fabricSuppliers: _fabricSuppliers,
                    loadingFabricSuppliers: _loadingFabricSuppliers,
                    parseColor: ColorUtils.parseColor,
                  ),
                  const SizedBox(height: 24),
                  VariantBreakdownSummary(
                    variants: _variants,
                    userFabrics: _userFabrics,
                    quantityController: _quantityController,
                    parseColor: ColorUtils.parseColor,
                  ),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
              Icons.edit,
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
                  'Edit Job Order',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Update production order details',
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
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSection(
      title: 'Basic Info',
      icon: Icons.info,
      color: Colors.deepPurple,
      children: [
        _buildTextField(
          controller: _jobOrderNameController,
          label: 'Job Order Name',
          icon: Icons.title,
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _customerNameController,
          label: 'Customer Name',
          icon: Icons.person,
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Required' : null,
        ),
      ],
      key: _basicInfoSectionKey,
    );
  }

  Widget _buildTimelineSection() {
    return _buildSection(
      title: 'Timeline',
      icon: Icons.calendar_today,
      color: Colors.teal,
      children: [
        _buildDateField(
          controller: _orderDateController,
          label: 'Order Date',
          icon: Icons.event,
        ),
        const SizedBox(height: 12),
        _buildDateField(
          controller: _dueDateController,
          label: 'Due Date',
          icon: Icons.event_available,
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Required' : null,
        ),
      ],
      key: _timelineSectionKey,
    );
  }

  Widget _buildAssignmentSection() {
    return _buildSection(
      title: 'Assignment',
      icon: Icons.assignment_ind,
      color: Colors.orange,
      children: [
        _buildTextField(
          controller: _assignedToController,
          label: 'Assigned To',
          icon: Icons.person_add,
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Required' : null,
        ),
      ],
      key: _assignmentSectionKey,
    );
  }

  Widget _buildAdditionalDetailsSection() {
    return _buildSection(
      title: 'Additional Details',
      icon: Icons.notes,
      color: Colors.indigo,
      children: [
        _buildTextField(
          controller: _quantityController,
          label: 'Total Quantity',
          icon: Icons.confirmation_number,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _priceController,
          label: 'Price',
          icon: Icons.attach_money,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _specialInstructionsController,
          label: 'Special Instructions',
          icon: Icons.comment,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        _buildSwitchTile(
          title: 'Upcycled',
          subtitle: 'Is this an upcycled job order?',
          value: _isUpcycled,
          onChanged: (val) => setState(() => _isUpcycled = val),
          icon: Icons.recycling,
        ),
        const SizedBox(height: 12),
        _buildDropdownField(
          value: _jobStatus,
          label: 'Job Status',
          icon: Icons.flag,
          items: ['In Progress', 'Completed', 'Cancelled'],
          onChanged: (val) => setState(() => _jobStatus = val ?? 'In Progress'),
        ),
      ],
      key: _additionalDetailsSectionKey,
    );
  }

  Widget _buildVariantsSection() {
    return Container(
      key: _variantsSectionKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Variants',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 8),
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VariantCard(
                      variant: variant,
                      index: idx,
                      userFabrics: _userFabrics,
                      fabricAllocated: _fabricAllocated,
                      quantityController: _quantityController,
                      sumVariants: _variants.fold<int>(0, (sum, v) => sum + (v.quantity ?? 0)),
                      onRemove: () {
                        setState(() {
                          _variants.removeAt(idx);
                        });
                      },
                      onVariantChanged: (index) {
                        setState(() {});
                      },
                      onFabricYardageChanged: () {
                        setState(() {});
                      },
                    ),
                    // Show fabric colors and yards for each variant
                    ...variant.fabrics.map((f) {
                      final fabric = _userFabrics.firstWhere(
                        (fab) => fab['fabricID'] == f.fabricId,
                        orElse: () => <String, dynamic>{},
                      );
                      final fabricName = fabric != null && fabric['name'] != null && fabric['name'].toString().isNotEmpty
                          ? fabric['name']
                          : (f.fabricName ?? 'Unknown');
                      final fabricColor = fabric != null && fabric['color'] != null
                          ? fabric['color']
                          : '#CCCCCC';
                      return Padding(
                        padding: const EdgeInsets.only(left: 24, top: 4, bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: ColorUtils.parseColor(fabricColor),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                            ),
                            Text(
                              '$fabricName',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${f.yardageUsed.toStringAsFixed(2)} yds',
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: Icon(Icons.add),
            label: Text('Add Variant'),
            onPressed: () {
              setState(() {
                _variants.add(FormProductVariant(
                  id: UniqueKey().toString(),
                  productID: '',
                  size: _sizeOptions.isNotEmpty ? _sizeOptions.first : '',
                  color: _colorOptions.isNotEmpty ? _colorOptions.first : '',
                  quantityInStock: 0,
                  quantity: 1,
                  fabrics: _userFabrics.isNotEmpty
                      ? [
                          VariantFabric(
                            fabricId: _userFabrics.first['fabricID'],
                            fabricName: _userFabrics.first['name'],
                            yardageUsed: 0.0,
                          ),
                        ]
                      : [],
                ));
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saving ? null : _updateJobOrder,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
      ),
      child: _saving
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save, size: 20),
                SizedBox(width: 8),
                Text(
                  'Update Job Order',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    Key? key,
    bool hasError = false,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: hasError ? Colors.red.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError ? Colors.red : color.withOpacity(0.2),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
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
      validator: validator,
      readOnly: true,
      onTap: () => _pickDate(controller),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
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
      value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
      items: items
          .map((e) => DropdownMenuItem<String>(
                value: e,
                child: Text(e),
              ))
          .toList(),
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _updateJobOrder() async {
    print('[DEBUG] _updateJobOrder called');
    print('[DEBUG] jobOrderName: "${_jobOrderNameController.text}"');
    print('[DEBUG] customerName: "${_customerNameController.text}"');
    print('[DEBUG] orderDate: "${_orderDateController.text}"');
    print('[DEBUG] dueDate: "${_dueDateController.text}"');
    print('[DEBUG] assignedTo: "${_assignedToController.text}"');
    print('[DEBUG] quantity: "${_quantityController.text}"');
    print('[DEBUG] price: "${_priceController.text}"');
    print('[DEBUG] specialInstructions: "${_specialInstructionsController.text}"');
    print('[DEBUG] isUpcycled: $_isUpcycled');
    print('[DEBUG] jobStatus: $_jobStatus');
    print('[DEBUG] _variants.length: ${_variants.length}');
    for (final v in _variants) {
      print('[DEBUG] Variant id: ${v.id}, size: ${v.size}, color: ${v.color}, quantity: ${v.quantity}, fabrics: ${v.fabrics.length}');
      for (final f in v.fabrics) {
        print('[DEBUG]   Fabric: id=${f.fabricId}, name=${f.fabricName}, yardage=${f.yardageUsed}');
      }
    }

    if (!_formKey.currentState!.validate()) {
      print('[DEBUG] Form not valid');
      return;
    }
    setState(() => _saving = true);

try {
  print('[DEBUG] Updating job order document...');
  await FirebaseFirestore.instance
      .collection('jobOrders')
      .doc(widget.jobOrderId)
      .update({
    'name': _jobOrderNameController.text.trim(),
    'customerName': _customerNameController.text.trim(),
    'orderDate': _orderDateController.text.isNotEmpty
        ? Timestamp.fromDate(DateTime.tryParse(_orderDateController.text) ?? DateTime.now())
        : null,
    'dueDate': _dueDateController.text.isNotEmpty
        ? Timestamp.fromDate(DateTime.tryParse(_dueDateController.text) ?? DateTime.now())
        : null,
    'assignedTo': _assignedToController.text.trim(),
    'quantity': int.tryParse(_quantityController.text) ?? 0,
    'price': double.tryParse(_priceController.text) ?? 0.0,
    'specialInstructions': _specialInstructionsController.text.trim(),
    'isUpcycled': _isUpcycled,
    'status': _jobStatus,
  });
  print('[DEBUG] Job order document updated.');

  // Update job order details (variants)
  final detailsRef = FirebaseFirestore.instance.collection('jobOrderDetails');
  final existingDetails = await detailsRef
      .where('jobOrderID', isEqualTo: widget.jobOrderId)
      .get();
  print('[DEBUG] Fetched ${existingDetails.docs.length} existing jobOrderDetails.');

  // Delete removed variants
  for (final doc in existingDetails.docs) {
    if (!_variants.any((v) => v.id == doc.id)) {
      print('[DEBUG] Deleting removed variant: ${doc.id}');
      await detailsRef.doc(doc.id).delete();
    }
  }
  for (final variant in _variants) {
    try {
      print('[DEBUG] Processing variant: ${variant.id}');
      print('[DEBUG]   size: ${variant.size}, color: ${variant.color}, quantity: ${variant.quantity}');
      if (variant.fabrics.isEmpty) {
        print('[ERROR]   Variant has no fabrics!');
        continue;
      }
      final fabric = variant.fabrics.firstWhere(
        (f) => f.fabricId != null && f.fabricId.isNotEmpty && f.fabricName != null && f.fabricName.isNotEmpty,
        orElse: () => VariantFabric(fabricId: '', fabricName: '', yardageUsed: 0.0),
      );
      if (fabric.fabricId.isEmpty || fabric.fabricName.isEmpty) {
        print('[ERROR] Skipping variant: no valid fabric with non-empty id and name');
        continue;
      }
      print('[DEBUG] About to update/add variant with:');
      print('  size: ${variant.size}');
      print('  color: ${variant.color}');
      print('  quantity: ${variant.quantity}');
      print('  fabricID: ${fabric.fabricId}');
      print('  fabricName: ${fabric.fabricName}');
      print('  yardageUsed: ${fabric.yardageUsed}');

      final existingDocIndex = existingDetails.docs.indexWhere((d) => d.id == variant.id);
      if (existingDocIndex != -1) {
        print('[DEBUG] Updating existing variant: ${variant.id}');
        await detailsRef.doc(variant.id).update({
          'size': variant.size,
          'color': variant.color,
          'quantity': variant.quantity,
          'fabricID': fabric.fabricId,
          'yardageUsed': fabric.yardageUsed,
          'fabricName': fabric.fabricName,
        });
      } else {
        print('[DEBUG] Adding new variant...');
        final docRef = await detailsRef.add({
          'jobOrderID': widget.jobOrderId,
          'size': variant.size,
          'color': variant.color,
          'quantity': variant.quantity,
          'fabricID': fabric.fabricId,
          'yardageUsed': fabric.yardageUsed,
          'fabricName': fabric.fabricName,
        });
        print('[DEBUG] New variant added with id: ${docRef.id}');
      }
    } catch (e, stack) {
      print('[ERROR] Exception while processing variant: $e');
      print(stack);
    }
  }
} catch (e, stack) {
  print('[ERROR] Exception in _updateJobOrder: $e');
  print(stack);
} finally {
  setState(() => _saving = false);
}
  }
    }