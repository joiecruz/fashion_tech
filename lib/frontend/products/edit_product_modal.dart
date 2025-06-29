import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../../models/product.dart';
import '../../models/product_image.dart';
import '../../utils/utils.dart';
import '../../backend/edit_product.dart';

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
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _supplierController;
  late TextEditingController _notesController;
  late TextEditingController _stockController;
  late String _selectedCategory;
  bool _isUpcycled = false;
  bool _isMade = false;
  bool _isLoading = false;
  DateTime? _acquisitionDate;

  List<File> _productImages = [];
  List<String> _productImageUrls = [];
  bool _uploadingImages = false;
  int _primaryImageIndex = 0;

  List<ProductVariantInput> _variants = [];

  final List<String> _categories = [
    'top',
    'bottom',
    'outerwear',
    'accessories',
  ];

  final List<String> _sizeOptions = [
    'XS', 'S', 'M', 'L', 'XL', 'XXL', 'One Size'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.productData['name'] ?? '');
    _priceController = TextEditingController(text: widget.productData['price']?.toString() ?? '');
    _supplierController = TextEditingController(text: widget.productData['supplier'] ?? '');
    _notesController = TextEditingController(text: widget.productData['notes'] ?? '');
    _stockController = TextEditingController(text: widget.productData['stock']?.toString() ?? '');
    _selectedCategory = widget.productData['category'] ?? _categories.first;
    _isUpcycled = widget.productData['isUpcycled'] ?? false;
    _isMade = widget.productData['isMade'] ?? false;

    // Fix acquisitionDate type error
    final acquisitionRaw = widget.productData['acquisitionDate'];
    if (acquisitionRaw is Timestamp) {
      _acquisitionDate = acquisitionRaw.toDate();
    } else if (acquisitionRaw is String) {
      _acquisitionDate = DateTime.tryParse(acquisitionRaw) ?? DateTime.now();
    } else {
      _acquisitionDate = DateTime.now();
    }

    // Load images and variants if present
    if (widget.productData['images'] != null) {
      _productImageUrls = List<String>.from(widget.productData['images']);
    }
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

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 60);
    if (picked.isNotEmpty) {
      setState(() {
        _productImages = picked.map((xFile) => File(xFile.path)).toList();
        _productImageUrls.clear();
        _primaryImageIndex = 0;
      });
      await _uploadImages();
    }
  }

  Future<void> _uploadImages() async {
    if (_productImages.isEmpty) return;
    setState(() => _uploadingImages = true);
    try {
      _productImageUrls.clear();
      for (int i = 0; i < _productImages.length; i++) {
        await _convertToBase64(i);
      }
    } finally {
      setState(() => _uploadingImages = false);
    }
  }

  Future<void> _convertToBase64(int index) async {
    if (index >= _productImages.length) return;
    final image = _productImages[index];
    try {
      final compressedImage = await _compressImage(image);
      final imageToProcess = compressedImage ?? image;
      final bytes = await imageToProcess.readAsBytes();
      final estimatedBase64Size = bytes.length * 1.4;
      if (estimatedBase64Size > 800 * 1024) {
        throw Exception('Image too large for storage.');
      }
      final base64String = base64Encode(bytes);
      final extension = image.path.split('.').last.toLowerCase();
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
      final dataUrl = 'data:$mimeType;base64,$base64String';
      setState(() {
        while (_productImageUrls.length <= index) {
          _productImageUrls.add('');
        }
        _productImageUrls[index] = dataUrl;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process image ${index + 1}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<File?> _compressImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      if (bytes.length <= 1200 * 1024) {
        return imageFile;
      }
      return imageFile;
    } catch (e) {
      return imageFile;
    }
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
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
    // Build the update map directly, like supplier modal
    final Map<String, dynamic> productData = {
      'name': _nameController.text.trim(),
      'price': double.tryParse(_priceController.text) ?? 0,
      'category': _selectedCategory,
      'supplier': _supplierController.text.trim(),
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      'isUpcycled': _isUpcycled,
      'isMade': _isMade,
      'images': _productImageUrls.isNotEmpty ? _productImageUrls : widget.productData['images'],
      'variants': _variants.map((v) => {
        'size': v.size,
        'color': v.color,
        'quantityInStock': v.quantityInStock,
      }).toList(),
      'acquisitionDate': _acquisitionDate,
      'updatedAt': DateTime.now(),
    };

    // If you want to keep createdAt, add it as well
    if (widget.productData['createdAt'] != null) {
      productData['createdAt'] = widget.productData['createdAt'];
    }

    await EditProductBackend.updateProduct(
      productID: widget.productData['productID'],
      updatedData: productData,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text('Product "${_nameController.text}" updated!'),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      Navigator.of(context).pop(true);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              const Text('Failed to update product. Please try again.'),
            ],
          ),
          backgroundColor: Colors.red[600],
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                              'Product Images',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_productImages.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Images (${_productImages.length})',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 120,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _productImages.length,
                                  itemBuilder: (context, index) {
                                    final isPrimary = index == _primaryImageIndex;
                                    return Container(
                                      margin: const EdgeInsets.only(right: 12),
                                      child: Stack(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _primaryImageIndex = index;
                                              });
                                            },
                                            child: Container(
                                              width: 100,
                                              height: 120,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isPrimary ? Colors.orange : Colors.grey[300]!,
                                                  width: isPrimary ? 4 : 2,
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(11),
                                                child: Image.file(
                                                  _productImages[index],
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (isPrimary)
                                            Positioned(
                                              top: 4,
                                              left: 4,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'PRIMARY',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _productImages.removeAt(index);
                                                  if (_productImageUrls.length > index) {
                                                    _productImageUrls.removeAt(index);
                                                  }
                                                  if (_primaryImageIndex >= _productImages.length) {
                                                    _primaryImageIndex = _productImages.length > 0 ? 0 : 0;
                                                  }
                                                });
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        GestureDetector(
                          onTap: _uploadingImages ? null : _pickImages,
                          child: Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 2,
                              ),
                              color: Colors.grey[50],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_uploadingImages)
                                  const Column(
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 8),
                                      Text('Processing images...'),
                                    ],
                                  )
                                else
                                  Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[100],
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.add_photo_alternate,
                                          size: 24,
                                          color: Colors.orange[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _productImages.isEmpty ? 'Add Product Images' : 'Add More Images',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Photos auto-compressed to 60% quality',
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
                        const SizedBox(height: 8),
                        if (_productImages.isNotEmpty)
                          Text(
                            'Tap an image to set it as the primary/thumbnail image. The primary image will be shown in product listings.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          )
                        else
                          Text(
                            'Upload multiple product images. Photos from your camera will be automatically compressed for storage.',
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
                                    size: _sizeOptions.first,
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
                                          items: _sizeOptions.map((size) {
                                            return DropdownMenuItem(
                                              value: size,
                                              child: Text(size),
                                            );
                                          }).toList(),
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