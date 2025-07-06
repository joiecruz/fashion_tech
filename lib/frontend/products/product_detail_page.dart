import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product_variant.dart';
import '../../backend/fetch_variants.dart';
import 'edit_product_modal.dart';
import 'dart:convert';

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> productData;

  const ProductDetailPage({
    Key? key,
    required this.productData,
  }) : super(key: key);

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ProductVariant> _variants = [];
  bool _isLoading = true;
  late Map<String, dynamic> _productData;

  @override
  void initState() {
    super.initState();
    _productData = Map<String, dynamic>.from(widget.productData);
    _tabController = TabController(length: 3, vsync: this);
    _loadProductData();
    _loadVariants();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openEditProductModal() async {
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
        child: EditProductModal(
          productData: _productData,
        ),
      ),
    );
    if (result == true) {
      await _loadProductData();
      await _loadVariants();
      setState(() {});
    }
  }

  Future<void> _loadProductData() async {
    final productId = _productData['productID'];
    if (productId == null) return;
    final doc = await FirebaseFirestore.instance.collection('products').doc(productId).get();
    if (doc.exists) {
      setState(() {
        _productData = {
          ..._productData,
          ...doc.data()!,
        };
      });
    }
  }

  Future<void> _loadVariants() async {
    setState(() => _isLoading = true);
    try {
      final variantMaps = await FetchVariantsBackend.fetchVariantsByProductID(_productData['productID']);
      setState(() {
        _variants = variantMaps
            .map((v) => ProductVariant(
                  id: v['variantID'],
                  productID: _productData['productID'],
                  size: v['size'],
                  colorID: v['color'] ?? '', // ERDv9: FetchVariantsBackend returns color field (but reads from colorID)
                  quantityInStock: v['quantityInStock'],
                ))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading variants: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatUpdatedAt(dynamic updatedAt) {
    if (updatedAt == null) return 'Never';
    DateTime date;
    if (updatedAt is Timestamp) {
      date = updatedAt.toDate();
    } else if (updatedAt is DateTime) {
      date = updatedAt;
    } else if (updatedAt is String) {
      date = DateTime.tryParse(updatedAt) ?? DateTime.now();
    } else {
      return 'Unknown';
    }
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Icon(Icons.image, size: 40, color: Colors.grey[400]);
    }
    if (imageUrl.startsWith('data:image')) {
      // Base64 image
      final base64Data = imageUrl.split(',').last;
      try {
        return Image.memory(
          base64Decode(base64Data),
          fit: BoxFit.cover,
          width: 80,
          height: 80,
        );
      } catch (e) {
        return Icon(Icons.broken_image, size: 40, color: Colors.red[300]);
      }
    } else if (Uri.tryParse(imageUrl)?.isAbsolute == true) {
      // Network image
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: 80,
        height: 80,
      );
    } else {
      return Icon(Icons.image_not_supported, size: 40, color: Colors.grey[400]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _productData['name'] ?? '',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black87),
            onPressed: _openEditProductModal,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[600],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blue[600],
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Variants'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildVariantsTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Product Info Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildProductImage(_productData['imageURL']),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _productData['name'] ?? '',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _productData['category'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₱${(_productData['price'] ?? 0).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Properties
                Row(
                  children: [
                    if (_productData['isUpcycled'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.recycling, size: 16, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(
                              'Upcycled',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _productData['lowStock'] == true ? Colors.red[100] : Colors.blue[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_productData['stock'] ?? 0} in stock',
                        style: TextStyle(
                          fontSize: 12,
                          color: _productData['lowStock'] == true ? Colors.red[700] : Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.update, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Last updated: ${_formatUpdatedAt(_productData['updatedAt'])}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Stats Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Total Stock',
                        (_productData['stock'] ?? 0).toString(),
                        Icons.inventory_2_outlined,
                        Colors.blue[600]!,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Price',
                        '₱${(_productData['price'] ?? 0).toStringAsFixed(2)}',
                        Icons.attach_money_outlined,
                        Colors.green[600]!,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Variants',
                        _variants.length.toString(),
                        Icons.tune_outlined,
                        Colors.purple[600]!,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Total Stock',
                        (_productData['stock'] ?? 0).toString(),
                        Icons.inventory_outlined,
                        Colors.blue[600]!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVariantsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_variants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No variants found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add variants to manage different sizes, colors, and stock levels',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _variants.length,
      itemBuilder: (context, index) {
        final variant = _variants[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Text(
                variant.size,
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              '${variant.size} - ${variant.colorID}', // ERDv9: Changed from color to colorID
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${variant.quantityInStock} units in stock',
              style: TextStyle(color: Colors.grey[600]),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: variant.quantityInStock < 5 ? Colors.red[100] : Colors.green[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                variant.quantityInStock < 5 ? 'Low Stock' : 'In Stock',
                style: TextStyle(
                  fontSize: 12,
                  color: variant.quantityInStock < 5 ? Colors.red[700] : Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'History tracking coming soon',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track product changes, stock movements, and sales history',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}