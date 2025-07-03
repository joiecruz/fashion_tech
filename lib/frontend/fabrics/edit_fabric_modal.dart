import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

class EditFabricModal extends StatefulWidget {
  final Map<String, dynamic> fabric;
  final String fabricId;
  const EditFabricModal({super.key, required this.fabric, required this.fabricId});

  @override
  State<EditFabricModal> createState() => _EditFabricModalState();
}

class _EditFabricModalState extends State<EditFabricModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _selectedType;
  late String _selectedColor;
  late TextEditingController _quantityController;
  late TextEditingController _expenseController;
  late String _selectedQuality;
  late TextEditingController _minOrderController;
  bool _isUpcycled = false;

  File? _swatchImage;
  String? _swatchImageUrl;
  bool _uploading = false;
  bool _useFirebaseStorage = false;

  final List<String> _typeOptions = [
    'Cotton', 'Polyester', 'Silk', 'Denim', 'Linen', 'Wool', 'Rayon', 'Other'
  ];
  final List<String> _colorOptions = [
    'White', 'Black', 'Red', 'Blue', 'Green', 'Yellow', 'Pink', 'Purple', 'Brown', 'Gray', 'Other'
  ];
  final List<String> _qualityOptions = [
    'Premium', 'Good', 'Standard', 'Low'
  ];

  @override
  void initState() {
    super.initState();
    final fabric = widget.fabric;
    _nameController = TextEditingController(text: fabric['name'] ?? '');
    _selectedType = _typeOptions.contains(fabric['type']) ? fabric['type'] : _typeOptions.first;
    _selectedColor = _colorOptions.contains(fabric['color']) ? fabric['color'] : _colorOptions.first;
    _quantityController = TextEditingController(text: (fabric['quantity'] ?? '').toString());
    _expenseController = TextEditingController(text: (fabric['pricePerUnit'] ?? '').toString());
    _selectedQuality = _qualityOptions.contains(fabric['qualityGrade']) ? fabric['qualityGrade'] : _qualityOptions.first;
    _minOrderController = TextEditingController(text: (fabric['minOrder'] ?? '').toString());
    _isUpcycled = fabric['isUpcycled'] ?? false;
    _swatchImageUrl = fabric['swatchImageURL'];
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
          SnackBar(content: const Text('Image processed successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _uploading = false);
      _swatchImageUrl = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process image: $e'), backgroundColor: Colors.red),
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
        // For web, use bytes directly; for mobile, use File
        if (kIsWeb) {
          final bytes = await picked.readAsBytes();
          final base64String = base64Encode(bytes);
          final mimeType = picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
          setState(() {
            _swatchImage = null;
            _swatchImageUrl = 'data:$mimeType;base64,$base64String';
          });
        } else {
          setState(() {
            _swatchImage = File(picked.path);
            _swatchImageUrl = null;
          });
          if (await _swatchImage!.exists()) {
            if (_useFirebaseStorage) {
              await _uploadImage();
            } else {
              await _uploadImageAsBase64();
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e'), backgroundColor: Colors.red),
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
      final uploadTask = ref.putFile(_swatchImage!);
      await uploadTask;
      _swatchImageUrl = await ref.getDownloadURL();
      setState(() => _uploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Image uploaded successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _uploading = false);
      _swatchImageUrl = null;
      if (_useFirebaseStorage) {
        _useFirebaseStorage = false;
        await _uploadImageAsBase64();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All upload methods failed: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (_swatchImage != null && _swatchImageUrl == null) {
      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 100));
      String message = _swatchImage == null
          ? 'Please select a fabric swatch image.'
          : _uploading
              ? 'Image is still uploading. Please wait for upload to complete.'
              : 'Image upload failed. Please try uploading the image again.';
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
      // Confirmation prompt before saving
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Save'),
          content: const Text('Are you sure you want to save changes to this fabric?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      // 1. Fetch previous data for undo
      final prevSnapshot = await FirebaseFirestore.instance
          .collection('fabrics')
          .doc(widget.fabricId)
          .get();
      final prevData = prevSnapshot.data();

      // 2. Prepare new data
      final updatedData = {
        'name': _nameController.text,
        'type': _selectedType,
        'color': _selectedColor,
        'quantity': int.tryParse(_quantityController.text) ?? 0,
        'pricePerUnit': double.tryParse(_expenseController.text) ?? 0.0,
        'qualityGrade': _selectedQuality,
        'minOrder': int.tryParse(_minOrderController.text) ?? 0,
        'isUpcycled': _isUpcycled,
        'swatchImageURL': _swatchImageUrl,
        'lastEdited': Timestamp.now(),
      };

      // 3. Update Firestore
      await FirebaseFirestore.instance
          .collection('fabrics')
          .doc(widget.fabricId)
          .update(updatedData);

      // 4. Show SnackBar with Undo
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Fabric updated successfully!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () async {
                if (prevData != null) {
                  await FirebaseFirestore.instance
                      .collection('fabrics')
                      .doc(widget.fabricId)
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
      }

      // 5. Close the modal
      Navigator.pop(context, updatedData);
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
                'Edit Fabric',
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
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('Swatch Image', style: TextStyle(fontWeight: FontWeight.w600)),
                            const Spacer(),
                            if (_swatchImageUrl != null)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: _uploading
                                    ? null
                                    : () {
                                        setState(() {
                                          _swatchImage = null;
                                          _swatchImageUrl = null;
                                        });
                                      },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _uploading ? null : _pickImage,
                          child: Container(
                            width: double.infinity,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: (_swatchImageUrl != null && _swatchImageUrl!.startsWith('data:image'))
                                ? Image.memory(
                                    base64Decode(_swatchImageUrl!.split(',').last),
                                    fit: BoxFit.cover,
                                  )
                                : (_swatchImageUrl != null && Uri.tryParse(_swatchImageUrl!)?.isAbsolute == true)
                                    ? Image.network(_swatchImageUrl!, fit: BoxFit.cover)
                                    : Icon(Icons.add_a_photo, color: Colors.grey[400], size: 48),
                          ),
                        ),
                        if (_uploading)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: LinearProgressIndicator(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Fabric Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter fabric name' : null,
                ),
                const SizedBox(height: 16),
                // Type & Color
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _typeOptions.contains(_selectedType) ? _selectedType : _typeOptions.first,
                        items: _typeOptions
                            .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedType = v ?? _typeOptions.first),
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _colorOptions.contains(_selectedColor) ? _selectedColor : _colorOptions.first,
                        items: _colorOptions
                            .map((color) => DropdownMenuItem(value: color, child: Text(color)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedColor = v ?? _colorOptions.first),
                        decoration: const InputDecoration(
                          labelText: 'Color',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Quantity & Price
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity (yards/meters)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter quantity' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _expenseController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price per Unit',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter price per unit' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Quality & Min Order
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _qualityOptions.contains(_selectedQuality) ? _selectedQuality : _qualityOptions.first,
                        items: _qualityOptions
                            .map((q) => DropdownMenuItem(
                                  value: q,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: _getQualityPreviewColor(q),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Text(q),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedQuality = v ?? _qualityOptions.first),
                        decoration: const InputDecoration(
                          labelText: 'Quality',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _minOrderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min Order',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter min order' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Upcycled Switch
                SwitchListTile(
                  value: _isUpcycled,
                  onChanged: (v) => setState(() => _isUpcycled = v),
                  title: const Text('Is Upcycled?'),
                  activeColor: Colors.green,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 20),
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
                      _uploading ? 'Uploading Image...' : 'Save Changes',
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