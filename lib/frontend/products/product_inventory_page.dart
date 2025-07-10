import 'package:flutter/material.dart';
import 'add_product_modal.dart';
import 'product_detail_page.dart';
import 'edit_product_modal.dart';
import 'package:fashion_tech/backend/fetch_products.dart';
import 'package:fashion_tech/frontend/profit/sell_modal.dart';
import 'package:fashion_tech/services/category_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../common/gradient_search_bar.dart';

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
  bool _isRefreshing = false;
  String _selectedCategory = 'All';
  bool _showUpcycledOnly = false;
  bool _showLowStockOnly = false;
  bool _hideOutOfStock = false;
  bool _isStatsExpanded = true;

  // Dynamic category system
  Map<String, String> _categoryDisplayNames = {};
  List<String> _availableCategories = [];

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

    _loadCategories();
    _loadProducts();
    _searchController.addListener(_filterProducts);
    // Remove this line, as _products is empty at init:
    // ProductInventoryPage.setPotentialValue(_products.fold(0.0, (sum, p) => sum + p['potentialValue']));
  }

  Future<void> _loadCategories() async {
    try {
      // Initialize categories if needed
      final isInitialized = await CategoryService.areDefaultCategoriesInitialized();
      if (!isInitialized) {
        await CategoryService.initializeDefaultCategories();
      }

      // Get categories from service
      final categories = await CategoryService.getAllProductCategories();
      
      if (mounted) {
        setState(() {
          _categoryDisplayNames = {
            for (var category in categories)
              category['name']: category['displayName'] ?? category['name']
          };
          _availableCategories = ['All', ...categories.map<String>((cat) => cat['name'])];
        });
      }
    } catch (e) {
      // Use fallback categories
      if (mounted) {
        setState(() {
          _categoryDisplayNames = {
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
          _availableCategories = ['All', ..._categoryDisplayNames.keys];
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _isRefreshing = true;
      });
    } else {
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
        if (isRefresh) {
          _isRefreshing = false;
        } else {
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
      setState(() {
        if (isRefresh) {
          _isRefreshing = false;
        } else {
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
        // Use categoryID for filtering (the backend fetch already maps categoryID to 'category' field)
        String productCategoryID = product['category'] ?? 'uncategorized'; 
        bool matchesCategory = _selectedCategory == 'All' || productCategoryID == _selectedCategory;
        bool matchesUpcycled = !_showUpcycledOnly || product['isUpcycled'];
        bool matchesLowStock = !_showLowStockOnly || product['lowStock'];
        
        // Optional filter to hide out-of-stock products
        bool hasStock = !_hideOutOfStock || (product['stock'] ?? 0) > 0;

        return matchesSearch && matchesCategory && matchesUpcycled && matchesLowStock && hasStock;
      }).toList();
    });
  }

  int get _totalProducts => _products.length;
  int get _lowStockCount => _products.where((p) => p['lowStock']).length;
  int get _outOfStockCount => _products.where((p) => (p['stock'] ?? 0) == 0).length;
  double get _totalPotentialValue => _products.fold(0.0, (sum, p) => sum + (p['price'] ?? 0) * (p['stock'] ?? 0));

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '₱${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '₱${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return '₱${value.toStringAsFixed(0)}';
    }
  }

  String _getCategoryDisplayName(String? categoryID) {
    if (categoryID == null || categoryID.isEmpty) return 'Uncategorized';
    return _categoryDisplayNames[categoryID] ?? categoryID.toUpperCase();
  }

  Widget _buildCategoryDropdown() {
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
              _selectedCategory == 'All' ? 'All Categories' : _getCategoryDisplayName(_selectedCategory),
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
        return _availableCategories.map((String option) {
          final displayName = option == 'All' ? 'All Categories' : _getCategoryDisplayName(option);
          return PopupMenuItem<String>(
            value: option,
            child: Row(
              children: [
                Icon(
                  option == 'All' ? Icons.grid_view_rounded : Icons.category_rounded,
                  size: 14,
                  color: Colors.blue[600],
                ),
                const SizedBox(width: 6),
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: option == _selectedCategory ? FontWeight.w600 : FontWeight.w400,
                    color: option == _selectedCategory ? Colors.blue[700] : Colors.grey[800],
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
                      hintText: 'Search products...',
                      primaryColor: Colors.blue,
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
                        child: AnimatedOpacity(
                          opacity: _isRefreshing ? 0.7 : 1.0,
                          duration: const Duration(milliseconds: 300),
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
                              _buildCategoryDropdown(),
                              const SizedBox(width: 12),
                              GradientFilterChip(
                                label: 'Upcycled',
                                isSelected: _showUpcycledOnly,
                                onTap: () {
                                  setState(() {
                                    _showUpcycledOnly = !_showUpcycledOnly;
                                    _filterProducts();
                                  });
                                },
                                primaryColor: Colors.blue,
                                icon: Icons.eco_rounded,
                              ),
                              const SizedBox(width: 12),
                              GradientFilterChip(
                                label: 'Low Stock',
                                isSelected: _showLowStockOnly,
                                onTap: () {
                                  setState(() {
                                    _showLowStockOnly = !_showLowStockOnly;
                                    _filterProducts();
                                  });
                                },
                                primaryColor: Colors.blue,
                                icon: Icons.warning_rounded,
                              ),
                              const SizedBox(width: 12),
                              GradientFilterChip(
                                label: 'Hide Out of Stock',
                                isSelected: _hideOutOfStock,
                                onTap: () {
                                  setState(() {
                                    _hideOutOfStock = !_hideOutOfStock;
                                    _filterProducts();
                                  });
                                },
                                primaryColor: Colors.blue,
                                icon: Icons.visibility_off_rounded,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Scrollable Content with Pull-to-Refresh
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _loadProducts(isRefresh: true),
                      color: Colors.blue[600],
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
                                                    '${_totalProducts} products • ${_lowStockCount} low stock • ${_outOfStockCount} out of stock',
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
                                                  icon: Icons.inventory_2_outlined,
                                                  iconColor: Colors.blue[600]!,
                                                  title: 'Total Products',
                                                  value: _totalProducts.toString(),
                                                ),
                                                const SizedBox(width: 8),
                                                _buildCompactStatCard(
                                                  icon: Icons.warning_outlined,
                                                  iconColor: Colors.red[600]!,
                                                  title: 'Low Stock',
                                                  value: _lowStockCount.toString(),
                                                ),
                                                const SizedBox(width: 8),
                                                _buildCompactStatCard(
                                                  icon: Icons.remove_circle_outline,
                                                  iconColor: Colors.grey[600]!,
                                                  title: 'Out of Stock',
                                                  value: _outOfStockCount.toString(),
                                                ),
                                                const SizedBox(width: 8),
                                                _buildCompactStatCard(
                                                  icon: Icons.attach_money,
                                                  iconColor: Colors.green[600]!,
                                                  title: 'Potential Value',
                                                  value: _formatCurrency(_totalPotentialValue),
                                                  isWide: true,
                                                ),
                                              ],
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
                          // Add New Item Button
                          SliverToBoxAdapter(
                            child: Container(
                              color: Colors.white,
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                              child: Container(
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.blue[600]!, Colors.blue[700]!],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue[600]!.withOpacity(0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
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
                                          child: const AddProductModal(),
                                        ),
                                      );

                                      if (result == true) {
                                        _selectedCategory = 'All';
                                        _showUpcycledOnly = false;
                                        _showLowStockOnly = false;
                                        _hideOutOfStock = false;
                                        _searchController.clear();
                                        await _loadProducts(isRefresh: true);
                                      }
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
                                          'Add New Product',
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
                          // Product List
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final product = _filteredProducts[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildProductCard(product, index),
                                  );
                                },
                                childCount: _filteredProducts.length,
                              ),
                            ),
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

  Widget _buildProductCard(Map<String, dynamic> product, int index) {
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
                                            _getCategoryDisplayName(product['category']),
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
                                        if ((product['stock'] ?? 0) == 0) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.grey[300]!),
                                            ),
                                            child: Text(
                                              'Out of Stock',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey[700],
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
                                _hideOutOfStock = false;
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