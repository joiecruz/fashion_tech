import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'add_fabric.dart';
import 'home_dashboard.dart'; // Import your HomeDashboard

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const const MyApp());
}

class ImageConstants {
  static final ImageConstants constants = ImageConstants._();
  factory ImageConstants() => constants;
  ImageConstants._();

  String convertBytesToBase64(Uint8List bytes) {
    String base64Image = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64Image';
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fashion Tech',
      home: Scaffold(
        appBar: AppBar(title: const Text('Fashion Tech Home')),
        body: const Center(
          child: AddFabricForm(),
        ),
      ),
    );
  }
}

class AddFabricForm extends StatefulWidget {
  const AddFabricForm({super.key});

  @override
  State<AddFabricForm> createState() => _AddFabricFormState();
}

class _AddFabricFormState extends State<AddFabricForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _typeController = TextEditingController();
  final _colorController = TextEditingController();
  final _qualityGradeController = TextEditingController();
  final _quantityController = TextEditingController();
  final _expensePerYardController = TextEditingController();
  bool _isUpcycled = false;

  Uint8List? _swatchImageBytes;
  String? _swatchImageName;

  @override
  void dispose() {
    _nameController.dispose();
    _minOrderController.dispose();
    _typeController.dispose();
    _colorController.dispose();
    _qualityGradeController.dispose();
    _quantityController.dispose();
    _expensePerYardController.dispose();
    super.dispose();
  }

  Future<void> _pickSwatchImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _swatchImageBytes = result.files.single.bytes;
        _swatchImageName = result.files.single.name;
      });
    }
  }

  Future<void> _deleteSwatchImage() async {
    setState(() {
      _swatchImageBytes = null;
      _swatchImageName = null;
    });
  }

  Future<void> _addFabricWithBase64() async {
    try {
      print('Preparing to add fabric...');
      String? base64Image;
      if (_swatchImageBytes != null) {
        base64Image = ImageConstants().convertBytesToBase64(_swatchImageBytes!);
        print('Image converted to base64, length: ${base64Image.length}');
      }
      await addFabric(
        name: _nameController.text,
        minOrder: int.parse(_minOrderController.text),
        type: _typeController.text,
        color: _colorController.text,
        isUpcycled: _isUpcycled,
        qualityGrade: _qualityGradeController.text,
        quantity: double.parse(_quantityController.text),
        swatchImageURL: base64Image ?? '',
        expensePerYard: double.parse(_expensePerYardController.text),
      );
      print('Fabric added!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fabric added!')),
      );
      _formKey.currentState!.reset();
      _nameController.clear();
      _minOrderController.clear();
      _typeController.clear();
      _colorController.clear();
      _qualityGradeController.clear();
      _quantityController.clear();
      _expensePerYardController.clear();
      setState(() {
        _swatchImageBytes = null;
        _swatchImageName = null;
        _isUpcycled = false;
      });
    } catch (e) {
      print('Error during add fabric: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.isEmpty ? 'Enter name' : null,
                ),
                TextFormField(
                  controller: _minOrderController,
                  decoration: const InputDecoration(labelText: 'Min Order'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.isEmpty ? 'Enter min order' : null,
                ),
                TextFormField(
                  controller: _typeController,
                  decoration: const InputDecoration(labelText: 'Type'),
                  validator: (value) => value == null || value.isEmpty ? 'Enter type' : null,
                ),
                TextFormField(
                  controller: _colorController,
                  decoration: const InputDecoration(labelText: 'Color'),
                  validator: (value) => value == null || value.isEmpty ? 'Enter color' : null,
                ),
                TextFormField(
                  controller: _qualityGradeController,
                  decoration: const InputDecoration(labelText: 'Quality Grade'),
                  validator: (value) => value == null || value.isEmpty ? 'Enter quality grade' : null,
                ),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.isEmpty ? 'Enter quantity' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text('Select Swatch Image'),
                      onPressed: _pickSwatchImage,
                    ),
                    const SizedBox(width: 12),
                    if (_swatchImageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _swatchImageBytes!,
                          height: 48,
                          width: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                    if (_swatchImageBytes != null)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Remove Image',
                        onPressed: _deleteSwatchImage,
                      ),
                  ],
                ),
                if (_swatchImageName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _swatchImageName!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _expensePerYardController,
                  decoration: const InputDecoration(labelText: 'Expense Per Yard'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.isEmpty ? 'Enter expense per yard' : null,
                ),
                SwitchListTile(
                  title: const Text('Is Upcycled?'),
                  value: _isUpcycled,
                  onChanged: (val) => setState(() => _isUpcycled = val),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate() && _swatchImageBytes != null) {
                      await _addFabricWithBase64();
                    } else if (_swatchImageBytes == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a swatch image!')),
                      );
                    }
                  },
                  child: const Text('Add Fabric'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}