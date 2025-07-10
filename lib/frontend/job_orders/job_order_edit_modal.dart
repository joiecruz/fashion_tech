import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../utils/color_utils.dart';
import '../common/simple_category_dropdown.dart';
import 'models/form_models.dart';
import 'widgets/variant_card.dart';
import 'widgets/variant_breakdown_summary.dart';
import 'widgets/fabric_suppliers_section.dart';
import 'components/job_order_actions.dart';

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
  
  // Focus nodes for keyboard handling
  final FocusNode _jobOrderNameFocus = FocusNode();
  final FocusNode _customerNameFocus = FocusNode();
  final FocusNode _assignedToFocus = FocusNode();
  final FocusNode _quantityFocus = FocusNode();
  final FocusNode _priceFocus = FocusNode();
  final FocusNode _specialInstructionsFocus = FocusNode();
  bool _isUpcycled = false;
  String _jobStatus = 'In Progress';
  String _originalJobStatus = 'In Progress'; // Track original status to detect "Mark as Done"
  String _selectedCategory = 'uncategorized'; // Add category field
  List<FormProductVariant> _variants = [];

  List<Map<String, dynamic>> _userFabrics = [];
  bool _loadingFabrics = true;

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

    // Add listeners to key controllers to update completion status dynamically
    _jobOrderNameController.addListener(() => setState(() {}));
    _customerNameController.addListener(() => setState(() {}));
    _orderDateController.addListener(() => setState(() {}));
    _dueDateController.addListener(() => setState(() {}));
    _assignedToController.addListener(() => setState(() {}));
    _priceController.addListener(() => setState(() {}));

    // Add listeners for keyboard handling
    _specialInstructionsFocus.addListener(() {
      if (_specialInstructionsFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });
      }
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
    print('[DEBUG] _fetchJobOrderData called for jobOrderId: ${widget.jobOrderId}');
    try {
      final jobOrderDoc = await FirebaseFirestore.instance
          .collection('jobOrders')
          .doc(widget.jobOrderId)
          .get();
      final jobOrder = jobOrderDoc.data();
      if (jobOrder == null) {
        print('[WARNING] Job order document not found or has no data for ID: ${widget.jobOrderId}');
        setState(() {
          _loadingJobOrder = false;
        });
        return;
      }
      print('[DEBUG] Job order data loaded successfully. Name: ${jobOrder['name']}');
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
      _originalJobStatus = _jobStatus; // Store original status to detect "Mark as Done"
      _selectedCategory = jobOrder['categoryID'] ?? jobOrder['category'] ?? 'uncategorized'; // ERDv9: Load categoryID field with fallback
      print('[DEBUG] Loaded job status from database: "${_jobStatus}"');
      print('[DEBUG] Original job status set to: "${_originalJobStatus}"');
      print('[DEBUG] Loaded category from database: "${_selectedCategory}" (categoryID: ${jobOrder['categoryID']}, category: ${jobOrder['category']})');

      // Fetch all jobOrderDetails for this job order
      final detailsSnapshot = await FirebaseFirestore.instance
          .collection('jobOrderDetails')
          .where('jobOrderID', isEqualTo: widget.jobOrderId)
          .get();

      // Group jobOrderDetails by size and color to create proper variants
      final Map<String, FormProductVariant> variantMap = {};
      
      for (final doc in detailsSnapshot.docs) {
        final data = doc.data();
        final size = data['size'] ?? '';
        final color = data['color'] ?? ''; // ERDv9: Use color field, handle legacy data
        final quantity = data['quantity'] ?? 0;
        
        print('[DEBUG] Processing detail ${doc.id}: size=$size, color=$color, quantity=$quantity');
        
        // Create a unique key for each size-color combination
        final variantKey = '${size}_$color';
        
        final fabric = VariantFabric(
          fabricId: data['fabricID'] ?? '',
          fabricName: data['fabricName'] ?? '',
          yardageUsed: (data['yardageUsed'] ?? 0).toDouble(),
        );

        if (variantMap.containsKey(variantKey)) {
          // Add fabric to existing variant
          final existingVariant = variantMap[variantKey]!;
          existingVariant.fabrics.add(fabric);
          // Update quantity if this detail has a higher quantity (they should all be the same for the same variant)
          if (quantity > existingVariant.quantity) {
            print('[DEBUG] Updating variant $variantKey quantity from ${existingVariant.quantity} to $quantity');
            existingVariant.quantity = quantity;
          }
          print('[DEBUG] Added fabric to existing variant $variantKey, now has ${existingVariant.fabrics.length} fabrics');
        } else {
          // Create new variant
          print('[DEBUG] Creating new variant $variantKey with quantity $quantity');
          variantMap[variantKey] = FormProductVariant(
            id: doc.id, // Use the first document ID for this variant
            productID: jobOrder['productID'] ?? '',
            size: size,
            colorID: color, // ERDv9: Use colorID, handle legacy data
            quantityInStock: 0,
            quantity: quantity,
            fabrics: [fabric],
          );
        }
      }

      final List<FormProductVariant> variants = variantMap.values.toList();

      // Log final variants for debugging
      for (int i = 0; i < variants.length; i++) {
        final v = variants[i];
        print('[DEBUG] Final variant $i: size=${v.size}, color=${v.colorID}, quantity=${v.quantity}, fabrics=${v.fabrics.length}');
      }

      setState(() {
        _variants = variants;
        _loadingJobOrder = false;
      });
      print('[DEBUG] _fetchJobOrderData completed successfully. Found ${variants.length} variants from ${detailsSnapshot.docs.length} detail records');
    } catch (e) {
      print('[ERROR] Failed to fetch job order data: $e');
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
    _jobOrderNameFocus.dispose();
    _customerNameFocus.dispose();
    _assignedToFocus.dispose();
    _quantityFocus.dispose();
    _priceFocus.dispose();
    _specialInstructionsFocus.dispose();
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
                                Navigator.of(context).pop();
                              }
                            },
                            onTap: () {
                              // Close on tap as well
                              Navigator.of(context).pop();
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
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        MediaQuery.of(context).viewInsets.bottom + 100,
                      ),
                      child: Column(
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
                  ),
                ],
              ),
            );
          },
        ),
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
              colors: [Colors.blue[100]!, Colors.blue[200]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.edit_outlined,
            color: Colors.blue[700],
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Job Order',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Update production order details',
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
    return _buildSection(
      title: 'Basic Information',
      icon: Icons.info_outline,
      color: Colors.blue,
      children: [
        _buildTextField(
          controller: _jobOrderNameController,
          label: 'Job Order Name',
          icon: Icons.assignment,
          focusNode: _jobOrderNameFocus,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: () => _customerNameFocus.requestFocus(),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _customerNameController,
          label: 'Customer Name',
          icon: Icons.person,
          focusNode: _customerNameFocus,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: () => _assignedToFocus.requestFocus(),
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
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateField(
                controller: _dueDateController,
                label: 'Due Date',
                icon: Icons.schedule,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
            ),
          ],
        ),
      ],
      key: _timelineSectionKey,
    );
  }

  Widget _buildAssignmentSection() {
    return _buildSection(
      title: 'Assignment & Quantities',
      icon: Icons.assignment_ind,
      color: Colors.orange,
      children: [
        _buildTextField(
          controller: _assignedToController,
          label: 'Assigned To',
          icon: Icons.person_add,
          focusNode: _assignedToFocus,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: () => _quantityFocus.requestFocus(),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _quantityController,
          label: 'Total Quantity',
          icon: Icons.confirmation_number,
          focusNode: _quantityFocus,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: () => _priceFocus.requestFocus(),
          keyboardType: TextInputType.number,
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
          controller: _priceController,
          label: 'Price',
          icon: Icons.attach_money,
          focusNode: _priceFocus,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: () => _specialInstructionsFocus.requestFocus(),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _specialInstructionsController,
          label: 'Special Instructions',
          icon: Icons.comment,
          focusNode: _specialInstructionsFocus,
          textInputAction: TextInputAction.done,
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        _buildSwitchTile(
          title: 'Upcycled',
          subtitle: 'Is this an upcycled job order?',
          value: _isUpcycled,
          onChanged: (val) => setState(() => _isUpcycled = val),
          icon: Icons.recycling,
        ),
        const SizedBox(height: 16),
        SimpleCategoryDropdown(
          selectedCategory: _selectedCategory,
          onChanged: (value) {
            setState(() {
              _selectedCategory = value ?? 'uncategorized';
            });
          },
          isRequired: false,
        ),
        const SizedBox(height: 16),
        _buildDropdownField(
          value: _jobStatus,
          label: 'Job Status',
          icon: Icons.flag,
          items: ['Open', 'In Progress', 'Done', 'Cancelled', 'Archived'],
          onChanged: (val) => setState(() => _jobStatus = val ?? 'In Progress'),
        ),
      ],
      key: _additionalDetailsSectionKey,
    );
  }

  Widget _buildVariantsSection() {
    return _buildSection(
      title: 'Product Variants',
      icon: Icons.category,
      color: Colors.deepPurple,
      children: [
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
                    sumVariants: _variants.fold<int>(0, (sum, v) => sum + v.quantity),
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
                      _onFabricYardageChanged();
                    },
                  ),
                  // Show fabric colors and yards for each variant
                  ...variant.fabrics.map((f) {
                    final fabric = _userFabrics.firstWhere(
                      (fab) => fab['fabricID'] == f.fabricId,
                      orElse: () => <String, dynamic>{},
                    );
                    final fabricName = fabric.isNotEmpty && fabric['name'] != null && fabric['name'].toString().isNotEmpty
                        ? fabric['name']
                        : f.fabricName.isNotEmpty ? f.fabricName : 'Unknown';
                    final fabricColor = fabric.isNotEmpty && fabric['color'] != null
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
                  const SizedBox(height: 8),
                ],
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: Icon(Icons.add),
          label: Text('Add Variant'),
          onPressed: () {
            setState(() {
              _variants.add(FormProductVariant(
                id: UniqueKey().toString(),
                productID: '',
                size: _sizeOptions.isNotEmpty ? _sizeOptions.first : '',
                colorID: _colorOptions.isNotEmpty ? _colorOptions.first : '', // ERDv9: Changed from color to colorID
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
      key: _variantsSectionKey,
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
          // Content - only visible when expanded
          if (isExpanded)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
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
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    VoidCallback? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: textInputAction ?? TextInputAction.next,
      onFieldSubmitted: onFieldSubmitted != null ? (_) => onFieldSubmitted() : null,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      autovalidateMode: AutovalidateMode.onUserInteraction,
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
        errorMaxLines: 2,
        helperMaxLines: 2,
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
      autovalidateMode: AutovalidateMode.onUserInteraction,
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
    // Debug: Check if value is in items
    if (!items.contains(value)) {
      print('[DEBUG] Dropdown value "$value" not found in items: $items. Using first item: ${items.isNotEmpty ? items.first : 'null'}');
    }
    
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
      autovalidateMode: AutovalidateMode.onUserInteraction,
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

  /// Helper method to update job order variants in database
  Future<void> _updateVariants() async {
    final detailsRef = FirebaseFirestore.instance.collection('jobOrderDetails');
    
    // Get all existing job order details
    final existingDetails = await detailsRef
        .where('jobOrderID', isEqualTo: widget.jobOrderId)
        .get();
    print('[DEBUG] Found ${existingDetails.docs.length} existing jobOrderDetails.');

    // Delete all existing details first (we'll recreate them based on current variants)
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in existingDetails.docs) {
      batch.delete(doc.reference);
    }

    // Create new jobOrderDetail documents for each fabric in each variant
    for (int i = 0; i < _variants.length; i++) {
      final variant = _variants[i];
      print('[DEBUG] Processing variant $i: size=${variant.size}, color=${variant.colorID}, quantity=${variant.quantity}');
      
      // Skip variants without proper data
      if (variant.fabrics.isEmpty) {
        print('[WARNING] Variant $i has no fabrics, skipping...');
        continue;
      }

      // Create a separate jobOrderDetail document for each fabric in this variant
      for (int j = 0; j < variant.fabrics.length; j++) {
        final fabric = variant.fabrics[j];
        print('[DEBUG] Creating detail for fabric $j: ${fabric.fabricId} - ${fabric.yardageUsed} yards');
        
        if (fabric.fabricId.isEmpty) {
          print('[WARNING] Fabric $j has empty fabricId, skipping...');
          continue;
        }

        final variantData = {
          'jobOrderID': widget.jobOrderId,
          'size': variant.size,
          'color': variant.colorID, // ERDv9: Use colorID consistently
          'quantity': variant.quantity, // Same quantity for all fabrics in this variant
          'fabricID': fabric.fabricId,
          'fabricName': fabric.fabricName,
          'yardageUsed': fabric.yardageUsed,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Create new document for each fabric
        final newDocRef = detailsRef.doc(); // Generate new document ID
        batch.set(newDocRef, variantData);
        print('[DEBUG] Queued creation of detail document: ${newDocRef.id}');
      }
    }

    // Commit all changes in a single batch
    await batch.commit();
    print('[DEBUG] All jobOrderDetail documents updated successfully.');
  }

  Future<void> _updateJobOrder() async {
    print('[DEBUG] _updateJobOrder called');
    print('[DEBUG] jobOrderId: ${widget.jobOrderId}');
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
    
    for (int i = 0; i < _variants.length; i++) {
      final v = _variants[i];
      print('[DEBUG] Variant $i: id=${v.id}, size=${v.size}, color=${v.color}, quantity=${v.quantity}, fabrics=${v.fabrics.length}');
      for (int j = 0; j < v.fabrics.length; j++) {
        final f = v.fabrics[j];
        print('[DEBUG]   Fabric $j: id=${f.fabricId}, name=${f.fabricName}, yardage=${f.yardageUsed}');
      }
    }

    if (!_formKey.currentState!.validate()) {
      print('[DEBUG] Form validation failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Please fill in all required fields'),
            ],
          ),
          backgroundColor: Colors.orange[600],
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    // Check if status is changing to Done for special confirmation
    bool isMarkingAsDone = (_originalJobStatus != 'Done' && _jobStatus == 'Done');

    // Show confirmation dialog with special message for Mark as Done
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isMarkingAsDone ? Icons.check_circle : Icons.edit,
              color: isMarkingAsDone ? Colors.green[600] : Colors.blue[600],
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(isMarkingAsDone ? 'Complete Job Order' : 'Update Job Order'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMarkingAsDone 
                  ? 'Are you sure you want to mark this job order as done?'
                  : 'Are you sure you want to update this job order?',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (isMarkingAsDone) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory, size: 16, color: Colors.blue[600]),
                        const SizedBox(width: 6),
                        Text(
                          'Product Conversion',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will automatically convert the job order to a product in your inventory. You\'ll be prompted to choose how to handle the new product.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isMarkingAsDone ? Colors.green[600] : Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            child: Text(isMarkingAsDone ? 'Complete Job Order' : 'Update'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      print('[DEBUG] User cancelled update');
      return;
    }

    setState(() => _saving = true);

    try {
      print('[DEBUG] Starting database update transaction...');
      
      // Parse dates properly with validation
      DateTime? orderDate;
      DateTime? dueDate;
      
      if (_orderDateController.text.isNotEmpty) {
        orderDate = DateTime.tryParse(_orderDateController.text);
        if (orderDate == null) {
          print('[WARNING] Invalid order date format: ${_orderDateController.text}');
        }
      }
      
      if (_dueDateController.text.isNotEmpty) {
        dueDate = DateTime.tryParse(_dueDateController.text);
        if (dueDate == null) {
          print('[WARNING] Invalid due date format: ${_dueDateController.text}');
        }
      }

      // Parse numeric values with validation
      final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
      
      print('[DEBUG] Parsed values - quantity: $quantity, price: $price');
      print('[DEBUG] Parsed dates - order: $orderDate, due: $dueDate');

      // Check if status changed from non-Done to Done (Mark as Done functionality)
      bool shouldTriggerProductConversion = (_originalJobStatus != 'Done' && _jobStatus == 'Done');
      print('[DEBUG] Status change detected: ${_originalJobStatus} -> ${_jobStatus}, trigger conversion: $shouldTriggerProductConversion');

      // If marking as done, handle product conversion FIRST (before any database changes)
      if (shouldTriggerProductConversion) {
        print('[DEBUG] Handling product conversion before making any database changes...');
        try {
          // Update variants first BEFORE product conversion (since conversion needs current variant data)
          await _updateVariants();
          
          // Update job order fields (except status) before product conversion
          await FirebaseFirestore.instance
              .collection('jobOrders')
              .doc(widget.jobOrderId)
              .update({
            'name': _jobOrderNameController.text.trim(),
            'customerName': _customerNameController.text.trim(),
            'orderDate': orderDate != null ? Timestamp.fromDate(orderDate) : null,
            'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
            'assignedTo': _assignedToController.text.trim(),
            'quantity': quantity,
            'price': price,
            'specialInstructions': _specialInstructionsController.text.trim(),
            'isUpcycled': _isUpcycled,
            // Note: NOT updating status here - markJobOrderAsDone will handle it
            'categoryID': _selectedCategory,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('[DEBUG] Job order fields updated (except status)');
          
          // Fetch updated job order data for product conversion
          final updatedJobOrderDoc = await FirebaseFirestore.instance
              .collection('jobOrders')
              .doc(widget.jobOrderId)
              .get();
          
          final updatedJobOrderData = updatedJobOrderDoc.data()!;
          
          // Fetch updated job order details for product conversion
          final updatedJobOrderDetails = await FirebaseFirestore.instance
              .collection('jobOrderDetails')
              .where('jobOrderID', isEqualTo: widget.jobOrderId)
              .get();

          if (updatedJobOrderDetails.docs.isNotEmpty && mounted) {
            // Create JobOrderActions instance for product conversion
            final jobOrderActions = JobOrderActions(
              context: context,
              productData: {}, // Empty product data map for new conversion
              onDataRefresh: () {}, // Empty callback since we're in a modal
            );

            // Trigger the mark as done process (which includes product conversion)
            // This will update the status to 'Done' internally if successful
            await jobOrderActions.markJobOrderAsDone(
              widget.jobOrderId,
              updatedJobOrderData['name'] ?? 'Unnamed Job Order',
              updatedJobOrderData,
            );
            
            print('[DEBUG] Product conversion completed successfully - job order marked as done');
            
          } else {
            print('[WARNING] No job order details found for product conversion');
            throw Exception('No job order details found for product conversion');
          }
        } catch (e) {
          print('[ERROR] Failed to complete product conversion: $e');
          
          // If product conversion failed or was cancelled, revert status to original
          _jobStatus = _originalJobStatus;
          
          if (mounted) {
            setState(() {}); // Update UI to show reverted status
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Job order update cancelled. Product conversion was not completed.'),
                    ),
                  ],
                ),
                backgroundColor: Colors.blue[600],
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }
          
          // Exit early - don't proceed with any updates
          return;
        }
      } else {
        // Regular update (not marking as done)
        print('[DEBUG] Performing regular update...');
        
        // Update the main job order document
        await FirebaseFirestore.instance
            .collection('jobOrders')
            .doc(widget.jobOrderId)
            .update({
          'name': _jobOrderNameController.text.trim(),
          'customerName': _customerNameController.text.trim(),
          'orderDate': orderDate != null ? Timestamp.fromDate(orderDate) : null,
          'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
          'assignedTo': _assignedToController.text.trim(),
          'quantity': quantity,
          'price': price,
          'specialInstructions': _specialInstructionsController.text.trim(),
          'isUpcycled': _isUpcycled,
          'status': _jobStatus,
          'categoryID': _selectedCategory,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('[DEBUG] Main job order document updated successfully.');
        
        // Update variants
        await _updateVariants();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(_originalJobStatus != 'Done' && _jobStatus == 'Done'
                    ? 'Job order completed and converted to product successfully!'
                    : 'Job order updated successfully!'),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }

      // Close the modal after successful update
      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }

    } catch (e, stack) {
      print('[ERROR] Exception in _updateJobOrder: $e');
      print('[ERROR] Stack trace: $stack');
      
      // Show detailed error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Failed to update job order: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading job order data...'),
          SizedBox(height: 8),
          Text(
            _loadingJobOrder ? 'Loading job order...' : 'Job order loaded ✓',
            style: TextStyle(
              color: _loadingJobOrder ? Colors.grey : Colors.green,
              fontSize: 12,
            ),
          ),
          Text(
            _loadingFabrics ? 'Loading fabrics...' : 'Fabrics loaded ✓',
            style: TextStyle(
              color: _loadingFabrics ? Colors.grey : Colors.green,
              fontSize: 12,
            ),
          ),
          Text(
            _loadingFabricSuppliers ? 'Loading fabric suppliers...' : 'Fabric suppliers loaded ✓',
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
            'Please add some fabrics before editing this job order.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
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
      icon: Icons.inventory,
      color: Colors.purple,
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

  bool _isSectionCompleted(String sectionTitle) {
    switch (sectionTitle) {
      case 'Basic Information':
        return _jobOrderNameController.text.isNotEmpty &&
               _customerNameController.text.isNotEmpty;
      case 'Timeline':
        return _orderDateController.text.isNotEmpty &&
               _dueDateController.text.isNotEmpty;
      case 'Assignment & Quantities':
        return _assignedToController.text.isNotEmpty &&
               _quantityController.text.isNotEmpty;
      case 'Additional Details':
        return true; // Optional section
      case 'Product Variants':
        return _variants.isNotEmpty;
      case 'Fabric Suppliers':
        return _fabricSuppliers.isNotEmpty;
      case 'Variant Breakdown':
        return _variants.isNotEmpty;
      default:
        return false;
    }
  }

  void _toggleSection(String sectionTitle) {
    setState(() {
      _sectionExpanded[sectionTitle] = !(_sectionExpanded[sectionTitle] ?? false);
    });
  }
}