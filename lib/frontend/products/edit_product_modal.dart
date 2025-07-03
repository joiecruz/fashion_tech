import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/product.dart';
import '../../models/product_image.dart';
import '../../utils/utils.dart';
import '../../utils/size_utils.dart';
import '../../utils/color_utils.dart';

class ProductVariantInput {
  String size;
  String color;
  int quantityInStock;

  ProductVariantInput({
    required this.size,
    required this.color,
    required this.quantityInStock,
  });
}

class EditProductModal extends StatefulWidget {
  final Map<String, dynamic> productData;
  const EditProductModal({super.key, required this.productData});

  @override
  State<EditProductModal> createState() => _EditProductModalState();
}

class _EditProductModalState extends State<EditProductModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _supplierController = TextEditingController();
  final _notesController = TextEditingController();
  final _stockController = TextEditingController();
  String _selectedCategory = 'top';
  bool _isUpcycled = false;
  bool _isMade = false;
  bool _isLoading = false;
  bool _uploading = false;
  DateTime? _acquisitionDate;

  // Single image logic
  File? _productImage;
  String? _productImageUrl;
  bool _uploadingImage = false;
  bool _useFirebaseStorage = true;

  List<ProductVariantInput> _variants = [];

  final List<String> _categories = [
    'top',
    'bottom',
    'outerwear',
    'accessories',
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.productData['name'] ?? '';
    _priceController.text = widget.productData['price']?.toString() ?? '';
    _supplierController.text = widget.productData['supplier'] ?? '';
    _notesController.text = widget.productData['notes'] ?? '';
    _stockController.text = widget.productData['stock']?.toString() ?? '';
    _selectedCategory = widget.productData['category'] ?? _categories.first;
    _isUpcycled = widget.productData['isUpcycled'] ?? false;
    _isMade = widget.productData['isMade'] ?? false;

    // Acquisition date
    final acquisitionRaw = widget.productData['acquisitionDate'];
    if (acquisitionRaw is Timestamp) {
      _acquisitionDate = acquisitionRaw.toDate();
    } else if (acquisitionRaw is String) {
      _acquisitionDate = DateTime.tryParse(acquisitionRaw) ?? DateTime.now();
    } else {
      _acquisitionDate = DateTime.now();
    }

    // Fetch the existing image (single image logic)
    _productImageUrl = widget.productData['imageURL'];

    // Fetch variants if any
    if (widget.productData['variants'] != null) {
      _variants = (widget.productData['variants'] as List)
          .map((v) => ProductVariantInput(
                size: v['size'],
                color: v['color'],
                quantityInStock: v['quantityInStock'],
              ))
          .toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _uploadImageAsBase64() async {
    if (_productImage == null) return;

    try {
      setState(() => _uploading = true);
      final fileSize = await _productImage!.length();
      if (fileSize > 2 * 1024 * 1024) {
        throw Exception('File size exceeds 2MB limit. Please choose a smaller image or reduce quality.');
      }

      final bytes = await _productImage!.readAsBytes();
      final base64String = base64Encode(bytes);
      final mimeType = _productImage!.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

      _productImageUrl = 'data:$mimeType;base64,$base64String';

      setState(() => _uploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Image processed successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _uploading = false);
      _productImageUrl = null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process image: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

Future<void> _pickImage() async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
      maxHeight: 800,
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      final mimeType = picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      setState(() {
        _productImage = null; // Not used
        _productImageUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
      });
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
  Future<void> _uploadImage() async {
    if (_productImage == null) return;

    try {
      setState(() => _uploading = true);

      final fileSize = await _productImage!.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('File size exceeds 5MB limit. Please choose a smaller image.');
      }

      final fileName = 'products/${DateTime.now().millisecondsSinceEpoch}_${_productImage!.path.split('/').last}';
      final ref = FirebaseStorage.instance.ref().child(fileName);

      final uploadTask = ref.putFile(_productImage!);

      await uploadTask;
      _productImageUrl = await ref.getDownloadURL();

      setState(() => _uploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Image uploaded successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _uploading = false);
      _productImageUrl = null;

      String errorMessage;
      if (e.toString().contains('File size exceeds')) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Trying alternative upload method...';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Trying alternative upload method...';
      } else if (e.toString().contains('storage/unauthorized')) {
        errorMessage = 'Unauthorized access. Trying alternative upload method...';
      } else {
        errorMessage = 'Upload failed. Trying alternative upload method...';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      if (_useFirebaseStorage) {
        _useFirebaseStorage = false;
        await _uploadImageAsBase64();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All upload methods failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _useFirebaseStorage = true;
                _uploadImage();
              },
            ),
          ),
        );
      }
    }
  }

