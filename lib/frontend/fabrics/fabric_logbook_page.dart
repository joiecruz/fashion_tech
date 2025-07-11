import 'package:fashion_tech/frontend/fabrics/edit_fabric_modal.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_fabric_modal.dart';
import 'dart:convert';
import 'dart:async';
import '../../services/fabric_operations_service.dart';
import '../../services/fabric_log_service.dart';
import '../../models/fabric_log.dart';
import '../common/gradient_search_bar.dart';
import '../../utils/log_helper.dart';

class FabricLogbookPage extends StatefulWidget {
  const FabricLogbookPage({super.key});

  @override
  State<FabricLogbookPage> createState() => _FabricLogbookPageState();
}

class _FabricLogbookPageState extends State<FabricLogbookPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allFabrics = [];
  List<Map<String, dynamic>> _filteredFabrics = [];
  String _selectedType = 'All';
  bool _showUpcycledOnly = false;
  bool _showLowStockOnly = false;
  bool _isStatsExpanded = true;
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _fabricsSubscription;
  
  // User filtering and debugging
  String? _currentUserId;
  // Removed _showUserDataOnly - users can only see their own data now

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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

    _initializeUser();
    _searchController.addListener(_onSearchChanged);
  }

  void _initializeUser() {
    // Get current user information
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
    } else {
      // Redirect to login if no user
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    
    _initializeFabrics();
  }

  void _initializeFabrics() {
    _fabricsSubscription?.cancel(); // Cancel any existing subscription
    
    // Always filter by current user - users can only see their own data
    if (_currentUserId == null) {
      setState(() {
        _isLoading = false;
        _allFabrics = [];
      });
      return;
    }
    
    try {
      // Use simple where query for user's fabrics only
      final fabricsQuery = FirebaseFirestore.instance
          .collection('fabrics')
          .where('createdBy', isEqualTo: _currentUserId);
      print('DEBUG: Using filtered query for user: $_currentUserId');

      _fabricsSubscription = fabricsQuery.snapshots()          .listen(
        (snapshot) {
          if (mounted) {
            var fabrics = snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList();

            // Since we're filtering by user, we need to sort manually
            fabrics.sort((a, b) {
              final aTime = a['createdAt'] as Timestamp?;
              final bTime = b['createdAt'] as Timestamp?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime); // Descending order
            });

            setState(() {
              _allFabrics = fabrics;
              _isLoading = false;
            });

            _applyFilters();
            
            // Start animation on first load
            if (_animationController.status == AnimationStatus.dismissed) {
              _animationController.forward();
            }
          }
        },
        onError: (error) {
          print('DEBUG: Firestore error: $error');
          
          if (mounted) {
            setState(() {
              _isLoading = false;
              _allFabrics = []; // Set empty list so UI shows empty state
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading your fabrics: ${error.toString()}'),
                backgroundColor: Colors.red.shade600,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                    });
                    _initializeFabrics();
                  },
                ),
              ),
            );
          }
        },
      );
      
      // Add timeout to detect hanging queries
      Timer(const Duration(seconds: 10), () {
        if (_isLoading && mounted) {
          setState(() {
            _isLoading = false;
            _allFabrics = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Loading took too long. Please check your connection.'),
              backgroundColor: Colors.orange.shade600,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                  });
                  _initializeFabrics();
                },
              ),
            ),
          );
        }
      });
      
    } catch (e) {
      print('DEBUG: Exception creating query: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _allFabrics = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create query: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredFabrics = _allFabrics.where((fabric) {
        // Exclude soft-deleted fabrics
        if (fabric['deletedAt'] != null) return false;
      final name = (fabric['name'] ?? '').toString().toLowerCase();
      final type = (fabric['type'] ?? '').toString().toLowerCase();
      final color = (fabric['color'] ?? '').toString().toLowerCase();
      final quantity = fabric['quantity'] ?? 0;
      final isUpcycled = fabric['isUpcycled'] ?? false;

      final matchesSearch = _searchController.text.isEmpty ||
          name.contains(_searchController.text.toLowerCase()) ||
          type.contains(_searchController.text.toLowerCase()) ||
          color.contains(_searchController.text.toLowerCase());

      final matchesType = _selectedType == 'All' || (fabric['type']?.toLowerCase() == _selectedType.toLowerCase());
      final matchesUpcycled = !_showUpcycledOnly || (fabric['isUpcycled'] == true);
      final matchesLowStock = !_showLowStockOnly || ((fabric['quantity'] ?? 0) < 5);

      return matchesType && matchesUpcycled && matchesLowStock && matchesSearch;
    }).toList();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _fabricsSubscription?.cancel();
    super.dispose();
  }

