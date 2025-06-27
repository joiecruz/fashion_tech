import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_product_modal.dart';
import 'product_detail_page.dart';

class ProductInventoryPage extends StatefulWidget {
  const ProductInventoryPage({Key? key}) : super(key: key);

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

  // Mock data for demo - replace with actual Firestore data
  final List<Map<String, dynamic>> _mockProducts = [
    {
      'productID': '1',
      'name': 'Denim Jacket Classic Fit',
      'description': 'Vintage-style denim jacket with classic fit and sustainable materials',
      'notes': 'Hand-distressed finish, limited edition',
      'category': 'outerwear',
      'price': 75.00,
      'unitCostEstimate': 35.00,
      'isUpcycled': true,
      'isMade': true,
      'stock': 5,
      'lowStock': true,
      'potentialValue': 375.00,
      'imageUrl': '',
      'variants': [
        {'variantID': '1a', 'size': 'M', 'color': 'Blue', 'quantityInStock': 3},
        {'variantID': '1b', 'size': 'L', 'color': 'Blue', 'quantityInStock': 2},
      ],
    },
    {
      'productID': '2',
      'name': 'Silk Scarf Artisan',
      'description': 'Hand-painted silk scarf with unique artisan design',
      'notes': 'Each piece is unique, slight variations expected',
      'category': 'accessories',
      'price': 25.50,
      'unitCostEstimate': 12.00,
      'isUpcycled': false,
      'isMade': true,
      'stock': 8,
      'lowStock': false,
      'potentialValue': 204.00,
      'imageUrl': '',
      'variants': [
        {'variantID': '2a', 'size': 'One Size', 'color': 'Red', 'quantityInStock': 4},
        {'variantID': '2b', 'size': 'One Size', 'color': 'Green', 'quantityInStock': 4},
      ],
    },
    {
      'productID': '3',
      'name': 'Linen Trousers Slim Fit',
      'description': 'Sustainable linen trousers with eco-friendly dyeing process',
      'notes': 'Pre-washed to prevent shrinkage, runs large',
      'category': 'bottom',
      'price': 60.00,
      'unitCostEstimate': 28.00,
      'isUpcycled': true,
      'isMade': false,
      'stock': 2,
      'lowStock': true,
      'potentialValue': 120.00,
      'imageUrl': '',
      'variants': [
        {'variantID': '3a', 'size': 'S', 'color': 'Beige', 'quantityInStock': 1},
        {'variantID': '3b', 'size': 'M', 'color': 'Beige', 'quantityInStock': 1},
      ],
    },
    {
      'productID': '4',
      'name': 'Classic Cotton Tee',
      'description': 'Organic cotton t-shirt with soft finish and durable construction',
      'notes': 'Available in multiple colors, high-quality print',
      'category': 'top',
      'price': 20.00,
      'unitCostEstimate': 8.00,
      'isUpcycled': false,
      'isMade': true,
      'stock': 12,
      'lowStock': false,
      'potentialValue': 240.00,
      'imageUrl': '',
      'variants': [
        {'variantID': '4a', 'size': 'S', 'color': 'White', 'quantityInStock': 4},
        {'variantID': '4b', 'size': 'M', 'color': 'White', 'quantityInStock': 4},
        {'variantID': '4c', 'size': 'L', 'color': 'Black', 'quantityInStock': 4},
      ],
    },
  ];

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch products from Firestore using ERDv7 schema (exclude soft-deleted products)
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('deletedAt', isNull: true) // Exclude soft-deleted products
          .orderBy('updatedAt', descending: true)
          .get();

      List<Map<String, dynamic>> products = [];

      for (var productDoc in productsSnapshot.docs) {
        final productData = productDoc.data();
        
        // Fetch variants for this product to calculate total stock
        final variantsSnapshot = await FirebaseFirestore.instance
            .collection('productvariants')
            .where('productID', isEqualTo: productDoc.id)
            .get();

        int totalStock = 0;
        List<Map<String, dynamic>> variants = [];
        
        for (var variantDoc in variantsSnapshot.docs) {
          final variantData = variantDoc.data();
          totalStock += (variantData['quantityInStock'] ?? 0) as int;
          variants.add({
            'variantID': variantDoc.id,
            'size': variantData['size'] ?? '',
            'color': variantData['color'] ?? '',
            'quantityInStock': variantData['quantityInStock'] ?? 0,
            'unitCostEstimate': variantData['unitCostEstimate'] ?? 0.0,
          });
        }

        // Fetch primary product image
        String imageUrl = '';
        try {
          final imageSnapshot = await FirebaseFirestore.instance
              .collection('productimages')
              .where('productID', isEqualTo: productDoc.id)
              .where('isPrimary', isEqualTo: true)
              .limit(1)
              .get();
          
          if (imageSnapshot.docs.isNotEmpty) {
            imageUrl = imageSnapshot.docs.first.data()['imageURL'] ?? '';
          }
        } catch (e) {
          print('Error fetching product image: $e');
        }

        // Calculate potential value (price * stock)
        double price = (productData['price'] ?? 0.0).toDouble();
        double potentialValue = price * totalStock;
        
        // Consider low stock if total stock is less than 5
        bool lowStock = totalStock < 5;

        products.add({
          'productID': productDoc.id,
          'name': productData['name'] ?? 'Unknown Product',
          'description': productData['description'],
          'notes': productData['notes'],
          'category': productData['category'] ?? 'Uncategorized',
          'price': price,
          'unitCostEstimate': (productData['unitCostEstimate'] ?? 0.0).toDouble(),
          'isUpcycled': productData['isUpcycled'] ?? false,
          'isMade': productData['isMade'] ?? false,
          'stock': totalStock,
          'lowStock': lowStock,
          'potentialValue': potentialValue,
          'imageUrl': imageUrl,
          'variants': variants,
          'createdAt': productData['createdAt'],
          'updatedAt': productData['updatedAt'],
        });
      }

