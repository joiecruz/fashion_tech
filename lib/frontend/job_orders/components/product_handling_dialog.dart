import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum ProductHandlingAction {
  addToLinkedProduct,
  createNewProduct,
  selectExistingProduct,
}

class ProductHandlingResult {
  final ProductHandlingAction action;
  final double paymentAmount;
  final String? categoryID;
  final double? customPrice;
  final List<String> imageURLs;
  
  ProductHandlingResult({
    required this.action,
    required this.paymentAmount,
    this.categoryID,
    this.customPrice,
    this.imageURLs = const [],
  });
}

class ProductHandlingDialog extends StatefulWidget {
  final Map<String, dynamic> jobOrderData;
  final List<QueryDocumentSnapshot> jobOrderDetails;

  const ProductHandlingDialog({
    super.key,
    required this.jobOrderData,
    required this.jobOrderDetails,
  });

  @override
  State<ProductHandlingDialog> createState() => _ProductHandlingDialogState();
}

class _ProductHandlingDialogState extends State<ProductHandlingDialog> {
  final TextEditingController _paymentController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  ProductHandlingAction? _selectedAction;
  String _selectedCategory = 'top';
  bool _useCustomPrice = false;
  List<File> _selectedImages = [];
  List<String> _uploadedImageURLs = [];
  bool _isUploading = false;
  
  final List<String> _categories = [
    'top',
    'bottom',
    'dress',
    'outerwear',
    'accessories',
    'shoes',
    'custom',
  ];

  @override
  void initState() {
    super.initState();
    // Calculate default price as total price / total quantity
    _calculateDefaultPrice();
  }

