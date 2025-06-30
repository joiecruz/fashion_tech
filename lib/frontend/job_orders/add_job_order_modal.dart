import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../utils/color_utils.dart';
import 'models/form_models.dart';
import 'widgets/variant_card.dart';
import 'widgets/variant_breakdown_summary.dart';
import 'widgets/fabric_suppliers_section.dart';

class AddJobOrderModal extends StatefulWidget {
  const AddJobOrderModal({Key? key}) : super(key: key);

  @override
  State<AddJobOrderModal> createState() => _AddJobOrderModalState();
}

class _AddJobOrderModalState extends State<AddJobOrderModal>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _variantsSectionKey = GlobalKey();
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

  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
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
    _quantityController.addListener(() {
      setState(() {});
    });

    // Start the animation
    _animationController.forward();
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
      print('Fetching fabric suppliers...');
      final snapshot = await FirebaseFirestore.instance
          .collection('supplierFabrics')
          .get()
          .timeout(Duration(seconds: 10));
      
      print('Found ${snapshot.docs.length} supplier-fabric documents');
      
      final Map<String, Map<String, dynamic>> suppliers = {};
      final Set<String> supplierIds = {};
      
      // First pass: collect all supplier IDs
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final fabricId = data['fabricID'] as String?;
        final supplierId = data['supplierID'] as String?;
        
        print('Processing doc ${doc.id}: fabricID = $fabricId, supplierID = $supplierId');
        print('Document data: $data');
        
        if (fabricId != null && supplierId != null) {
          suppliers[fabricId] = data;
          supplierIds.add(supplierId);
        } else {
          print('Warning: Document ${doc.id} missing fabricID or supplierID field');
        }
      }
      
      print('Collected supplier IDs: $supplierIds');
      
      // Second pass: fetch actual supplier details
      final Map<String, Map<String, dynamic>> supplierDetails = {};
      if (supplierIds.isNotEmpty) {
        print('Fetching supplier details...');
        final supplierSnapshot = await FirebaseFirestore.instance
            .collection('suppliers')
            .get()
            .timeout(Duration(seconds: 10));
        
        print('Found ${supplierSnapshot.docs.length} supplier documents');
        
        for (final doc in supplierSnapshot.docs) {
          final data = doc.data();
          final supplierId = doc.id;
          
          print('Supplier doc $supplierId: $data');
          
          if (supplierIds.contains(supplierId)) {
            supplierDetails[supplierId] = data;
          }
        }
      }
      
      print('Fetched supplier details: $supplierDetails');
      
      // Third pass: merge supplier details with fabric-supplier mapping
      for (final fabricId in suppliers.keys) {
        final fabricSupplierData = suppliers[fabricId]!;
        final supplierId = fabricSupplierData['supplierID'] as String?;
        
        if (supplierId != null && supplierDetails.containsKey(supplierId)) {
          // Merge the supplier details into the fabric-supplier mapping
          fabricSupplierData.addAll(supplierDetails[supplierId]!);
          print('Merged supplier details for fabric $fabricId: $fabricSupplierData');
        } else {
          print('No supplier details found for supplier $supplierId (fabric: $fabricId)');
        }
      }
      
      print('Final processed suppliers map: $suppliers');
      
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
    _animationController.dispose();
    _scrollController.dispose();
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

  @override
  Widget build(BuildContext context) {
    if (_loadingFabrics || _loadingFabricSuppliers) {
      return _buildLoadingState();
    }

    if (_userFabrics.isEmpty) {
      return _buildNoFabricsState();
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
                  // Top notch for better modal closing UX
                  Center(
                    child: GestureDetector(
                      onPanStart: (details) {
                        // Track the start of drag
                      },
                      onPanUpdate: (details) {
                        // Close modal when dragging down significantly
                        if (details.delta.dy > 8) {
                          _closeModal();
                        }
                      },
                      onTap: () {
                        // Close on tap as well
                        _closeModal();
                      },
                      child: Container(
                        width: 60,
                        height: 20,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Header
                  _buildHeader(),
                  
                  const SizedBox(height: 24),
                  
                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Basic Information Section
                        _buildBasicInfoSection(),
                        
                        const SizedBox(height: 20),
                        
                        // Timeline Section
                        _buildTimelineSection(),
                        
                        const SizedBox(height: 20),
                        
                        // Assignment & Quantities Section
                        _buildAssignmentSection(),
                        
                        const SizedBox(height: 20),
                        
                        // Additional Details Section
                        _buildAdditionalDetailsSection(),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Product Variants Section
                  _buildVariantsSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Fabric Suppliers Section
                  FabricSuppliersSection(
                    variants: _variants,
                    userFabrics: _userFabrics,
                    fabricSuppliers: _fabricSuppliers,
                    loadingFabricSuppliers: _loadingFabricSuppliers,
                    parseColor: ColorUtils.parseColor,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Variant Breakdown Summary Section
                  VariantBreakdownSummary(
                    variants: _variants,
                    userFabrics: _userFabrics,
                    quantityController: _quantityController,
                    parseColor: ColorUtils.parseColor,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Save Button
                  _buildSaveButton(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
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

  Widget _buildNoFabricsState() {
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
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSection(
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
    );
  }

  Widget _buildTimelineSection() {
    return _buildSection(
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
    );
  }

  Widget _buildAssignmentSection() {
    return _buildSection(
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
    );
  }

  Widget _buildAdditionalDetailsSection() {
    return _buildSection(
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
    );
  }

  Widget _buildVariantsSection() {
    return Container(
      key: _variantsSectionKey,
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
              OutlinedButton.icon(
                onPressed: () async {
                  final int previousVariantCount = _variants.length;
                  
                  setState(() {
                    _variants.add(FormProductVariant(
                      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                      productID: 'temp_product',
                      size: 'Small',
                      color: 'Mixed', // Color will be determined by fabrics
                      quantityInStock: 0,
                      fabrics: [],
                    ));
                  });
                  
                  // Only scroll if there were previous variants
                  if (previousVariantCount > 0) {
                    // Auto-scroll to show the new variant after a short delay to allow UI to update
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (_scrollController.hasClients && _variantsSectionKey.currentContext != null) {
                      try {
                        final RenderBox renderBox = _variantsSectionKey.currentContext!.findRenderObject() as RenderBox;
                        final variantsSectionPosition = renderBox.localToGlobal(Offset.zero);
                        
                        // Calculate approximate position of the new variant
                        // Each variant card is approximately 400-450px tall including margins and content
                        final approximateVariantHeight = 420.0;
                        final variantsSectionHeaderHeight = 100.0; // Header + padding
                        
                        // Position of the new variant (last one in the list)
                        final newVariantPosition = variantsSectionPosition.dy + 
                                                 variantsSectionHeaderHeight + 
                                                 (previousVariantCount * approximateVariantHeight);
                        
                        // Calculate target scroll position to show the new variant nicely
                        final targetPosition = _scrollController.offset + newVariantPosition - 200; // 200px from top of viewport
                        
                        _scrollController.animateTo(
                          targetPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                        );
                      } catch (e) {
                        // Fallback: scroll to a reasonable position
                        final fallbackPosition = _scrollController.position.maxScrollExtent * 0.8;
                        _scrollController.animateTo(
                          fallbackPosition,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    }
                  }
                },
                icon: Icon(Icons.add_circle_outline, size: 16),
                label: Text(
                  'Add Variant',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade600,
                  side: BorderSide(color: Colors.blue.shade300, width: 1),
                  backgroundColor: Colors.blue.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size(0, 36),
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
                return VariantCard(
                  variant: variant,
                  index: idx,
                  userFabrics: _userFabrics,
                  fabricAllocated: _fabricAllocated,
                  quantityController: _quantityController,
                  onRemove: () {
                    setState(() {
                      _variants.removeAt(idx);
                      _onFabricYardageChanged();
                    });
                  },
                  onVariantChanged: (index) {
                    setState(() {});
                  },
                  onFabricYardageChanged: _onFabricYardageChanged,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
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

  // Method to smoothly close the modal with animation
  Future<void> _closeModal() async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
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
      await _closeModal();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving job order: $e')),
      );
    }
  }
}
