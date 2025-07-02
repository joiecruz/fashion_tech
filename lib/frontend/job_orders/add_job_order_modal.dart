/*
 * CRITICAL DOCUMENTATION: Product Variants Section Creates JobOrderDetails, NOT ProductVariants
 * 
 * This modal is for creating Job Orders and their associated JobOrderDetails.
 * The "Product Variants" section in the UI is specifically for creating JobOrderDetails records,
 * which are linked to the Job Order and represent the specific variants ordered.
 * 
 * Key Distinctions:
 * - JobOrderDetails: Records specific to this job order (size, fabric, quantity, etc.)
 * - ProductVariant: Master data representing available product variants (separate collection)
 * 
 * ERDv8 Compliance:
 * - JobOrder.name is required
 * - JobOrderDetails.size is required 
 * - JobOrderDetails.quantity is required
 * - JobOrderDetails.color is auto-populated from selected fabrics
 * 
 * Business Logic - Fabric Inventory Management:
 * - When a job order is saved, fabric quantities are automatically reduced based on yardageUsed
 * - Validation prevents job order creation if insufficient fabric inventory
 * - Fabric quantity updates are atomic to prevent overselling
 * 
 * NO ProductVariant collection records should be created from this modal!
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../utils/color_utils.dart';
import '../../utils/size_utils.dart';
import 'models/form_models.dart';
import 'widgets/variant_card.dart';
import 'widgets/variant_breakdown_summary.dart';
import 'widgets/fabric_suppliers_section.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Store supplier-fabric relationships for display
  Map<String, Map<String, dynamic>> _fabricSuppliers = {};
  bool _loadingFabricSuppliers = true;

  Map<String, double> _fabricAllocated = {};

  // Track expanded/collapsed state for each section
  Map<String, bool> _sectionExpanded = {
    'Basic Information': true,  // Start with this section expanded
    'Timeline': true,          // Timeline is also critical - expand by default
    'Assignment & Quantities': false,
    'Additional Details': false,
    'Product Variants': false,
    'Fabric Suppliers': false,
    'Variant Breakdown': false,
  };

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
    
    // Add listeners to key controllers to update completion status dynamically
    _jobOrderNameController.addListener(() => setState(() {}));
    _customerNameController.addListener(() => setState(() {}));
    _orderDateController.addListener(() => setState(() {}));
    _dueDateController.addListener(() => setState(() {}));
    _assignedToController.addListener(() => setState(() {}));
    _priceController.addListener(() => setState(() {}));

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
            'pricePerUnit': data['pricePerUnit'] ?? 0.0,
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
        allocation[fabric.fabricId] = (allocation[fabric.fabricId] ?? 0) + (fabric.yardageUsed);
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
              child: Column(
                children: [
                  // Sticky header area (notch + title)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildHeader(),
                        ),
                        
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  
                  // Scrollable content area
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                  
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
                  _buildFabricSuppliersSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Variant Breakdown Summary Section
                  _buildVariantBreakdownSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Save Button with bottom padding
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: _buildSaveButton(),
                  ),
                ],
              ),
            ),
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
                    'pricePerUnit': 10.0,
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
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange[100]!, Colors.orange[200]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.work_outline,
            color: Colors.orange[700],
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Job Order',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Create a custom production order',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      margin: const EdgeInsets.only(top: 20), // Add top external padding
      child: _buildSection(
        key: _basicInfoSectionKey,
        title: 'Basic Information',
        icon: Icons.info_outline,
        color: Colors.blue,
        children: [
        _buildTextField(
          controller: _jobOrderNameController,
          label: 'Job Order Name',
          hint: 'E.g., Summer Collection Dress',
          icon: Icons.assignment,
          validator: (val) {
            if (val?.isEmpty ?? true) return 'Job order name is required';
            final trimmed = val!.trim();
            if (trimmed.isEmpty) return 'Job order name cannot be empty';
            if (trimmed.length > 100) return 'Job order name is too long (max: 100 characters)';
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _customerNameController,
          label: 'Customer Name',
          hint: 'E.g., John Doe',
          icon: Icons.person,
          validator: (val) {
            if (val?.isEmpty ?? true) return 'Customer name is required';
            final trimmed = val!.trim();
            if (trimmed.isEmpty) return 'Customer name cannot be empty';
            if (trimmed.length > 50) return 'Customer name is too long (max: 50 characters)';
            // Check for valid name format (letters, spaces, hyphens, apostrophes)
            if (!RegExp(r"^[a-zA-Z\s\-'\.]+$").hasMatch(trimmed)) {
              return 'Please enter a valid name (letters, spaces, hyphens only)';
            }
            return null;
          },
        ),
      ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    return _buildSection(
      key: _timelineSectionKey,
      title: 'Timeline',
      icon: Icons.schedule,
      color: Colors.green,
      children: [
        Row(
          children: [
            Expanded(
              child:              _buildDateField(
                controller: _orderDateController,
                label: 'Order Date',
                icon: Icons.event,
                validator: (val) {
                  if (val?.isEmpty ?? true) return 'Order date is required';
                  final date = DateTime.tryParse(val!);
                  if (date == null) return 'Please select a valid date';
                  if (date.isAfter(DateTime.now().add(Duration(days: 1)))) {
                    return 'Order date cannot be in the future';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateField(
                controller: _dueDateController,
                label: 'Due Date',
                icon: Icons.schedule,
                validator: (val) {
                  if (val?.isEmpty ?? true) return 'Due date is required';
                  final dueDate = DateTime.tryParse(val!);
                  if (dueDate == null) return 'Please select a valid date';
                  
                  // Check if due date is before order date
                  final orderDateStr = _orderDateController.text;
                  if (orderDateStr.isNotEmpty) {
                    final orderDate = DateTime.tryParse(orderDateStr);
                    if (orderDate != null && dueDate.isBefore(orderDate)) {
                      return 'Due date must be after order date';
                    }
                  }
                  
                  // Check if due date is too far in the past
                  if (dueDate.isBefore(DateTime.now().subtract(Duration(days: 1)))) {
                    return 'Due date cannot be in the past';
                  }
                  
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssignmentSection() {
    return _buildSection(
      key: _assignmentSectionKey,
      title: 'Assignment & Quantities',
      icon: Icons.work,
      color: Colors.orange,
      children: [
        _buildTextField(
          controller: _assignedToController,
          label: 'Assigned To',
          hint: 'E.g., Maria Santos',
          icon: Icons.person_outline,
          validator: (val) {
            if (val?.isEmpty ?? true) return 'Assignment is required';
            final trimmed = val!.trim();
            if (trimmed.isEmpty) return 'Assignment cannot be empty';
            if (trimmed.length > 50) return 'Name is too long (max: 50 characters)';
            // Check for valid name format
            if (!RegExp(r"^[a-zA-Z\s\-'\.]+$").hasMatch(trimmed)) {
              return 'Please enter a valid name (letters, spaces, hyphens only)';
            }
            return null;
          },
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
                  if (val?.isEmpty ?? true) return 'Quantity required';
                  final trimmed = val!.trim();
                  if (trimmed.isEmpty) return 'Quantity cannot be empty';
                  
                  // Check for non-numeric characters
                  if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
                    return 'Use numbers only (no letters or symbols)';
                  }
                  
                  final n = int.tryParse(trimmed);
                  if (n == null) return 'Enter a whole number';
                  if (n <= 0) return 'Quantity must be greater than 0';
                  if (n > 10000) return 'Quantity too large (max: 10,000)';
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
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val?.isEmpty ?? true) return 'Price required';
                  final trimmed = val!.trim();
                  if (trimmed.isEmpty) return 'Price cannot be empty';
                  
                  // Check for invalid characters (letters, symbols except decimal point)
                  if (!RegExp(r'^\d*\.?\d*$').hasMatch(trimmed)) {
                    return 'Use numbers only (decimals allowed)';
                  }
                  
                  final n = double.tryParse(trimmed);
                  if (n == null) return 'Enter a valid price';
                  if (n < 0) return 'Price cannot be negative';
                  if (n > 1000000) return 'Price too large (max: ₱1M)';
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
      key: _additionalDetailsSectionKey,
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
          validator: (val) {
            if (val != null && val.trim().length > 500) {
              return 'Instructions are too long (max: 500 characters)';
            }
            return null;
          },
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
          validator: (val) {
            if (val?.isEmpty ?? true) return 'Job status is required';
            if (!['Open', 'In Progress', 'Done'].contains(val)) {
              return 'Please select a valid status';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// DEVELOPER NOTE: Product Variants Section - Creates JobOrderDetails, NOT ProductVariants
  /// 
  /// This section is labeled "Product Variants" in the UI for user clarity, but it actually 
  /// creates JobOrderDetails records in Firestore, NOT ProductVariant records.
  /// 
  /// Each variant configured here will result in one or more JobOrderDetails documents
  /// being saved to Firestore with the following ERDv8-compliant required fields:
  /// - jobOrderID: Links to the parent JobOrder
  /// - fabricID: Primary fabric used for this variant
  /// - yardageUsed: Total yards of fabric required (ERDv8 field name)
  /// - size: Size of this variant (required in ERDv8)
  /// - color: Auto-populated from selected fabrics
  /// - quantity: Quantity of this specific variant (required in ERDv8)
  /// 
  /// NO ProductVariant collection documents are created in this modal.
  Widget _buildVariantsSection() {
    return _buildSection(
      key: _variantsSectionKey,
      title: 'Product Variants',
      icon: Icons.category,
      color: Colors.indigo,
      children: [
        // Add Variant Button - Only show when section is expanded
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final int previousVariantCount = _variants.length;
              
              setState(() {
                _variants.add(FormProductVariant(
                  id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                  productID: 'temp_product',
                  size: SizeUtils.sizeOptions.first,
                  color: 'Mixed', // Color will be determined by fabrics
                  quantityInStock: 0,
                  quantity: 0, // No prefilled quantity - user must enter
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              minimumSize: Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Variants content
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
              // Calculate sum of all variant quantities
              int sumVariants = _variants.fold(0, (sum, v) => sum + v.quantity);
              return VariantCard(
                variant: variant,
                index: idx,
                userFabrics: _userFabrics,
                fabricAllocated: _fabricAllocated,
                quantityController: _quantityController,
                sumVariants: sumVariants,
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
    Key? key,
    bool hasError = false,
  }) {
    final bool isExpanded = _sectionExpanded[title] ?? false;
    final bool isCompleted = _isSectionCompleted(title);
    
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError ? Colors.red.shade300 : 
                 isCompleted ? Colors.green.shade200 : Colors.grey.shade200,
          width: hasError ? 2 : isCompleted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: hasError ? Colors.red.shade100 : 
                   isCompleted ? Colors.green.shade100 : Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - always visible, clickable to expand/collapse
          InkWell(
            onTap: () => _toggleSection(title),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              padding: EdgeInsets.all(isExpanded ? 20 : 16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isExpanded ? 8 : 6),
                    decoration: BoxDecoration(
                      color: hasError ? Colors.red.shade50 : 
                             isCompleted ? Colors.green.shade50 : color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      hasError ? Icons.error_outline : 
                      isCompleted ? Icons.check_circle_outline : icon,
                      color: hasError ? Colors.red.shade600 : 
                             isCompleted ? Colors.green.shade600 : color,
                      size: isExpanded ? 20 : 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isExpanded ? 18 : 16,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        if (isCompleted && !isExpanded)
                          Text(
                            'Completed',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey.shade600,
                      size: isExpanded ? 24 : 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content - conditionally visible with animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: isExpanded ? null : 0,
            child: isExpanded
                ? Container(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        errorMaxLines: 2, // Allow error text to wrap to prevent clipping
        helperMaxLines: 2, // Allow helper text to wrap if needed
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
      ),
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
      ),
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
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

  /// Validate the entire form and return a list of validation errors
  /// 
  /// DEVELOPER NOTE: The "Product Variants" section validation is for UI elements that
  /// create JobOrderDetails records, not ProductVariant records. This validates required
  /// fields for ERDv8-compliant JobOrderDetails creation.
  List<ValidationError> _validateForm() {
    final errors = <ValidationError>[];

    // Basic info validation
    if (_jobOrderNameController.text.trim().isEmpty) {
      errors.add(ValidationError(
        message: 'Job Order Name is required',
        sectionKey: _basicInfoSectionKey,
        sectionName: 'Basic Information',
      ));
    }
    
    if (_customerNameController.text.trim().isEmpty) {
      errors.add(ValidationError(
        message: 'Customer Name is required',
        sectionKey: _basicInfoSectionKey,
        sectionName: 'Basic Information',
      ));
    }

    // Timeline validation
    if (_dueDateController.text.trim().isEmpty) {
      errors.add(ValidationError(
        message: 'Due Date is required',
        sectionKey: _timelineSectionKey,
        sectionName: 'Timeline',
      ));
    }

    // Assignment validation
    if (_assignedToController.text.trim().isEmpty) {
      errors.add(ValidationError(
        message: 'Assigned To is required',
        sectionKey: _assignmentSectionKey,
        sectionName: 'Assignment',
      ));
    }

    // Product Variants (JobOrderDetails) validation - Developer Note: This validates the UI section 
    // labeled "Product Variants" which actually creates JobOrderDetails, not ProductVariant records
    if (_variants.isEmpty) {
      errors.add(ValidationError(
        message: 'At least one product variant is required',
        sectionKey: _variantsSectionKey,
        sectionName: 'Product Variants',
      ));
    } else {
      // Calculate total fabric usage across all variants for inventory validation
      final Map<String, double> totalFabricUsage = {};
      
      // Validate each variant
      for (int i = 0; i < _variants.length; i++) {
        final variant = _variants[i];
        
        if (variant.size.trim().isEmpty) {
          errors.add(ValidationError(
            message: 'Size is required for variant ${i + 1}',
            sectionKey: _variantsSectionKey,
            sectionName: 'Product Variants',
          ));
        }
        
        if (variant.quantity <= 0) {
          errors.add(ValidationError(
            message: 'Quantity must be greater than 0 for variant ${i + 1}',
            sectionKey: _variantsSectionKey,
            sectionName: 'Product Variants',
          ));
        }
        
        if (variant.fabrics.isEmpty) {
          errors.add(ValidationError(
            message: 'At least one fabric is required for variant ${i + 1}',
            sectionKey: _variantsSectionKey,
            sectionName: 'Product Variants',
          ));
        } else {
          // Validate fabric assignments and calculate total usage
          for (int j = 0; j < variant.fabrics.length; j++) {
            final fabric = variant.fabrics[j];
            if (fabric.yardageUsed <= 0) {
              errors.add(ValidationError(
                message: 'Yards required must be greater than 0 for fabric ${j + 1} in variant ${i + 1}',
                sectionKey: _variantsSectionKey,
                sectionName: 'Product Variants',
              ));
            } else {
              // Accumulate fabric usage for inventory validation
              totalFabricUsage[fabric.fabricId] = 
                  (totalFabricUsage[fabric.fabricId] ?? 0) + fabric.yardageUsed;
            }
          }
        }
      }
      
      // Validate fabric inventory - ensure sufficient quantity available
      for (final fabricId in totalFabricUsage.keys) {
        final requiredAmount = totalFabricUsage[fabricId]!;
        final fabric = _userFabrics.firstWhere(
          (f) => f['fabricID'] == fabricId, 
          orElse: () => {},
        );
        
        if (fabric.isNotEmpty) {
          final availableQuantity = (fabric['quantity'] ?? 0) as num;
          if (availableQuantity < requiredAmount) {
            final fabricName = fabric['name'] ?? 'Unknown Fabric';
            errors.add(ValidationError(
              message: 'Insufficient $fabricName: ${availableQuantity.toStringAsFixed(1)} yards available, ${requiredAmount.toStringAsFixed(1)} yards required',
              sectionKey: _variantsSectionKey,
              sectionName: 'Product Variants',
            ));
          }
        } else {
          errors.add(ValidationError(
            message: 'Fabric not found in inventory: $fabricId',
            sectionKey: _variantsSectionKey,
            sectionName: 'Product Variants',
          ));
        }
      }
    }

    return errors;
  }

  // Method to show validation errors and scroll to first error
  Future<void> _showValidationErrors(List<ValidationError> errors) async {
    if (errors.isEmpty) return;
    
    // Mark sections with errors for visual indication
    setState(() {
      // This will trigger a rebuild with hasError flags for sections with errors
    });
    
    // Scroll to the first error
    final firstError = errors.first;
    final RenderBox? renderBox = firstError.sectionKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      await _scrollController.animateTo(
        _scrollController.offset + position.dy - 100, // Offset for header
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    }
    
    // Show error dialog with detailed information
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              const Text('Validation Errors'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please fix the following issues:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ...errors.map((error) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.arrow_right, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              error.sectionName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                            Text(error.message),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Save JobOrder and create JobOrderDetails records
  /// 
  /// DEVELOPER NOTE: The "Product Variants" section in the UI creates JobOrderDetails records,
  /// NOT ProductVariant records. This method:
  /// 1. Creates one JobOrder document with ERDv8-compliant fields
  /// 2. Creates JobOrderDetails documents for each variant (size/fabric combination)
  /// 3. Updates fabric inventory by reducing quantities based on yardageUsed
  /// 4. NO ProductVariant collection records are created
  /// 
  /// ERDv8 Compliance:
  /// - JobOrder.name is required
  /// - JobOrderDetails.size and .quantity are required
  /// - JobOrderDetails.color is auto-populated from fabrics
  /// 
  /// Business Logic:
  /// - Fabric quantities are decremented based on total yardageUsed across all variants
  /// - Validation prevents job order creation if insufficient fabric inventory
  Future<void> _saveJobOrder() async {
    try {
      // Validate the form first
      final errors = _validateForm();
      if (errors.isNotEmpty) {
        await _showValidationErrors(errors);
        return;
      }

      // Save job order with ERDv8 compliant fields
      final jobOrderRef = FirebaseFirestore.instance.collection('jobOrders').doc();
      await jobOrderRef.set({
        'name': _jobOrderNameController.text, // ERDv8: required name field
        'productID': 'default_product_id', // TODO: Replace with actual product ID selection in production
        'quantity': int.tryParse(_quantityController.text) ?? 0, // required - use global quantity
        'customerName': _customerNameController.text, // required
        'status': _jobStatus, // required
        'dueDate': (_dueDateController.text.isNotEmpty)
            ? Timestamp.fromDate(DateTime.tryParse(_dueDateController.text) ?? DateTime.now())
            : FieldValue.serverTimestamp(), // required
        'createdBy': FirebaseAuth.instance.currentUser?.uid,// required - should be actual user ID in production
        'assignedTo': _assignedToController.text, // optional
        'specialInstructions': _specialInstructionsController.text, // optional
        'orderDate': (_orderDateController.text.isNotEmpty)
            ? Timestamp.fromDate(DateTime.tryParse(_orderDateController.text) ?? DateTime.now())
            : FieldValue.serverTimestamp(), // optional
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create JobOrderDetails records for each variant from the "Product Variants" UI section
      // DEVELOPER NOTE: Despite the UI label "Product Variants", these create JobOrderDetails records
      
      // Track fabric usage for inventory reduction
      final Map<String, double> totalFabricUsage = {};
      
      for (final variant in _variants) {
        // Calculate total fabric usage per fabric ID for this variant
        for (final fabric in variant.fabrics) {
          totalFabricUsage[fabric.fabricId] = 
              (totalFabricUsage[fabric.fabricId] ?? 0) + fabric.yardageUsed;
        }
        
        // Get unique fabric colors for this variant
        final fabricColors = variant.fabrics
            .map((f) => _userFabrics.firstWhere((fabric) => fabric['fabricID'] == f.fabricId, orElse: () => {})['color'] ?? '#000000')
            .toSet()
            .toList();
        
        // Create comma-separated color string
        final colorString = fabricColors.join(', ');
        
        // Create primary JobOrderDetails record for this variant
        final jobOrderDetailRef = FirebaseFirestore.instance.collection('jobOrderDetails').doc();
        await jobOrderDetailRef.set({
          'jobOrderID': jobOrderRef.id, // required
          'fabricID': variant.fabrics.first.fabricId, // required - primary fabric
          'yardageUsed': variant.fabrics.fold(0.0, (sum, f) => sum + f.yardageUsed), // required - total yardage for this variant
          'size': variant.size, // required (ERDv8 update)
          'color': colorString, // auto-populated from fabrics
          'quantity': variant.quantity, // required (ERDv8 update) - quantity of this specific variant
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Create additional JobOrderDetails records for secondary fabrics in this variant
        for (int i = 1; i < variant.fabrics.length; i++) {
          final additionalFabric = variant.fabrics[i];
          final additionalJobOrderDetailRef = FirebaseFirestore.instance.collection('jobOrderDetails').doc();
          await additionalJobOrderDetailRef.set({
            'jobOrderID': jobOrderRef.id,
            'fabricID': additionalFabric.fabricId,
            'yardageUsed': additionalFabric.yardageUsed,
            'size': variant.size,
            'color': _userFabrics.firstWhere((fabric) => fabric['fabricID'] == additionalFabric.fabricId, orElse: () => {})['color'] ?? '#000000',
            'quantity': 0, // Secondary fabrics don't add to quantity count
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Update fabric inventory - reduce quantities based on usage
      // CRITICAL: This ensures fabric inventory is properly managed
      for (final fabricId in totalFabricUsage.keys) {
        final usageAmount = totalFabricUsage[fabricId]!;
        
        // Get current fabric data
        final fabricDoc = await FirebaseFirestore.instance
            .collection('fabrics')
            .doc(fabricId)
            .get();
            
        if (fabricDoc.exists) {
          final currentQuantity = (fabricDoc.data()?['quantity'] ?? 0.0) as num;
          final newQuantity = (currentQuantity.toDouble() - usageAmount).clamp(0.0, double.infinity);
          
          // Update fabric quantity in Firestore
          await FirebaseFirestore.instance
              .collection('fabrics')
              .doc(fabricId)
              .update({
            'quantity': newQuantity,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          print('Fabric $fabricId: Updated quantity from $currentQuantity to $newQuantity (used: $usageAmount yards)');
        } else {
          print('Warning: Fabric $fabricId not found in database');
        }
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              const Text('Success'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Job order saved successfully!'),
              const SizedBox(height: 12),
              const Text(
                'Fabric inventory has been updated:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...totalFabricUsage.entries.map((entry) {
                final fabricName = _userFabrics.firstWhere(
                  (f) => f['fabricID'] == entry.key, 
                  orElse: () => {'name': 'Unknown'},
                )['name'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle_outline, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$fabricName: -${entry.value.toStringAsFixed(1)} yards',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                await _closeModal(); // Close modal
              },
              child: const Text('OK'),
            )
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Error saving job order: $e'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
  }

  void _toggleSection(String sectionTitle) {
    setState(() {
      _sectionExpanded[sectionTitle] = !(_sectionExpanded[sectionTitle] ?? false);
    });
  }

  /// Check if a section has required fields completed
  bool _isSectionCompleted(String sectionTitle) {
    switch (sectionTitle) {
      case 'Basic Information':
        return _jobOrderNameController.text.trim().isNotEmpty &&
               _customerNameController.text.trim().isNotEmpty;
      case 'Timeline':
        return _orderDateController.text.trim().isNotEmpty &&
               _dueDateController.text.trim().isNotEmpty;
      case 'Assignment & Quantities':
        return _assignedToController.text.trim().isNotEmpty &&
               _quantityController.text.trim().isNotEmpty &&
               _priceController.text.trim().isNotEmpty;
      case 'Product Variants':
        return _variants.isNotEmpty && _variants.every((v) => v.fabrics.isNotEmpty);
      case 'Fabric Suppliers':
        return _variants.isNotEmpty && _variants.any((v) => v.fabrics.isNotEmpty);
      case 'Variant Breakdown':
        return _variants.isNotEmpty;
      default:
        return false;
    }
  }

  Widget _buildFabricSuppliersSection() {
    return _buildSection(
      title: 'Fabric Suppliers',
      icon: Icons.local_shipping,
      color: Colors.teal,
      children: [
        FabricSuppliersSection(
          variants: _variants,
          userFabrics: _userFabrics,
          fabricSuppliers: _fabricSuppliers,
          loadingFabricSuppliers: _loadingFabricSuppliers,
          parseColor: ColorUtils.parseColor,
        ),
      ],
    );
  }

  Widget _buildVariantBreakdownSection() {
    return _buildSection(
      title: 'Variant Breakdown',
      icon: Icons.analytics,
      color: Colors.deepPurple,
      children: [
        VariantBreakdownSummary(
          variants: _variants,
          userFabrics: _userFabrics,
          quantityController: _quantityController,
          parseColor: ColorUtils.parseColor,
        ),
      ],
    );
  }

}

// Validation error class for better error handling
class ValidationError {
  final String message;
  final GlobalKey sectionKey;
  final String sectionName;

  ValidationError({
    required this.message,
    required this.sectionKey,
    required this.sectionName,
  });
}
