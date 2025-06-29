import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // For kIsWeb
import '../../utils/utils.dart';

class AddFabricModal extends StatefulWidget {
  const AddFabricModal({super.key});

  @override
  State<AddFabricModal> createState() => _AddFabricModalState();
}

class _AddFabricModalState extends State<AddFabricModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  String _selectedType = 'Cotton';
  String _selectedColor = ColorUtils.colorOptions.first;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _expenseController = TextEditingController();
  String _selectedQuality = 'Good';
  final TextEditingController _minOrderController = TextEditingController();
  final TextEditingController _reasonsController = TextEditingController();
  bool _isUpcycled = false;

  File? _swatchImage;
  String? _swatchImageUrl;
  bool _uploading = false;
  bool _useFirebaseStorage = false; // Set to false to skip Firebase Storage and use base64 directly

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
          _swatchImage = null; // Not used on web
          _swatchImageUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
        });
      } else {
        // On mobile/desktop, use File
        setState(() {
          _swatchImage = File(picked.path);
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
      final currentUser = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('fabrics').add({
        'name': _nameController.text,
        'type': _selectedType,
        'color': _selectedColor,
        'quantity': int.tryParse(_quantityController.text) ?? 0,
        'pricePerUnit': double.tryParse(_expenseController.text) ?? 0.0,
        'qualityGrade': _selectedQuality,
        'minOrder': int.tryParse(_minOrderController.text) ?? 0,
        'isUpcycled': _isUpcycled,
        'swatchImageURL': _swatchImageUrl,
        'createdBy': currentUser?.uid ?? 'anonymous', // ERDv8 requirement
        'createdAt': Timestamp.now(),
        'lastEdited': Timestamp.now(),
      });

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Success'),
          content: const Text('Fabric added successfully!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      Navigator.pop(context);
    }
  }
  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _expenseController.dispose();
    _minOrderController.dispose();
    _reasonsController.dispose();
    super.dispose();
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
                'Add New Fabric',
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
                          decoration: InputDecoration(
                            hintText: 'Enter fabric name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.blue[600]!),
                            ),
                          ),
                          validator: (val) => val!.isEmpty ? 'Please enter a fabric name' : null,
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
                                Text(
                                  'Fabric Type',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Flexible(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedType,
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
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedType = value!;
                                      });
                                    },
                                    validator: (val) => val == null ? 'Required' : null,
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
                                Text(
                                  'Color',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Flexible(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedColor,
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
                                    selectedItemBuilder: (context) {
                                      return ColorUtils.buildColorSelectedItems(context, size: 16);
                                    },
                                    items: ColorUtils.buildColorDropdownItems(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedColor = value!;
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
                                  'Quantity (yards)',
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
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: '0',
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
                                Text(
                                  'Expense per yard (₱)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Flexible(
                                  child: TextFormField(
                                    controller: _expenseController,
                                    keyboardType: TextInputType.number,
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
                                Text(
                                  'Quality Grade',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Flexible(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedQuality,
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
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: '0',
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

                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_uploading || (_swatchImage != null && _swatchImageUrl == null)) 
                        ? null 
                        : _submitForm,
                    icon: const Icon(Icons.save, size: 20),
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

                TextFormField(
                  controller: _reasonsController,
                  decoration: const InputDecoration(
                    labelText: 'Notes & Reasons',
                    hintText: 'Any additional notes about this fabric...',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),

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
      ],
    );
  }
}