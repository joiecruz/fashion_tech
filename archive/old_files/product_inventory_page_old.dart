import 'package:flutter/material.dart';
import 'add_product_modal.dart';
import 'product_detail_page.dart';
import 'edit_product_modal.dart';
import 'package:fashion_tech/backend/fetch_products.dart';
import 'package:fashion_tech/frontend/profit/sell_modal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../design_system.dart';
import 'dart:convert';

class ProductInventoryPage extends StatefulWidget {
  const ProductInventoryPage({Key? key}) : super(key: key);

  static double latestPotentialValue = 0.0;
  static ValueNotifier<double> potentialValueNotifier = ValueNotifier(0.0);

  static void setPotentialValue(double value) {
    potentialValueNotifier.value = value;
  }

  @override
  State<ProductInventoryPage> createState() => _ProductInventoryPageState();
}

class _ProductInventoryPageState extends State<ProductInventoryPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  bool _showUpcycledOnly = false;
  bool _showLowStockOnly = false;
  bool _isStatsExpanded = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Widget _buildProductImage(String? imageUrl, {double size = 60}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Icon(Icons.image, size: size * 0.5, color: Colors.grey[400]);
    }
    if (imageUrl.startsWith('data:image')) {
      final base64Data = imageUrl.split(',').last;
      try {
        return Image.memory(
          base64Decode(base64Data),
          fit: BoxFit.cover,
          width: size,
          height: size,
        );
      } catch (e) {
        return Icon(Icons.broken_image, size: size * 0.5, color: Colors.red[300]);
      }
    } else if (Uri.tryParse(imageUrl)?.isAbsolute == true) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.image, color: Colors.grey[400], size: size * 0.5);
        },
      );
    } else {
      return Icon(Icons.image_not_supported, size: size * 0.5, color: Colors.grey[400]);
    }
  }

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

    _loadProducts();
    _searchController.addListener(_filterProducts);
    // Remove this line, as _products is empty at init:
    // ProductInventoryPage.setPotentialValue(_products.fold(0.0, (sum, p) => sum + p['potentialValue']));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final products = await FetchProductsBackend.fetchProducts();

      // Sort by updatedAt descending (most recent first)
      products.sort((a, b) {
        final aTime = a['updatedAt'];
        final bTime = b['updatedAt'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        final aDate = aTime is DateTime
            ? aTime
            : (aTime is Timestamp
                ? aTime.toDate()
                : DateTime.tryParse(aTime.toString()) ?? DateTime(1970));
        final bDate = bTime is DateTime
            ? bTime
            : (bTime is Timestamp
                ? bTime.toDate()
                : DateTime.tryParse(bTime.toString()) ?? DateTime(1970));
        return bDate.compareTo(aDate);
      });

      setState(() {
        _products = products;
        _filteredProducts = products;
        if (!isRefresh) {
          _isLoading = false;
        }
      });

      // Update the static potential value for dashboard
      double totalPotentialValue = 0.0;
      for (final product in products) {
        // If you have a 'potentialValue' field, use it. Otherwise, calculate price * stock.
        totalPotentialValue += (product['price'] ?? 0) * (product['stock'] ?? 0);
      }
      ProductInventoryPage.setPotentialValue(totalPotentialValue);

      _animationController.forward();

      // Apply current filters after loading
      _filterProducts();

      // Show success feedback only for pull-to-refresh
      if (isRefresh && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('${products.length} products refreshed'),
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
      print('Error loading products: $e');
      setState(() {
        if (!isRefresh) {
          _isLoading = false;
        }
      });
      _animationController.forward();

      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(isRefresh ? 'Failed to refresh products' : 'Failed to load products'),
              ],
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _loadProducts(isRefresh: isRefresh),
            ),
          ),
        );
      }
    }
  }

  void _filterProducts() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((product) {
        bool matchesSearch = product['name'].toLowerCase().contains(query);
        bool matchesCategory = _selectedCategory == 'All' || product['category'] == _selectedCategory;
        bool matchesUpcycled = !_showUpcycledOnly || product['isUpcycled'];
        bool matchesLowStock = !_showLowStockOnly || product['lowStock'];

        // Exclude products with no stock
        final int stock = product['stock'] ?? 0;
        bool hasStock = stock > 0;

        return matchesSearch && matchesCategory && matchesUpcycled && matchesLowStock && hasStock;
      }).toList();
    });
  }

  // Modern helper methods
  
  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(DesignSystem.spaceLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Category',
                style: DesignSystem.titleStyle.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: DesignSystem.spaceMD),
              ...['All', 'top', 'bottom', 'outerwear', 'accessories'].map((category) {
                return ListTile(
                  title: Text(category == 'All' ? 'All Categories' : category.toUpperCase()),
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                      _filterProducts();
                    });
                    Navigator.pop(context);
                  },
                  trailing: _selectedCategory == category ? const Icon(Icons.check, color: DesignSystem.primaryOrange) : null,
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  void _showAddProductModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(DesignSystem.radiusLG),
            topRight: Radius.circular(DesignSystem.radiusLG),
          ),
        ),
        child: const AddProductModal(),
      ),
    ).then((result) {
      if (result == true) {
        _loadProducts();
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
                            'Inventory Statistics',
                            style: DesignSystem.titleStyle.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (!_isStatsExpanded) 
                            Text(
                              '${_filteredProducts.length} products • Tap to expand',
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
                      icon: Icons.inventory,
                      value: _totalProducts.toString(),
                      label: 'Total Products',
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
                      icon: Icons.attach_money,
                      value: '₱${_totalValue.toStringAsFixed(0)}',
                      label: 'Total Value',
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

  Widget _buildModernProductCard(Map<String, dynamic> product) {
    final name = product['name'] ?? 'Unknown Product';
    final price = (product['price'] ?? 0).toDouble();
    final category = product['categoryID'] ?? product['category'] ?? 'Unknown';
    final isUpcycled = product['isUpcycled'] ?? false;
    final imageUrl = product['imageURL'];
    final variants = product['variants'] as List<dynamic>? ?? [];
    final totalStock = variants.fold<int>(0, (sum, variant) => sum + (variant['quantityInStock'] ?? 0) as int);
    final isLowStock = totalStock < 5;

    return ModernCard(
      margin: const EdgeInsets.symmetric(
        horizontal: DesignSystem.spaceMD,
        vertical: DesignSystem.spaceSM,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(productData: product),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Product Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(DesignSystem.radiusMD),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DesignSystem.radiusMD),
                  child: _buildProductImage(imageUrl, size: 80),
                ),
              ),
              const SizedBox(width: DesignSystem.spaceMD),
              
              // Product Info
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
                            category.toUpperCase(),
                            style: DesignSystem.captionStyle.copyWith(
                              color: DesignSystem.primaryOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: DesignSystem.spaceSM),
                        Text(
                          '₱${price.toStringAsFixed(2)}',
                          style: DesignSystem.bodyStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: DesignSystem.secondaryTeal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignSystem.spaceXS),
                    Row(
                      children: [
                        Icon(
                          Icons.inventory,
                          size: 16,
                          color: isLowStock ? DesignSystem.warningAmber : Colors.grey[600],
                        ),
                        const SizedBox(width: DesignSystem.spaceXS),
                        Text(
                          '$totalStock in stock',
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
                        height: MediaQuery.of(context).size.height * 0.95,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(DesignSystem.radiusLG),
                            topRight: Radius.circular(DesignSystem.radiusLG),
                          ),
                        ),
                        child: SellModal(product: product, variants: variants.cast<Map<String, dynamic>>()),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DesignSystem.primaryOrange,
                    side: BorderSide(color: DesignSystem.primaryOrange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignSystem.radiusSM),
                    ),
                  ),
                  icon: const Icon(Icons.point_of_sale, size: 16),
                  label: const Text('Sell', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: DesignSystem.spaceSM),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => Container(
                        height: MediaQuery.of(context).size.height * 0.95,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(DesignSystem.radiusLG),
                            topRight: Radius.circular(DesignSystem.radiusLG),
                          ),
                        ),
                        child: EditProductModal(productData: product),
                      ),
                    ).then((result) {
                      if (result == true) {
                        _loadProducts();
                      }
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignSystem.radiusSM),
                    ),
                  ),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Computed properties for stats
  int get _totalProducts => _filteredProducts.length;
  int get _lowStockCount => _filteredProducts.where((p) {
    final variants = p['variants'] as List<dynamic>? ?? [];
    final totalStock = variants.fold<int>(0, (sum, variant) => sum + (variant['quantityInStock'] ?? 0) as int);
    return totalStock < 5;
  }).length;
  int get _upcycledCount => _filteredProducts.where((p) => p['isUpcycled'] == true).length;
  double get _totalValue => _filteredProducts.fold(0.0, (sum, p) {
    final variants = p['variants'] as List<dynamic>? ?? [];
    final totalStock = variants.fold<int>(0, (sum, variant) => sum + (variant['quantityInStock'] ?? 0) as int);
    return sum + ((p['price'] ?? 0) * totalStock);
  });

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '₱${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '₱${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return '₱${value.toStringAsFixed(0)}';
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
                    hintText: 'Search products...',
                    onRefresh: () => _loadProducts(isRefresh: true),
                    filterChips: [
                      ModernFilterChip(
                        label: _selectedCategory,
                        isSelected: _selectedCategory != 'All',
                        icon: Icons.category,
                        onTap: () => _showCategoryFilter(),
                      ),
                      ModernFilterChip(
                        label: 'Upcycled',
                        isSelected: _showUpcycledOnly,
                        icon: Icons.recycling,
                        onTap: () {
                          setState(() {
                            _showUpcycledOnly = !_showUpcycledOnly;
                            _filterProducts();
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
                            _filterProducts();
                          });
                        },
                      ),
                    ],
                  ),
                  
                  // Scrollable Content with Pull-to-Refresh
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _loadProducts(isRefresh: true),
                      color: DesignSystem.primaryOrange,
                      backgroundColor: Colors.white,
                      strokeWidth: 3.0,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // Collapsible Stats Section
                          SliverToBoxAdapter(
                            child: _buildStatsSection(),
                          ),
                          
                          // Products List or Empty State
                          _filteredProducts.isEmpty
                              ? SliverToBoxAdapter(
                                  child: ModernEmptyState(
                                    icon: Icons.shopping_bag,
                                    title: 'No Products Found',
                                    message: _products.isEmpty
                                        ? 'Start by adding your first product to the inventory'
                                        : 'No products match your current search and filters',
                                    actionText: _products.isEmpty ? 'Add Product' : null,
                                    onAction: _products.isEmpty ? _showAddProductModal : null,
                                  ),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final product = _filteredProducts[index];
                                      return FadeSlideAnimation(
                                        delay: index * 50,
                                        child: _buildModernProductCard(product),
                                      );
                                    },
                                    childCount: _filteredProducts.length,
                                  ),
                                ),
                          
                          // Bottom Spacing
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 100),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      
      // Modern Floating Action Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProductModal,
        backgroundColor: DesignSystem.primaryOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusMD),
        ),
      ),
    );
  }

