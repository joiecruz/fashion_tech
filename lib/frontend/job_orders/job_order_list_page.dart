import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_job_order_modal.dart';
import 'job_order_edit_modal.dart';

enum ProductHandlingAction {
  addToLinkedProduct,
  createNewProduct,
  selectExistingProduct,
}

class ProductHandlingResult {
  final ProductHandlingAction action;
  final double paymentAmount;
  
  ProductHandlingResult({
    required this.action,
    required this.paymentAmount,
  });
}

class JobOrderListPage extends StatefulWidget {
  const JobOrderListPage({super.key});
  @override
  State<JobOrderListPage> createState() => _JobOrderListPageState();
}

class _JobOrderListPageState extends State<JobOrderListPage>
    with SingleTickerProviderStateMixin {
  String _selectedStatus = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Caches for ERDv8 compliance
  Map<String, String> userNames = {};
  Map<String, String> productNames = {};
  Map<String, Map<String, dynamic>> productData = {};
  bool _dataLoaded = false;
  bool _isStatsExpanded = true;
  bool _isRefreshing = false;  // Add refresh state

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Stats
  int _totalOrders = 0;
  int _openOrders = 0;
  int _inProgressOrders = 0;
  int _doneOrders = 0;
  int _overdueOrders = 0;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _preloadData();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _preloadData() async {
    print('DEBUG: Starting to preload data...');

    // Fetch all users for ERDv8 compliance (createdBy, assignedTo, acceptedBy)
    final usersSnap = await FirebaseFirestore.instance.collection('users').get();
    print('DEBUG: Found ${usersSnap.docs.length} users');
    userNames = {
      for (var doc in usersSnap.docs)
        doc.id: '${(doc.data()['firstName'] ?? '')} ${(doc.data()['lastName'] ?? '')}'.trim()
    };

    // Fetch all products with full data for ERDv8 compliance
    final productsSnap = await FirebaseFirestore.instance.collection('products').get();
    print('DEBUG: Found ${productsSnap.docs.length} products');
    productNames = {
      for (var doc in productsSnap.docs)
        doc.id: (doc.data()['name'] ?? '') as String
    };

    // Fetch products with variants and fabrics for complete data
    productData = {};
    for (var doc in productsSnap.docs) {
      final productDocData = doc.data();
      
      // Fetch variants for this product
      final variantsSnapshot = await FirebaseFirestore.instance
          .collection('productVariants')
          .where('productID', isEqualTo: doc.id)
          .get();
      
      List<Map<String, dynamic>> variants = [];
      for (var variantDoc in variantsSnapshot.docs) {
        final variantData = variantDoc.data();
        variants.add({
          'variantID': variantDoc.id,
          'size': variantData['size'] ?? '',
          'color': variantData['colorID'] ?? variantData['color'] ?? '', // ERDv9: Use colorID, fallback to legacy color
          'quantityInStock': variantData['quantityInStock'] ?? 0,
        });
      }
      
      // Note: Fabrics are not directly linked to products in ERDv9, they're linked via job orders
      // For now, we'll keep an empty fabrics array for compatibility
      List<Map<String, dynamic>> fabrics = [];
      
      productData[doc.id] = {
        'name': productDocData['name'] ?? '',
        'category': productDocData['category'] ?? '',
        'price': productDocData['price'] ?? 0.0,
        'imageURL': productDocData['imageURL'] ?? '',
        'isUpcycled': productDocData['isUpcycled'] ?? false,
        'variants': variants,
        'fabrics': fabrics,
      };
    }

    print('DEBUG: Data preloaded successfully');
    setState(() {
      _dataLoaded = true;
    });

    _animationController.forward();
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });

    try {
      // Clear existing data
      userNames.clear();
      productNames.clear();
      productData.clear();
      
      // Reload all data
      await _preloadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.refresh, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Job orders refreshed successfully'),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to refresh: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _updateStats(List<QueryDocumentSnapshot> jobOrders) {
    _totalOrders = jobOrders.length;
    _openOrders = jobOrders.where((doc) =>
      (doc.data() as Map<String, dynamic>)['status'] == 'Open'
    ).length;
    _inProgressOrders = jobOrders.where((doc) =>
      (doc.data() as Map<String, dynamic>)['status'] == 'In Progress'
    ).length;
    _doneOrders = jobOrders.where((doc) =>
      (doc.data() as Map<String, dynamic>)['status'] == 'Done'
    ).length;

    // Count overdue orders
    final now = DateTime.now();
    _overdueOrders = jobOrders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final dueDateTimestamp = data['dueDate'] as Timestamp?;
      if (dueDateTimestamp == null) return false;
      final dueDate = dueDateTimestamp.toDate();
      return dueDate.isBefore(now) && data['status'] != 'Done';
    }).length;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_dataLoaded) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading job orders...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Header with search and filters
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange[50]!, Colors.grey[100]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange[200]!.withOpacity(0.3)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search job orders by name, customer, or assignee...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status filter dropdown and refresh button
                  Row(
                    children: [
                      Text(
                        'Status:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildStatusDropdown(),
                      const Spacer(),
                      // Refresh button
                      Tooltip(
                        message: 'Refresh job orders',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _isRefreshing ? null : _refreshData,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: _isRefreshing
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[600]!),
                                      ),
                                    )
                                  : AnimatedRotation(
                                      turns: _isRefreshing ? 1 : 0,
                                      duration: const Duration(milliseconds: 500),
                                      child: Icon(
                                        Icons.refresh,
                                        color: Colors.orange[600],
                                        size: 20,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('jobOrders')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                            size: 64,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text('Error loading job orders',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('${snapshot.error}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  var jobOrders = snapshot.data!.docs;
                  _updateStats(jobOrders);

                  // Apply status filter
                  if (_selectedStatus != 'All') {
                    jobOrders = jobOrders.where((doc) =>
                      (doc.data() as Map<String, dynamic>)['status'] == _selectedStatus
                    ).toList();
                  }

                  // Apply search filter
                  if (_searchQuery.isNotEmpty) {
                    jobOrders = jobOrders.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final jobOrderName = data['name'] ?? '';
                      final customerName = data['customerName'] ?? '';
                      final assignedToName = userNames[data['assignedTo']] ?? '';
                      final productName = productNames[data['productID']] ?? '';

                      return jobOrderName.toLowerCase().contains(_searchQuery) ||
                             customerName.toLowerCase().contains(_searchQuery) ||
                             assignedToName.toLowerCase().contains(_searchQuery) ||
                             productName.toLowerCase().contains(_searchQuery);
                    }).toList();
                  }

                  return RefreshIndicator(
                    onRefresh: _refreshData,
                    color: Colors.orange[600],
                    backgroundColor: Colors.white,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // Overview section (like inventory pages)
                        SliverToBoxAdapter(
                          child: _buildOverviewSection(),
                        ),

                        // Job orders list
                        SliverPadding(
                          padding: const EdgeInsets.only(bottom: 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return TweenAnimationBuilder<double>(
                                  duration: Duration(milliseconds: 300 + (index * 50)),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  builder: (context, value, child) {
                                    return Transform.translate(
                                      offset: Offset(0, 20 * (1 - value)),
                                      child: Opacity(
                                        opacity: value,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                          child: _buildJobOrderCard(jobOrders[index], index),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                              childCount: jobOrders.length,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // Floating Action Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              margin: const EdgeInsets.only(top: 100),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: AddJobOrderModal(),
            ),
          );
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Job Order', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange[600],
        elevation: 4,
      ),
    );
  }

  Widget _buildStatusDropdown() {
    final statusOptions = ['All', 'Open', 'In Progress', 'Done'];

    return PopupMenuButton<String>(
      onSelected: (String newValue) {
        setState(() {
          _selectedStatus = newValue;
        });
      },
      offset: const Offset(0, 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey[50]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: _getStatusColor(_selectedStatus).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.filter_list,
                size: 12,
                color: _getStatusColor(_selectedStatus),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _selectedStatus,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) {
        return statusOptions.map((String option) {
          return PopupMenuItem<String>(
            value: option,
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(option),
                  size: 14,
                  color: _getStatusColor(option),
                ),
                const SizedBox(width: 8),
                Text(
                  option,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Open':
        return Colors.orange[600]!;
      case 'In Progress':
        return Colors.orange[500]!;
      case 'Done':
        return Colors.green[600]!;
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
      default:
        return Icons.filter_list;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Job Orders Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first job order to get started',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  margin: const EdgeInsets.only(top: 100),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: AddJobOrderModal(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Job Order'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Collapse/Expand Button (like inventory pages)
          InkWell(
            onTap: () {
              setState(() {
                _isStatsExpanded = !_isStatsExpanded;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange[50]!, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.orange[200]!, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        color: Colors.orange[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Overview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (!_isStatsExpanded) ...[
                        Text(
                          '$_totalOrders orders • $_openOrders open${_overdueOrders > 0 ? ' • $_overdueOrders overdue' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      AnimatedRotation(
                        turns: _isStatsExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Animated Stats Content (card-based design like inventory)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _isStatsExpanded ? null : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isStatsExpanded ? 1.0 : 0.0,
              child: _isStatsExpanded ? Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: _overdueOrders > 0
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // First row with main stats
                        Row(
                          children: [
                            Expanded(child: _buildStatCard(
                              icon: Icons.assignment,
                              iconColor: Colors.orange[600]!,
                              title: 'Total\nOrders',
                              value: _totalOrders.toString(),
                              isCompact: true,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: _buildStatCard(
                              icon: Icons.access_time,
                              iconColor: Colors.orange[700]!,
                              title: 'Open\nOrders',
                              value: _openOrders.toString(),
                              isCompact: true,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: _buildStatCard(
                              icon: Icons.trending_up,
                              iconColor: Colors.orange[500]!,
                              title: 'In\nProgress',
                              value: _inProgressOrders.toString(),
                              isCompact: true,
                            )),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Second row with completion and overdue
                        Row(
                          children: [
                            Expanded(child: _buildStatCard(
                              icon: Icons.check_circle,
                              iconColor: Colors.green[600]!,
                              title: 'Completed\nOrders',
                              value: _doneOrders.toString(),
                              isCompact: true,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: _buildStatCard(
                              icon: Icons.warning,
                              iconColor: Colors.red[600]!,
                              title: 'Overdue\nOrders',
                              value: _overdueOrders.toString(),
                              isCompact: true,
                              isUrgent: true,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: Container()), // Empty space for balance
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildStatCard(
                          icon: Icons.assignment,
                          iconColor: Colors.orange[600]!,
                          title: 'Total\nOrders',
                          value: _totalOrders.toString(),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard(
                          icon: Icons.access_time,
                          iconColor: Colors.orange[700]!,
                          title: 'Open\nOrders',
                          value: _openOrders.toString(),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard(
                          icon: Icons.trending_up,
                          iconColor: Colors.orange[500]!,
                          title: 'In\nProgress',
                          value: _inProgressOrders.toString(),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard(
                          icon: Icons.check_circle,
                          iconColor: Colors.green[600]!,
                          title: 'Completed\nOrders',
                          value: _doneOrders.toString(),
                        )),
                      ],
                    ),
              ) : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    bool isCompact = false,
    bool isUrgent = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 8 : 16),
      decoration: BoxDecoration(
        gradient: isUrgent
          ? LinearGradient(
              colors: [Colors.red[50]!, Colors.red[100]!.withOpacity(0.3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : LinearGradient(
              colors: [Colors.orange[50]!, Colors.orange[100]!.withOpacity(0.3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent ? Colors.red[200]! : Colors.orange[200]!,
          width: isUrgent ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isUrgent ? Colors.red : Colors.orange).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: isCompact ? 16 : 24,
          ),
          SizedBox(height: isCompact ? 4 : 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCompact ? 9 : 12,
              color: Colors.grey[600],
              height: 1.1,
            ),
          ),
          SizedBox(height: isCompact ? 2 : 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isCompact ? 14 : 20,
              fontWeight: FontWeight.bold,
              color: isUrgent ? Colors.red[700] : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobOrderCard(QueryDocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>;

    // ERDv8 JobOrder fields
    final String jobOrderID = doc.id;
    final String jobOrderName = data['name'] ?? 'Unnamed Job Order';
    final String productID = data['productID'] ?? '';
    final int quantity = data['quantity'] ?? 0;
    final String customerName = data['customerName'] ?? '';
    final String status = data['status'] ?? 'Open';
    final Timestamp? dueDateTimestamp = data['dueDate'] as Timestamp?;
    final String assignedTo = data['assignedTo'] ?? '';
    final Timestamp? createdAtTimestamp = data['createdAt'] as Timestamp?;

    // Convert timestamps
    final DateTime? dueDate = dueDateTimestamp?.toDate();
    final DateTime? createdAt = createdAtTimestamp?.toDate();

    // Get related data
    final productInfo = productData[productID] ?? {};
    final List<dynamic> productVariants = productInfo['variants'] ?? [];
    final List<dynamic> productFabrics = productInfo['fabrics'] ?? [];

    // Try to find the matching variant for this job order
    Map<String, dynamic>? matchedVariant;
    if (data['variantID'] != null && data['variantID'].toString().isNotEmpty) {
      matchedVariant = productVariants.cast<Map<String, dynamic>>().firstWhere(
        (v) => v['variantID'] == data['variantID'],
        orElse: () => {},
      );
    }

    // Try to find the matching fabric for this job order
    Map<String, dynamic>? matchedFabric;
    if (data['fabricID'] != null && data['fabricID'].toString().isNotEmpty) {
      matchedFabric = productFabrics.cast<Map<String, dynamic>>().firstWhere(
        (f) => f['fabricID'] == data['fabricID'],
        orElse: () => {},
      );
    }

    // Extract color, size, and fabric name
    final String variantColor = matchedVariant?['color'] ?? '';
    final String variantSize = matchedVariant?['size'] ?? '';
    final String fabricName = matchedFabric?['fabricName'] ?? '';

    // Check if overdue
    final bool isOverdue = dueDate != null &&
                          dueDate.isBefore(DateTime.now()) &&
                          status != 'Done';
    final int overdueDays = isOverdue ?
        DateTime.now().difference(dueDate).inDays : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
        border: isOverdue ? Border.all(color: Colors.red.shade200, width: 1) : null,
      ),
      child: InkWell(
        onTap: () {
          print('Navigate to job order details: $jobOrderID');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact header with job order name, status, and quantity
              Row(
                children: [
                  // Job order icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange[100]!, Colors.orange[200]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.assignment,
                      color: Colors.orange[600],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Job order name and product
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                jobOrderName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Quantity badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Text(
                                'Qty: $quantity',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                productNames[productID] ?? 'Not linked to a product',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Status chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getStatusColor(status).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor(status),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Compact info grid
              Row(
                children: [
                  // Customer & Assignment column
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          icon: Icons.person_outline,
                          label: 'Customer',
                          value: customerName.isNotEmpty ? customerName : 'No customer',
                          isCompact: true,
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          icon: Icons.assignment_ind_outlined,
                          label: 'Assigned',
                          value: assignedTo.isNotEmpty ? userNames[assignedTo] ?? assignedTo : 'Unassigned',
                          isCompact: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Dates column
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Created',
                          value: createdAt != null ? _formatCompactDate(createdAt) : '-',
                          isCompact: true,
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          icon: isOverdue ? Icons.warning_outlined : Icons.schedule_outlined,
                          label: 'Due Date',
                          value: dueDate != null ? _formatCompactDate(dueDate) : '-',
                          isCompact: true,
                          isUrgent: isOverdue,
                          urgentText: isOverdue ? '$overdueDays days overdue' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Category and upcycled tags (if applicable)
              if (productInfo['category'] != null || productInfo['isUpcycled'] == true) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (productInfo['category'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (productInfo['category'] as String).toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      if (productInfo['isUpcycled'] == true) const SizedBox(width: 6),
                    ],
                    if (productInfo['isUpcycled'] == true) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'UPCYCLED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Color, size, and fabric info (if available)
              if (variantColor.isNotEmpty || variantSize.isNotEmpty || fabricName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (variantColor.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Color: $variantColor',
                          style: TextStyle(fontSize: 10, color: Colors.blue[700], fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (variantSize.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Size: $variantSize',
                          style: TextStyle(fontSize: 10, color: Colors.purple[700], fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (fabricName.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Fabric: $fabricName',
                          style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Compact action buttons
              Row(
                children: [
                  // Edit button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => Container(
                            margin: const EdgeInsets.only(top: 100),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            child: JobOrderEditModal(jobOrderId: jobOrderID),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Delete button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Job Order'),
                            content: Text('Delete "$jobOrderName"? This cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await FirebaseFirestore.instance
                                .collection('jobOrders')
                                .doc(jobOrderID)
                                .delete();

                          print('Delete job order: $jobOrderID');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.green,
                              content: Text(
                                'Successfully Deleted "$jobOrderName"',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete, size: 14),
                      label: const Text('Delete', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[600],
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        side: BorderSide(color: Colors.red[300]!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Mark as Done / Completed indicator
                  if (status != 'Done')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _markJobOrderAsDone(jobOrderID, jobOrderName, data),
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text('Mark as Done', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 14, color: Colors.green[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Completed',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method for compact info rows
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isCompact = false,
    bool isUrgent = false,
    String? urgentText,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: isUrgent ? Colors.red[600] : Colors.grey[500],
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isUrgent ? Colors.red[700] : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (urgentText != null) ...[
                Text(
                  urgentText,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.red[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Compact date formatting
  String _formatCompactDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '${difference}d ago';
    } else if (difference < 30) {
      final weeks = (difference / 7).floor();
      return '${weeks}w ago';
    } else {
      return '${date.month}/${date.day}/${date.year.toString().substring(2)}';
    }
  }

  // Mark job order as done with product handling
  Future<void> _markJobOrderAsDone(String jobOrderID, String jobOrderName, Map<String, dynamic> jobOrderData) async {
    print('[DEBUG] Starting mark as done process for job order: $jobOrderID');
    
    try {
      // Step 1: Fetch jobOrderDetails first
      print('[DEBUG] Fetching job order details...');
      final jobOrderDetailsSnap = await FirebaseFirestore.instance
          .collection('jobOrderDetails')
          .where('jobOrderID', isEqualTo: jobOrderID)
          .get();

      print('[DEBUG] Found ${jobOrderDetailsSnap.docs.length} jobOrderDetails for job order $jobOrderID');

      // Debug: Print each job order detail
      for (int i = 0; i < jobOrderDetailsSnap.docs.length; i++) {
        final detail = jobOrderDetailsSnap.docs[i];
        final data = detail.data();
        print('[DEBUG] JobOrderDetail $i: ID=${detail.id}, Data=$data');
      }

      if (jobOrderDetailsSnap.docs.isEmpty) {
        print('[WARNING] No job order details found - cannot create product without variants');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('No product variants found for this job order. Cannot create product.')),
                ],
              ),
              backgroundColor: Colors.orange[600],
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
        return;
      }

      // Step 2: Show product handling dialog BEFORE marking as done
      print('[DEBUG] Showing product handling dialog...');
      final productResult = await _showProductHandlingDialog(jobOrderData, jobOrderDetailsSnap.docs);
      
      if (productResult == null) {
        // User cancelled - don't mark as done
        print('[DEBUG] User cancelled product handling dialog - job order remains in current status');
        return;
      }

      print('[DEBUG] User selected product action: ${productResult.action}');
      print('[DEBUG] Payment amount: ${productResult.paymentAmount}');

      // Step 3: Handle product creation/update based on user choice
      try {
        await _handleProductAction(productResult.action, jobOrderID, jobOrderName, jobOrderData, jobOrderDetailsSnap.docs);
        print('[DEBUG] Product action handled successfully');
      } catch (e) {
        print('[ERROR] Failed to handle product action: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Failed to handle product action: ${e.toString()}')),
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
        return; // Don't mark as done if product action failed
      }

      // Step 4: Only NOW mark job order as done in database (after successful product handling)
      print('[DEBUG] Updating job order status to Done...');
      await FirebaseFirestore.instance
          .collection('jobOrders')
          .doc(jobOrderID)
          .update({
            'status': 'Done',
            'updatedAt': Timestamp.now(),
            'completedAt': Timestamp.now(),
          });
      print('[DEBUG] Job order status updated successfully');

      // Step 5: Create transaction if payment was specified
      if (productResult.paymentAmount > 0) {
        try {
          print('[DEBUG] Creating transaction for payment: ${productResult.paymentAmount}');
          final transactionRef = await FirebaseFirestore.instance.collection('transactions').add({
            'jobOrderID': jobOrderID,
            'amount': productResult.paymentAmount,
            'type': 'expense',
            'date': Timestamp.now(),
            'description': 'Payment to worker for job order "$jobOrderName"',
            'createdAt': Timestamp.now(),
            'createdBy': jobOrderData['assignedTo'] ?? jobOrderData['createdBy'],
          });
          print('[DEBUG] Transaction created successfully: ${transactionRef.id}');
        } catch (e) {
          print('[WARNING] Failed to create transaction: $e');
          // Don't fail the whole operation if transaction creation fails
        }
      } else {
        print('[DEBUG] No payment amount specified - skipping transaction creation');
      }

      // Note: Transaction creation is now handled separately when payment is specified

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('Job order "$jobOrderName" completed successfully')),
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

    } catch (e) {
      print('[ERROR] Failed to mark job order as done: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to mark job order as done: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  // Show dialog to handle product creation/update options with payment
  Future<ProductHandlingResult?> _showProductHandlingDialog(Map<String, dynamic> jobOrderData, List<QueryDocumentSnapshot> jobOrderDetails) async {
    final linkedProductID = jobOrderData['linkedProductID'];
    final hasLinkedProduct = linkedProductID != null && linkedProductID.toString().isNotEmpty;
    
    final TextEditingController paymentController = TextEditingController();
    ProductHandlingAction? selectedAction;

    return showDialog<ProductHandlingResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Complete Job Order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Job order is ready to be marked as Done!', 
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                const Text('How would you like to handle the completed product?'),
                const SizedBox(height: 16),
                if (hasLinkedProduct) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link, color: Colors.blue[600], size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('This job order is linked to an existing product.', 
                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.inventory, color: Colors.orange[600], size: 16),
                          const SizedBox(width: 8),
                          Text('Found ${jobOrderDetails.length} variant(s) to process:', 
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...jobOrderDetails.map((detail) {
                        final data = detail.data() as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(left: 20, bottom: 2),
                          child: Text(
                            '• ${data['size'] ?? 'No size'} ${data['color'] ?? 'No color'} (${data['yardageUsed'] ?? 0} yards)',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                
                // Payment section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.attach_money, color: Colors.green[600], size: 16),
                          const SizedBox(width: 8),
                          const Text('Worker Payment', 
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('Enter the amount paid to the worker for this job order:', 
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: paymentController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Enter payment amount (optional)',
                          prefixIcon: Icon(Icons.attach_money, size: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Leave empty if no payment is made at this time', 
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Action selection
                const Text('Choose product handling action:', 
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                
                if (hasLinkedProduct) ...[
                  RadioListTile<ProductHandlingAction>(
                    title: const Text('Add to Linked Product'),
                    subtitle: const Text('Add stock to the already linked product'),
                    value: ProductHandlingAction.addToLinkedProduct,
                    groupValue: selectedAction,
                    onChanged: (value) => setState(() => selectedAction = value),
                    dense: true,
                  ),
                ],
                RadioListTile<ProductHandlingAction>(
                  title: const Text('Create New Product'),
                  subtitle: const Text('Create a brand new product from this job order'),
                  value: ProductHandlingAction.createNewProduct,
                  groupValue: selectedAction,
                  onChanged: (value) => setState(() => selectedAction = value),
                  dense: true,
                ),
                RadioListTile<ProductHandlingAction>(
                  title: const Text('Add to Existing Product'),
                  subtitle: const Text('Select an existing product to add stock to'),
                  value: ProductHandlingAction.selectExistingProduct,
                  groupValue: selectedAction,
                  onChanged: (value) => setState(() => selectedAction = value),
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: selectedAction != null ? () {
                final paymentAmount = double.tryParse(paymentController.text.trim()) ?? 0.0;
                Navigator.pop(context, ProductHandlingResult(
                  action: selectedAction!,
                  paymentAmount: paymentAmount,
                ));
              } : null,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Complete Job Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Handle the selected product action
  Future<void> _handleProductAction(
    ProductHandlingAction action,
    String jobOrderID,
    String jobOrderName,
    Map<String, dynamic> jobOrderData,
    List<QueryDocumentSnapshot> jobOrderDetails,
  ) async {
    print('[DEBUG] Handling product action: $action');

    switch (action) {
      case ProductHandlingAction.addToLinkedProduct:
        await _addToLinkedProduct(jobOrderID, jobOrderData, jobOrderDetails);
        break;
      case ProductHandlingAction.createNewProduct:
        await _createNewProduct(jobOrderID, jobOrderName, jobOrderData, jobOrderDetails);
        break;
      case ProductHandlingAction.selectExistingProduct:
        await _selectExistingProduct(jobOrderID, jobOrderData, jobOrderDetails);
        break;
    }
  }

  // Add stock to the linked product
  Future<void> _addToLinkedProduct(String jobOrderID, Map<String, dynamic> jobOrderData, List<QueryDocumentSnapshot> jobOrderDetails) async {
    final linkedProductID = jobOrderData['linkedProductID'];
    print('[DEBUG] Adding stock to linked product: $linkedProductID');

    // Create product variants from jobOrderDetails
    final batch = FirebaseFirestore.instance.batch();
    
    for (final detail in jobOrderDetails) {
      final detailData = detail.data() as Map<String, dynamic>;
      
      // Create ProductVariant record with correct field names
      final variantRef = FirebaseFirestore.instance.collection('productVariants').doc();
      batch.set(variantRef, {
        'productID': linkedProductID,
        'size': detailData['size'] ?? '',
        'colorID': detailData['color'] ?? '', // ERDv9: Use colorID for product variants (stores color string)
        'quantityInStock': detailData['quantity'] ?? 1, // Use actual quantity
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'sourceJobOrderID': jobOrderID,
        'sourceJobOrderDetailID': detail.id,
      });
    }

    await batch.commit();
    print('[DEBUG] Added ${jobOrderDetails.length} variants to linked product $linkedProductID');
    
    // Refresh cached product data to reflect new variants
    await _refreshProductData(linkedProductID);
  }

  // Create a new product from the job order
  Future<void> _createNewProduct(String jobOrderID, String jobOrderName, Map<String, dynamic> jobOrderData, List<QueryDocumentSnapshot> jobOrderDetails) async {
    print('[DEBUG] Creating new product from job order: $jobOrderID');
    print('[DEBUG] Job order name: "$jobOrderName"');
    print('[DEBUG] Job order data: $jobOrderData');
    print('[DEBUG] Job order details count: ${jobOrderDetails.length}');

    if (jobOrderDetails.isEmpty) {
      throw Exception('No job order details provided - cannot create product without variants');
    }
    
    if (jobOrderName.trim().isEmpty) {
      throw Exception('Job order name is empty - cannot create product without a name');
    }

    try {
      // Get product info from the original product template (if any)
      final originalProductID = jobOrderData['productID'];
      final originalProductInfo = this.productData[originalProductID] ?? {};
      print('[DEBUG] Original product ID: $originalProductID');
      print('[DEBUG] Original product info: $originalProductInfo');

      // Create new product
      final productRef = FirebaseFirestore.instance.collection('products').doc();
      print('[DEBUG] Generated new product ID: ${productRef.id}');
      
      // Use proper field names matching the Product model and existing collection structure
      final newProductData = {
        'name': jobOrderName,
        'notes': 'Created from job order: $jobOrderName',
        'price': originalProductInfo['price'] ?? jobOrderData['price'] ?? 0.0,
        'categoryID': originalProductInfo['category'] ?? 'custom', // Using categoryID as per ERDv9
        'isUpcycled': originalProductInfo['isUpcycled'] ?? jobOrderData['isUpcycled'] ?? false,
        'isMade': true, // This is a completed product
        'createdBy': jobOrderData['createdBy'] ?? jobOrderData['assignedTo'] ?? 'unknown',
        'createdAt': Timestamp.now(), // Use Firestore Timestamp
        'updatedAt': Timestamp.now(), // Use Firestore Timestamp
        'sourceJobOrderID': jobOrderID, // Additional metadata
      };
      
      print('[DEBUG] Product data to be saved: $newProductData');
      
      await productRef.set(newProductData);
      print('[DEBUG] Product document created successfully');

      // Verify the product was created
      final verifyProduct = await productRef.get();
      if (!verifyProduct.exists) {
        throw Exception('Product document was not created in database');
      }
      print('[DEBUG] Product creation verified - document exists with data: ${verifyProduct.data()}');

      // Create product variants from jobOrderDetails
      final batch = FirebaseFirestore.instance.batch();
      
      for (final detail in jobOrderDetails) {
        final detailData = detail.data() as Map<String, dynamic>;
        print('[DEBUG] Processing job order detail: ${detail.id} - $detailData');
        
        // Create ProductVariant record with correct field names
        final variantRef = FirebaseFirestore.instance.collection('productVariants').doc();
        final variantData = {
          'productID': productRef.id,
          'size': detailData['size'] ?? '',
          'colorID': detailData['color'] ?? '', // ERDv9: Use colorID for product variants (stores color string)
          'quantityInStock': detailData['quantity'] ?? 1, // Use the actual quantity from job order detail
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'sourceJobOrderID': jobOrderID, // Additional metadata
          'sourceJobOrderDetailID': detail.id, // Additional metadata
        };
        
        print('[DEBUG] Variant data to be saved: $variantData');
        batch.set(variantRef, variantData);
      }

      await batch.commit();
      print('[DEBUG] Created new product ${productRef.id} with ${jobOrderDetails.length} variants successfully');
      
      // Verify variants were created
      final verifyVariants = await FirebaseFirestore.instance
          .collection('productVariants')
          .where('productID', isEqualTo: productRef.id)
          .get();
      
      print('[DEBUG] Verification: Found ${verifyVariants.docs.length} variants for product ${productRef.id}');
      
      if (verifyVariants.docs.length != jobOrderDetails.length) {
        print('[WARNING] Mismatch in variant count - expected ${jobOrderDetails.length}, found ${verifyVariants.docs.length}');
      }
      
      // Refresh cached product data to reflect new variants
      await _refreshProductData(productRef.id);
      
    } catch (e, stackTrace) {
      print('[ERROR] Failed to create new product: $e');
      print('[ERROR] Stack trace: $stackTrace');
      rethrow; // Re-throw the error so it can be handled by the calling method
    }
  }

  // Select an existing product to add stock to
  Future<void> _selectExistingProduct(String jobOrderID, Map<String, dynamic> jobOrderData, List<QueryDocumentSnapshot> jobOrderDetails) async {
    print('[DEBUG] Selecting existing product for job order: $jobOrderID');

    // Fetch all products for selection (excluding soft-deleted ones)
    final productsSnap = await FirebaseFirestore.instance
        .collection('products')
        .orderBy('name')
        .get();

    // Filter out soft-deleted products in memory
    final availableProducts = productsSnap.docs.where((doc) {
      final data = doc.data();
      return data['deletedAt'] == null;
    }).toList();

    if (!mounted) return;

    if (availableProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No products available for selection'),
          backgroundColor: Colors.orange[600],
        ),
      );
      return;
    }

    // Show product selection dialog
    final selectedProductID = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Product'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: availableProducts.length,
            itemBuilder: (context, index) {
              final doc = availableProducts[index];
              final data = doc.data();
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange[100],
                  child: Icon(Icons.inventory, color: Colors.orange[600], size: 20),
                ),
                title: Text(data['name'] ?? 'Unnamed Product'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Price: \$${data['price'] ?? 0.0}'),
                    Text('Category: ${data['categoryID'] ?? 'Unknown'}'),
                    if (data['isUpcycled'] == true) 
                      Text('Upcycled', style: TextStyle(color: Colors.green[600], fontWeight: FontWeight.w500)),
                  ],
                ),
                onTap: () => Navigator.pop(context, doc.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedProductID == null) return;

    // Add variants to selected product
    final batch = FirebaseFirestore.instance.batch();
    
    for (final detail in jobOrderDetails) {
      final detailData = detail.data() as Map<String, dynamic>;
      
      // Create ProductVariant record with correct field names
      final variantRef = FirebaseFirestore.instance.collection('productVariants').doc();
      batch.set(variantRef, {
        'productID': selectedProductID,
        'size': detailData['size'] ?? '',
        'colorID': detailData['color'] ?? '', // ERDv9: Use colorID for product variants (stores color string)
        'quantityInStock': detailData['quantity'] ?? 1, // Use actual quantity
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'sourceJobOrderID': jobOrderID,
        'sourceJobOrderDetailID': detail.id,
      });
    }

    await batch.commit();
    print('[DEBUG] Added ${jobOrderDetails.length} variants to selected product $selectedProductID');
    
    // Refresh cached product data to reflect new variants
    await _refreshProductData(selectedProductID);
  }

  // Refresh product data for a specific product (to update cached variants)
  Future<void> _refreshProductData(String productID) async {
    print('[DEBUG] Refreshing product data for product: $productID');
    
    try {
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productID)
          .get();
      
      if (!productDoc.exists) {
        print('[WARNING] Product $productID not found when refreshing data');
        return;
      }
      
      final productDocData = productDoc.data()!;
      
      // Fetch variants for this product
      final variantsSnapshot = await FirebaseFirestore.instance
          .collection('productVariants')
          .where('productID', isEqualTo: productID)
          .get();
      
      List<Map<String, dynamic>> variants = [];
      for (var variantDoc in variantsSnapshot.docs) {
        final variantData = variantDoc.data();
        variants.add({
          'variantID': variantDoc.id,
          'size': variantData['size'] ?? '',
          'color': variantData['colorID'] ?? variantData['color'] ?? '', // ERDv9: Use colorID, fallback to legacy color
          'quantityInStock': variantData['quantityInStock'] ?? 0,
        });
      }
      
      // Update cached product data
      productData[productID] = {
        'name': productDocData['name'] ?? '',
        'category': productDocData['category'] ?? '',
        'price': productDocData['price'] ?? 0.0,
        'imageURL': productDocData['imageURL'] ?? '',
        'isUpcycled': productDocData['isUpcycled'] ?? false,
        'variants': variants,
        'fabrics': [], // Keep empty for compatibility
      };
      
      print('[DEBUG] Updated cached data for product $productID with ${variants.length} variants');
      
    } catch (e) {
      print('[ERROR] Failed to refresh product data for $productID: $e');
    }
  }
}