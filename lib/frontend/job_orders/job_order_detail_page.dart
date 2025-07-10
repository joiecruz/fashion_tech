import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/color_selector.dart';
import 'job_order_edit_modal.dart';

class JobOrderDetailPage extends StatefulWidget {
  final String jobOrderId;
  final Map<String, dynamic>? initialData;

  const JobOrderDetailPage({
    Key? key,
    required this.jobOrderId,
    this.initialData,
  }) : super(key: key);

  @override
  State<JobOrderDetailPage> createState() => _JobOrderDetailPageState();
}

class _JobOrderDetailPageState extends State<JobOrderDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _jobOrderData = {};
  Map<String, dynamic> _productData = {};
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    if (widget.initialData != null) {
      _jobOrderData = Map<String, dynamic>.from(widget.initialData!);
    }
    
    _loadJobOrderData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadJobOrderData() async {
    try {
      // Load job order data
      final jobOrderDoc = await FirebaseFirestore.instance
          .collection('jobOrders')
          .doc(widget.jobOrderId)
          .get();

      if (!jobOrderDoc.exists) {
        setState(() {
          _errorMessage = 'Job order not found';
          _isLoading = false;
        });
        return;
      }

      _jobOrderData = {
        'id': jobOrderDoc.id,
        ...jobOrderDoc.data()!,
      };

      // Load related product data
      final productId = _jobOrderData['productID'];
      if (productId != null && productId.isNotEmpty) {
        final productDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .get();
        
        if (productDoc.exists) {
          _productData = productDoc.data()!;
        }
      }

      // Load user data for assigned user
      final assignedTo = _jobOrderData['assignedTo'];
      if (assignedTo != null && assignedTo.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(assignedTo)
            .get();
        
        if (userDoc.exists) {
          _userData = userDoc.data()!;
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading job order: $e';
        _isLoading = false;
      });
    }
  }

  /// Shows a confirmation dialog for deleting the job order
  /// Includes fabric return functionality if fabrics were allocated
  Future<void> _showDeleteConfirmation() async {
    // Check if job order has fabric allocations
    final fabricAllocations = await _getFabricAllocations();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[600], size: 24),
            const SizedBox(width: 8),
            const Text('Delete Job Order'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${_jobOrderData['name']}"?',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_outlined, size: 16, color: Colors.red[600]),
                      const SizedBox(width: 6),
                      Text(
                        'This action cannot be undone',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.red[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• All job order details will be permanently deleted\n'
                    '• Associated variants will be removed\n'
                    '• Timeline history will be lost',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            if (fabricAllocations.isNotEmpty) ...[
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
                        Icon(Icons.inventory_2, size: 16, color: Colors.blue[600]),
                        const SizedBox(width: 6),
                        Text(
                          'Fabric Return Available',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Allocated fabrics can be returned to inventory if not used.',
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (fabricAllocations.isNotEmpty) {
        await _showFabricReturnDialog(fabricAllocations);
      } else {
        await _deleteJobOrder();
      }
    }
  }

  /// Gets fabric allocations for the job order
  Future<List<Map<String, dynamic>>> _getFabricAllocations() async {
    try {
      final jobOrderDetailsQuery = await FirebaseFirestore.instance
          .collection('jobOrderDetails')
          .where('jobOrderID', isEqualTo: widget.jobOrderId)
          .get();

      return jobOrderDetailsQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'fabricID': data['fabricID'],
          'fabricName': data['fabricName'] ?? 'Unknown Fabric',
          'yardageUsed': data['yardageUsed'] ?? 0.0,
          'color': data['color'] ?? '',
          'size': data['size'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error fetching fabric allocations: $e');
      return [];
    }
  }

  /// Shows fabric return dialog if fabrics were allocated
  Future<void> _showFabricReturnDialog(List<Map<String, dynamic>> fabricAllocations) async {
    final Map<String, double> returnAmounts = {};
    
    // Initialize with full allocated amounts
    for (final allocation in fabricAllocations) {
      final key = '${allocation['fabricID']}_${allocation['color']}';
      returnAmounts[key] = (allocation['yardageUsed'] as num).toDouble();
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Return Fabrics to Inventory'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select fabrics to return to inventory:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: fabricAllocations.length,
                    itemBuilder: (context, index) {
                      final allocation = fabricAllocations[index];
                      final key = '${allocation['fabricID']}_${allocation['color']}';
                      final maxAmount = (allocation['yardageUsed'] as num).toDouble();
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                allocation['fabricName'],
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Color: ${allocation['color']} • Size: ${allocation['size']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('Return: '),
                                  Expanded(
                                    child: Slider(
                                      value: returnAmounts[key] ?? 0,
                                      min: 0,
                                      max: maxAmount,
                                      divisions: (maxAmount * 10).round(),
                                      label: '${returnAmounts[key]?.toStringAsFixed(1)} yards',
                                      onChanged: (value) {
                                        setState(() {
                                          returnAmounts[key] = value;
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: TextFormField(
                                      initialValue: returnAmounts[key]?.toStringAsFixed(1),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        final parsed = double.tryParse(value);
                                        if (parsed != null && parsed >= 0 && parsed <= maxAmount) {
                                          setState(() {
                                            returnAmounts[key] = parsed;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Max: ${maxAmount.toStringAsFixed(1)} yards',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete & Return Fabrics'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _deleteJobOrderWithFabricReturn(fabricAllocations, returnAmounts);
    }
  }

  /// Deletes the job order and returns specified fabrics to inventory
  Future<void> _deleteJobOrderWithFabricReturn(
    List<Map<String, dynamic>> fabricAllocations,
    Map<String, double> returnAmounts,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Delete job order details
      for (final allocation in fabricAllocations) {
        final detailRef = FirebaseFirestore.instance
            .collection('jobOrderDetails')
            .doc(allocation['id']);
        batch.delete(detailRef);
        
        // Return fabric to inventory
        final key = '${allocation['fabricID']}_${allocation['color']}';
        final returnAmount = returnAmounts[key] ?? 0;
        
        if (returnAmount > 0) {
          final fabricRef = FirebaseFirestore.instance
              .collection('fabrics')
              .doc(allocation['fabricID']);
          
          batch.update(fabricRef, {
            'quantity': FieldValue.increment(returnAmount),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      
      // Delete the job order
      final jobOrderRef = FirebaseFirestore.instance
          .collection('jobOrders')
          .doc(widget.jobOrderId);
      batch.delete(jobOrderRef);
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Job order deleted and fabrics returned to inventory',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        
        Navigator.pop(context, true); // Return to previous screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting job order: $e'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Simple job order deletion without fabric considerations
  Future<void> _deleteJobOrder() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Delete job order details
      final jobOrderDetailsQuery = await FirebaseFirestore.instance
          .collection('jobOrderDetails')
          .where('jobOrderID', isEqualTo: widget.jobOrderId)
          .get();
      
      for (final doc in jobOrderDetailsQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete the job order
      final jobOrderRef = FirebaseFirestore.instance
          .collection('jobOrders')
          .doc(widget.jobOrderId);
      batch.delete(jobOrderRef);
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Job order deleted successfully',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        
        Navigator.pop(context, true); // Return to previous screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting job order: $e'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _openEditModal() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.only(top: 60),
        height: MediaQuery.of(context).size.height - 60,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: JobOrderEditModal(jobOrderId: widget.jobOrderId),
      ),
    );
    
    if (result == true) {
      await _loadJobOrderData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final jobOrderName = _jobOrderData['name'] ?? 'Unnamed Job Order';
    final status = _jobOrderData['status'] ?? 'Open';
    final isOverdue = _isJobOrderOverdue();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(jobOrderName, status, isOverdue),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 24),
                _buildQuickStatsCard(),
                const SizedBox(height: 16),
                _buildTabBarCard(),
                const SizedBox(height: 16),
                _buildTabContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(String jobOrderName, String status, bool isOverdue) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(8),
          child: const Icon(Icons.arrow_back, color: Colors.black87),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        // Edit button
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Container(
              decoration: BoxDecoration(
                color: Colors.orange[600]!.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.edit, color: Colors.white, size: 20),
            ),
            onPressed: _openEditModal,
            tooltip: 'Edit Job Order',
          ),
        ),
        // Delete button
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: IconButton(
            icon: Container(
              decoration: BoxDecoration(
                color: Colors.red[600]!.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.delete, color: Colors.white, size: 20),
            ),
            onPressed: _showDeleteConfirmation,
            tooltip: 'Delete Job Order',
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getStatusColor(status).withOpacity(0.8),
                _getStatusColor(status).withOpacity(0.6),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(status),
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOverdue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red[600],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'OVERDUE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    jobOrderName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (_productData['name'] != null)
                    Text(
                      'Product: ${_productData['name']}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    final quantity = _jobOrderData['quantity'] ?? 0;
    final customerName = _jobOrderData['customerName'] ?? '';
    final assignedUserName = _getUserDisplayName();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.production_quantity_limits,
              label: 'Quantity',
              value: quantity.toString(),
              color: Colors.orange[600]!,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[200],
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.person,
              label: 'Customer',
              value: customerName.isEmpty ? 'Not set' : customerName,
              color: Colors.blue[600]!,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[200],
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.assignment_ind,
              label: 'Assigned To',
              value: assignedUserName,
              color: Colors.green[600]!,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTabBarCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.orange[600]!.withOpacity(0.1),
        ),
        labelColor: Colors.orange[600],
        unselectedLabelColor: Colors.grey[600],
        tabs: const [
          Tab(
            icon: Icon(Icons.info_outline),
            text: 'Details',
          ),
          Tab(
            icon: Icon(Icons.schedule),
            text: 'Timeline',
          ),
          Tab(
            icon: Icon(Icons.inventory_2),
            text: 'Materials',
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(),
          _buildTimelineTab(),
          _buildMaterialsTab(),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailSection('Basic Information', [
              _buildDetailRow('Job Order ID', widget.jobOrderId),
              _buildDetailRow('Job Order Name', _jobOrderData['name'] ?? 'Not set'),
              _buildDetailRow('Customer Name', _jobOrderData['customerName'] ?? 'Not set'),
              _buildDetailRow('Status', _jobOrderData['status'] ?? 'Open'),
              _buildDetailRow('Quantity', '${_jobOrderData['quantity'] ?? 0}'),
              if (_jobOrderData['price'] != null)
                _buildDetailRow('Price', '\$${_jobOrderData['price']}'),
            ]),
            const SizedBox(height: 20),
            if (_productData.isNotEmpty)
              _buildDetailSection('Product Information', [
                _buildDetailRow('Product Name', _productData['name'] ?? 'Not set'),
                if (_productData['description'] != null)
                  _buildDetailRow('Description', _productData['description']),
                if (_productData['categoryName'] != null)
                  _buildDetailRow('Category', _productData['categoryName']),
                if (_jobOrderData['color'] != null)
                  _buildColorRow('Color', _jobOrderData['color']),
                if (_jobOrderData['size'] != null)
                  _buildDetailRow('Size', _jobOrderData['size']),
              ]),
            const SizedBox(height: 20),
            if (_jobOrderData['notes'] != null && _jobOrderData['notes'].toString().trim().isNotEmpty)
              _buildDetailSection('Notes', [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Text(
                    _jobOrderData['notes'].toString(),
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineTab() {
    final createdAt = _jobOrderData['createdAt'] as Timestamp?;
    final dueDate = _jobOrderData['dueDate'] as Timestamp?;
    final updatedAt = _jobOrderData['updatedAt'] as Timestamp?;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimelineItem(
              icon: Icons.add_circle,
              title: 'Job Order Created',
              time: createdAt?.toDate(),
              color: Colors.blue[600]!,
              isCompleted: true,
            ),
            if (updatedAt != null && updatedAt != createdAt)
              _buildTimelineItem(
                icon: Icons.edit,
                title: 'Last Updated',
                time: updatedAt.toDate(),
                color: Colors.orange[600]!,
                isCompleted: true,
              ),
            if (dueDate != null)
              _buildTimelineItem(
                icon: Icons.schedule,
                title: 'Due Date',
                time: dueDate.toDate(),
                color: _isJobOrderOverdue() ? Colors.red[600]! : Colors.green[600]!,
                isCompleted: false,
                isOverdue: _isJobOrderOverdue(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialsTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _loadMaterialsData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading materials data',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final materialsData = snapshot.data!;
          final variants = materialsData['variants'] as List<Map<String, dynamic>>;
          final totalFabricUsage = materialsData['totalUsage'] as Map<String, double>;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (variants.isNotEmpty) ...[
                  // Variants section
                  _buildDetailSection('Job Order Variants & Materials', [
                    ...variants.map((variant) => _buildVariantCard(variant)),
                  ]),
                  const SizedBox(height: 20),
                  
                  // Total fabric usage summary
                  if (totalFabricUsage.isNotEmpty) ...[
                    _buildDetailSection('Total Fabric Usage Summary', [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[50]!, Colors.blue[100]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          children: totalFabricUsage.entries.map((entry) {
                            final parts = entry.key.split('_');
                            final fabricName = parts[0];
                            final color = parts.length > 1 ? parts[1] : '';
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.inventory_2, size: 16, color: Colors.blue[600]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$fabricName${color.isNotEmpty ? ' ($color)' : ''}',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[600],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${entry.value.toStringAsFixed(1)} yards',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ]),
                  ],
                ] else ...[
                  // Empty state
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Material Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Material details and variants will appear here when available.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Loads materials data including variants and fabric usage
  Future<Map<String, dynamic>> _loadMaterialsData() async {
    try {
      // Fetch job order details (variants)
      final jobOrderDetailsQuery = await FirebaseFirestore.instance
          .collection('jobOrderDetails')
          .where('jobOrderID', isEqualTo: widget.jobOrderId)
          .get();

      final List<Map<String, dynamic>> variants = [];
      final Map<String, double> totalFabricUsage = {};
      final Map<String, String> fabricNames = {}; // Cache for fabric names

      for (final doc in jobOrderDetailsQuery.docs) {
        final data = doc.data();
        final fabricID = data['fabricID'] ?? '';
        
        // Fetch fabric name if we have a fabricID and haven't cached it yet
        String fabricName = data['fabricName'] ?? '';
        if (fabricID.isNotEmpty && fabricName.isEmpty && !fabricNames.containsKey(fabricID)) {
          try {
            final fabricDoc = await FirebaseFirestore.instance
                .collection('fabrics')
                .doc(fabricID)
                .get();
            
            if (fabricDoc.exists) {
              final fabricData = fabricDoc.data()!;
              fabricName = fabricData['name'] ?? fabricData['fabricName'] ?? 'Unknown Fabric';
              fabricNames[fabricID] = fabricName; // Cache for future use
            }
          } catch (e) {
            print('Error fetching fabric $fabricID: $e');
            fabricName = 'Unknown Fabric';
          }
        } else if (fabricNames.containsKey(fabricID)) {
          fabricName = fabricNames[fabricID]!;
        }
        
        // If still no fabric name, use fallback
        if (fabricName.isEmpty) {
          fabricName = 'Unknown Fabric';
        }
        
        // Add to variants list with proper labeling
        variants.add({
          'id': doc.id,
          'fabricID': fabricID,
          'fabricName': fabricName,
          'yardageUsed': (data['yardageUsed'] ?? 0).toDouble(),
          'quantity': data['quantity'] ?? 1, // Add quantity for variant
          'color': data['color'] ?? '',
          'size': data['size'] ?? '',
          'notes': data['notes'] ?? '',
          'variantID': data['variantID'] ?? '',
        });

        // Aggregate fabric usage
        final fabricKey = '${fabricName}_${data['color'] ?? ''}';
        final yardage = (data['yardageUsed'] ?? 0).toDouble();
        totalFabricUsage[fabricKey] = (totalFabricUsage[fabricKey] ?? 0) + yardage;
      }

      return {
        'variants': variants,
        'totalUsage': totalFabricUsage,
      };
    } catch (e) {
      throw Exception('Failed to load materials data: $e');
    }
  }

  /// Builds a card for each variant showing its material details
  Widget _buildVariantCard(Map<String, dynamic> variant) {
    final quantity = variant['quantity'] ?? 1;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with variant label and quantity
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.inventory,
                  color: Colors.indigo[600],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Variant',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.indigo[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.indigo[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.indigo[200]!),
                          ),
                          child: Text(
                            'Qty: $quantity',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (variant['variantID'].isNotEmpty)
                      Text(
                        'ID: ${variant['variantID']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Fabric information
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.texture, color: Colors.green[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fabric Material',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                      Text(
                        variant['fabricName'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${variant['yardageUsed'].toStringAsFixed(1)} yards',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Variant specifications
          Row(
            children: [
              Expanded(
                child: _buildVariantDetailItem(
                  icon: Icons.palette,
                  label: 'Color',
                  value: variant['color'].isEmpty ? 'Not specified' : variant['color'],
                  color: Colors.blue[600]!,
                  isColor: variant['color'].isNotEmpty,
                  colorValue: variant['color'],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVariantDetailItem(
                  icon: Icons.straighten,
                  label: 'Size',
                  value: variant['size'].isEmpty ? 'Not specified' : variant['size'],
                  color: Colors.purple[600]!,
                ),
              ),
            ],
          ),
          
          // Notes if available
          if (variant['notes'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Variant Notes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          variant['notes'].toString(),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds a detail item for variant information
  Widget _buildVariantDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isColor = false,
    String? colorValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (isColor && colorValue != null && colorValue.isNotEmpty) ...[
                ColorDisplay(
                  colorId: colorValue,
                  colorName: colorValue,
                  size: 16,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorRow(String label, String colorValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                ColorDisplay(
                  colorId: colorValue,
                  colorName: colorValue,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  colorValue,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required String title,
    required DateTime? time,
    required Color color,
    required bool isCompleted,
    bool isOverdue = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted ? color : color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isCompleted ? Colors.white : color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isOverdue ? Colors.red[600] : Colors.black87,
                      ),
                    ),
                    if (isOverdue) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red[600],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'OVERDUE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (time != null)
                  Text(
                    _formatDateTime(time),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getUserDisplayName() {
    if (_userData.isEmpty) return 'Unassigned';
    
    return _userData['displayName'] ?? 
           _userData['name'] ?? 
           (_userData['firstName'] != null && _userData['lastName'] != null 
               ? '${_userData['firstName']} ${_userData['lastName']}'
               : _userData['email']?.split('@').first ?? 
                 'Unknown User');
  }

  bool _isJobOrderOverdue() {
    final dueDate = _jobOrderData['dueDate'] as Timestamp?;
    final status = _jobOrderData['status'];
    
    return dueDate != null &&
           dueDate.toDate().isBefore(DateTime.now()) &&
           status != 'Done' &&
           status != 'Archived';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Open':
        return Colors.blue[600]!;  // Blue for new/open items
      case 'In Progress':
        return Colors.orange[600]!;  // Orange for work in progress
      case 'Done':
        return Colors.green[600]!;  // Green for completed
      case 'Archived':
        return Colors.grey[600]!;  // Grey for archived
      case 'Cancelled':
        return Colors.red[600]!;  // Red for cancelled
      default:
        return Colors.indigo[400]!;  // Indigo for unknown status
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Open':
        return Icons.access_time;
      case 'In Progress':
        return Icons.trending_up;
      case 'Done':
        return Icons.check_circle;
      case 'Cancelled':
        return Icons.cancel;
      case 'Archived':
        return Icons.archive;
      default:
        return Icons.assignment;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today, ${_formatTime(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${_formatTime(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
