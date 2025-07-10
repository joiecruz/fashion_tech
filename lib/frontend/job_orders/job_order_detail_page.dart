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
                const SizedBox(height: 100), // Bottom padding for FAB
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditModal,
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit),
        label: const Text('Edit Job Order'),
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
    final fabricName = _jobOrderData['fabricName'] ?? '';
    final color = _jobOrderData['color'] ?? '';
    final size = _jobOrderData['size'] ?? '';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fabricName.isNotEmpty || color.isNotEmpty || size.isNotEmpty) ...[
              _buildDetailSection('Materials & Specifications', [
                if (fabricName.isNotEmpty)
                  _buildDetailRow('Fabric', fabricName),
                if (color.isNotEmpty)
                  _buildColorRow('Color', color),
                if (size.isNotEmpty)
                  _buildDetailRow('Size', size),
              ]),
            ] else ...[
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
                      'Material details will appear here when available.',
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
        return Colors.orange[600]!;
      case 'In Progress':
        return Colors.orange[500]!;
      case 'Done':
        return Colors.green[600]!;
      case 'Archived':
        return Colors.grey[600]!;
      case 'Cancelled':
        return Colors.red[600]!;
      default:
        return Colors.orange[400]!;
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
