import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(home: JobOrderPage()));
}

class JobOrderPage extends StatefulWidget {
  @override
  _JobOrderPageState createState() => _JobOrderPageState();
}

class _JobOrderPageState extends State<JobOrderPage> {
  final _formKey = GlobalKey<FormState>();
  String _jobName = '';
  String _clientName = '';
  DateTime? _dueDate;

  String? selectedFabricId;
  double? yardageUsed;
  List<Map<String, dynamic>> _jobOrderDetails = [];

  List<DocumentSnapshot> _fabricList = [];

  @override
  void initState() {
    super.initState();
    fetchFabrics();
  }

  void fetchFabrics() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('FABRIC').get();
    setState(() {
      _fabricList = snapshot.docs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Job Order')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  decoration: InputDecoration(labelText: 'Job Name'),
                  onSaved: (value) => _jobName = value ?? '',
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Enter job name' : null,
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Client Name'),
                  onSaved: (value) => _clientName = value ?? '',
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter client name'
                      : null,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _pickDueDate,
                  child: Text(_dueDate == null
                      ? 'Pick Due Date'
                      : 'Due Date: ${_dueDate!.toLocal().toString().split(' ')[0]}'),
                ),
                Divider(height: 32),
                Text('Add Fabric Usage', style: TextStyle(fontWeight: FontWeight.bold)),

                DropdownButtonFormField<String>(
                  value: selectedFabricId,
                  items: _fabricList.map((fabric) {
                    return DropdownMenuItem(
                      value: fabric.id,
                      child: Text(fabric['Name']),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() {
                    selectedFabricId = value;
                  }),
                  decoration: InputDecoration(labelText: 'Select Fabric'),
                  validator: (value) =>
                      value == null ? 'Select a fabric' : null,
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Yardage Used'),
                  keyboardType: TextInputType.number,
                  onChanged: (val) =>
                      yardageUsed = double.tryParse(val) ?? 0,
                  validator: (val) {
                    final parsed = double.tryParse(val ?? '');
                    return (parsed == null || parsed <= 0)
                        ? 'Enter valid yardage'
                        : null;
                  },
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedFabricId != null && yardageUsed != null) {
                      setState(() {
                        _jobOrderDetails.add({
                          'fabricID': selectedFabricId,
                          'yardageUsed': yardageUsed!,
                        });
                        selectedFabricId = null;
                        yardageUsed = null;
                      });
                    }
                  },
                  child: Text('Add Fabric'),
                ),
                SizedBox(height: 16),
                ..._jobOrderDetails.map((d) => Text(
                    'Fabric: ${d['fabricID']} - Used: ${d['yardageUsed']} yards')),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _submitForm,
                  child: Text('Submit Job Order'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pickDueDate() async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        _dueDate = date;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final jobOrderRef =
          await FirebaseFirestore.instance.collection('jobOrders').add({
        'jobName': _jobName,
        'clientName': _clientName,
        'dueDate': _dueDate,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      for (var detail in _jobOrderDetails) {
        final fabricRef = FirebaseFirestore.instance
            .collection('fabrics')
            .doc(detail['fabricID']);
        final fabricDoc = await fabricRef.get();
        final currentQty = fabricDoc['quantity'] ?? 0;

        final newQty = currentQty - detail['yardageUsed'];
        if (newQty < 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Insufficient fabric (${detail['fabricID']}) to complete order.')));
          return;
        }

        // Deduct fabric
        await fabricRef.update({'Quantity': newQty});

        // Add job order detail
        await jobOrderRef.collection('jobOrders').add({
          'fabricID': detail['fabricID'],
          'yardageUsed': detail['yardageUsed'],
        });
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Job Order Created')));
      Navigator.pop(context);
    }
  }
}