Future<void> _deleteFabricById(String fabricId, String? createdBy) async {
  try {
    await FirebaseFirestore.instance
        .collection('fabrics')
        .doc(fabricId)
        .update({'deletedAt': Timestamp.now()});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.delete, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              const Text('Fabric marked as deleted.'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    // Optionally: Add logging here (will be handled next)
  } catch (e) {
    print('Error soft deleting fabric: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              const Text('Failed to delete fabric.'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

  // Soft delete fabric by setting deletedAt field and log the operation
  Future<void> _softDeleteFabricById(String fabricId, String? createdBy) async {
    try {
      await FirebaseFirestore.instance.collection('fabrics').doc(fabricId).update({
        'deletedAt': Timestamp.now(),
        'lastEdited': Timestamp.now(),
      });
      await addLog(
        collection: 'fabricLogs',
        createdBy: createdBy ?? FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
        remarks: 'Soft deleted fabric',
        changeType: 'delete',
        extraData: {
          'fabricId': fabricId,
          'deletedAt': Timestamp.now(),
        },
      );
    } catch (e) {
      print('Failed to soft delete fabric: $e');
    }
  }

  bool _isBase64Image(String str) {
    return str.startsWith('data:image/') || (str.isNotEmpty && !str.startsWith('http'));
  }

  ImageProvider _getSwatchImageProvider(String swatchUrl) {
    if (_isBase64Image(swatchUrl)) {
      final base64Str = swatchUrl.startsWith('data:image/')
          ? swatchUrl.split(',').last
          : swatchUrl;
      return MemoryImage(base64Decode(base64Str));
    } else {
      return NetworkImage(swatchUrl);
    }
  }

  int _getLowStockCount(List<Map<String, dynamic>> fabrics) {
    return fabrics.where((fabric) {
      final quantity = fabric['quantity'] ?? 0;
      return quantity < 5;
    }).length;
  }

  double _getTotalExpense(List<Map<String, dynamic>> fabrics) {
    return fabrics.fold(0.0, (total, fabric) {
      final quantity = fabric['quantity'] ?? 0;
      final price = fabric['pricePerUnit'] ?? 0.0;
      return total + (quantity * price);
    });
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '₱${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '₱${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return '₱${value.toStringAsFixed(0)}';
    }
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Fixed Search Bar at top
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: CompactGradientSearchBar(
                      controller: _searchController,
                      hintText: 'Search fabrics by name, type, or color...',
                      primaryColor: Colors.green,
                      onChanged: (value) {
                        // Search is handled through the controller
                      },
                      onClear: () {
                        _searchController.clear();
                      },
                    ),
                  ),
                  // Sticky Filter Chips - Full Width
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text(
                              'Filters:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildTypeDropdown(),
                            const SizedBox(width: 12),
                            GradientFilterChip(
                              label: 'Upcycled',
                              isSelected: _showUpcycledOnly,
                              onTap: () {
                                setState(() {
                                  _showUpcycledOnly = !_showUpcycledOnly;
                                });
                                _applyFilters();
                              },
                              primaryColor: Colors.green,
                              icon: Icons.eco_rounded,
                            ),
                            const SizedBox(width: 12),
                            GradientFilterChip(
                              label: 'Low Stock',
                              isSelected: _showLowStockOnly,
                              onTap: () {
                                setState(() {
                                  _showLowStockOnly = !_showLowStockOnly;
                                });
                                _applyFilters();
                              },
                              primaryColor: Colors.green,
                              icon: Icons.warning_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Scrollable Content with Pull-to-Refresh
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _refreshFabrics(),
                      color: Colors.green.shade600,
                      backgroundColor: Colors.white,
                      strokeWidth: 3.0,
                      displacement: 50,
                      edgeOffset: 0,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                        // Collapsible Stats Cards
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
                                        bottom: BorderSide(color: Colors.grey.shade200, width: 1),
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
                                              'Statistics',
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
                                              Expanded(
                                                child: Text(
                                                  '${_allFabrics.length} fabrics • ${_getLowStockCount(_allFabrics)} low stock',
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
                                // Animated Stats Content
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  constraints: BoxConstraints(
                                    maxHeight: _isStatsExpanded ? 70 : 0,
                                  ),
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 200),
                                    opacity: _isStatsExpanded ? 1.0 : 0.0,
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            _buildCompactStatCard(
                                              icon: Icons.palette_outlined,
                                              iconColor: Colors.blue.shade600,
                                              title: 'Total Fabrics',
                                              value: _allFabrics.length.toString(),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildCompactStatCard(
                                              icon: Icons.warning_outlined,
                                              iconColor: Colors.red.shade600,
                                              title: 'Low Stock',
                                              value: _getLowStockCount(_allFabrics).toString(),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildCompactStatCard(
                                              icon: Icons.attach_money,
                                              iconColor: Colors.green.shade600,
                                              title: 'Total Expense',
                                              value: _formatCurrency(_getTotalExpense(_allFabrics)),
                                              isWide: true,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Add New Item Button
                        SliverToBoxAdapter(
                          child: Container(
                            color: Colors.white,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.green.shade600, Colors.green.shade700],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.shade600.withOpacity(0.25),
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
                                        height: MediaQuery.of(context).size.height - 100,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                        ),
                                        child: AddFabricModal(),
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
                                        'Add New Fabric',
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
                        // Fabric List
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                          sliver: _buildFabricsList(),
                        ),
                      ],
                    ),
                  ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFabricsList() {
    if (_allFabrics.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[100]!, Colors.green[200]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 48,
                  color: Colors.green[600],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Start Your Fabric Collection',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your first fabric to begin tracking your inventory.',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[600]!, Colors.green[700]!],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green[600]!.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
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
                          height: MediaQuery.of(context).size.height - 100,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          child: AddFabricModal(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Add Your First Fabric',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
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
            ],
          ),
        ),
      );
    }

    if (_filteredFabrics.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey[100]!, Colors.grey[200]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.search_off,
                  size: 48,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Matching Fabrics',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search terms or filters\nto find what you\'re looking for.',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _selectedType = 'All';
                    _showUpcycledOnly = false;
                    _showLowStockOnly = false;
                  });
                  _applyFilters();
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear All Filters'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green[600],
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final fabric = _filteredFabrics[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildFabricCard(fabric, index),
          );
        },
        childCount: _filteredFabrics.length,
      ),
    );
  }

  Widget _buildFabricCard(Map<String, dynamic> fabric, int index) {
    final swatchUrl = fabric['swatchImageURL'] ?? '';
    final name = fabric['name'] ?? 'Unnamed Fabric';
    final type = fabric['type'] ?? '';
    final color = fabric['color'] ?? '';
    final quality = fabric['qualityGrade'] ?? '';
    final quantity = fabric['quantity'] ?? 0;
    final pricePerUnit = fabric['pricePerUnit'] ?? 0.0;
    final minOrder = fabric['minOrder'] ?? 0;
    final isUpcycled = fabric['isUpcycled'] ?? false;
    final supplierID = fabric['supplierID']; // Add supplier ID
    
    // Calculate total value and status
    final totalValue = quantity * pricePerUnit;
    final isLowStock = quantity < 5;
    final isOutOfStock = quantity == 0;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: isOutOfStock 
                    ? Border.all(color: Colors.red.shade400, width: 2)
                    : isLowStock 
                        ? Border.all(color: Colors.orange.shade400, width: 1.5)
                        : Border.all(color: Colors.grey.shade200, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: isOutOfStock 
                        ? Colors.red.withOpacity(0.12)
                        : isLowStock 
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
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
                      // Enhanced fabric swatch
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: swatchUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image(
                                  image: _getSwatchImageProvider(swatchUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildEnhancedFallbackSwatch(color),
                                ),
                              )
                            : _buildEnhancedFallbackSwatch(color),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (type.isNotEmpty)
                                        Text(
                                          type.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: _getFabricTypeColor(type),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Status labels and actions in upper right corner
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isUpcycled)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green[100],
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Upcycled',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green[700],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (isLowStock || isOutOfStock) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isOutOfStock ? Colors.red[50] : Colors.orange[50],
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isOutOfStock ? Colors.red.shade200 : Colors.orange.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          isOutOfStock ? 'Out of Stock' : 'Low Stock',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isOutOfStock ? Colors.red[700] : Colors.orange[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            // Show fabric details if available
                            if (color.isNotEmpty || quality.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (color.isNotEmpty)
                                    Text(
                                      color.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  if (color.isNotEmpty && quality.isNotEmpty)
                                    Text(
                                      ' • ',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  if (quality.isNotEmpty)
                                    Text(
                                      quality.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _getQualityTextColor(quality),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            // Show supplier info if available
                            if (supplierID != null) ...[
                              const SizedBox(height: 6),
                              FutureBuilder<String>(
                                future: _getSupplierName(supplierID),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                    return Row(
                                      children: [
                                        Icon(
                                          Icons.local_shipping_rounded,
                                          size: 14,
                                          color: Colors.blue[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Supplier: ${snapshot.data}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.blue[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                            // Show creator info for debugging
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.person_rounded,
                                  size: 14,
                                  color: fabric['createdBy'] == _currentUserId 
                                    ? Colors.green[600] 
                                    : Colors.orange[600],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Created by: ${fabric['createdBy'] == _currentUserId ? "Me" : fabric['createdBy']?.substring(0, 8) ?? "Unknown"}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: fabric['createdBy'] == _currentUserId 
                                        ? Colors.green[700] 
                                        : Colors.orange[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Show full user ID on tap for debugging
                                if (fabric['createdBy'] != null)
                                  GestureDetector(
                                    onTap: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Full Creator ID: ${fabric['createdBy']}'),
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        Icons.info_outline,
                                        size: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            // Show most recent fabric log remarks if available - REPLACE WITH FABRIC NOTES
                            if (fabric['notes'] != null && (fabric['notes'] as String).trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.sticky_note_2_outlined, size: 16, color: Colors.blue[400]),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        fabric['notes'],
                                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₱${pricePerUnit.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total Value: ₱${totalValue.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (minOrder > 0)
                              Text(
                                'Min Order: $minOrder yards',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Date information
                            if (fabric['createdAt'] != null || fabric['lastEdited'] != null) ...[
                              if (fabric['lastEdited'] != null)
                                Text(
                                  'Edited ${_formatDate((fabric['lastEdited'] as Timestamp).toDate())}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                )
                              else if (fabric['createdAt'] != null)
                                Text(
                                  'Created ${_formatDate((fabric['createdAt'] as Timestamp).toDate())}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                ),
                              const SizedBox(height: 4),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isOutOfStock 
                                    ? Colors.red[50]
                                    : isLowStock 
                                        ? Colors.orange[50]
                                        : Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isOutOfStock 
                                      ? Colors.red.shade200
                                      : isLowStock 
                                          ? Colors.orange.shade200
                                          : Colors.blue.shade200,
                                ),
                              ),
                              child: Text(
                                'Stock: $quantity units',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isOutOfStock 
                                      ? Colors.red[700]
                                      : isLowStock 
                                          ? Colors.orange[700]
                                          : Colors.blue[700],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 1,
                    width: double.infinity,
                    color: Colors.grey[200],
                  ),
                  const SizedBox(height: 16),
                  // Check ownership for action buttons
                  Builder(
                    builder: (context) {
                      final isOwner = fabric['createdBy'] == _currentUserId;
                      final createdBy = fabric['createdBy'] as String?;
                      
                      return Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isOwner ? () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Fabric'),
                                    content: Text(isOwner 
                                      ? 'Are you sure you want to delete this fabric? This action cannot be undone.'
                                      : 'You can only delete fabrics you created.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      if (isOwner)
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                        ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _deleteFabricById(fabric['id'], createdBy);
                                }
                              } : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isOwner ? Colors.red[600] : Colors.grey[400],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: Icon(
                                isOwner ? Icons.delete : Icons.block,
                                size: 16,
                              ),
                              label: Text(
                                isOwner ? 'Delete' : 'Not Owner',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isOwner ? () async {
                                await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => Container(
                                    margin: const EdgeInsets.only(top: 100),
                                    height: MediaQuery.of(context).size.height - 100,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                    ),
                                    child: EditFabricModal(
                                      fabric: fabric,
                                      fabricId: fabric['id'],
                                    ),
                                  ),
                                );
                              } : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.warning, color: Colors.white, size: 16),
                                        const SizedBox(width: 8),
                                        const Text('You can only edit fabrics you created!'),
                                      ],
                                    ),
                                    backgroundColor: Colors.orange.shade600,
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isOwner ? Colors.black87 : Colors.grey[600],
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                side: BorderSide(
                                  color: isOwner ? Colors.grey.shade300 : Colors.grey.shade400,
                                ),
                              ),
                              icon: Icon(
                                isOwner ? Icons.edit : Icons.edit_off,
                                size: 16,
                              ),
                              label: Text(
                                isOwner ? 'Edit' : 'View Only',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // TODO: Implement order functionality
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Order $name feature coming soon!')),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              icon: const Icon(Icons.shopping_cart, size: 16),
                              label: const Text('Order', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );    
  }

  Widget _buildEnhancedFallbackSwatch(String? color) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade200,
            Colors.grey.shade100,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.texture_outlined,
            size: 24,
            color: Colors.grey[500],
          ),
          if (color != null && color.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                color.length > 10 ? '${color.substring(0, 10)}...' : color,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getQualityTextColor(String quality) {
    switch (quality.toLowerCase()) {
      case 'premium':
      case 'high':
        return Colors.amber[700]!;
      case 'good':
      case 'medium':
        return Colors.blue[700]!;
      case 'standard':
      case 'low':
        return Colors.grey[700]!;
      default:
        return Colors.grey[600]!;
    }
  }

  // Helper methods for fabric log display
  IconData _getLogIcon(FabricChangeType changeType) {
    switch (changeType) {
      case FabricChangeType.add:
        return Icons.add_circle_outline;
      case FabricChangeType.deduct:
        return Icons.remove_circle_outline;
      case FabricChangeType.correction:
        return Icons.edit_outlined;
    }
  }

  Color _getLogIconColor(FabricChangeType changeType) {
    switch (changeType) {
      case FabricChangeType.add:
        return Colors.green[600]!;
      case FabricChangeType.deduct:
        return Colors.red[600]!;
      case FabricChangeType.correction:
        return Colors.orange[600]!;
    }
  }

  String _getChangeTypeText(FabricChangeType changeType) {
    switch (changeType) {
      case FabricChangeType.add:
        return 'Added';
      case FabricChangeType.deduct:
        return 'Removed';
      case FabricChangeType.correction:
        return 'Corrected';
    }
  }

  Future<String> _getSupplierName(String supplierID) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('suppliers')
          .doc(supplierID)
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        return data?['supplierName'] ?? 'Unknown Supplier';
      }
      return '';
    } catch (e) {
      print('Error fetching supplier name: $e');
      return '';
    }
  }

  // Helper methods for fabric card UI
  Color _getFabricTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'cotton':
        return Colors.green[600]!;
      case 'silk':
        return Colors.purple[600]!;
      case 'wool':
        return Colors.brown[600]!;
      case 'polyester':
        return Colors.blue[600]!;
      case 'linen':
        return Colors.amber[600]!;
      case 'denim':
        return Colors.indigo[600]!;
      case 'leather':
        return Colors.orange[700]!;
      case 'lace':
        return Colors.pink[600]!;
      case 'velvet':
        return Colors.deepPurple[600]!;
      case 'chiffon':
        return Colors.teal[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildTypeDropdown() {
    final typeOptions = ['All', 'Cotton', 'Silk', 'Wool', 'Linen', 'Polyester', 'Blend', 'Denim', 'Leather', 'Lace', 'Velvet', 'Chiffon'];

    return PopupMenuButton<String>(
      onSelected: (String newValue) {
        setState(() {
          _selectedType = newValue;
        });
        _applyFilters();
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
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.category_rounded,
                size: 12,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _selectedType == 'All' ? 'All Types' : _selectedType.toUpperCase(),
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
        return typeOptions.map((String option) {
          final displayName = option == 'All' ? 'All Types' : option;
          return PopupMenuItem<String>(
            value: option,
            child: Row(
              children: [
                Icon(
                  option == 'All' ? Icons.grid_view_rounded : Icons.category_rounded,
                  size: 14,
                  color: Colors.green[600],
                ),
                const SizedBox(width: 6),
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: option == _selectedType ? FontWeight.w600 : FontWeight.w400,
                    color: option == _selectedType ? Colors.green[700] : Colors.grey[800],
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  Future<void> _refreshFabrics() async {
    try {
      // Show success feedback for manual refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('${_allFabrics.length} fabrics refreshed'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      
      // The stream subscription will automatically update the data
      // We can also trigger a manual refresh if needed
      await Future.delayed(const Duration(milliseconds: 500)); // Small delay for better UX
      
    } catch (e) {
      print('Error refreshing fabrics: $e');
      
      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Text('Failed to refresh fabrics'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _refreshFabrics(),
            ),
          ),
        );
      }
    }
  }
}
