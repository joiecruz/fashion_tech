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

// Helper class for product variant input
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

class AddProductModal extends StatefulWidget {
  const AddProductModal({super.key});

  @override
  State<AddProductModal> createState() => _AddProductModalState();
}

class _AddProductModalState extends State<AddProductModal>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _supplierController = TextEditingController();
  final _notesController = TextEditingController();
  final _stockController = TextEditingController();
  
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _priceFocus = FocusNode();
  final FocusNode _supplierFocus = FocusNode();
  final FocusNode _stockFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();
  
  String _selectedCategory = 'top';
  bool _isUpcycled = false;
  bool _isMade = false;
  bool _isLoading = false;
  DateTime? _acquisitionDate = DateTime.now();

  // Product Images (Multiple)
  List<File> _productImages = [];
  List<String> _productImageUrls = [];
  int _primaryImageIndex = 0; // Index of the primary/thumbnail image
  bool _uploadingImages = false;
  bool _useFirebaseStorage = true;

  List<ProductVariantInput> _variants = [];

  final List<String> _categories = [
    'top',
    'bottom',
    'outerwear',
    'accessories',
  ];

  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
    
    // Add listeners for keyboard handling
    _notesFocus.addListener(() {
      if (_notesFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    _stockController.dispose();
    _scrollController.dispose();
    _nameFocus.dispose();
    _priceFocus.dispose();
    _supplierFocus.dispose();
    _stockFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  Future<void> _uploadImagesAsBase64(List<File> images) async {
    if (images.isEmpty) return;

    try {
      setState(() => _uploadingImages = true);
      
      List<String> urls = [];
      for (File image in images) {
        final fileSize = await image.length();
        if (fileSize > 2 * 1024 * 1024) {
          throw Exception('File size exceeds 2MB limit. Please choose smaller images or reduce quality.');
        }

        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        final mimeType = image.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
        urls.add('data:$mimeType;base64,$base64String');
      }

      _productImageUrls = urls;
      setState(() => _uploadingImages = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${images.length} image(s) processed successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Base64 upload error: $e');
      setState(() => _uploadingImages = false);
      _productImageUrls.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process images: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFiles.isNotEmpty) {
        // Check if adding these images would exceed the limit
        final currentCount = kIsWeb ? _productImageUrls.length : _productImages.length;
        final availableSlots = 6 - currentCount;
        
        if (availableSlots <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 6 images allowed'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        
        // Limit the selected files to available slots
        final filesToAdd = pickedFiles.take(availableSlots).toList();
        
        if (filesToAdd.length < pickedFiles.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Only ${filesToAdd.length} images added. Maximum 6 images allowed.'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        if (kIsWeb) {
          // On web, use bytes and base64
          List<String> urls = [];
          for (var picked in filesToAdd) {
            final bytes = await picked.readAsBytes();
            final mimeType = picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
            urls.add('data:$mimeType;base64,${base64Encode(bytes)}');
          }
          setState(() {
            _productImageUrls.addAll(urls);
            if (_primaryImageIndex >= _productImageUrls.length) _primaryImageIndex = 0;
          });
        } else {
          // On mobile/desktop, use File
          List<File> files = filesToAdd.map((picked) => File(picked.path)).toList();
          setState(() {
            _productImages.addAll(files);
            if (_primaryImageIndex >= _productImages.length) _primaryImageIndex = 0;
          });
          
          // Check if all files exist
          bool allExist = true;
          for (File file in files) {
            if (!await file.exists()) {
              allExist = false;
              break;
            }
          }
          
          if (allExist) {
            // Calculate total file size
            int totalSize = 0;
            for (File file in files) {
              totalSize += await file.length();
            }
            print('${files.length} images selected');
            print('Total size: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB');
            
            if (_useFirebaseStorage) {
              await _uploadImages();
            } else {
              await _uploadImagesAsBase64(files);
            }
          } else {
            throw Exception('Some selected files do not exist or are not accessible');
          }
        }
      }
    } catch (e) {
      print('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting images: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _uploadImages() async {
    if (_productImages.isEmpty) return;

    try {
      setState(() => _uploadingImages = true);

      List<String> urls = [];
      
      for (File image in _productImages) {
        final fileSize = await image.length();
        if (fileSize > 5 * 1024 * 1024) {
          throw Exception('File size exceeds 5MB limit. Please choose smaller images.');
        }

        final fileName = 'products/${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}';
        final ref = FirebaseStorage.instance.ref().child(fileName);

        print('Starting upload for file: $fileName');
        print('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

        final uploadTask = ref.putFile(image);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          print('Upload progress: ${progress.toStringAsFixed(1)}%');
        });

        await uploadTask;
        final url = await ref.getDownloadURL();
        urls.add(url);
        print('Upload successful! URL: $url');
      }

      _productImageUrls = urls;
      setState(() => _uploadingImages = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_productImages.length} image(s) uploaded successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Upload error: $e');
      setState(() => _uploadingImages = false);
      _productImageUrls.clear();

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
        await _uploadImagesAsBase64(_productImages);
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
                _uploadImages();
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
    print('DEBUG: _productImageUrls = $_productImageUrls');

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
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        price: double.parse(_priceController.text),
        categoryID: _selectedCategory, // ERDv9: Uses categoryID instead of category
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
          'colorID': variant.color, // ERDv9: Uses colorID instead of color
          'quantityInStock': variant.quantityInStock,
        });
      }

      // Create product images if processed
      if (_productImageUrls.isNotEmpty) {
        try {
          for (int i = 0; i < _productImageUrls.length; i++) {
            final productImageRef = FirebaseFirestore.instance.collection('productImages').doc();
            final productImage = ProductImage(
              id: productImageRef.id,
              productID: productRef.id,
              imageURL: _productImageUrls[i],
              isPrimary: i == _primaryImageIndex, // Mark the primary image
              uploadedBy: userId,
              uploadedAt: DateTime.now(),
            );
            await productImageRef.set(productImage.toMap());
          }
          
          // Update product with primary image URL
          if (_primaryImageIndex < _productImageUrls.length) {
            await FirebaseFirestore.instance
                .collection('products')
                .doc(productRef.id)
                .update({'imageURL': _productImageUrls[_primaryImageIndex]});
          }
        } catch (e, stackTrace) {
          print('DEBUG: ERROR saving product images: $e');
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
  }  double _calculateContainerHeight() {
    final imageCount = kIsWeb ? _productImageUrls.length : _productImages.length;
    if (imageCount == 0) return 160; // Default height for empty state
    
    final canAddMore = imageCount < 6;
    final totalSlots = canAddMore ? imageCount + 1 : imageCount;
    
    // Calculate grid height based on number of rows needed
    const crossAxisCount = 3;
    final rows = (totalSlots / crossAxisCount).ceil();
    final gridHeight = rows * 100.0 + (rows - 1) * 8.0; // 100px per item + 8px spacing
    
    // Add padding for the grid container (8px all around = 16px total vertical)
    return gridHeight + 16;
  }

Widget _buildImagePreview() {
  if (_uploadingImages) {
    return const Center(child: CircularProgressIndicator());
  } else if (_productImageUrls.isNotEmpty) {
    // Show multiple images in a grid layout
    return _buildImageGrid();
  } else if (!kIsWeb && _productImages.isNotEmpty) {
    // On mobile/desktop, show the file images
    return _buildImageGrid();
  } else {
    return GestureDetector(
      onTap: _pickImages,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt, color: Colors.orange, size: 40),
          const SizedBox(height: 8),
          Text(
            'Tap to upload product images',
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
                Text('Upload Images', style: TextStyle(color: Colors.orange)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Max size 5MB each, JPG/PNG',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

Widget _buildImageGrid() {
  final imageCount = kIsWeb ? _productImageUrls.length : _productImages.length;
  final canAddMore = imageCount < 6;
  final totalSlots = canAddMore ? imageCount + 1 : imageCount;
  
  // Calculate grid height based on number of rows needed
  final crossAxisCount = 3;
  final rows = (totalSlots / crossAxisCount).ceil();
  final gridHeight = rows * 100.0 + (rows - 1) * 8.0; // 100px per item + 8px spacing
  
  return Container(
    height: gridHeight,
    padding: const EdgeInsets.all(8), // Add consistent padding around the grid
    child: GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: totalSlots,
      itemBuilder: (context, index) {
        // Add button as last item if we can add more
        if (canAddMore && index == imageCount) {
          return GestureDetector(
            onTap: _pickImages,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey[400]!,
                  width: 2,
                ),
                color: Colors.grey[100],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add,
                    color: Colors.grey[600],
                    size: 32,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _primaryImageIndex = index;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image ${index + 1} set as primary'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: index == _primaryImageIndex 
                    ? Colors.orange 
                    : Colors.grey[300]!,
                width: index == _primaryImageIndex ? 3 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (kIsWeb)
                    Image.network(
                      _productImageUrls[index],
                      fit: BoxFit.cover,
                    )
                  else
                    Image.file(
                      _productImages[index],
                      fit: BoxFit.cover,
                    ),
                  if (index == _primaryImageIndex)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
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
            ),
          ),
        );
      },
    ),
  );
}

  void _removeImage(int index) {
    setState(() {
      if (kIsWeb) {
        _productImageUrls.removeAt(index);
      } else {
        _productImages.removeAt(index);
        if (_productImageUrls.length > index) {
          _productImageUrls.removeAt(index);
        }
      }
      
      // Adjust primary image index if necessary
      if (_primaryImageIndex >= index && _primaryImageIndex > 0) {
        _primaryImageIndex--;
      }
      
      // Reset primary index if no images left
      final imageCount = kIsWeb ? _productImageUrls.length : _productImages.length;
      if (_primaryImageIndex >= imageCount && imageCount > 0) {
        _primaryImageIndex = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[100]!, Colors.blue[200]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.inventory_2_rounded,
                            color: Colors.blue[700],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add New Product',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'Add product information to your inventory',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Form
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    MediaQuery.of(context).viewInsets.bottom + 100,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                // Product Image Upload
                Card(
                  elevation: 0,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey[200]!),
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
                        Container(
                          width: double.infinity,
                          height: (_productImages.isNotEmpty || _productImageUrls.isNotEmpty) 
                              ? _calculateContainerHeight() 
                              : 160,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (_productImages.isNotEmpty || _productImageUrls.isNotEmpty)
                                  ? Colors.orange[300]!
                                  : Colors.grey[300]!,
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                            color: (_productImages.isNotEmpty || _productImageUrls.isNotEmpty)
                                ? Colors.orange[50]
                                : Colors.grey[50],
                          ),
                            child: Stack(
                              children: [
                                Positioned.fill(child: _buildImagePreview()),
                                if ((_productImageUrls.isNotEmpty || _productImages.isNotEmpty) && !_uploadingImages)
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check, color: Colors.white, size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${kIsWeb ? _productImageUrls.length : _productImages.length}',
                                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ),
                        const SizedBox(height: 8),
                        if (_productImageUrls.isNotEmpty || _productImages.isNotEmpty)
                          Text(
                            'Tap images to select primary thumbnail. Orange star = primary image.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          )
                        else
                          Text(
                            'Upload product images. Select one or multiple images at once.',
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
                  elevation: 0,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey[200]!),
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
                          focusNode: _nameFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _priceFocus.requestFocus(),
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
                          elevation: 0,
                          color: Colors.grey[50],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey[200]!),
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
                                    focusNode: _priceFocus,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) => _supplierFocus.requestFocus(),
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
                          elevation: 0,
                          color: Colors.grey[50],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey[200]!),
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
                  elevation: 0,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey[200]!),
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
                          focusNode: _supplierFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _stockFocus.requestFocus(),
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
                  elevation: 0,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey[200]!),
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
                  elevation: 0,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey[200]!),
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
                          focusNode: _notesFocus,
                          textInputAction: TextInputAction.done,
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
                  elevation: 0,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey[200]!),
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
                  elevation: 0,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey[200]!),
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
      ),
    ],
  ),
        ),
      ),
    );
  }
}