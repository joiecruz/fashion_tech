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
  bool _isLoading = false; // Start with false since we have initial data
  late Map<String, dynamic> _productData;
  String? _createdByName; // Store the user's display name

  @override
  void initState() {
    super.initState();
    print('=== INIT: ProductDetailPage initState called ===');
    print('=== INIT: Widget productData received: ${widget.productData}');
    
    _productData = Map<String, dynamic>.from(widget.productData);
    _tabController = TabController(length: 3, vsync: this);
    
    print('=== INIT: _productData after copy: $_productData');
    print('=== INIT: _productData.isEmpty: ${_productData.isEmpty}');
    print('=== INIT: _productData keys: ${_productData.keys.toList()}');
    
    // Only load additional data from Firestore, but use provided data as base
    _loadProductData();
    _loadVariants();
    _loadCreatedByName();
    
    print('=== INIT: initState completed ===');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openEditProductModal() async {
    // Prepare productData with variants for the edit modal
    final productDataWithVariants = {
      ..._productData,
      'variants': _variants.map((v) => {
        'size': v.size,
        'colorID': v.colorID,
        'color': v.colorID, // For compatibility
        'quantityInStock': v.quantityInStock,
      }).toList(),
    };

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
          productData: productDataWithVariants,
        ),
      ),
    );
    if (result == true) {
      await _loadProductData();
      await _loadVariants();
      await _loadCreatedByName();
      setState(() {});
    }
  }

  Future<void> _loadProductData() async {
    final productId = _productData['productID'] ?? _productData['id'];
    print('Loading product data for ID: $productId');
    
    if (productId == null) {
      print('No product ID found in data: $_productData');
      return;
    }
    
    try {
      final doc = await FirebaseFirestore.instance.collection('products').doc(productId).get();
      print('Firestore document exists: ${doc.exists}');
      
      if (doc.exists) {
        final firestoreData = doc.data()!;
        print('Firestore data: $firestoreData');
        
        setState(() {
          // Merge Firestore data with existing data, keeping existing as fallback
          _productData = {
            ..._productData, // Keep existing data as base
            ...firestoreData, // Override with fresh Firestore data
            'productID': productId, // Ensure we always have productID
          };
        });
        print('Updated product data: $_productData');
      } else {
        print('Document does not exist for productID: $productId');
        // Keep using the initial product data if Firestore document doesn't exist
      }
    } catch (e) {
      print('Error loading product data: $e');
      // Keep using the initial product data if there's an error
    }
  }

  Future<void> _loadCreatedByName() async {
    final createdBy = _productData['createdBy'];
    if (createdBy == null || createdBy.isEmpty) {
      setState(() {
        _createdByName = 'Unknown';
      });
      return;
    }
    
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(createdBy).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        setState(() {
          // Try different possible name fields
          _createdByName = userData['displayName'] ?? 
                          userData['name'] ?? 
                          userData['firstName'] != null && userData['lastName'] != null 
                              ? '${userData['firstName']} ${userData['lastName']}'
                              : userData['email']?.split('@').first ?? 
                                'Unknown User';
        });
      } else {
        setState(() {
          _createdByName = 'Unknown User';
        });
      }
    } catch (e) {
      print('Error loading user name: $e');
      setState(() {
        _createdByName = 'Unknown';
      });
    }
  }

  Future<void> _loadVariants() async {
    setState(() => _isLoading = true);
    try {
      final productId = _productData['productID'] ?? _productData['id'];
      if (productId == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final variantMaps = await FetchVariantsBackend.fetchVariantsByProductID(productId);
      setState(() {
        _variants = variantMaps
            .map((v) => ProductVariant(
                  id: v['variantID'],
                  productID: productId,
                  size: v['size'],
                  colorID: v['color'] ?? '', // FetchVariantsBackend returns color field
                  quantityInStock: v['quantityInStock'],
                ))
            .toList();
        
        // Update total stock in product data
        final totalStock = _variants.fold(0, (sum, variant) => sum + variant.quantityInStock);
        _productData['stock'] = totalStock;
        _productData['lowStock'] = totalStock < 10; // Consider low stock if less than 10 total
        
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

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${_productData['name']}"?'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone. All variants will also be deleted.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final productId = _productData['productID'] ?? _productData['id'];
        if (productId == null) return;

        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Deleting product...'),
              ],
            ),
          ),
        );

        // Delete all variants first
        final variantsSnapshot = await FirebaseFirestore.instance
            .collection('productVariants')
            .where('productID', isEqualTo: productId)
            .get();

        final batch = FirebaseFirestore.instance.batch();
        
        // Add variant deletions to batch
        for (final doc in variantsSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // Add product deletion to batch
        batch.delete(FirebaseFirestore.instance.collection('products').doc(productId));

        // Execute batch delete
        await batch.commit();

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        // Show success and navigate back
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate deletion
        }
      } catch (e) {
        // Close loading dialog
        if (mounted) Navigator.pop(context);
        
        // Show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting product: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.image, size: 40, color: Colors.grey[500]),
      );
    }
    
    if (imageUrl.startsWith('data:image')) {
      // Base64 image
      final base64Data = imageUrl.split(',').last;
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            base64Decode(base64Data),
            fit: BoxFit.cover,
            width: 80,
            height: 80,
          ),
        );
      } catch (e) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.red[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.broken_image, size: 40, color: Colors.red[400]),
        );
      }
    } else if (Uri.tryParse(imageUrl)?.isAbsolute == true) {
      // Network image
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: 80,
          height: 80,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.broken_image, size: 40, color: Colors.red[400]),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
      );
    } else {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey[500]),
      );
    }
  }

  Future<void> _refreshData() async {
    print('Refreshing data...');
    setState(() => _isLoading = true);
    await _loadProductData();
    await _loadVariants();
    await _loadCreatedByName();
    print('Data refresh complete');
  }

  @override
  Widget build(BuildContext context) {
    print('=== BUILD: ProductDetailPage build called ===');
    print('=== BUILD: _isLoading: $_isLoading');
    print('=== BUILD: _productData: $_productData');
    print('=== BUILD: _productData.isEmpty: ${_productData.isEmpty}');
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _productData['name'] ?? 'Product Details',
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
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteProduct,
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
    print('=== OVERVIEW: _buildOverviewTab called ===');
    print('=== OVERVIEW: _productData: $_productData');
    
    // Only show loading if we have no data at all
    if (_productData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading product details...'),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width < 400 ? 12 : (MediaQuery.of(context).size.width < 600 ? 16 : 20),
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section - Product Overview Card with better structure
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue[50]!, Colors.white],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width < 400 ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Header - Improved responsive layout
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        
                        if (screenWidth < 600) {
                          // Enhanced layout for small/medium screens
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top row with image and main info
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Image - better sized for medium screens
                                  Container(
                                    width: screenWidth < 400 ? 70 : 80,
                                    height: screenWidth < 400 ? 70 : 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: _buildProductImage(_productData['imageURL']),
                                    ),
                                  ),
                                  SizedBox(width: screenWidth < 400 ? 12 : 16),
                                  
                                  // Product Info - aligned left and structured
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Product Name
                                        Text(
                                          _productData['name'] ?? 'Unnamed Product',
                                          style: TextStyle(
                                            fontSize: screenWidth < 400 ? 16 : 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                            height: 1.2,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: screenWidth < 400 ? 6 : 8),
                                        
                                        // Category chip
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: screenWidth < 400 ? 8 : 10,
                                            vertical: screenWidth < 400 ? 4 : 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _productData['category'] ?? 'Uncategorized',
                                            style: TextStyle(
                                              fontSize: screenWidth < 400 ? 11 : 12,
                                              color: Colors.blue[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: screenWidth < 400 ? 8 : 10),
                                        
                                        // Price with better styling
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: screenWidth < 400 ? 10 : 12,
                                            vertical: screenWidth < 400 ? 6 : 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green[50],
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.green[200]!, width: 1),
                                          ),
                                          child: Text(
                                            '₱${((_productData['price'] ?? 0) is String ? double.tryParse(_productData['price'].toString()) ?? 0 : _productData['price'] ?? 0).toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: screenWidth < 400 ? 16 : 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        } else {
                          // Original row layout for larger screens
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product Image
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: _buildProductImage(_productData['imageURL']),
                              ),
                              const SizedBox(width: 16),
                              
                              // Product Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Product Name
                                    Text(
                                      _productData['name'] ?? 'Unnamed Product',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    
                                    // Category
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _productData['category'] ?? 'Uncategorized',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    
                                    // Price
                                    Text(
                                      '₱${((_productData['price'] ?? 0) is String ? double.tryParse(_productData['price'].toString()) ?? 0 : _productData['price'] ?? 0).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    
                    SizedBox(height: MediaQuery.of(context).size.width < 400 ? 16 : 20),
                    
                    // Status Badges - Better organized for all screen sizes
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        
                        return Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth < 400 ? 8 : 12,
                            vertical: screenWidth < 400 ? 8 : 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Wrap(
                            spacing: screenWidth < 400 ? 6 : 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.start,
                            children: [
                              // Stock Status Badge
                              _buildEnhancedStatusBadge(
                                '${_productData['stock'] ?? 0} in stock',
                                (_productData['lowStock'] == true) ? Colors.red : Colors.green,
                                (_productData['lowStock'] == true) ? Icons.warning_rounded : Icons.check_circle_rounded,
                                screenWidth < 400,
                              ),
                              
                              // Upcycled Badge
                              if (_productData['isUpcycled'] == true)
                                _buildEnhancedStatusBadge(
                                  'Upcycled',
                                  Colors.green,
                                  Icons.recycling_rounded,
                                  screenWidth < 400,
                                ),
                              
                              // Made Badge
                              if (_productData['isMade'] == true)
                                _buildEnhancedStatusBadge(
                                  'Made',
                                  Colors.blue,
                                  Icons.build_rounded,
                                  screenWidth < 400,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            // Description Section - Simplified for small screens
            if (_productData['description'] != null && _productData['description'].toString().isNotEmpty) ...[
              SizedBox(height: MediaQuery.of(context).size.width < 400 ? 8 : 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (MediaQuery.of(context).size.width < 400) {
                    // Simplified card for small screens
                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.description_rounded, size: 16, color: Colors.blue.withOpacity(0.7)),
                                const SizedBox(width: 6),
                                const Text(
                                  'Description',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _productData['description'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    // Original card for larger screens
                    return _buildInfoCard(
                      'Description',
                      Icons.description,
                      Colors.blue,
                      child: Text(
                        _productData['description'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
            
            // Notes Section - Simplified for small screens
            if (_productData['notes'] != null && _productData['notes'].toString().isNotEmpty) ...[
              SizedBox(height: MediaQuery.of(context).size.width < 400 ? 8 : 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (MediaQuery.of(context).size.width < 400) {
                    // Simplified note for small screens
                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!, width: 0.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.sticky_note_2_rounded, size: 14, color: Colors.orange[700]),
                                const SizedBox(width: 4),
                                Text(
                                  'Notes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _productData['notes'],
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange[600],
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    // Original card for larger screens
                    return _buildInfoCard(
                      'Notes',
                      Icons.sticky_note_2,
                      Colors.orange,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Text(
                          _productData['notes'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Statistics Grid - Improved for small screens
            LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = MediaQuery.of(context).size.width;
                
                // For very small screens, use a simple list instead of cards
                if (screenWidth < 400) {
                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.analytics_rounded, size: 16, color: Colors.purple.withOpacity(0.7)),
                              const SizedBox(width: 6),
                              const Text(
                                'Statistics',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildCompactStatRow('Stock', '${_productData['stock'] ?? 0}', Icons.inventory_2_rounded, Colors.blue),
                          const SizedBox(height: 8),
                          _buildCompactStatRow('Variants', '${_variants.length}', Icons.tune_rounded, Colors.purple),
                          const SizedBox(height: 8),
                          _buildCompactStatRow('Value', '₱${((_productData['potentialValue'] ?? 0) is String ? double.tryParse(_productData['potentialValue'].toString()) ?? 0 : _productData['potentialValue'] ?? 0).toStringAsFixed(0)}', Icons.trending_up_rounded, Colors.green),
                          const SizedBox(height: 8),
                          _buildCompactStatRow('Price', '₱${((_productData['price'] ?? 0) is String ? double.tryParse(_productData['price'].toString()) ?? 0 : _productData['price'] ?? 0).toStringAsFixed(0)}', Icons.attach_money_rounded, Colors.orange),
                        ],
                      ),
                    ),
                  );
                } else {
                  // Original card layout for larger screens
                  return _buildInfoCard(
                    'Statistics',
                    Icons.analytics,
                    Colors.purple,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // More nuanced responsive grid
                        int crossAxisCount;
                        double childAspectRatio;
                        
                        if (constraints.maxWidth < 300) {
                          // Very small screens - single column
                          crossAxisCount = 1;
                          childAspectRatio = 3.0;
                        } else if (constraints.maxWidth < 450) {
                          // Small screens - 2 columns
                          crossAxisCount = 2;
                          childAspectRatio = 1.4;
                        } else if (constraints.maxWidth < 600) {
                          // Medium screens - 2 columns
                          crossAxisCount = 2;
                          childAspectRatio = 1.2;
                        } else {
                          // Large screens - 4 columns
                          crossAxisCount = 4;
                          childAspectRatio = 1.0;
                        }
                        
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          children: [
                            _buildStatCard(
                              'Stock',
                              '${_productData['stock'] ?? 0}',
                              Icons.inventory_2,
                              Colors.blue,
                            ),
                            _buildStatCard(
                              'Variants',
                              '${_variants.length}',
                              Icons.tune,
                              Colors.purple,
                            ),
                            _buildStatCard(
                              'Value',
                              '₱${((_productData['potentialValue'] ?? 0) is String ? double.tryParse(_productData['potentialValue'].toString()) ?? 0 : _productData['potentialValue'] ?? 0).toStringAsFixed(0)}',
                              Icons.trending_up,
                              Colors.green,
                            ),
                            _buildStatCard(
                              'Price',
                              '₱${((_productData['price'] ?? 0) is String ? double.tryParse(_productData['price'].toString()) ?? 0 : _productData['price'] ?? 0).toStringAsFixed(0)}',
                              Icons.attach_money,
                              Colors.orange,
                            ),
                          ],
                        );
                      },
                    ),
                  );
                }
              },
            ),
            
            SizedBox(height: MediaQuery.of(context).size.width < 400 ? 8 : 12),
            
            // Additional Details - Simplified for small screens
            LayoutBuilder(
              builder: (context, constraints) {
                if (MediaQuery.of(context).size.width < 400) {
                  // Simplified details for small screens
                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey.withOpacity(0.7)),
                              const SizedBox(width: 6),
                              const Text(
                                'Details',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildCompactDetailRow('Created by', _createdByName ?? 'Loading...'),
                          const SizedBox(height: 6),
                          _buildCompactDetailRow('Created', _formatUpdatedAt(_productData['createdAt'])),
                          const SizedBox(height: 6),
                          _buildCompactDetailRow('Updated', _formatUpdatedAt(_productData['updatedAt'])),
                          if (_productData['acquisitionDate'] != null) ...[
                            const SizedBox(height: 6),
                            _buildCompactDetailRow('Acquired', _formatUpdatedAt(_productData['acquisitionDate'])),
                          ],
                        ],
                      ),
                    ),
                  );
                } else {
                  // Original card for larger screens
                  return _buildInfoCard(
                    'Details',
                    Icons.info_outline,
                    Colors.grey,
                    child: Column(
                      children: [
                        _buildDetailRow('Created by', _createdByName ?? 'Loading...'),
                        _buildDetailRow('Created', _formatUpdatedAt(_productData['createdAt'])),
                        _buildDetailRow('Last updated', _formatUpdatedAt(_productData['updatedAt'])),
                        if (_productData['acquisitionDate'] != null)
                          _buildDetailRow('Acquired', _formatUpdatedAt(_productData['acquisitionDate'])),
                      ],
                    ),
                  );
                }
              },
            ),
            
            // Bottom spacing for better UX
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  
  Widget _buildInfoCard(String title, IconData icon, Color color, {required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: color.withOpacity(0.7)),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Check if we're in a single column layout (very wide cards)
        final isWideCard = constraints.maxWidth > 250;
        
        return Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: isWideCard 
              ? Row(
                  children: [
                    Icon(icon, color: color.withOpacity(0.7), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: color.withOpacity(0.8),
                            ),
                          ),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color.withOpacity(0.7), size: 24),
                    const SizedBox(height: 8),
                    FittedBox(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
          ),
        );
      },
    );
  }
  
  Widget _buildCompactStatRow(String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text(
          '$title:',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // For very narrow screens, stack vertically
          if (constraints.maxWidth < 250) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
              ],
            );
          } else {
            // For wider screens, use row layout
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: constraints.maxWidth < 350 ? 80 : 100,
                  child: Text(
                    '$label:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
  
  Widget _buildCompactDetailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
  
  Widget _buildEnhancedStatusBadge(String text, Color color, IconData icon, bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10, 
        vertical: isCompact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: isCompact ? 14 : 16, 
            color: color.withOpacity(0.8),
          ),
          SizedBox(width: isCompact ? 4 : 6),
          Text(
            text,
            style: TextStyle(
              fontSize: isCompact ? 11 : 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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

}