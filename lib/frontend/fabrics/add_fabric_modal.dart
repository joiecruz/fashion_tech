import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:convert';
import '../../utils/utils.dart';

class AddFabricModal extends StatefulWidget {
  const AddFabricModal({super.key});

  @override
  State<AddFabricModal> createState() => _AddFabricModalState();
}

class _AddFabricModalState extends State<AddFabricModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  String _selectedType = 'Cotton'; // Changed to dropdown
  String _selectedColor = ColorUtils.colorOptions.first;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _expenseController = TextEditingController();
  String _selectedQuality = 'Good'; // Changed to dropdown
  final TextEditingController _minOrderController = TextEditingController();
  bool _isUpcycled = false;

  File? _swatchImage;
  String? _swatchImageUrl;
  bool _uploading = false;
  bool _useFirebaseStorage = false; // Set to false to skip Firebase Storage and use base64 directly

  Future<void> _uploadImageAsBase64() async {
    if (_swatchImage == null) return;
    
    try {
      setState(() => _uploading = true);          // Check file size (2MB limit for base64 to avoid large document sizes)
          final fileSize = await _swatchImage!.length();
          if (fileSize > 2 * 1024 * 1024) { // 2MB in bytes
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
        setState(() {
          _swatchImage = File(picked.path);
          _swatchImageUrl = null; // Reset URL when new image is picked
        });
        
        // Check if file exists and is readable
        if (await _swatchImage!.exists()) {
          final fileSize = await _swatchImage!.length();
          print('Image selected: ${_swatchImage!.path}');
          print('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
          
          // Try Firebase Storage first, fallback to base64 if it fails
          if (_useFirebaseStorage) {
            await _uploadImage();
          } else {
            // Use base64 encoding directly (no Firebase Storage needed)
            await _uploadImageAsBase64();
          }
        } else {
          throw Exception('Selected file does not exist or is not accessible');
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
      
      // Check file size (5MB limit)
      final fileSize = await _swatchImage!.length();
      if (fileSize > 5 * 1024 * 1024) { // 5MB in bytes
        throw Exception('File size exceeds 5MB limit. Please choose a smaller image.');
      }
      
      final fileName = 'swatches/${DateTime.now().millisecondsSinceEpoch}_${_swatchImage!.path.split('/').last}';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      
      print('Starting upload for file: $fileName');
      print('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      
      final uploadTask = ref.putFile(_swatchImage!);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('Upload progress: ${progress.toStringAsFixed(1)}%');
      });
      
      await uploadTask;
      _swatchImageUrl = await ref.getDownloadURL();
      
      print('Upload successful! URL: $_swatchImageUrl');
      
      setState(() => _uploading = false);
      
      // Show success feedback
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
      
      // Clear the failed upload
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
      
      // Fallback to base64 upload if Firebase Storage fails
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
                _useFirebaseStorage = true; // Reset to try Firebase Storage again
                _uploadImage();
              },
            ),
          ),
        );
      }
    }
  }

  void _submitForm() async {
    // Check if image is selected and uploaded
    if (_swatchImage == null || _swatchImageUrl == null) {
      FocusScope.of(context).unfocus(); // Dismiss keyboard if open
      await Future.delayed(const Duration(milliseconds: 100)); // Ensure dialog is visible
      
      String message;
      if (_swatchImage == null) {
        message = 'Please select a fabric swatch image.';
      } else if (_uploading) {
        message = 'Image is still uploading. Please wait for upload to complete.';
      } else {
        message = 'Image upload failed. Please try uploading the image again.';
      }
      
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

      Navigator.pop(context); // Go back after adding
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _expenseController.dispose();
    _minOrderController.dispose();
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
                // Swatch Image Upload Card
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
                              'Fabric Swatch Image',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Image Upload Area
                        GestureDetector(
                          onTap: _uploading ? null : _pickImage,
                          child: Container(
                            width: double.infinity,
                            height: _swatchImage != null ? 220 : 160,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _swatchImage != null ? Colors.orange[300]! : Colors.grey[300]!,
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                              color: _swatchImage != null ? Colors.orange[50] : Colors.grey[50],
                            ),
                            child: _uploading
                                ? Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: Colors.black54,
                                    ),
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'Uploading...',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : (_swatchImage != null && _swatchImage!.existsSync())
                                    ? Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.file(
                                              _swatchImage!,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          if (_swatchImageUrl != null)
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black26,
                                                      blurRadius: 4,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
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
                                              top: 8,
                                              left: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black26,
                                                      blurRadius: 4,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
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
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 4,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: IconButton(
                                                icon: Icon(Icons.edit, color: Colors.orange[600], size: 20),
                                                onPressed: _uploading ? null : _pickImage,
                                                padding: const EdgeInsets.all(8),
                                                constraints: const BoxConstraints(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.orange[100],
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.add_a_photo,
                                              size: 32,
                                              color: Colors.orange[600],
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Tap to upload fabric swatch',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.orange[700],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Max size 2MB, JPG/PNG',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                          ),
                        ),

                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Upload a clear image of the fabric swatch for easy identification',
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: _uploading
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
                      _uploading ? 'Uploading Image...' : 'Save Fabric',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
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
                                  _useFirebaseStorage = false; // Use base64 directly
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