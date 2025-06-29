import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/product.dart';
import '../../models/product_image.dart';
import '../../utils/utils.dart';

// Helper class for product variant input
class ProductVariantInput {
  String size;
  String color;
  int quantityInStock;
  double? unitCostEstimate;

  ProductVariantInput({
    required this.size,
    required this.color,
    required this.quantityInStock,
    this.unitCostEstimate,
  });
}

class AddProductModal extends StatefulWidget {
  const AddProductModal({super.key});

  @override
  State<AddProductModal> createState() => _AddProductModalState();
}

class _AddProductModalState extends State<AddProductModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _unitCostController = TextEditingController();
  final _supplierController = TextEditingController();
  final _notesController = TextEditingController();
  final _stockController = TextEditingController();
  String _selectedCategory = 'top';
  bool _isUpcycled = false;
  bool _isMade = false;
  bool _isLoading = false;
  bool _uploading = false;
  DateTime? _acquisitionDate = DateTime.now();

  // Product Image
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

  final List<String> _sizeOptions = [
    'XS', 'S', 'M', 'L', 'XL', 'XXL', 'One Size'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _unitCostController.dispose();
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
      print('Base64 upload error: $e');
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
      if (kIsWeb) {
        // On web, use bytes and base64
        final bytes = await picked.readAsBytes();
        final mimeType = picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
        setState(() {
          _productImage = null; // Not used on web
          _productImageUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
        });
      } else {
        // On mobile/desktop, use File
        setState(() {
          _productImage = File(picked.path);
          _productImageUrl = null;
        });
        if (await _productImage!.exists()) {
          final fileSize = await _productImage!.length();
          print('Image selected: ${_productImage!.path}');
          print('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
          if (_useFirebaseStorage) {
            await _uploadImage();
          } else {
            await _uploadImageAsBase64();
          }
        } else {
          throw Exception('Selected file does not exist or is not accessible');
        }
      }
    }
  } catch (e) {
    print('Error picking image: $e');
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

      final fileName = 'swatches/${DateTime.now().millisecondsSinceEpoch}_${_productImage!.path.split('/').last}';
      final ref = FirebaseStorage.instance.ref().child(fileName);

      print('Starting upload for file: $fileName');
      print('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      final uploadTask = ref.putFile(_productImage!);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      await uploadTask;
      _productImageUrl = await ref.getDownloadURL();

      print('Upload successful! URL: $_productImageUrl');

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
      print('Upload error: $e');
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
        print('Falling back to base64 upload...');
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

    print('DEBUG: _saveProduct called');
    print('DEBUG: _productImageUrl = $_productImageUrl');

    try {
      // Create consolidated description including supplier info and acquisition date
      String consolidatedDescription = '';

      // Add supplier info if provided
      if (_supplierController.text.trim().isNotEmpty) {
        consolidatedDescription += 'Supplier/Source: ${_supplierController.text.trim()}';
      }

      // Add acquisition date if provided
      if (_acquisitionDate != null) {
        if (consolidatedDescription.isNotEmpty) consolidatedDescription += '\n';
        consolidatedDescription += 'Acquired: ${_acquisitionDate!.day}/${_acquisitionDate!.month}/${_acquisitionDate!.year}';
      }

      // Get current user ID for both product and image
      final currentUser = FirebaseAuth.instance.currentUser;
      final userId = currentUser?.uid ?? 'anonymous'; // Fallback to anonymous if no user
      print('DEBUG: Current user ID: $userId');

      // Create the product first
      final productRef = FirebaseFirestore.instance.collection('products').doc();
      final product = Product(
        id: productRef.id,
        name: _nameController.text.trim(),
        description: consolidatedDescription.isNotEmpty ? consolidatedDescription : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        price: double.parse(_priceController.text),
        unitCostEstimate: _unitCostController.text.isNotEmpty
            ? double.parse(_unitCostController.text)
            : null,
        category: _selectedCategory,
        isUpcycled: _isUpcycled,
        isMade: _isMade,
        createdBy: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await productRef.set(product.toMap());

      // Create product variants
      for (final variant in _variants) {
        await FirebaseFirestore.instance
            .collection('productVariants')
            .add({
          'productID': productRef.id,
          'size': variant.size,
          'color': variant.color,
          'quantityInStock': variant.quantityInStock,
          'unitCostEstimate': variant.unitCostEstimate,
        });
      }

      // Create product image if uploaded
      if (_productImageUrl != null && _productImageUrl!.isNotEmpty) {
        try {
          final productImageRef = FirebaseFirestore.instance.collection('productImages').doc();
          final productImage = ProductImage(
            id: productImageRef.id,
            productID: productRef.id,
            imageURL: _productImageUrl!,
            isPrimary: true,
            uploadedBy: userId,
            uploadedAt: DateTime.now(),
          );
          await productImageRef.set(productImage.toMap());
        } catch (e, stackTrace) {
          print('DEBUG: ERROR saving product image: $e');
          print('DEBUG: Stack trace: $stackTrace');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product and variants added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding product: $e'),
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

Widget _buildImagePreview() {
  if (_uploading) {
    return const Center(child: CircularProgressIndicator());
  } else if (kIsWeb && _productImageUrl != null) {
    // On web, show the image from base64 url
    return Image.network(
      _productImageUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  } else if (_productImage != null && _productImage!.existsSync()) {
    // On mobile/desktop, show the file image
    return Image.file(
      _productImage!,
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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.upload, color: Colors.orange, size: 18),
              SizedBox(width: 6),
              Text('Upload Image', style: TextStyle(color: Colors.orange)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Max size 5MB, JPG/PNG',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
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
                'Add New Product',
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
                          onTap: _uploadingImage ? null : _pickImage,
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
                                if (_productImage != null || !_uploadingImage)
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
                                if (_productImageUrl != null && !_uploadingImage)
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
                        Center(
                          child: Text(
                            'Optional: Add a product image to help identify this item',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
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

                // Unit Cost Estimate (Optional)
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
                          'Unit Cost Estimate (₱) - Optional',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _unitCostController,
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
                          ),
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              final cost = double.tryParse(value);
                              if (cost == null || cost < 0) {
                                return 'Enter valid cost';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
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
                              initialDate: _acquisitionDate!,
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
                                      const SizedBox(width: 8),
                                      // Unit Cost (Optional)
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: variant.unitCostEstimate?.toString() ?? '',
                                          decoration: const InputDecoration(
                                            labelText: 'Unit Cost (₱) - Optional',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (value) {
                                            final cost = value.isEmpty ? null : double.tryParse(value);
                                            setState(() {
                                              _variants[index].unitCostEstimate = cost;
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
                      _isLoading ? 'Saving...' : 'Save Product',
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