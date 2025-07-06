import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/services/fabric_operations_service.dart';
import 'lib/services/fabric_log_service.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp();
  
  print('Testing fabric logging system...');
  
  // Test 1: Check if we can query existing fabric logs
  try {
    print('\n--- Test 1: Querying existing fabric logs ---');
    
    final logsQuery = await FirebaseFirestore.instance
        .collection('fabricLogs')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();
    
    print('Successfully queried fabricLogs collection');
    print('Found ${logsQuery.docs.length} existing logs');
    
    for (var doc in logsQuery.docs) {
      final data = doc.data();
      print('Log ${doc.id}: ${data['changeType']} - ${data['quantityChanged']} units - "${data['remarks']}"');
    }
  } catch (e) {
    print('Error querying fabricLogs: $e');
  }
  
  // Test 2: Check recent logs for existing fabrics
  try {
    print('\n--- Test 2: Checking fabric logs for existing fabrics ---');
    
    final fabricsQuery = await FirebaseFirestore.instance
        .collection('fabrics')
        .limit(3)
        .get();
    
    print('Found ${fabricsQuery.docs.length} fabrics to check');
    
    for (var fabricDoc in fabricsQuery.docs) {
      final fabricId = fabricDoc.id;
      final fabricData = fabricDoc.data();
      final fabricName = fabricData['name'] ?? 'Unknown';
      
      print('\\nChecking logs for fabric: $fabricName (ID: $fabricId)');
      
      // Use our service to get logs
      final logs = await FabricLogService.getRecentFabricLogs(fabricId, limit: 3);
      
      if (logs.isNotEmpty) {
        print('  Found ${logs.length} recent logs:');
        for (var log in logs) {
          print('    ${log.changeType} ${log.quantityChanged} units - "${log.remarks}"');
          print('    Created: ${log.createdAt} by ${log.createdBy}');
        }
      } else {
        print('  No logs found for this fabric');
      }
    }
  } catch (e) {
    print('Error checking fabric logs: $e');
  }
  
  // Test 3: Test adding a new fabric with logging
  try {
    print('\n--- Test 3: Testing fabric addition with logging ---');
    
    final testFabricData = {
      'name': 'Test Logging Fabric ${DateTime.now().millisecondsSinceEpoch}',
      'type': 'cotton',
      'color': 'blue',
      'colorID': 'blue',
      'categoryID': 'cotton',
      'quantity': 50,
      'pricePerUnit': 15.00,
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
    
    print('Adding test fabric...');
    final fabricId = await FabricOperationsService.addFabric(
      fabricData: testFabricData,
      createdBy: 'test_user',
      remarks: 'Test fabric added for logging system verification',
    );
    
    print('SUCCESS: Test fabric added with ID: $fabricId');
    
    // Wait a moment for Firestore to process
    await Future.delayed(Duration(seconds: 2));
    
    // Check if log was created
    final logs = await FabricLogService.getFabricLogs(fabricId);
    if (logs.isNotEmpty) {
      print('SUCCESS: Log was created for the new fabric');
      final log = logs.first;
      print('  Change Type: ${log.changeType}');
      print('  Quantity: ${log.quantityChanged}');
      print('  Remarks: ${log.remarks}');
      print('  Created By: ${log.createdBy}');
    } else {
      print('ERROR: No log was created for the new fabric');
    }
    
    // Test 4: Test editing the fabric
    print('\\n--- Test 4: Testing fabric edit with logging ---');
    
    final updatedData = {
      'quantity': 75, // Changed from 50 to 75
      'lastEdited': Timestamp.now(),
    };
    
    await FabricOperationsService.updateFabric(
      fabricId: fabricId,
      updatedData: updatedData,
      updatedBy: 'test_user',
      remarks: 'Test fabric quantity updated - increased by 25 units',
    );
    
    print('SUCCESS: Test fabric updated');
    
    // Wait a moment for Firestore to process
    await Future.delayed(Duration(seconds: 2));
    
    // Check if edit log was created
    final updatedLogs = await FabricLogService.getFabricLogs(fabricId);
    if (updatedLogs.length > logs.length) {
      print('SUCCESS: Edit log was created');
      final editLog = updatedLogs.first; // Most recent
      print('  Change Type: ${editLog.changeType}');
      print('  Quantity: ${editLog.quantityChanged}');
      print('  Remarks: ${editLog.remarks}');
    } else {
      print('WARNING: No edit log was created (quantity may not have changed)');
    }
    
    // Test 5: Test deleting the fabric
    print('\\n--- Test 5: Testing fabric deletion with logging ---');
    
    await FabricOperationsService.deleteFabric(
      fabricId: fabricId,
      deletedBy: 'test_user',
      remarks: 'Test fabric deleted for logging system verification',
    );
    
    print('SUCCESS: Test fabric deleted');
    
    // Wait a moment for Firestore to process
    await Future.delayed(Duration(seconds: 2));
    
    // Check if deletion log was created
    final deletionLogs = await FabricLogService.getFabricLogs(fabricId);
    if (deletionLogs.length > updatedLogs.length) {
      print('SUCCESS: Deletion log was created');
      final deleteLog = deletionLogs.first; // Most recent
      print('  Change Type: ${deleteLog.changeType}');
      print('  Quantity: ${deleteLog.quantityChanged}');
      print('  Remarks: ${deleteLog.remarks}');
    } else {
      print('ERROR: No deletion log was created');
    }
    
  } catch (e) {
    print('Error in fabric operations test: $e');
  }
  
  print('\\n--- Fabric logging test completed ---');
}
