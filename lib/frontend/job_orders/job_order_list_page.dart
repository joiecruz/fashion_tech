import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_job_order_modal.dart';
import 'job_order_edit_modal.dart';
import 'components/job_order_filters.dart';
import 'components/job_order_card.dart';
import 'components/job_order_empty_state.dart';
import 'components/job_order_actions.dart';
import '../../services/category_service.dart';

class JobOrderListPage extends StatefulWidget {
  const JobOrderListPage({super.key});
  @override
  State<JobOrderListPage> createState() => _JobOrderListPageState();
}

class _JobOrderListPageState extends State<JobOrderListPage>
    with SingleTickerProviderStateMixin {
  String _selectedStatus = 'All';
  String _selectedCategory = 'All Categories';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Caches for ERDv8 compliance
  Map<String, String> userNames = {};
  Map<String, String> productNames = {};
  Map<String, Map<String, dynamic>> productData = {};
  Map<String, String> categoryNames = {}; // Add category cache
  List<Map<String, dynamic>> categories = []; // Categories list for filter
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

    // Fetch categories for display names
    try {
      final categoriesData = await CategoryService.getAllProductCategories();
      print('DEBUG: Found ${categoriesData.length} categories');
      categoryNames = {
        for (var category in categoriesData)
          category['name']: category['displayName'] ?? category['name']
      };
      categories = categoriesData; // Store categories list for filter
    } catch (e) {
      print('DEBUG: Error loading categories: $e');
      // Use fallback category names
      categoryNames = {
        'top': 'Top',
        'bottom': 'Bottom',
        'outerwear': 'Outerwear',
        'dress': 'Dress',
        'activewear': 'Activewear',
        'underwear': 'Underwear & Intimates',
        'sleepwear': 'Sleepwear',
        'swimwear': 'Swimwear',
        'footwear': 'Footwear',
        'accessories': 'Accessories',
        'formal': 'Formal Wear',
        'uncategorized': 'Uncategorized',
      };
      // Create fallback categories list
      categories = categoryNames.entries.map((entry) => {
        'name': entry.key,
        'displayName': entry.value,
      }).toList();
    }

    // Fetch all products with full data for ERDv8 compliance
    final productsSnap = await FirebaseFirestore.instance.collection('products').get();
    print('DEBUG: Found ${productsSnap.docs.length} products');
    productNames = {
      for (var doc in productsSnap.docs)
        doc.id: (doc.data()['name'] ?? '') as String
    };

    // Fetch products - no longer storing variants to avoid bidirectional references
    productData = {};
    for (var doc in productsSnap.docs) {
      final productDocData = doc.data();
      
      // Get category info - handle both new categoryID and legacy category fields
      final categoryID = productDocData['categoryID'] ?? productDocData['category'] ?? 'uncategorized';
      final categoryDisplayName = categoryNames[categoryID] ?? categoryID.toString().toUpperCase();
      
      // Store only core product data - variants will be queried on-demand
      productData[doc.id] = {
        'name': productDocData['name'] ?? '',
        'categoryID': categoryID, // ERDv9: Store the category ID
        'categoryName': categoryDisplayName, // ERDv9: Store the display name
        'price': productDocData['price'] ?? 0.0,
        'imageURL': productDocData['imageURL'] ?? '',
        'isUpcycled': productDocData['isUpcycled'] ?? false,
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
      categoryNames.clear();
      
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

  Widget _buildCompactStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    bool isWide = false,
  }) {
    return Container(
      width: isWide ? 130 : 90,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            iconColor.withOpacity(0.12),
            iconColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(3),
            child: Icon(icon, color: iconColor, size: 14),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: iconColor.withOpacity(0.8),
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isWide ? 11 : 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
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
            JobOrderFilters(
              selectedStatus: _selectedStatus,
              selectedCategory: _selectedCategory,
              searchQuery: _searchQuery,
              searchController: _searchController,
              onStatusChanged: (String newValue) {
                setState(() {
                  _selectedStatus = newValue;
                });
              },
              onCategoryChanged: (String newValue) {
                setState(() {
                  _selectedCategory = newValue;
                });
              },
              onRefresh: _refreshData,
              isRefreshing: _isRefreshing,
              categories: categories,
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
                    return JobOrderEmptyState(
                      onCreateJobOrder: () async {
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
                    );
                  }

                  var jobOrders = snapshot.data!.docs;
                  _updateStats(jobOrders);

                  // Apply status filter
                  if (_selectedStatus != 'All') {
                    jobOrders = jobOrders.where((doc) =>
                      (doc.data() as Map<String, dynamic>)['status'] == _selectedStatus
                    ).toList();
                  }

                  // Apply category filter
                  if (_selectedCategory != 'All Categories') {
                    jobOrders = jobOrders.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final productID = data['productID'] ?? '';
                      final productInfo = productData[productID] ?? {};
                      final categoryDisplayName = productInfo['categoryName'] ?? '';
                      return categoryDisplayName == _selectedCategory;
                    }).toList();
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
                        // Overview section - Built directly into page for smooth animation
                        SliverToBoxAdapter(
                          child: Container(
                            color: Colors.white,
                            child: Column(
                              children: [
                                // Collapse/Expand Button
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
                                              Container(
                                                constraints: const BoxConstraints(maxWidth: 200),
                                                child: Text(
                                                  '$_totalOrders orders • $_openOrders open${_overdueOrders > 0 ? ' • $_overdueOrders overdue' : ''}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
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
                                // Animated Stats Content - Using height instead of maxHeight for smoother animation
                                ClipRect(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    height: _isStatsExpanded ? 70.0 : 0.0,
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 200),
                                      opacity: _isStatsExpanded ? 1.0 : 0.0,
                                      child: AnimatedOpacity(
                                        opacity: _isRefreshing ? 0.6 : 1.0,
                                        duration: const Duration(milliseconds: 300),
                                        child: Container(
                                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: [
                                                _buildCompactStatCard(
                                                  icon: Icons.assignment,
                                                  iconColor: Colors.orange[600]!,
                                                  title: 'Total Orders',
                                                  value: _totalOrders.toString(),
                                                ),
                                                const SizedBox(width: 8),
                                                _buildCompactStatCard(
                                                  icon: Icons.access_time,
                                                  iconColor: Colors.orange[700]!,
                                                  title: 'Open',
                                                  value: _openOrders.toString(),
                                                ),
                                                const SizedBox(width: 8),
                                                _buildCompactStatCard(
                                                  icon: Icons.trending_up,
                                                  iconColor: Colors.blue[600]!,
                                                  title: 'In Progress',
                                                  value: _inProgressOrders.toString(),
                                                ),
                                                const SizedBox(width: 8),
                                                _buildCompactStatCard(
                                                  icon: Icons.check_circle,
                                                  iconColor: Colors.green[600]!,
                                                  title: 'Completed',
                                                  value: _doneOrders.toString(),
                                                ),
                                                if (_overdueOrders > 0) ...[
                                                  const SizedBox(width: 8),
                                                  _buildCompactStatCard(
                                                    icon: Icons.warning,
                                                    iconColor: Colors.red[600]!,
                                                    title: 'Overdue',
                                                    value: _overdueOrders.toString(),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Add New Job Order Button
                        SliverToBoxAdapter(
                          child: Container(
                            color: Colors.white,
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.orange[600]!, Colors.orange[700]!],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange[600]!.withOpacity(0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
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
                                  borderRadius: BorderRadius.circular(10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.add_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Add New Job Order',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Job orders list
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final jobOrderActions = JobOrderActions(
                                  context: context,
                                  productData: productData,
                                  onDataRefresh: () => setState(() {}),
                                );

                                return TweenAnimationBuilder<double>(
                                  duration: Duration(milliseconds: 300 + (index * 50)),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  builder: (context, value, child) {
                                    return Transform.translate(
                                      offset: Offset(0, 20 * (1 - value)),
                                      child: Opacity(
                                        opacity: value,
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 16),
                                          child: JobOrderCard(
                                            doc: jobOrders[index],
                                            index: index,
                                            userNames: userNames,
                                            productNames: productNames,
                                            productData: productData,
                                            categoryNames: categoryNames,
                                            status: (jobOrders[index].data() as Map<String, dynamic>)['status'] ?? 'Open',
                                            onEdit: () async {
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
                                                  child: JobOrderEditModal(jobOrderId: jobOrders[index].id),
                                                ),
                                              );
                                            },
                                            onDelete: () async {
                                              final data = jobOrders[index].data() as Map<String, dynamic>;
                                              final jobOrderName = data['name'] ?? 'Unnamed Job Order';
                                              
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
                                                      .doc(jobOrders[index].id)
                                                      .delete();

                                                print('Delete job order: ${jobOrders[index].id}');
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
                                            onMarkAsDone: () async {
                                              final data = jobOrders[index].data() as Map<String, dynamic>;
                                              final jobOrderName = data['name'] ?? 'Unnamed Job Order';
                                              await jobOrderActions.markJobOrderAsDone(jobOrders[index].id, jobOrderName, data);
                                            },
                                            onUpdateStatus: () async {
                                              await _updateJobOrderStatus(jobOrders[index]);
                                            },
                                          ),
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
    );
  }

  // Handle dynamic status updates based on current status
  Future<void> _updateJobOrderStatus(QueryDocumentSnapshot jobOrderDoc) async {
    final data = jobOrderDoc.data() as Map<String, dynamic>;
    final currentStatus = data['status'] ?? 'Open';
    final jobOrderName = data['name'] ?? 'Unnamed Job Order';
    
    String newStatus;
    String actionDescription;
    
    switch (currentStatus) {
      case 'Open':
        newStatus = 'In Progress';
        actionDescription = 'started work on';
        break;
      case 'Done':
        newStatus = 'Archived';
        actionDescription = 'archived';
        break;
      default:
        return; // No action for other statuses
    }
    
    try {
      await FirebaseFirestore.instance
          .collection('jobOrders')
          .doc(jobOrderDoc.id)
          .update({
            'status': newStatus,
            'updatedAt': Timestamp.now(),
            if (newStatus == 'Archived') 'archivedAt': Timestamp.now(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newStatus == 'In Progress' ? Icons.play_arrow : Icons.archive,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Successfully $actionDescription "$jobOrderName"',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: newStatus == 'In Progress' ? Colors.blue[600] : Colors.grey[600],
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
                Expanded(
                  child: Text(
                    'Failed to update status: ${e.toString()}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
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
    }
  }
}