Widget _buildStatCard({
  required IconData icon,
  required Color iconColor,
  required String title,
  required String value,
  bool isLarge = false,
}) {
  // Choose a gradient based on the iconColor
  Gradient cardGradient = LinearGradient(
    colors: [
      iconColor.withOpacity(0.18),
      iconColor.withOpacity(0.07),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  final Color iconBg = iconColor.withOpacity(0.15);

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: cardGradient,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: iconColor.withOpacity(0.18)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: iconColor,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isLarge ? 16 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildFilterChip(String label, String value, List<String> options) {
    return PopupMenuButton<String>(
      onSelected: (String newValue) {
        setState(() {
          _selectedCategory = newValue;
          _filterProducts();
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
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.category_rounded,
                size: 12,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              value == 'All' ? value : value.toUpperCase(),
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
        return options.map((String option) {
          String displayOption = option == 'All' ? option : option.toUpperCase();
          return PopupMenuItem<String>(
            value: option,
            child: Row(
              children: [
                Icon(
                  option == 'All' ? Icons.grid_view_rounded : Icons.label_rounded,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  displayOption,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: option == value ? FontWeight.w600 : FontWeight.w400,
                    color: option == value ? Colors.blue[700] : Colors.grey[800],
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  Widget _buildToggleChip(String label, bool isSelected, Function(bool) onToggle) {
    return GestureDetector(
      onTap: () => onToggle(!isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.white, Colors.grey[50]!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.blue[600]!.withOpacity(0.25)
                  : Colors.black.withOpacity(0.06),
              blurRadius: isSelected ? 6 : 4,
              offset: Offset(0, isSelected ? 2 : 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : (label == 'Upcycled' ? Colors.green[100] : Colors.orange[100]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : (label == 'Upcycled' ? Icons.eco_rounded : Icons.warning_amber_rounded),
                size: 12,
                color: isSelected
                    ? Colors.white
                    : (label == 'Upcycled' ? Colors.green[700] : Colors.orange[700]),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, int index) {
    print('Product imageURL: ${product['imageURL']} | imageUrl: ${product['imageUrl']}');

    final bool canSell = product['variants'] != null &&
        (product['variants'] as List)
            .whereType<Map<String, dynamic>>()
            .any((v) => (v['quantityInStock'] ?? 0) > 0);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
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
              ),
              child: InkWell(
                onTap: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProductDetailPage(productData: product),
                    ),
                  );
                  if (result == true) {
                    await _loadProducts(isRefresh: true);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Product Image
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _buildProductImage(
                              product['imageURL'],
                              size: 60,
                            ),
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
                                            product['name'],
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            '${product['category'].toString().toUpperCase()}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Status labels
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (product['isUpcycled'])
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
                                            if (product['isMade'] == true)
                                              Container(
                                                margin: EdgeInsets.only(left: product['isUpcycled'] ? 4 : 0),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[100],
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'Made',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.blue[700],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (product['lowStock']) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.red[50],
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.red[200]!),
                                            ),
                                            child: Text(
                                              'Low Stock',
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
                                  ],
                                ),
                                // Description or notes
                                if (product['description'] != null && product['description'].toString().trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    product['description'].toString().length > 60 
                                        ? '${product['description'].toString().substring(0, 60)}...'
                                        : product['description'].toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ] else if (product['notes'] != null && product['notes'].toString().trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    product['notes'].toString().length > 60 
                                        ? '${product['notes'].toString().substring(0, 60)}...'
                                        : product['notes'].toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontStyle: FontStyle.italic,
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₱${product['price'].toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Total Value: ₱${(product['price'] * product['stock']).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Text(
                              'Stock: ${product['stock']}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
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
                      const SizedBox(height: 12),
                      if (product['variants'] != null && product['variants'].isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Variants (${product['variants'].length}):',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: product['variants'].take(3).map<Widget>((variant) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Text(
                                    '${variant['size']} - ${variant['color']} (${variant['quantityInStock']})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            if (product['variants'].length > 3)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '+${product['variants'].length - 3} more variants',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        )
                      else
                        Text(
                          'No variants available',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Container(
                        height: 1,
                        width: double.infinity,
                        color: Colors.grey[200],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: AbsorbPointer(
                              absorbing: !canSell,
                              child: ElevatedButton.icon(
                                onPressed: canSell
                                    ? () async {
                                        final result = await showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (context) => SellModal(product: product, variants: product['variants']),
                                        );
                                        if (result != null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Sold ${result['quantity']} item(s)!'), backgroundColor: Colors.green),
                                          );
                                          await _loadProducts(isRefresh: true);
                                        }
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canSell ? Colors.blue[600] : Colors.grey[400],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.attach_money, size: 16),
                                label: const Text('Sell', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                            onPressed: () async {
                              final result = await showModalBottomSheet<bool>(
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
                                  child: EditProductModal(productData: product),
                                ),
                              );
                              if (result == true) {
                                _selectedCategory = 'All';
                                _showUpcycledOnly = false;
                                _showLowStockOnly = false;
                                _searchController.clear();
                                await _loadProducts(isRefresh: true);
                              }
                            },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Job Orders for ${product['name']} feature coming soon!')),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                              icon: const Icon(Icons.work, size: 16),
                              label: const Text('Job Orders', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}