import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // For kIsWeb
import '../../backend/fetch_suppliers.dart';
import '../../backend/add_supplier_fabric.dart';
import '../../services/fabric_operations_service.dart';
import '../common/simple_color_dropdown.dart';

class AddFabricModal extends StatefulWidget {
  const AddFabricModal({super.key});

  @override
  State<AddFabricModal> createState() => _AddFabricModalState();
}

class _AddFabricModalState extends State<AddFabricModal> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _nameController = TextEditingController();
  String _selectedType = 'Cotton';
  String _selectedColor = 'Black'; // Default color
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _expenseController = TextEditingController();
  String _selectedQuality = 'Good';
  final TextEditingController _minOrderController = TextEditingController();
  final TextEditingController _reasonsController = TextEditingController();
  
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _quantityFocus = FocusNode();
  final FocusNode _expenseFocus = FocusNode();
  final FocusNode _minOrderFocus = FocusNode();
  final FocusNode _reasonsFocus = FocusNode();
  
  bool _isUpcycled = false;

  // Supplier-related variables
  List<Map<String, dynamic>> _suppliers = [];
  String? _selectedSupplierId;
  bool _loadingSuppliers = true;

  File? _swatchImage;
  String? _swatchImageUrl;
  bool _uploading = false;
  bool _useFirebaseStorage = false; // Set to false to skip Firebase Storage and use base64 directly

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    
    // Add listeners for keyboard handling
    _reasonsFocus.addListener(() {
      if (_reasonsFocus.hasFocus) {
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

  Future<void> _loadSuppliers() async {
    try {
      final suppliers = await FetchSuppliersBackend.fetchAllSuppliers();
      setState(() {
        _suppliers = suppliers;
        _loadingSuppliers = false;
      });
    } catch (e) {
      print('Error loading suppliers: $e');
      setState(() {
        _loadingSuppliers = false;
      });
    }
  }

  Future<void> _uploadImageAsBase64() async {
    if (_swatchImage == null) return;

    try {
      setState(() => _uploading = true);
      final fileSize = await _swatchImage!.length();
      if (fileSize > 2 * 1024 * 1024) {
        throw Exception('File size exceeds 2MB limit. Please choose a smaller image or reduce quality.');
      }

      final bytes = await _swatchImage!.readAsBytes();
      final base64String = base64Encode(bytes);
      final mimeType = _swatchImage!.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

      _swatchImageUrl = 'data:$mimeType;base64,$base64String';

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
      _swatchImageUrl = null;

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
    XFile? picked;

    // Show dialog to choose between camera and gallery
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Take Photo'),
                subtitle: const Text('Use camera to take a new photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select from existing photos'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    // If user cancelled the dialog, return
    if (source == null) return;

    picked = await picker.pickImage(
      source: source,
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
          _swatchImage = null; // Not used on web
          _swatchImageUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
        });
      } else {
        // On mobile/desktop, use File
        setState(() {
          _swatchImage = File(picked!.path);
          _swatchImageUrl = null;
        });
        if (await _swatchImage!.exists()) {
          final fileSize = await _swatchImage!.length();
          print('Image selected: ${_swatchImage!.path}');
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
    if (_swatchImage == null) return;

    try {
      setState(() => _uploading = true);

      final fileSize = await _swatchImage!.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('File size exceeds 5MB limit. Please choose a smaller image.');
      }

      final fileName = 'swatches/${DateTime.now().millisecondsSinceEpoch}_${_swatchImage!.path.split('/').last}';
      final ref = FirebaseStorage.instance.ref().child(fileName);

      print('Starting upload for file: $fileName');
      print('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      final uploadTask = ref.putFile(_swatchImage!);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      await uploadTask;
      _swatchImageUrl = await ref.getDownloadURL();

      print('Upload successful! URL: $_swatchImageUrl');

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
      _swatchImageUrl = null;

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

void _submitForm() async {
  if (_swatchImageUrl == null) {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 100));

    String message = _uploading
        ? 'Image is still uploading. Please wait for upload to complete.'
        : 'Please select a fabric swatch image.';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Missing Swatch Image'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  if (_formKey.currentState!.validate()) {
    // Handle default values and auto-generation
    final fabricName = _nameController.text.trim().isEmpty 
        ? _generateFabricCode() 
        : _nameController.text.trim();
    
    final quantity = _quantityController.text.trim().isEmpty 
        ? 0.0 
        : (double.tryParse(_quantityController.text.trim()) ?? 0.0);
    
    final minOrder = _minOrderController.text.trim().isEmpty 
        ? 0.0 
        : (double.tryParse(_minOrderController.text.trim()) ?? 0.0);
    
    // Cross-field validation (only if both values are provided and > 0)
    if (quantity > 0 && minOrder > quantity) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Error'),
          content: const Text('Minimum order quantity cannot be greater than available quantity.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    
    try {
      // Prepare fabric data
      final fabricData = {
        'name': fabricName,
        'type': _selectedType,
        'colorID': _selectedColor, // ERDv9: Changed from 'color' to 'colorID'
        'categoryID': _selectedType, // ERDv9: Added categoryID field
        'quantity': quantity,
        'pricePerUnit': double.tryParse(_expenseController.text) ?? 0.0,
        'qualityGrade': _selectedQuality,
        'minOrder': minOrder,
        'isUpcycled': _isUpcycled,
        'swatchImageURL': _swatchImageUrl,
        'supplierID': _selectedSupplierId, // Add supplier ID for reference
        'notes': _reasonsController.text.trim().isEmpty ? null : _reasonsController.text.trim(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous', // ERDv8 requirement
        'createdAt': Timestamp.now(),
        'lastEdited': Timestamp.now(),
        'deletedAt': null, // Ensure deletedAt is set to null on creation
      };
      
      // Add fabric using the operations service with logging
      final fabricId = await FabricOperationsService.addFabric(
        fabricData: fabricData,
        createdBy: FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
        remarks: _reasonsController.text.trim().isEmpty 
            ? 'Initial fabric added to inventory' 
            : _reasonsController.text.trim(),
      );

      // If a supplier is selected, create the supplier-fabric relationship using backend service
      if (_selectedSupplierId != null) {
        await AddSupplierFabricBackend.addSupplierFabric(
          supplierID: _selectedSupplierId!,
          fabricID: fabricId,
          supplyPrice: double.tryParse(_expenseController.text) ?? 0.0,
          minOrder: minOrder.toInt(),
          daysToDeliver: null, // Can be updated later
        );
      }

      // Show success message
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: Text(_selectedSupplierId != null 
                ? 'Fabric and supplier relationship added successfully!' 
                : 'Fabric added successfully!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        Navigator.pop(context); // Go back after adding
        
      } catch (e) {
        print('Error adding fabric: $e');
        
        // Show error message
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to add fabric: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _expenseController.dispose();
    _minOrderController.dispose();
    _reasonsController.dispose();
    _scrollController.dispose();
    _nameFocus.dispose();
    _quantityFocus.dispose();
    _expenseFocus.dispose();
    _minOrderFocus.dispose();
    _reasonsFocus.dispose();
    super.dispose();
  }

  // Helper method to show validation summary
  void _showValidationSummary() async {
    final errors = <String>[];
    
    // Check only required fields
    if (_expenseController.text.trim().isEmpty) {
      errors.add('• Expense per yard is required');
    }
    if (_swatchImageUrl == null) {
      errors.add('• Swatch image is required');
    }
    
    if (errors.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Please Complete Required Fields'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The following fields need attention:'),
              const SizedBox(height: 8),
              ...errors.map((error) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(error, style: const TextStyle(color: Colors.red)),
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // Helper method to validate numeric fields
  bool _isValidNumber(String value, {bool allowZero = false}) {
    if (value.trim().isEmpty) return false;
    final number = double.tryParse(value.trim());
    return number != null && (allowZero ? number >= 0 : number > 0);
  }

  // Helper method to get field validation state
  bool _isFieldValid(String fieldName) {
    switch (fieldName) {
      case 'name':
        // Name is optional - always valid
        return true;
      case 'quantity':
        // Quantity is optional - always valid
        return true;
      case 'expense':
        return _isValidNumber(_expenseController.text, allowZero: true);
      case 'minOrder':
        // MinOrder is optional - always valid
        return true;
      case 'image':
        return _swatchImageUrl != null;
      default:
        return true;
    }
  }

  // Helper method to check if the entire form is valid
  bool _isFormValid() {
    return _isFieldValid('expense') && 
           _selectedType.isNotEmpty && 
           _selectedColor.isNotEmpty && 
           _selectedQuality.isNotEmpty;
  }

  // Helper method to generate unique fabric code
  String _generateFabricCode() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(7); // Last 6 digits
    final typeCode = _selectedType.substring(0, 2).toUpperCase();
    final colorCode = _selectedColor.substring(0, 2).toUpperCase();
    return 'FAB-$typeCode$colorCode-$timestamp';
  }

  Color _getQualityPreviewColor(String quality) {
    switch (quality.toLowerCase()) {
      case 'premium':
      case 'high':
        return Colors.amber[600]!;
      case 'good':
        return Colors.blue[600]!;
      case 'standard':
        return Colors.green[600]!;
      case 'low':
        return Colors.grey[600]!;
      default:
        return Colors.grey[400]!;
    }
  }

  Widget _buildImagePreview() {
    if (_uploading) {
      return const Center(child: CircularProgressIndicator());
    } else if (kIsWeb && _swatchImageUrl != null) {
      // On web, show the image from base64 url
      return Image.network(
        _swatchImageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (!kIsWeb && _swatchImage != null) {
      // On mobile/desktop, show the file image
      return Image.file(
        _swatchImage!,
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
            'Tap to take photo or upload image',
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
                Icon(Icons.camera_alt, color: Colors.orange, size: 18),
                SizedBox(width: 6),
                Text('Camera or Gallery', style: TextStyle(color: Colors.orange)),
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
                        colors: [Colors.green[100]!, Colors.green[200]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.palette_rounded,
                      color: Colors.green[700],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add New Fabric',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Add fabric information to your inventory',
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
        // Body
        Expanded(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // --- Swatch Image Upload Section ---
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.orange.shade200,
                        style: BorderStyle.solid,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.orange.shade50,
                    ),
                    child: Center(
                      child: Stack(
                        children: [
                          Positioned.fill(child: _buildImagePreview()),
                          if (_swatchImage != null)
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
                          if (_swatchImageUrl != null)
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
                          if (_swatchImage != null && _swatchImageUrl == null && !_uploading)
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.error, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Upload Failed',
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
                ),

                const SizedBox(height: 16),

                // Fabric Name Card
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
                          'Fabric Name',
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
                          onFieldSubmitted: (_) => _quantityFocus.requestFocus(),
                          decoration: InputDecoration(
                            hintText: 'Enter fabric name or leave empty for auto-generated code',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                            ),
                            errorMaxLines: 2,
                          ),
                          validator: (val) {
                            // Fabric name is optional - no validation needed
                            if (val != null && val.trim().isNotEmpty) {
                              final trimmed = val.trim();
                              if (trimmed.length > 100) return 'Fabric name is too long (max: 100 characters)';
                              // Allow letters, numbers, spaces, and common punctuation
                              if (!RegExp(r"^[a-zA-Z0-9\s\-\(\)\.,%]+$").hasMatch(trimmed)) {
                                return 'Please enter a valid fabric name (letters, numbers, spaces, hyphens only)';
                              }
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Type and Color Row
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Fabric Type
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
                                Row(
                                  children: [
                                    Text(
                                      'Fabric Type',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    Text(
                                      ' *',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Flexible(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedType,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade200),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                                      ),
                                      errorMaxLines: 2,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                    items: [
                                      'Cotton',
                                      'Silk',
                                      'Wool',
                                      'Linen',
                                      'Polyester',
                                      'Denim',
                                      'Chiffon',
                                      'Velvet',
                                      'Lace',
                                      'Leather',
                                      'Blend',
                                      'Other'
                                    ].map((String type) {
                                      return DropdownMenuItem(
                                        value: type,
                                        child: Text(
                                          type,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      );
                                    }).toList(),
                                    validator: (val) {
                                      if (val == null || val.isEmpty) return 'Please select a fabric type';
                                      return null;
                                    },
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedType = value!;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Color
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
                                Row(
                                  children: [
                                    Text(
                                      'Color',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    Text(
                                      ' *',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Simple color dropdown to avoid stack overflow
                                SimpleColorDropdown(
                                  selectedColor: _selectedColor,
                                  onChanged: (value) {
                                    if (value != null && value != _selectedColor) {
                                      setState(() {
                                        _selectedColor = value;
                                      });
                                    }
                                  },
                                  isRequired: true,
                                  validator: (val) {
                                    if (val == null || val.isEmpty) return 'Please select a color';
                                    return null;
                                  },
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

                // Quantity and Expense Row
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Quantity
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
                                  'Quantity',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Flexible(
                                  child: TextFormField(
                                    controller: _quantityController,
                                    focusNode: _quantityFocus,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) => _expenseFocus.requestFocus(),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      hintText: 'Enter quantity or leave empty for 0',
                                      suffixText: 'yards',
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade200),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                                      ),
                                      errorMaxLines: 2,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                    validator: (val) {
                                      // Quantity is optional - only validate if provided
                                      if (val != null && val.trim().isNotEmpty) {
                                        final trimmed = val.trim();
                                        final quantity = double.tryParse(trimmed);
                                        if (quantity == null) return 'Please enter a valid number';
                                        if (quantity < 0) return 'Quantity cannot be negative';
                                        // Allow multiple decimal places - no restriction
                                      }
                                      return null;
                                    },
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Expense
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
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Expense per yard (₱)',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                    Text(
                                      ' *',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Flexible(
                                  child: TextFormField(
                                    controller: _expenseController,
                                    focusNode: _expenseFocus,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) => _minOrderFocus.requestFocus(),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      hintText: 'Enter cost per yard (e.g., 150.50)',
                                      suffixText: '₱/yard',
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade200),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                                      ),
                                      errorMaxLines: 2,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                    validator: (val) {
                                      if (val?.isEmpty ?? true) return 'Expense per yard is required';
                                      final trimmed = val!.trim();
                                      if (trimmed.isEmpty) return 'Expense cannot be empty';
                                      final expense = double.tryParse(trimmed);
                                      if (expense == null) return 'Please enter a valid amount';
                                      if (expense < 0) return 'Expense cannot be negative';
                                      if (expense > 100000) return 'Expense is too large (max: ₱100,000/yard)';
                                      // Check for reasonable decimal precision (max 2 decimal places)
                                      if (trimmed.contains('.') && trimmed.split('.')[1].length > 2) {
                                        return 'Please use at most 2 decimal places';
                                      }
                                      return null;
                                    },
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
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

                // Quality Grade and Min Order Row
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Quality Grade
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
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Quality Grade',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                    Text(
                                      ' *',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Flexible(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedQuality,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade200),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                                      ),
                                      errorMaxLines: 2,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                    items: [
                                      'Premium',
                                      'High',
                                      'Good',
                                      'Standard',
                                      'Low'
                                    ].map((String quality) {
                                      return DropdownMenuItem<String>(
                                        value: quality,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: _getQualityPreviewColor(quality),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              quality,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    validator: (val) {
                                      if (val == null || val.isEmpty) return 'Please select a quality grade';
                                      return null;
                                    },
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedQuality = value!;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Minimum Order
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
                                  'Min Order Qty',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Flexible(
                                  child: TextFormField(
                                    controller: _minOrderController,
                                    focusNode: _minOrderFocus,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) => _reasonsFocus.requestFocus(),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      hintText: 'Enter minimum order or leave empty for 0',
                                      suffixText: 'yards',
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade200),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                                      ),
                                      errorMaxLines: 2,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                    validator: (val) {
                                      // Minimum order is optional - only validate if provided
                                      if (val != null && val.trim().isNotEmpty) {
                                        final trimmed = val.trim();
                                        final minOrder = double.tryParse(trimmed);
                                        if (minOrder == null) return 'Please enter a valid number';
                                        if (minOrder < 0) return 'Minimum order cannot be negative';
                                        // Allow multiple decimal places - no restriction
                                      }
                                      return null;
                                    },
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
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

                // Supplier Selection Card
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
                          'Supplier',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _loadingSuppliers
                            ? Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                value: _selectedSupplierId,
                                hint: const Text('Select a supplier (optional)'),
                                isExpanded: true,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                                  ),
                                  errorMaxLines: 2,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                items: [
                                  // None option
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('No supplier'),
                                  ),
                                  // Supplier options
                                  ..._suppliers.map((supplier) {
                                    return DropdownMenuItem<String>(
                                      value: supplier['supplierID'],
                                      child: Text(
                                        supplier['supplierName'] ?? 'Unknown Supplier',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }),
                                ],
                                // Note: No validator needed since supplier selection is optional
                                onChanged: (value) {
                                  setState(() {
                                    _selectedSupplierId = value;
                                  });
                                },
                              ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Sustainability Properties Card
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
                          'Sustainability Properties',
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
                              Icons.eco,
                              color: Colors.green[600],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Upcycled Fabric',
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
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Notes & Reasons Card
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
                          'Notes & Reasons',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _reasonsController,
                          focusNode: _reasonsFocus,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            hintText: 'Any additional notes about this fabric...',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                            ),
                            errorMaxLines: 2,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          maxLines: 3,
                          maxLength: 200,
                          validator: (val) {
                            if (val != null && val.isNotEmpty) {
                              final trimmed = val.trim();
                              if (trimmed.length > 200) return 'Notes are too long (max: 200 characters)';
                              // Check for reasonable note content (prevent just special characters)
                              if (trimmed.isNotEmpty && !RegExp(r'[a-zA-Z0-9]').hasMatch(trimmed)) {
                                return 'Notes should contain meaningful text';
                              }
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Help Text Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Before You Save',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Make sure all required fields are filled out correctly\n'
                        '• Upload a clear swatch image for better identification\n'
                        '• Double-check quantities and pricing information\n'
                        '• Review supplier selection if applicable',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Validation Status Indicator
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isFormValid() ? Colors.green.shade50 : Colors.orange.shade50,
                    border: Border.all(
                      color: _isFormValid() ? Colors.green.shade200 : Colors.orange.shade200,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isFormValid() ? Icons.check_circle : Icons.warning,
                        color: _isFormValid() ? Colors.green.shade600 : Colors.orange.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isFormValid() 
                              ? 'All required fields are complete'
                              : 'Please complete all required fields',
                          style: TextStyle(
                            color: _isFormValid() ? Colors.green.shade800 : Colors.orange.shade800,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_uploading || (_swatchImage != null && _swatchImageUrl == null)) 
                        ? null 
                        : () {
                            // Show validation summary if form is invalid
                            if (!_formKey.currentState!.validate()) {
                              _showValidationSummary();
                              return;
                            }
                            _submitForm();
                          },
                    icon: _uploading 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save, size: 20),
                    label: Text(
                      _uploading ? 'Uploading Image...' : 'Save Fabric',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Retry Upload Section
                if (_swatchImage != null && _swatchImageUrl == null && !_uploading)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Colors.orange[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange[600], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Image Upload Failed',
                                  style: TextStyle(
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'The image upload failed. Please try uploading again.',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _useFirebaseStorage = false;
                                  _uploadImageAsBase64();
                                },
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Retry Upload'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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
    );
  }
}