      setState(() {
        _products = products;
        _filteredProducts = products;
        _isLoading = false;
      });
      
      _animationController.forward();
    } catch (e) {
      print('Error loading products: $e');
      // Fallback to mock data if Firestore fails
      setState(() {
        _products = _mockProducts;
        _filteredProducts = _mockProducts;
        _isLoading = false;
      });
      _animationController.forward();
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
        
        return matchesSearch && matchesCategory && matchesUpcycled && matchesLowStock;
      }).toList();
    });
  }

  int get _totalProducts => _products.length;
  int get _lowStockCount => _products.where((p) => p['lowStock']).length;
  double get _totalPotentialValue => _products.fold(0.0, (sum, p) => sum + p['potentialValue']);

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
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
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
                            _buildFilterChip('Category', _selectedCategory, ['All', 'top', 'bottom', 'outerwear', 'accessories']),
                            const SizedBox(width: 12),
                            _buildToggleChip('Upcycled', _showUpcycledOnly, (value) {
                              setState(() {
                                _showUpcycledOnly = value;
                                _filterProducts();
                              });
                            }),
                            const SizedBox(width: 12),
                            _buildToggleChip('Low Stock', _showLowStockOnly, (value) {
                              setState(() {
                                _showLowStockOnly = value;
                                _filterProducts();
                              });
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Scrollable Content
                  Expanded(
                    child: CustomScrollView(
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
                                              Text(
                                                '${_totalProducts} products • ${_lowStockCount} low stock',
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
                                // Animated Stats Content
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  constraints: BoxConstraints(
                                    maxHeight: _isStatsExpanded ? 200 : 0,
                                  ),
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 200),
                                    opacity: _isStatsExpanded ? 1.0 : 0.0,
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                                      child: Row(
                                        children: [
                                          Expanded(child: _buildStatCard(
                                            icon: Icons.inventory_2_outlined,
                                            iconColor: Colors.blue[600]!,
                                            title: 'Total\nProducts',
                                            value: _totalProducts.toString(),
                                          )),
                                          const SizedBox(width: 16),
                                          Expanded(child: _buildStatCard(
                                            icon: Icons.warning_outlined,
                                            iconColor: Colors.red[600]!,
                                            title: 'Low Stock\n(<5)',
                                            value: _lowStockCount.toString(),
                                          )),
                                          const SizedBox(width: 16),
                                          Expanded(child: _buildStatCard(
                                            icon: Icons.attach_money,
                                            iconColor: Colors.green[600]!,
                                            title: 'Potential\nValue',
                                            value: '₱${_totalPotentialValue.toStringAsFixed(2)}',
                                            isLarge: true,
                                          )),
                                        ],
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
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.blue[600]!, Colors.blue[700]!],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue[600]!.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
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
                                              margin: const EdgeInsets.only(top: 100), // Adjusted to appear below search and filters
                                              height: MediaQuery.of(context).size.height - 100, // Full height minus margin
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                              ),
                                              child: const AddProductModal(),
                                            ),
                                          );
                                          
                                          if (result == true) {
                                            // Refresh the product list if a product was added
                                            _loadProducts();
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_circle_outline,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Add New Product',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
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
                        ),
                        
                        // Product List
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), // Added bottom padding
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
                ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isLarge ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
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
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProductDetailPage(productData: product),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Product Image Placeholder
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: product['imageUrl'].isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    product['imageUrl'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.image,
                                        color: Colors.grey[400],
                                        size: 30,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.image,
                                  color: Colors.grey[400],
                                  size: 30,
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
                                  // Status labels section in upper right corner
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
                              // Show description or notes if available
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
                            if (product['unitCostEstimate'] != null && product['unitCostEstimate'] > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Cost: ₱${product['unitCostEstimate'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
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
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Implement sell functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Sell ${product['name']} feature coming soon!')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailPage(productData: product),
                                ),
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
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // TODO: Implement job orders functionality
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
        )
        );
      },
    );
  }
}