  void _calculateDefaultPrice() {
    final totalPrice = (widget.jobOrderData['price'] ?? 0.0) as double;
    final totalQuantity = widget.jobOrderDetails.fold<int>(
      0,
      (sum, detail) => sum + ((detail.data() as Map<String, dynamic>)['quantity'] ?? 0) as int,
    );
    
    if (totalQuantity > 0) {
      final unitPrice = totalPrice / totalQuantity;
      _priceController.text = unitPrice.toStringAsFixed(2);
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages = images.map((xFile) => File(xFile.path)).toList();
      });
    }
  }

  Future<void> _uploadImages() async {
    if (_selectedImages.isEmpty) return;
    
    setState(() {
      _isUploading = true;
    });
    
    try {
      final List<String> urls = [];
      
      for (int i = 0; i < _selectedImages.length; i++) {
        final file = _selectedImages[i];
        final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final storageRef = FirebaseStorage.instance.ref().child('product_images/$fileName');
        
        if (kIsWeb) {
          // For web, read file as bytes
          final bytes = await file.readAsBytes();
          final uploadTask = storageRef.putData(bytes);
          final snapshot = await uploadTask.whenComplete(() {});
          final url = await snapshot.ref.getDownloadURL();
          urls.add(url);
        } else {
          // For mobile, upload file directly
          final uploadTask = storageRef.putFile(file);
          final snapshot = await uploadTask.whenComplete(() {});
          final url = await snapshot.ref.getDownloadURL();
          urls.add(url);
        }
      }
      
      setState(() {
        _uploadedImageURLs = urls;
        _isUploading = false;
      });
      
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading images: $e')),
      );
    }
  }

  @override
  void dispose() {
    _paymentController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linkedProductID = widget.jobOrderData['linkedProductID'];
    final hasLinkedProduct = linkedProductID != null && linkedProductID.toString().isNotEmpty;

    return AlertDialog(
      title: const Text('Complete Job Order'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Job order is ready to be marked as Done!', 
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text('How would you like to handle the completed product?'),
            const SizedBox(height: 16),
            
            if (hasLinkedProduct) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, color: Colors.blue[600], size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('This job order is linked to an existing product.', 
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.inventory, color: Colors.orange[600], size: 16),
                      const SizedBox(width: 8),
                      Text('Found ${widget.jobOrderDetails.length} variant(s) to process:', 
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...widget.jobOrderDetails.map((detail) {
                    final data = detail.data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(left: 20, bottom: 2),
                      child: Text(
                        '• ${data['size'] ?? 'No size'} ${data['color'] ?? 'No color'} (${data['yardageUsed'] ?? 0} yards)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Product action selection
            const Text('Select Action:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            
            if (hasLinkedProduct) ...[
              RadioListTile<ProductHandlingAction>(
                title: const Text('Add to linked product'),
                subtitle: const Text('Add variants to the existing linked product'),
                value: ProductHandlingAction.addToLinkedProduct,
                groupValue: _selectedAction,
                onChanged: (value) => setState(() => _selectedAction = value),
              ),
            ],
            
            RadioListTile<ProductHandlingAction>(
              title: const Text('Create new product'),
              subtitle: const Text('Create a new product from this job order'),
              value: ProductHandlingAction.createNewProduct,
              groupValue: _selectedAction,
              onChanged: (value) => setState(() => _selectedAction = value),
            ),
            
            RadioListTile<ProductHandlingAction>(
              title: const Text('Select existing product'),
              subtitle: const Text('Add variants to an existing product'),
              value: ProductHandlingAction.selectExistingProduct,
              groupValue: _selectedAction,
              onChanged: (value) => setState(() => _selectedAction = value),
            ),
            
            // Show additional fields when creating new product
            if (_selectedAction == ProductHandlingAction.createNewProduct) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // Category selection
              const Text('Product Category:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 16),
              
              // Price selection
              const Text('Product Price:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _useCustomPrice,
                    onChanged: (value) => setState(() => _useCustomPrice = value!),
                  ),
                  const Text('Use custom unit price'),
                ],
              ),
              if (_useCustomPrice) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Unit Price',
                    prefixText: '\$',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'Using calculated unit price: \$${_priceController.text}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              
              // Image upload
              const Text('Product Images:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.image),
                    label: const Text('Select Images'),
                  ),
                  const SizedBox(width: 8),
                  if (_selectedImages.isNotEmpty) ...[
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : _uploadImages,
                      icon: _isUploading 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload),
                      label: Text(_isUploading ? 'Uploading...' : 'Upload'),
                    ),
                  ],
                ],
              ),
              if (_selectedImages.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Selected ${_selectedImages.length} image(s)', 
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
              if (_uploadedImageURLs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Uploaded ${_uploadedImageURLs.length} image(s)', 
                  style: const TextStyle(color: Colors.green, fontSize: 12)),
              ],
            ],
            
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            
            // Payment section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.attach_money, color: Colors.green[600], size: 16),
                      const SizedBox(width: 8),
                      const Text('Worker Payment', 
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Enter the amount paid to the worker for this job order:', 
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _paymentController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Enter payment amount (optional)',
                      prefixIcon: Icon(Icons.attach_money, size: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Leave empty if no payment is made at this time', 
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Action selection
            const Text('Choose product handling action:', 
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            
            if (hasLinkedProduct) ...[
              RadioListTile<ProductHandlingAction>(
                title: const Text('Add to Linked Product'),
                subtitle: const Text('Add stock to the already linked product'),
                value: ProductHandlingAction.addToLinkedProduct,
                groupValue: _selectedAction,
                onChanged: (value) => setState(() => _selectedAction = value),
                dense: true,
              ),
            ],
            RadioListTile<ProductHandlingAction>(
              title: const Text('Create New Product'),
              subtitle: const Text('Create a brand new product from this job order'),
              value: ProductHandlingAction.createNewProduct,
              groupValue: _selectedAction,
              onChanged: (value) => setState(() => _selectedAction = value),
              dense: true,
            ),
            RadioListTile<ProductHandlingAction>(
              title: const Text('Add to Existing Product'),
              subtitle: const Text('Select an existing product to add stock to'),
              value: ProductHandlingAction.selectExistingProduct,
              groupValue: _selectedAction,
              onChanged: (value) => setState(() => _selectedAction = value),
              dense: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _selectedAction != null ? () {
            final paymentAmount = double.tryParse(_paymentController.text.trim()) ?? 0.0;
            final customPrice = _useCustomPrice ? double.tryParse(_priceController.text.trim()) : null;
            
            Navigator.pop(context, ProductHandlingResult(
              action: _selectedAction!,
              paymentAmount: paymentAmount,
              categoryID: _selectedCategory,
              customPrice: customPrice,
              imageURLs: _uploadedImageURLs,
            ));
          } : null,
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Complete Job Order'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
