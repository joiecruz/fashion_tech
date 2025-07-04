import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/services/fabric_operations_service.dart';
import 'lib/services/fabric_log_service.dart';
import 'lib/models/fabric_log.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fabric Logging Test',
      home: FabricLoggingTestPage(),
    );
  }
}

class FabricLoggingTestPage extends StatefulWidget {
  @override
  _FabricLoggingTestPageState createState() => _FabricLoggingTestPageState();
}

class _FabricLoggingTestPageState extends State<FabricLoggingTestPage> {
  final TextEditingController _remarksController = TextEditingController();
  String? _testFabricId;
  List<FabricLog> _logs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _remarksController.text = "Test fabric added for logging verification";
  }

  Future<void> _testAddFabric() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Create test fabric data
      final fabricData = {
        'name': 'Test Fabric ${DateTime.now().millisecondsSinceEpoch}',
        'type': 'cotton',
        'color': 'blue',
        'colorID': 'blue',
        'categoryID': 'cotton',
        'quantity': 100,
        'pricePerUnit': 25.50,
        'qualityGrade': 'A',
        'minOrder': 10,
        'isUpcycled': false,
        'swatchImageURL': null,
        'supplierID': null,
        'notes': 'Test fabric for logging',
        'createdBy': 'test_user',
        'createdAt': Timestamp.now(),
        'lastEdited': Timestamp.now(),
      };

      // Add fabric using the operations service
      _testFabricId = await FabricOperationsService.addFabric(
        fabricData: fabricData,
        createdBy: 'test_user',
        remarks: _remarksController.text.trim(),
      );

      print('Test fabric added with ID: $_testFabricId');
      
      // Wait a moment for Firestore to process
      await Future.delayed(Duration(seconds: 2));
      
      // Fetch the logs for this fabric
      await _fetchLogs();
      
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test fabric added successfully!')),
      );
    } catch (e) {
      print('Error adding test fabric: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _fetchLogs() async {
    if (_testFabricId == null) return;

    try {
      final logs = await FabricLogService.getFabricLogs(_testFabricId!);
      setState(() {
        _logs = logs;
      });
      print('Fetched ${logs.length} logs for fabric $_testFabricId');
      
      for (var log in logs) {
        print('Log: ${log.changeType} - ${log.quantityChanged} - ${log.remarks}');
      }
    } catch (e) {
      print('Error fetching logs: $e');
    }
  }

  Future<void> _testEditFabric() async {
    if (_testFabricId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add a test fabric first')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedData = {
        'quantity': 150, // Changed from 100 to 150
        'lastEdited': Timestamp.now(),
      };

      await FabricOperationsService.updateFabric(
        fabricId: _testFabricId!,
        updatedData: updatedData,
        updatedBy: 'test_user',
        remarks: 'Quantity updated in test - increased by 50 units',
      );

      print('Test fabric updated');
      
      // Wait a moment for Firestore to process
      await Future.delayed(Duration(seconds: 2));
      
      // Fetch the logs again
      await _fetchLogs();
      
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test fabric updated successfully!')),
      );
    } catch (e) {
      print('Error updating test fabric: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _testDeleteFabric() async {
    if (_testFabricId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add a test fabric first')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FabricOperationsService.deleteFabric(
        fabricId: _testFabricId!,
        deletedBy: 'test_user',
        remarks: 'Test fabric deleted for logging verification',
      );

      print('Test fabric deleted');
      
      // Wait a moment for Firestore to process
      await Future.delayed(Duration(seconds: 2));
      
      // Fetch the logs again
      await _fetchLogs();
      
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test fabric deleted successfully!')),
      );
    } catch (e) {
      print('Error deleting test fabric: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fabric Logging Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _remarksController,
              decoration: InputDecoration(
                labelText: 'Test Remarks',
                hintText: 'Enter remarks for testing',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _testAddFabric,
              child: Text('Test Add Fabric'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isLoading ? null : _testEditFabric,
              child: Text('Test Edit Fabric'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isLoading ? null : _testDeleteFabric,
              child: Text('Test Delete Fabric'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            if (_testFabricId != null) ...[
              Text('Test Fabric ID: $_testFabricId'),
              SizedBox(height: 10),
            ],
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fabric Logs (${_logs.length}):',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                log.changeType == FabricChangeType.add
                                    ? Icons.add_circle
                                    : log.changeType == FabricChangeType.deduct
                                        ? Icons.remove_circle
                                        : Icons.edit,
                                color: log.changeType == FabricChangeType.add
                                    ? Colors.green
                                    : log.changeType == FabricChangeType.deduct
                                        ? Colors.red
                                        : Colors.orange,
                              ),
                              title: Text(
                                '${log.changeType.toString().split('.').last.toUpperCase()} - ${log.quantityChanged} units',
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (log.remarks != null)
                                    Text(
                                      'Remarks: ${log.remarks}',
                                      style: TextStyle(fontStyle: FontStyle.italic),
                                    ),
                                  Text('Created: ${log.createdAt}'),
                                  Text('By: ${log.createdBy}'),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
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