Widget _buildImagePreview() {
  if (_productImageUrl != null && _productImageUrl!.startsWith('data:image')) {
    final base64Data = _productImageUrl!.split(',').last;
    return Image.memory(
      base64Decode(base64Data),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  } else {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt, color: Colors.orange, size: 40),
        const SizedBox(height: 8),
        Text(
          'Tap to upload product image',
          style: TextStyle(color: Colors.orange.shade700),
        ),
      ],
    );
  }
}
Future<void> _saveProduct() async {
  if (!_formKey.currentState!.validate()) return;

  if (_variants.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please add at least one product variant')),
    );
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final docId = widget.productData['id'] ?? widget.productData['productID'];
    if (docId == null) {
      throw Exception('No document ID provided for update.');
    }

    // 1. Fetch and store the previous product data for undo
    final prevSnapshot = await FirebaseFirestore.instance
        .collection('products')
        .doc(docId)
        .get();
    final prevData = prevSnapshot.data();

    final Map<String, dynamic> productData = {
      'name': _nameController.text.trim(),
      'price': double.tryParse(_priceController.text) ?? 0,
      'category': _selectedCategory,
      'supplier': _supplierController.text.trim(),
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      'isUpcycled': _isUpcycled,
      'isMade': _isMade,
      'imageURL': _productImageUrl,
      'variants': _variants.map((v) => {
        'size': v.size,
        'color': v.color,
        'quantityInStock': v.quantityInStock,
      }).toList(),
      'acquisitionDate': _acquisitionDate,
      'updatedAt': DateTime.now(),
    };

    if (widget.productData['createdAt'] != null) {
      productData['createdAt'] = widget.productData['createdAt'];
    }

    await FirebaseFirestore.instance
        .collection('products')
        .doc(docId)
        .update(productData);
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Product updated successfully!'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () async {
              if (prevData != null) {
                await FirebaseFirestore.instance
                    .collection('products')
                    .doc(docId)
                    .update(prevData);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Undo successful!'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
          ),
        ),
      );
      Navigator.of(context).pop(true);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              const Text(
                'Edit Product',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),
        ),
        // Body
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Product Image Upload
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.image,
                              color: Colors.orange[600],
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Product Image',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _uploading ? null : _pickImage,
                          child: Container(
                            width: double.infinity,
                            height: (_productImage != null || _productImageUrl != null) ? 220 : 160,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (_productImage != null || _productImageUrl != null)
                                    ? Colors.orange[300]!
                                    : Colors.grey[300]!,
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                              color: (_productImage != null || _productImageUrl != null)
                                  ? Colors.orange[50]
                                  : Colors.grey[50],
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(child: _buildImagePreview()),
                                if (_productImage != null || _productImageUrl != null)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                                        onPressed: _pickImage,
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      ),
                                    ),
                                  ),
                                if (_productImageUrl != null && !_uploading)
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.check, color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text(
                                            'Uploaded',
                                            style: TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_productImageUrl != null || _productImage != null)
                          Text(
                            'Tap the image to change or re-upload. The image will be shown in product listings.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          )
                        else
                          Text(
                            'Upload a product image. Photos from your camera will be automatically compressed for storage.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Product Name
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Name',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Enter product name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.blue[600]!),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a product name';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Price and Category Row
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Price
                      Expanded(
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Price (₱)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Flexible(
                                  child: TextFormField(
                                    controller: _priceController,
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      hintText: '0.00',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.blue[600]!),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Enter price';
                                      }
                                      final price = double.tryParse(value);
                                      if (price == null || price <= 0) {
                                        return 'Enter valid price';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Category
                      Expanded(
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Category',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Flexible(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedCategory,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.blue[600]!),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                    items: _categories.map((category) {
                                      return DropdownMenuItem(
                                        value: category,
                                        child: Text(
                                          category.toUpperCase(),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedCategory = value!;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Supplier/Source (Optional)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supplier/Source - Optional',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _supplierController,
                          decoration: InputDecoration(
                            hintText: 'Enter supplier name or source',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.blue[600]!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Acquisition Date
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Acquisition Date',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final selectedDate = await showDatePicker(
                              context: context,
                              initialDate: _acquisitionDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(primary: Colors.blue[600]!),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (selectedDate != null) {
                              setState(() {
                                _acquisitionDate = selectedDate;
                              });
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                                const SizedBox(width: 12),
                                Text(
                                  _acquisitionDate != null
                                      ? '${_acquisitionDate!.day}/${_acquisitionDate!.month}/${_acquisitionDate!.year}'
                                      : 'Select date',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _acquisitionDate != null ? Colors.black87 : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Additional Notes
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Additional Notes - Optional',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Any additional notes, purchase details, condition, etc.',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.blue[600]!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Product Properties
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Properties',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Upcycled Switch
                        Row(
                          children: [
                            Icon(
                              Icons.recycling,
                              color: Colors.green[600],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Upcycled Product',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Made from recycled materials',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isUpcycled,
                              onChanged: (value) {
                                setState(() {
                                  _isUpcycled = value;
                                });
                              },
                              activeColor: Colors.green[600],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Made Switch
                        Row(
                          children: [
                            Icon(
                              Icons.handyman,
                              color: Colors.blue[600],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Made Product',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Product is ready for sale',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isMade,
                              onChanged: (value) {
                                setState(() {
                                  _isMade = value;
                                });
                              },
                              activeColor: Colors.blue[600],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Product Variants Section
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Product Variants',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _variants.add(ProductVariantInput(
                                    size: SizeUtils.sizeOptions.first,
                                    color: ColorUtils.colorOptions.first,
                                    quantityInStock: 0,
                                  ));
                                });
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Variant'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_variants.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: const Center(
                              child: Text(
                                'No variants added yet.\nAdd variants to specify size, color, and stock quantities.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ..._variants.asMap().entries.map((entry) {
                            final index = entry.key;
                            final variant = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Variant ${index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                        onPressed: () {
                                          setState(() {
                                            _variants.removeAt(index);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // Size Dropdown
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: variant.size,
                                          decoration: const InputDecoration(
                                            labelText: 'Size',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: SizeUtils.buildSizeDropdownItems(showDescriptions: true),
                                          onChanged: (value) {
                                            setState(() {
                                              _variants[index].size = value!;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Color Dropdown
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: variant.color,
                                          decoration: const InputDecoration(
                                            labelText: 'Color',
                                            border: OutlineInputBorder(),
                                          ),
                                          selectedItemBuilder: (context) {
                                            return ColorUtils.buildColorSelectedItems(context, size: 16);
                                          },
                                          items: ColorUtils.buildColorDropdownItems(),
                                          onChanged: (value) {
                                            setState(() {
                                              _variants[index].color = value!;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // Quantity
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: variant.quantityInStock.toString(),
                                          decoration: const InputDecoration(
                                            labelText: 'Quantity in Stock',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                          validator: (value) {
                                            if (value == null || value.trim().isEmpty) {
                                              return 'Required';
                                            }
                                            final qty = int.tryParse(value);
                                            if (qty == null || qty < 0) {
                                              return 'Valid qty';
                                            }
                                            return null;
                                          },
                                          onChanged: (value) {
                                            final qty = int.tryParse(value) ?? 0;
                                            setState(() {
                                              _variants[index].quantityInStock = qty;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save, size: 20),
                    label: Text(
                      _isLoading ? 'Saving...' : 'Save Changes',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}