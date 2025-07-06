import 'package:fashion_tech/frontend/fabrics/edit_fabric_modal.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_fabric_modal.dart';
import 'dart:convert';
import 'dart:async';
import '../../services/fabric_operations_service.dart';
import '../design_system.dart';

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

    _initializeFabrics();
    _searchController.addListener(_onSearchChanged);
  }

  void _initializeFabrics() {
    _fabricsSubscription = FirebaseFirestore.instance
        .collection('fabrics')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final fabrics = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

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
    });
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    
    final filtered = _allFabrics.where((fabric) {
      final name = (fabric['name'] ?? '').toString().toLowerCase();
      final type = (fabric['type'] ?? '').toString().toLowerCase();
      final color = (fabric['color'] ?? '').toString().toLowerCase();
      final quantity = fabric['quantity'] ?? 0;
      final isUpcycled = fabric['isUpcycled'] ?? false;

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          type.contains(query) ||
          color.contains(query);

      final matchesType = _selectedType == 'All' || type == _selectedType.toLowerCase();
      final matchesUpcycled = !_showUpcycledOnly || isUpcycled;
      final matchesLowStock = !_showLowStockOnly || quantity < 5;

      return matchesSearch && matchesType && matchesUpcycled && matchesLowStock;
    }).toList();

    if (mounted) {
      setState(() {
        _filteredFabrics = filtered;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _fabricsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _deleteFabricById(String fabricId) async {
    try {
      // Delete fabric using the operations service with logging
      await FabricOperationsService.deleteFabric(
        fabricId: fabricId,
        deletedBy: FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
        remarks: 'Fabric deleted from inventory',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Fabric deleted successfully!'),
          backgroundColor: DesignSystem.successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete fabric: $e'),
          backgroundColor: DesignSystem.errorRed,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignSystem.backgroundGrey,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Modern Search Header
                  ModernSearchHeader(
                    controller: _searchController,
                    hintText: 'Search fabrics...',
                    onRefresh: () => _initializeFabrics(),
                    filterChips: [
                      ModernFilterChip(
                        label: _selectedType,
                        isSelected: _selectedType != 'All',
                        icon: Icons.category,
                        onTap: () => _showTypeFilter(),
                      ),
                      ModernFilterChip(
                        label: 'Upcycled',
                        isSelected: _showUpcycledOnly,
                        icon: Icons.recycling,
                        onTap: () {
                          setState(() {
                            _showUpcycledOnly = !_showUpcycledOnly;
                            _applyFilters();
                          });
                        },
                      ),
                      ModernFilterChip(
                        label: 'Low Stock',
                        isSelected: _showLowStockOnly,
                        icon: Icons.warning,
                        onTap: () {
                          setState(() {
                            _showLowStockOnly = !_showLowStockOnly;
                            _applyFilters();
                          });
                        },
                      ),
                    ],
                  ),
                  
                  // Scrollable Content
                  Expanded(
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // Collapsible Stats Section
                        SliverToBoxAdapter(
                          child: _buildStatsSection(),
                        ),
                        
                        // Fabrics List or Empty State
                        _filteredFabrics.isEmpty
                            ? SliverToBoxAdapter(
                                child: ModernEmptyState(
                                  icon: Icons.checkroom,
                                  title: 'No Fabrics Found',
                                  message: _allFabrics.isEmpty
                                      ? 'Start by adding your first fabric to the inventory'
                                      : 'No fabrics match your current search and filters',
                                  actionText: _allFabrics.isEmpty ? 'Add Fabric' : null,
                                  onAction: _allFabrics.isEmpty ? _showAddFabricModal : null,
                                ),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final fabric = _filteredFabrics[index];
                                    return FadeSlideAnimation(
                                      delay: index * 50,
                                      child: _buildModernFabricCard(fabric),
                                    );
                                  },
                                  childCount: _filteredFabrics.length,
                                ),
                              ),
                        
                        // Bottom Spacing
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 100),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      
      // Modern Floating Action Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFabricModal,
        backgroundColor: DesignSystem.primaryOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Fabric'),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusMD),
        ),
      ),
    );
  }

  void _showTypeFilter() {
    final types = ['All', 'cotton', 'polyester', 'silk', 'wool', 'linen', 'blend', 'other'];
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(DesignSystem.spaceLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Fabric Type',
                style: DesignSystem.titleStyle.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: DesignSystem.spaceMD),
              ...types.map((type) {
                return ListTile(
                  title: Text(type == 'All' ? 'All Types' : type.toUpperCase()),
                  onTap: () {
                    setState(() {
                      _selectedType = type;
                      _applyFilters();
                    });
                    Navigator.pop(context);
                  },
                  trailing: _selectedType == type ? const Icon(Icons.check, color: DesignSystem.primaryOrange) : null,
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  void _showAddFabricModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(DesignSystem.radiusLG),
            topRight: Radius.circular(DesignSystem.radiusLG),
          ),
        ),
        child: const AddFabricModal(),
      ),
    ).then((result) {
      if (result == true) {
        _initializeFabrics();
      }
    });
  }

  Widget _buildStatsSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Column(
        children: [
          ModernCard(
            margin: const EdgeInsets.all(DesignSystem.spaceMD),
            child: InkWell(
              onTap: () {
                setState(() {
                  _isStatsExpanded = !_isStatsExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(DesignSystem.spaceMD),
                child: Row(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      color: DesignSystem.primaryOrange,
                      size: 24,
                    ),
                    const SizedBox(width: DesignSystem.spaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fabric Statistics',
                            style: DesignSystem.titleStyle.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (!_isStatsExpanded) 
                            Text(
                              '${_filteredFabrics.length} fabrics • Tap to expand',
                              style: DesignSystem.captionStyle.copyWith(color: Colors.grey[600]),
                            ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isStatsExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          if (_isStatsExpanded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DesignSystem.spaceMD),
              child: Row(
                children: [
                  Expanded(
                    child: ModernStatCard(
                      icon: Icons.checkroom,
                      value: _totalFabrics.toString(),
                      label: 'Total Fabrics',
                      iconColor: DesignSystem.primaryOrange,
                      isCompact: true,
                    ),
                  ),
                  const SizedBox(width: DesignSystem.spaceMD),
                  Expanded(
                    child: ModernStatCard(
                      icon: Icons.warning,
                      value: _lowStockCount.toString(),
                      label: 'Low Stock',
                      iconColor: DesignSystem.warningAmber,
                      isCompact: true,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DesignSystem.spaceMD),
              child: Row(
                children: [
                  Expanded(
                    child: ModernStatCard(
                      icon: Icons.recycling,
                      value: _upcycledCount.toString(),
                      label: 'Upcycled',
                      iconColor: DesignSystem.successGreen,
                      isCompact: true,
                    ),
                  ),
                  const SizedBox(width: DesignSystem.spaceMD),
                  Expanded(
                    child: ModernStatCard(
                      icon: Icons.straighten,
                      value: '${_totalYardage.toStringAsFixed(1)} yds',
                      label: 'Total Yardage',
                      iconColor: DesignSystem.secondaryTeal,
                      isCompact: true,
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

  Widget _buildModernFabricCard(Map<String, dynamic> fabric) {
    final name = fabric['name'] ?? 'Unknown Fabric';
    final type = fabric['type'] ?? 'Unknown';
    final color = fabric['color'] ?? 'Unknown';
    final quantity = (fabric['quantity'] ?? 0).toDouble();
    final isUpcycled = fabric['isUpcycled'] ?? false;
    final swatchUrl = fabric['swatchImageURL'];
    final isLowStock = quantity < 5;

    return ModernCard(
      margin: const EdgeInsets.symmetric(
        horizontal: DesignSystem.spaceMD,
        vertical: DesignSystem.spaceSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Fabric Swatch
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(DesignSystem.radiusMD),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DesignSystem.radiusMD),
                  child: swatchUrl != null && swatchUrl.isNotEmpty
                      ? Image(
                          image: _getSwatchImageProvider(swatchUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.texture, size: 40, color: Colors.grey[400]);
                          },
                        )
                      : Icon(Icons.texture, size: 40, color: Colors.grey[400]),
                ),
              ),
              const SizedBox(width: DesignSystem.spaceMD),
              
              // Fabric Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: DesignSystem.titleStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUpcycled) ...[
                          const SizedBox(width: DesignSystem.spaceSM),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignSystem.spaceSM,
                              vertical: DesignSystem.spaceXS,
                            ),
                            decoration: BoxDecoration(
                              color: DesignSystem.successGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(DesignSystem.radiusSM),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.recycling,
                                  size: 12,
                                  color: DesignSystem.successGreen,
                                ),
                                const SizedBox(width: DesignSystem.spaceXS),
                                Text(
                                  'Upcycled',
                                  style: DesignSystem.captionStyle.copyWith(
                                    color: DesignSystem.successGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: DesignSystem.spaceXS),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignSystem.spaceSM,
                            vertical: DesignSystem.spaceXS,
                          ),
                          decoration: BoxDecoration(
                            color: DesignSystem.primaryOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(DesignSystem.radiusSM),
                          ),
                          child: Text(
                            type.toUpperCase(),
                            style: DesignSystem.captionStyle.copyWith(
                              color: DesignSystem.primaryOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: DesignSystem.spaceSM),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignSystem.spaceSM,
                            vertical: DesignSystem.spaceXS,
                          ),
                          decoration: BoxDecoration(
                            color: DesignSystem.secondaryTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(DesignSystem.radiusSM),
                          ),
                          child: Text(
                            color.toUpperCase(),
                            style: DesignSystem.captionStyle.copyWith(
                              color: DesignSystem.secondaryTeal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignSystem.spaceXS),
                    Row(
                      children: [
                        Icon(
                          Icons.straighten,
                          size: 16,
                          color: isLowStock ? DesignSystem.warningAmber : Colors.grey[600],
                        ),
                        const SizedBox(width: DesignSystem.spaceXS),
                        Text(
                          '${quantity.toStringAsFixed(1)} yards',
                          style: DesignSystem.captionStyle.copyWith(
                            color: isLowStock ? DesignSystem.warningAmber : Colors.grey[600],
                            fontWeight: isLowStock ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (isLowStock) ...[
                          const SizedBox(width: DesignSystem.spaceXS),
                          Text(
                            '• Low Stock',
                            style: DesignSystem.captionStyle.copyWith(
                              color: DesignSystem.warningAmber,
                              fontWeight: FontWeight.w600,
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
          
          // Action Buttons
          const SizedBox(height: DesignSystem.spaceMD),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => Container(
                        height: MediaQuery.of(context).size.height * 0.9,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(DesignSystem.radiusLG),
                            topRight: Radius.circular(DesignSystem.radiusLG),
                          ),
                        ),
                        child: EditFabricModal(
                          fabric: fabric,
                          fabricId: fabric['fabricId'] ?? '',
                        ),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _initializeFabrics();
                      }
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DesignSystem.primaryOrange,
                    side: BorderSide(color: DesignSystem.primaryOrange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignSystem.radiusSM),
                    ),
                  ),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: DesignSystem.spaceSM),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Fabric'),
                        content: Text('Are you sure you want to delete "$name"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteFabricById(fabric['id']);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DesignSystem.errorRed,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DesignSystem.errorRed,
                    side: BorderSide(color: DesignSystem.errorRed),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignSystem.radiusSM),
                    ),
                  ),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Computed properties for stats
  int get _totalFabrics => _filteredFabrics.length;
  int get _lowStockCount => _filteredFabrics.where((f) => (f['quantity'] ?? 0) < 5).length;
  int get _upcycledCount => _filteredFabrics.where((f) => f['isUpcycled'] == true).length;
  double get _totalYardage => _filteredFabrics.fold(0.0, (sum, f) => sum + ((f['quantity'] ?? 0) as num).toDouble());
}
