import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class AddFabricPage extends StatefulWidget {
  const AddFabricPage({super.key});

  @override
  State<AddFabricPage> createState() => _AddFabricPageState();
}

class _AddFabricPageState extends State<AddFabricPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _expenseController = TextEditingController();
  final TextEditingController _qualityController = TextEditingController();

  bool _isUpcycled = false;
  File? _swatchImage;
  String? _swatchImageUrl;
  bool _uploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _swatchImage = File(picked.path);
      });
      await _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    if (_swatchImage == null) return;
    setState(() => _uploading = true);
    final fileName = 'swatches/${DateTime.now().millisecondsSinceEpoch}_${_swatchImage!.path.split('/').last}';
    final ref = FirebaseStorage.instance.ref().child(fileName);
    await ref.putFile(_swatchImage!);
    _swatchImageUrl = await ref.getDownloadURL();
    setState(() => _uploading = false);
  }

  void _submitForm() async {
    if (_swatchImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a fabric swatch image.')),
      );
      return;
    }
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance.collection('fabrics').add({
        'name': _nameController.text,
        'type': _typeController.text,
        'color': _colorController.text,
        'quantity': int.tryParse(_quantityController.text) ?? 0,
        'expensePerYard': double.tryParse(_expenseController.text) ?? 0.0,
        'qualityGrade': _qualityController.text,
        'swatchImageURL': _swatchImageUrl,
        'isUpcycled': _isUpcycled,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Fabric added successfully!'),
      ));

      Navigator.pop(context); // Go back after adding
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Fabric Entry')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
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
                  child: _uploading
                      ? const CircularProgressIndicator()
                      : _swatchImage != null
                          ? Image.file(_swatchImage!, fit: BoxFit.cover, width: 120, height: 120)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, color: Colors.orange, size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to upload fabric image',
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
                            ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Fabric Details Form ---
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Fabric Name'),
                    validator: (val) => val!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _typeController,
                    decoration: const InputDecoration(labelText: 'Fabric Type'),
                  ),
                  TextFormField(
                    controller: _colorController,
                    decoration: const InputDecoration(labelText: 'Color'),
                  ),
                  TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(labelText: 'Quantity (yards)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _expenseController,
                    decoration: const InputDecoration(labelText: 'Expense per yard'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _qualityController,
                    decoration: const InputDecoration(labelText: 'Quality Grade'),
                  ),
                  SwitchListTile(
                    value: _isUpcycled,
                    onChanged: (val) => setState(() => _isUpcycled = val),
                    title: const Text('Is Upcycled?'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _submitForm,
                    child: const Text('Add Fabric'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
