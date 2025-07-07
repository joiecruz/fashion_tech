import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_handling_dialog.dart';

class JobOrderActions {
  final BuildContext context;
  final Map<String, Map<String, dynamic>> productData;
  final VoidCallback onDataRefresh;

  JobOrderActions({
    required this.context,
    required this.productData,
    required this.onDataRefresh,
  });

  // Mark job order as done with product handling
  Future<void> markJobOrderAsDone(String jobOrderID, String jobOrderName, Map<String, dynamic> jobOrderData) async {
    print('[DEBUG] Starting mark as done process for job order: $jobOrderID');
    
    try {
      // Step 1: Fetch jobOrderDetails first
      print('[DEBUG] Fetching job order details...');
      final jobOrderDetailsSnap = await FirebaseFirestore.instance
          .collection('jobOrderDetails')
          .where('jobOrderID', isEqualTo: jobOrderID)
          .get();

      print('[DEBUG] Found ${jobOrderDetailsSnap.docs.length} jobOrderDetails for job order $jobOrderID');

      if (jobOrderDetailsSnap.docs.isEmpty) {
        print('[WARNING] No job order details found - cannot create product without variants');
        _showSnackBar(
          'No product variants found for this job order. Cannot create product.',
          Colors.orange[600]!,
          Icons.warning,
        );
        return;
      }

      // Step 2: Show product handling dialog BEFORE marking as done
      print('[DEBUG] Showing product handling dialog...');
      final productResult = await showDialog<ProductHandlingResult>(
        context: context,
        builder: (context) => ProductHandlingDialog(
          jobOrderData: jobOrderData,
          jobOrderDetails: jobOrderDetailsSnap.docs,
        ),
      );
      
      if (productResult == null) {
        print('[DEBUG] User cancelled product handling dialog');
        return;
      }

      print('[DEBUG] User selected product action: ${productResult.action}');
      print('[DEBUG] Payment amount: ${productResult.paymentAmount}');

      // Step 3: Handle product creation/update based on user choice
      try {
        await _handleProductAction(
          productResult.action, 
          jobOrderID, 
          jobOrderName, 
          jobOrderData, 
          jobOrderDetailsSnap.docs,
          productResult, // Pass the full result object
        );
        print('[DEBUG] Product action handled successfully');
      } catch (e) {
        print('[ERROR] Failed to handle product action: $e');
        _showSnackBar(
          'Failed to handle product action: ${e.toString()}',
          Colors.red[600]!,
          Icons.error_outline,
        );
        return;
      }

      // Step 4: Mark job order as done in database
      print('[DEBUG] Updating job order status to Done...');
      await FirebaseFirestore.instance
          .collection('jobOrders')
          .doc(jobOrderID)
          .update({
            'status': 'Done',
            'updatedAt': Timestamp.now(),
            'completedAt': Timestamp.now(),
          });

      // Step 5: Create transaction if payment was specified
      if (productResult.paymentAmount > 0) {
        try {
          print('[DEBUG] Creating transaction for payment: ${productResult.paymentAmount}');
          await FirebaseFirestore.instance.collection('transactions').add({
            'jobOrderID': jobOrderID,
            'amount': productResult.paymentAmount,
            'type': 'expense',
            'date': Timestamp.now(),
            'description': 'Payment to worker for job order "$jobOrderName"',
            'createdAt': Timestamp.now(),
            'createdBy': jobOrderData['assignedTo'] ?? jobOrderData['createdBy'],
          });
          print('[DEBUG] Transaction created successfully');
        } catch (e) {
          print('[WARNING] Failed to create transaction: $e');
        }
      }

      _showSnackBar(
        'Job order "$jobOrderName" completed successfully',
        Colors.green[600]!,
        Icons.check_circle,
      );

    } catch (e) {
      print('[ERROR] Failed to mark job order as done: $e');
      _showSnackBar(
        'Failed to mark job order as done: ${e.toString()}',
        Colors.red[600]!,
        Icons.error_outline,
      );
    }
  }

