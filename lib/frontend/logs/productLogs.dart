import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ProductLogsPage extends StatefulWidget {
  const ProductLogsPage({Key? key}) : super(key: key);

  @override
  State<ProductLogsPage> createState() => _ProductLogsPageState();
}

class _ProductLogsPageState extends State<ProductLogsPage> {
  final user = FirebaseAuth.instance.currentUser;
  late final String? userId;
  bool _loading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    userId = user?.uid;
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _loading = true);
    final snapshot = await FirebaseFirestore.instance
        .collection('inventoryLogs')
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    setState(() {
      _logs = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'productID': data['productID'] ?? '',
          'supplierID': data['supplierID'] ?? '',
          'changeType': data['changeType'] ?? '',
          'quantityChanged': data['quantityChanged'] ?? 0,
          'remarks': data['remarks'] ?? '',
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
        };
      }).toList();
      _loading = false;
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Inventory Logs'),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: _logs.isEmpty
                    ? SizedBox(
                        height: 300,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              const Text(
                                'No inventory logs found.',
                                style: TextStyle(fontSize: 16, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Text(
                              'Recent Product Inventory Logs',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  headingRowColor: MaterialStateProperty.all(Colors.blueGrey[50]),
                                  columns: const [
                                    DataColumn(label: Text('Product ID')),
                                    DataColumn(label: Text('Supplier ID')),
                                    DataColumn(label: Text('Change Type')),
                                    DataColumn(label: Text('Qty')),
                                    DataColumn(label: Text('Remarks')),
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Edit')),
                                  ],
                                  rows: _logs.map((log) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(log['productID'].toString())),
                                        DataCell(Text(log['supplierID'].toString())),
                                        DataCell(Text(log['changeType'].toString())),
                                        DataCell(Text(log['quantityChanged'].toString())),
                                        DataCell(Text(log['remarks'].toString())),
                                        DataCell(Text(_formatDate(log['createdAt']))),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            tooltip: 'Edit Log',
                                            onPressed: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => EditProductLogPage(
                                                    logId: log['id'],
                                                    logData: log,
                                                  ),
                                                ),
                                              );
                                              _fetchLogs();
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
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

class EditProductLogPage extends StatefulWidget {
  final String logId;
  final Map<String, dynamic> logData;
  const EditProductLogPage({required this.logId, required this.logData, Key? key}) : super(key: key);

  @override
  State<EditProductLogPage> createState() => _EditProductLogPageState();
}

class _EditProductLogPageState extends State<EditProductLogPage> {
  final List<String> changeTypes = ['add', 'remove', 'adjust'];
  final List<String> remarksOptions = [
    'Stock In',
    'Stock Out',
    'Damaged',
    'Returned',
    'Adjustment',
    'Other'
  ];
  late TextEditingController supplierIDController;
  late TextEditingController quantityChangedController;

  String? selectedChangeType;
  String? selectedRemarks;

  @override
  void initState() {
    super.initState();
    selectedChangeType = widget.logData['changeType'];
    supplierIDController = TextEditingController(text: widget.logData['supplierID'] ?? '');
    quantityChangedController = TextEditingController(text: widget.logData['quantityChanged'].toString());
    selectedRemarks = widget.logData['remarks'] ?? '';
  }

  @override
  void dispose() {
    supplierIDController.dispose();
    quantityChangedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // For remarks dropdown, always include previous remarks if not present
    List<String> remarksDropdownValues = List.from(remarksOptions);
    if (selectedRemarks != null &&
        selectedRemarks!.isNotEmpty &&
        !remarksDropdownValues.contains(selectedRemarks)) {
      remarksDropdownValues.insert(0, selectedRemarks!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product Log'),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory, color: Colors.blueGrey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Product ID',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              widget.logData['productID'] ?? '',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Change Type', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButton<String>(
                      value: changeTypes.contains(selectedChangeType) ? selectedChangeType : null,
                      isExpanded: true,
                      underline: Container(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedChangeType = newValue;
                        });
                      },
                      items: changeTypes.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Supplier ID', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  ),
                  TextField(
                    controller: supplierIDController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter supplier ID',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Quantity Changed', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  ),
                  TextField(
                    controller: quantityChangedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter quantity changed',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Remarks', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButton<String>(
                      value: selectedRemarks != null && selectedRemarks!.isNotEmpty
                          ? selectedRemarks
                          : null,
                      isExpanded: true,
                      underline: Container(),
                      hint: const Text('Select remarks'),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedRemarks = newValue;
                        });
                      },
                      items: remarksDropdownValues
                          .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('inventoryLogs')
                                .doc(widget.logId)
                                .update({
                              'changeType': selectedChangeType,
                              'supplierID': supplierIDController.text,
                              'quantityChanged': int.tryParse(quantityChangedController.text) ?? 0,
                              'remarks': selectedRemarks ?? '',
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Product log updated successfully!'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}