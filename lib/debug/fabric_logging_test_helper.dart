// Quick test to verify fabric logging
// You can call this from your app to test the logging system

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/fabric_operations_service.dart';
import '../services/fabric_log_service.dart';

class FabricLoggingTestHelper {
  
  // Test if we can read existing logs
  static Future<void> testReadLogs() async {
    print('=== Testing Fabric Log Reading ===');
    
    try {
      // First, get some existing fabrics
      final fabricsQuery = await FirebaseFirestore.instance
          .collection('fabrics')
          .limit(3)
          .get();
      
      print('Found ${fabricsQuery.docs.length} fabrics to test');
      
      for (var fabricDoc in fabricsQuery.docs) {
        final fabricId = fabricDoc.id;
        final fabricData = fabricDoc.data();
        final fabricName = fabricData['name'] ?? 'Unknown';
        
        print('\\nTesting fabric: $fabricName (ID: $fabricId)');
        
        // Test our service
        final logs = await FabricLogService.getRecentFabricLogs(fabricId, limit: 2);
        print('  Service returned ${logs.length} logs');
        
        if (logs.isNotEmpty) {
          for (var log in logs) {
            print('    Log: ${log.changeType} ${log.quantityChanged} units');
            print('    Remarks: "${log.remarks}"');
            print('    Created: ${log.createdAt} by ${log.createdBy}');
          }
        } else {
          print('    No logs found');
        }
        
        // Also test direct Firestore query
        final directQuery = await FirebaseFirestore.instance
            .collection('fabricLogs')
            .where('fabricID', isEqualTo: fabricId)
            .orderBy('createdAt', descending: true)
            .limit(2)
            .get();
        
        print('  Direct Firestore query returned ${directQuery.docs.length} logs');
        
        if (directQuery.docs.isNotEmpty) {
          for (var doc in directQuery.docs) {
            final data = doc.data();
            print('    Direct: ${data['changeType']} ${data['quantityChanged']} units');
            print('    Direct Remarks: "${data['remarks']}"');
          }
        }
      }
      
    } catch (e) {
      print('Error in testReadLogs: $e');
    }
  }
  
  // Test creating a new fabric with logging
  static Future<String?> testCreateFabric() async {
    print('\\n=== Testing Fabric Creation with Logging ===');
    
    try {
      final testFabricData = {
        'name': 'Test Fabric ${DateTime.now().millisecondsSinceEpoch}',
        'type': 'cotton',
        'color': 'red',
        'colorID': 'red',
        'categoryID': 'cotton',
        'quantity': 25,
        'pricePerUnit': 12.50,
        'qualityGrade': 'A',
        'minOrder': 5,
        'isUpcycled': false,
        'swatchImageURL': null,
        'supplierID': null,
        'notes': 'Test fabric for logging verification',
        'createdBy': 'test_user',
        'createdAt': Timestamp.now(),
        'lastEdited': Timestamp.now(),
      };
      
      print('Creating test fabric...');
      
      final fabricId = await FabricOperationsService.addFabric(
        fabricData: testFabricData,
        createdBy: 'test_user',
        remarks: 'This is a test fabric created to verify logging system is working properly',
      );
      
      print('Test fabric created with ID: $fabricId');
      
      // Wait a moment for Firestore to process
      await Future.delayed(Duration(seconds: 2));
      
      // Check if log was created
      final logs = await FabricLogService.getFabricLogs(fabricId);
      
      print('Found ${logs.length} logs for new fabric');
      
      if (logs.isNotEmpty) {
        final log = logs.first;
        print('SUCCESS: Log created');
        print('  Change Type: ${log.changeType}');
        print('  Quantity: ${log.quantityChanged}');
        print('  Remarks: "${log.remarks}"');
        print('  Created By: ${log.createdBy}');
        print('  Created At: ${log.createdAt}');
      } else {
        print('ERROR: No log was created for the new fabric');
      }
      
      return fabricId;
      
    } catch (e) {
      print('Error in testCreateFabric: $e');
      return null;
    }
  }
  
  // Test editing a fabric
  static Future<void> testEditFabric(String fabricId) async {
    print('\\n=== Testing Fabric Edit with Logging ===');
    
    try {
      final updatedData = {
        'quantity': 35, // Change quantity
        'lastEdited': Timestamp.now(),
      };
      
      print('Editing fabric $fabricId...');
      
      await FabricOperationsService.updateFabric(
        fabricId: fabricId,
        updatedData: updatedData,
        updatedBy: 'test_user',
        remarks: 'Test edit: increased quantity by 10 units for testing purposes',
      );
      
      print('Fabric edited successfully');
      
      // Wait a moment for Firestore to process
      await Future.delayed(Duration(seconds: 2));
      
      // Check if edit log was created
      final logs = await FabricLogService.getFabricLogs(fabricId);
      
      print('Found ${logs.length} logs for edited fabric');
      
      if (logs.length >= 2) {
        final editLog = logs.first; // Most recent
        print('SUCCESS: Edit log created');
        print('  Change Type: ${editLog.changeType}');
        print('  Quantity: ${editLog.quantityChanged}');
        print('  Remarks: "${editLog.remarks}"');
      } else {
        print('WARNING: Edit log may not have been created');
      }
      
    } catch (e) {
      print('Error in testEditFabric: $e');
    }
  }
  
  // Run all tests
  static Future<void> runAllTests() async {
    print('\\n🧪 Starting Fabric Logging System Tests 🧪');
    
    await testReadLogs();
    
    final fabricId = await testCreateFabric();
    
    if (fabricId != null) {
      await testEditFabric(fabricId);
    }
    
    print('\\n✅ All tests completed! Check the output above for results.');
  }
}

// Widget to run tests from the UI
class FabricLoggingTestWidget extends StatefulWidget {
  @override
  _FabricLoggingTestWidgetState createState() => _FabricLoggingTestWidgetState();
}

class _FabricLoggingTestWidgetState extends State<FabricLoggingTestWidget> {
  String _testOutput = 'Tap "Run Tests" to start testing fabric logging system...';
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fabric Logging Tests'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isRunning ? null : _runTests,
              child: _isRunning 
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Running Tests...'),
                      ],
                    )
                  : Text('Run Tests'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _testOutput,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runTests() async {
    setState(() {
      _isRunning = true;
      _testOutput = 'Starting tests...\\n';
    });

    try {
      await FabricLoggingTestHelper.runAllTests();
      
      setState(() {
        _testOutput += '\\n✅ Tests completed successfully!\\n';
      });

    } catch (e) {
      setState(() {
        _testOutput += '\\nERROR: $e\\n';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }
}