  // Handle the selected product action
  Future<void> _handleProductAction(
    ProductHandlingAction action,
    String jobOrderID,
    String jobOrderName,
    Map<String, dynamic> jobOrderData,
    List<QueryDocumentSnapshot> jobOrderDetails,
    ProductHandlingResult productResult,
  ) async {
    print('[DEBUG] Handling product action: $action');

    switch (action) {
      case ProductHandlingAction.addToLinkedProduct:
        await _addToLinkedProduct(jobOrderID, jobOrderData, jobOrderDetails);
        break;
      case ProductHandlingAction.createNewProduct:
        await _createNewProduct(jobOrderID, jobOrderName, jobOrderData, jobOrderDetails, productResult);
        break;
      case ProductHandlingAction.selectExistingProduct:
        await _selectExistingProduct(jobOrderID, jobOrderData, jobOrderDetails);
        break;
    }
  }

  // Add stock to the linked product
  Future<void> _addToLinkedProduct(String jobOrderID, Map<String, dynamic> jobOrderData, List<QueryDocumentSnapshot> jobOrderDetails) async {
    final linkedProductID = jobOrderData['linkedProductID'];
    print('[DEBUG] Adding stock to linked product: $linkedProductID');

    final batch = FirebaseFirestore.instance.batch();
    
    for (final detail in jobOrderDetails) {
      final detailData = detail.data() as Map<String, dynamic>;
      final quantity = (detailData['quantity'] ?? 0) as int;
      
      // Skip if somehow we get 0 quantity
      if (quantity <= 0) {
        print('[WARNING] Skipping variant with 0 quantity for detail: ${detail.id}');
        continue;
      }
      
      final variantRef = FirebaseFirestore.instance.collection('productVariants').doc();
      batch.set(variantRef, {
        'productID': linkedProductID,
        'size': detailData['size'] ?? '',
        'colorID': detailData['color'] ?? '',
        'quantityInStock': quantity, // Use quantity from jobOrderDetails
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'sourceJobOrderID': jobOrderID,
        'sourceJobOrderDetailID': detail.id,
      });
      
      print('[DEBUG] Adding variant to linked product - quantity: $quantity, size: ${detailData['size']}, color: ${detailData['color']}');
    }

    await batch.commit();
    print('[DEBUG] Added ${jobOrderDetails.length} variants to linked product $linkedProductID');
    
    await _refreshProductData(linkedProductID);
  }

