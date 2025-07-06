import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_job_order_modal.dart';
import 'job_order_edit_modal.dart';
import 'components/job_order_stats.dart';
import 'components/job_order_filters.dart';
import 'components/job_order_card.dart';
import 'components/job_order_empty_state.dart';
import 'components/job_order_actions.dart';

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
            JobOrderFilters(
              selectedStatus: _selectedStatus,
              searchQuery: _searchQuery,
              searchController: _searchController,
              onStatusChanged: (String newValue) {
                setState(() {
                  _selectedStatus = newValue;
                });
              },
              onRefresh: _refreshData,
              isRefreshing: _isRefreshing,
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
                        // Overview section
                        SliverToBoxAdapter(
                          child: JobOrderStats(
                            isExpanded: _isStatsExpanded,
                            onToggle: () {
                              setState(() {
                                _isStatsExpanded = !_isStatsExpanded;
                              });
                            },
                            totalOrders: _totalOrders,
                            openOrders: _openOrders,
                            inProgressOrders: _inProgressOrders,
                            doneOrders: _doneOrders,
                            overdueOrders: _overdueOrders,
                          ),
                        ),

                        // Job orders list
                        SliverPadding(
                          padding: const EdgeInsets.only(bottom: 100),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                          child: JobOrderCard(
                                            doc: jobOrders[index],
                                            index: index,
                                            userNames: userNames,
                                            productNames: productNames,
                                            productData: productData,
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
}