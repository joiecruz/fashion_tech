import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class JobOrderLogsPage extends StatefulWidget {
  const JobOrderLogsPage({Key? key}) : super(key: key);

  @override
  State<JobOrderLogsPage> createState() => _JobOrderLogsPageState();
}

class _JobOrderLogsPageState extends State<JobOrderLogsPage> {
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
        .collection('jobOrderLogs')
        .orderBy('timestamp', descending: true)
        .get();

    setState(() {
      _logs = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'jobOrderID': data['jobOrderID'] ?? '',
          'changeType': data['changeType'] ?? '',
          'previousValue': data['previousValue'] ?? '',
          'newValue': data['newValue'] ?? '',
          'notes': data['notes'] ?? '',
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
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
        title: const Text('Job Order Logs'),
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
                                'No job order logs found.',
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
                              'Recent Job Order Logs',
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
                                    DataColumn(label: Text('Job Order ID')),
                                    DataColumn(label: Text('Change Type')),
                                    DataColumn(label: Text('Previous')),
                                    DataColumn(label: Text('New Value')),
                                    DataColumn(label: Text('Notes')),
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Edit')),
                                  ],
                                  rows: _logs.map((log) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(log['jobOrderID'].toString())),
                                        DataCell(Text(log['changeType'].toString())),
                                        DataCell(Text(log['previousValue'].toString())),
                                        DataCell(Text(log['newValue'].toString())),
                                        DataCell(Text(log['notes'].toString())),
                                        DataCell(Text(_formatDate(log['timestamp']))),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            tooltip: 'Edit Log',
                                            onPressed: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => EditJobOrderLogPage(
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

class EditJobOrderLogPage extends StatefulWidget {
  final String logId;
  final Map<String, dynamic> logData;
  const EditJobOrderLogPage({required this.logId, required this.logData, Key? key}) : super(key: key);

  @override
  State<EditJobOrderLogPage> createState() => _EditJobOrderLogPageState();
}

class _EditJobOrderLogPageState extends State<EditJobOrderLogPage> {
  final List<String> changeTypes = ['statusUpdate', 'reassign', 'edit'];
  final List<String> statusValues = ['Open', 'In Progress', 'Done'];
  final List<String> notesOptions = [
    'Started',
    'Paused',
    'Resumed',
    'Completed',
    'Delayed',
    'Other'
  ];

  late TextEditingController previousValueController;
  late TextEditingController newValueController;

  String? selectedChangeType;
  String? selectedNotes;

  @override
  void initState() {
    super.initState();
    selectedChangeType = widget.logData['changeType'];
    previousValueController = TextEditingController(text: widget.logData['previousValue'] ?? '');
    newValueController = TextEditingController(text: widget.logData['newValue'] ?? '');
    selectedNotes = widget.logData['notes'] ?? '';
  }

  @override
  void dispose() {
    previousValueController.dispose();
    newValueController.dispose();
    super.dispose();
  }

  bool isStatusUpdate() {
    return selectedChangeType == 'statusUpdate';
  }

  @override
  Widget build(BuildContext context) {
    // For status dropdowns, always include previous/new value if not present
    List<String> statusDropdownValues = List.from(statusValues);
    if (previousValueController.text.isNotEmpty &&
        !statusDropdownValues.contains(previousValueController.text)) {
      statusDropdownValues.insert(0, previousValueController.text);
    }
    if (newValueController.text.isNotEmpty &&
        !statusDropdownValues.contains(newValueController.text)) {
      statusDropdownValues.insert(0, newValueController.text);
    }

    // For notes dropdown, always include previous notes if not present
    List<String> notesDropdownValues = List.from(notesOptions);
    if (selectedNotes != null &&
        selectedNotes!.isNotEmpty &&
        !notesDropdownValues.contains(selectedNotes)) {
      notesDropdownValues.insert(0, selectedNotes!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Job Order Log'),
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
                      const Icon(Icons.assignment, color: Colors.blueGrey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Job Order ID',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              widget.logData['jobOrderID'] ?? '',
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
                          // Reset fields when change type changes
                          if (isStatusUpdate()) {
                            previousValueController.text = statusValues.contains(previousValueController.text)
                                ? previousValueController.text
                                : '';
                            newValueController.text = statusValues.contains(newValueController.text)
                                ? newValueController.text
                                : '';
                          }
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
                    child: Text('Previous Value', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  ),
                  isStatusUpdate()
                      ? Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DropdownButton<String>(
                            value: previousValueController.text.isNotEmpty
                                ? previousValueController.text
                                : null,
                            isExpanded: true,
                            underline: Container(),
                            hint: const Text('Select status'),
                            onChanged: (String? newValue) {
                              setState(() {
                                previousValueController.text = newValue ?? '';
                              });
                            },
                            items: statusDropdownValues
                                .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                                .toList(),
                          ),
                        )
                      : TextField(
                          controller: previousValueController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Enter previous value',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('New Value', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  ),
                  isStatusUpdate()
                      ? Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DropdownButton<String>(
                            value: newValueController.text.isNotEmpty
                                ? newValueController.text
                                : null,
                            isExpanded: true,
                            underline: Container(),
                            hint: const Text('Select status'),
                            onChanged: (String? newValue) {
                              setState(() {
                                newValueController.text = newValue ?? '';
                              });
                            },
                            items: statusDropdownValues
                                .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                                .toList(),
                          ),
                        )
                      : TextField(
                          controller: newValueController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Enter new value',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Notes', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButton<String>(
                      value: selectedNotes != null && selectedNotes!.isNotEmpty
                          ? selectedNotes
                          : null,
                      isExpanded: true,
                      underline: Container(),
                      hint: const Text('Select notes'),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedNotes = newValue;
                        });
                      },
                      items: notesDropdownValues
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
                                .collection('jobOrderLogs')
                                .doc(widget.logId)
                                .update({
                              'changeType': selectedChangeType,
                              'previousValue': previousValueController.text,
                              'newValue': newValueController.text,
                              'notes': selectedNotes ?? '',
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Job order log updated successfully!'),
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