  // Create a new product from the job order
  Future<void> _createNewProduct(
    String jobOrderID, 
    String jobOrderName, 
    Map<String, dynamic> jobOrderData, 
    List<QueryDocumentSnapshot> jobOrderDetails,
    ProductHandlingResult productResult,
  ) async {
    print('[DEBUG] Creating new product from job order: $jobOrderID');

    if (jobOrderDetails.isEmpty) {
      throw Exception('No job order details provided - cannot create product without variants');
    }
    
    if (jobOrderName.trim().isEmpty) {
      throw Exception('Job order name is empty - cannot create product without a name');
    }

    try {
      final originalProductID = jobOrderData['productID'];
      final originalProductInfo = this.productData[originalProductID] ?? {};

      // Calculate total stock from jobOrderDetails quantities
      int totalStock = 0;
      
      for (final detail in jobOrderDetails) {
        final detailData = detail.data() as Map<String, dynamic>;
        final quantity = (detailData['quantity'] ?? 0) as int;
        
        if (quantity <= 0) {
          throw Exception('JobOrderDetail has invalid quantity: ${detail.id} (quantity: $quantity)');
        }
        
        totalStock += quantity;
        print('[DEBUG] JobOrderDetail quantity - ID: ${detail.id}, quantity: $quantity');
      }

      print('[DEBUG] Total stock calculated from jobOrderDetails: $totalStock');

      if (totalStock <= 0) {
        throw Exception('Total stock must be greater than 0 to create product');
      }

      // Calculate unit price (use custom price if provided, otherwise calculate from total)
      final totalPrice = (jobOrderData['price'] ?? 0.0) as double;
      final unitPrice = productResult.customPrice ?? (totalPrice / totalStock);
      
      print('[DEBUG] Total price: $totalPrice, Unit price: $unitPrice, Total stock: $totalStock');

      final productRef = FirebaseFirestore.instance.collection('products').doc();
      
      // Create variant documents first and collect their IDs
      final List<String> variantIDs = [];
      final batch = FirebaseFirestore.instance.batch();
      
      for (final detail in jobOrderDetails) {
        final detailData = detail.data() as Map<String, dynamic>;
        final variantQuantity = (detailData['quantity'] ?? 0) as int;
        
        // Skip if somehow we get 0 quantity
        if (variantQuantity <= 0) {
          print('[WARNING] Skipping variant with 0 quantity for detail: ${detail.id}');
          continue;
        }
        
        final variantRef = FirebaseFirestore.instance.collection('productVariants').doc();
        variantIDs.add(variantRef.id);
        
        final variantData = {
          'productID': productRef.id,
          'size': detailData['size'] ?? '',
          'colorID': detailData['color'] ?? '',
          'quantityInStock': variantQuantity, // Use quantity from jobOrderDetails
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'sourceJobOrderID': jobOrderID,
          'sourceJobOrderDetailID': detail.id,
        };
        
        print('[DEBUG] Creating variant with quantity: $variantQuantity for size: ${detailData['size']}, color: ${detailData['color']}');
        batch.set(variantRef, variantData);
      }
      
      // Create the product with all required fields
      final newProductData = {
        'name': jobOrderName,
        'notes': 'Created from job order: $jobOrderName',
        'price': unitPrice,
        'categoryID': productResult.categoryID ?? jobOrderData['category'] ?? originalProductInfo['category'] ?? 'custom',
        'isUpcycled': originalProductInfo['isUpcycled'] ?? jobOrderData['isUpcycled'] ?? false,
        'isMade': true,
        'createdBy': jobOrderData['createdBy'] ?? jobOrderData['assignedTo'] ?? 'unknown',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'acquisitionDate': Timestamp.now(), // Set to current time when converted
        'deletedAt': null,
        'imageURL': productResult.imageURLs.isNotEmpty ? productResult.imageURLs.first : null,
        'stock': totalStock, // Ensure stock matches total from variants
        'variantIDs': variantIDs,
        'sourceJobOrderID': jobOrderID,
      };
      
      print('[DEBUG] Creating product with data: ${newProductData.keys.toList()}');
      print('[DEBUG] Product stock: ${newProductData['stock']}, Price: ${newProductData['price']}');
      
      batch.set(productRef, newProductData);
      await batch.commit();
      
      // Create product images if provided
      if (productResult.imageURLs.isNotEmpty) {
        final imageBatch = FirebaseFirestore.instance.batch();
        
        for (int i = 0; i < productResult.imageURLs.length; i++) {
          final imageRef = FirebaseFirestore.instance.collection('productImages').doc();
          imageBatch.set(imageRef, {
            'productID': productRef.id,
            'imageURL': productResult.imageURLs[i],
            'isPrimary': i == 0, // First image is primary
            'uploadedBy': jobOrderData['createdBy'] ?? jobOrderData['assignedTo'] ?? 'unknown',
            'uploadedAt': Timestamp.now(),
          });
        }
        
        await imageBatch.commit();
      }
      
      print('[DEBUG] Created new product ${productRef.id} with ${jobOrderDetails.length} variants successfully');
      
      await _refreshProductData(productRef.id);
      
    } catch (e, stackTrace) {
      print('[ERROR] Failed to create new product: $e');
      print('[ERROR] Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Select an existing product to add stock to
  Future<void> _selectExistingProduct(String jobOrderID, Map<String, dynamic> jobOrderData, List<QueryDocumentSnapshot> jobOrderDetails) async {
    print('[DEBUG] Selecting existing product for job order: $jobOrderID');

    final productsSnap = await FirebaseFirestore.instance
        .collection('products')
        .orderBy('name')
        .get();

    final availableProducts = productsSnap.docs.where((doc) {
      final data = doc.data();
      return data['deletedAt'] == null;
    }).toList();

    if (availableProducts.isEmpty) {
      _showSnackBar(
        'No products available for selection',
        Colors.orange[600]!,
        Icons.warning,
      );
      return;
    }

    final selectedProductID = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Product'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: availableProducts.length,
            itemBuilder: (context, index) {
              final doc = availableProducts[index];
              final data = doc.data();
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange[100],
                  child: Icon(Icons.inventory, color: Colors.orange[600], size: 20),
                ),
                title: Text(data['name'] ?? 'Unnamed Product'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Price: \$${data['price'] ?? 0.0}'),
                    Text('Category: ${data['categoryID'] ?? 'Unknown'}'),
                    if (data['isUpcycled'] == true) 
                      Text('Upcycled', style: TextStyle(color: Colors.green[600], fontWeight: FontWeight.w500)),
                  ],
                ),
                onTap: () => Navigator.pop(context, doc.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedProductID == null) return;

    // Add variants to selected product
    final batch = FirebaseFirestore.instance.batch();
    
    for (final detail in jobOrderDetails) {
      final detailData = detail.data() as Map<String, dynamic>;
      final quantity = (detailData['quantity'] ?? 0) as int;
      
      // Skip if somehow we get 0 quantity
      if (quantity <= 0) {
        print('[WARNING] Skipping variant with 0 quantity for detail: ${detail.id}');
        continue;
      }
      
      final variantRef = FirebaseFirestore.instance.collection('productVariants').doc();
      batch.set(variantRef, {
        'productID': selectedProductID,
        'size': detailData['size'] ?? '',
        'colorID': detailData['color'] ?? '',
        'quantityInStock': quantity, // Use quantity from jobOrderDetails
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'sourceJobOrderID': jobOrderID,
        'sourceJobOrderDetailID': detail.id,
      });
      
      print('[DEBUG] Adding variant to selected product - quantity: $quantity, size: ${detailData['size']}, color: ${detailData['color']}');
    }

    await batch.commit();
    print('[DEBUG] Added ${jobOrderDetails.length} variants to selected product $selectedProductID');
    
    await _refreshProductData(selectedProductID);
  }

  // Refresh product data for a specific product
  Future<void> _refreshProductData(String productID) async {
    print('[DEBUG] Refreshing product data for product: $productID');
    
    try {
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productID)
          .get();
      
      if (!productDoc.exists) {
        print('[WARNING] Product $productID not found when refreshing data');
        return;
      }
      
      final productDocData = productDoc.data()!;
      
      final variantsSnapshot = await FirebaseFirestore.instance
          .collection('productVariants')
          .where('productID', isEqualTo: productID)
          .get();
      
      List<Map<String, dynamic>> variants = [];
      int totalStock = 0;
      
      for (var variantDoc in variantsSnapshot.docs) {
        final variantData = variantDoc.data();
        final quantity = (variantData['quantityInStock'] ?? 0) as int;
        totalStock += quantity;
        
        variants.add({
          'variantID': variantDoc.id,
          'size': variantData['size'] ?? '',
          'color': variantData['colorID'] ?? variantData['color'] ?? '',
          'quantityInStock': quantity,
        });
      }
      
      print('[DEBUG] Calculated total stock: $totalStock from ${variants.length} variants');
      
      // Update the product document with the correct stock if it differs
      if (productDocData['stock'] != totalStock) {
        print('[DEBUG] Updating product stock from ${productDocData['stock']} to $totalStock');
        await FirebaseFirestore.instance
            .collection('products')
            .doc(productID)
            .update({
              'stock': totalStock,
              'updatedAt': Timestamp.now(),
            });
      }
          // Update cached product data - no longer storing variants to avoid bidirectional references
    productData[productID] = {
      'name': productDocData['name'] ?? '',
      'category': productDocData['category'] ?? '',
      'price': productDocData['price'] ?? 0.0,
      'imageURL': productDocData['imageURL'] ?? '',
      'isUpcycled': productDocData['isUpcycled'] ?? false,
      'stock': totalStock, // Use calculated stock
    };
      
      print('[DEBUG] Updated cached data for product $productID with ${variants.length} variants and total stock: $totalStock');
      
      // Trigger refresh callback
      onDataRefresh();
      
    } catch (e) {
      print('[ERROR] Failed to refresh product data for $productID: $e');
    }
  }

  // Helper method to show snackbar
  void _showSnackBar(String message, Color backgroundColor, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
