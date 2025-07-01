import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_job_order_modal.dart';

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
    
    productData = {
      for (var doc in productsSnap.docs)
        doc.id: {
          'name': doc.data()['name'] ?? '',
          'category': doc.data()['category'] ?? '',
          'price': doc.data()['price'] ?? 0.0,
          'imageURL': doc.data()['imageURL'] ?? '',
          'isUpcycled': doc.data()['isUpcycled'] ?? false,
        }
    };

    print('DEBUG: Data preloaded successfully');
    setState(() {
      _dataLoaded = true;
    });
    
    _animationController.forward();
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
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search job orders...',
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
                  
                  // Status filter dropdown (compact)
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
                      final productName = productNames[data['productID']] ?? '';
                      final customerName = data['customerName'] ?? '';
                      final assignedToName = userNames[data['assignedTo']] ?? '';
                      
                      return productName.toLowerCase().contains(_searchQuery) ||
                             customerName.toLowerCase().contains(_searchQuery) ||
                             assignedToName.toLowerCase().contains(_searchQuery);
                    }).toList();
                  }
                  
                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Overview section (like inventory pages)
                      SliverToBoxAdapter(
                        child: _buildOverviewSection(),
                      ),
                      
                      // Job orders list
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 100), // Add bottom padding to prevent overflow
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
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        backgroundColor: Colors.blue,
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
        return Colors.blue[600]!;
      case 'Done':
        return Colors.green[600]!;
      default:
        return Colors.grey[600]!;
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
              backgroundColor: Colors.blue,
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
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        color: Colors.grey[600],
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
                              iconColor: Colors.blue[600]!,
                              title: 'Total\nOrders',
                              value: _totalOrders.toString(),
                              isCompact: true,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: _buildStatCard(
                              icon: Icons.access_time,
                              iconColor: Colors.orange[600]!,
                              title: 'Open\nOrders',
                              value: _openOrders.toString(),
                              isCompact: true,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: _buildStatCard(
                              icon: Icons.trending_up,
                              iconColor: Colors.blue[600]!,
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
                          iconColor: Colors.blue[600]!,
                          title: 'Total\nOrders',
                          value: _totalOrders.toString(),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard(
                          icon: Icons.access_time,
                          iconColor: Colors.orange[600]!,
                          title: 'Open\nOrders',
                          value: _openOrders.toString(),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard(
                          icon: Icons.trending_up,
                          iconColor: Colors.blue[600]!,
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
        color: isUrgent ? Colors.red[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent ? Colors.red[200]! : Colors.grey[200]!,
          width: isUrgent ? 1.5 : 1,
        ),
        boxShadow: isUrgent ? [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
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
    final String productName = productInfo['name'] ?? 'Unknown Product';
    final String productCategory = productInfo['category'] ?? '';
    final String productImageURL = productInfo['imageURL'] ?? '';
    final bool isUpcycled = productInfo['isUpcycled'] ?? false;
    
    final String assignedToName = userNames[assignedTo] ?? assignedTo;
    
    // Check if overdue
    final bool isOverdue = dueDate != null && 
                          dueDate.isBefore(DateTime.now()) && 
                          status != 'Done';
    final int overdueDays = isOverdue ? 
        DateTime.now().difference(dueDate).inDays : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isOverdue ? Border.all(color: Colors.red.shade200, width: 1) : null,
      ),
      child: InkWell(
        onTap: () {
          // Navigate to job order details
          print('Navigate to job order details: $jobOrderID');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with product info
              Row(
                children: [
                  // Product image/icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: productImageURL.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              productImageURL,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.checkroom, 
                                  color: Colors.grey[400], 
                                  size: 24,
                                );
                              },
                            ),
                          )
                        : Icon(Icons.checkroom, 
                            color: Colors.grey[400], 
                            size: 24,
                          ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Product name and details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                productName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            // Status chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12, 
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getStatusColor(status).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor(status),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (productCategory.isNotEmpty) ...[
                              Text(
                                productCategory.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (isUpcycled) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6, 
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'UPCYCLED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Customer and assignment info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          customerName.isNotEmpty ? customerName : 'No customer',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assigned To',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          assignedToName.isNotEmpty ? assignedToName : 'Unassigned',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Dates and quantity
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Created',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          createdAt != null ? _formatDate(createdAt) : '-',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
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
                              'Due Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isOverdue) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6, 
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'OVERDUE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dueDate != null ? _formatDate(dueDate) : '-',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isOverdue ? Colors.red[700] : Colors.black87,
                          ),
                        ),
                        if (isOverdue) ...[
                          Text(
                            '$overdueDays days overdue',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quantity',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12, 
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          quantity.toString(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Action button
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Navigate to details
                    print('View details for job order: $jobOrderID');
                  },
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, 
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}