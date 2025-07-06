// Simple test script to verify fabric logging
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  // Initialize Firestore (this would normally be done in main.dart)
  print('Starting fabric logging test...');
  
  // Test 1: Check if we can query the fabricLogs collection
  try {
    final logsQuery = await FirebaseFirestore.instance
        .collection('fabricLogs')
        .limit(5)
        .get();
    
    print('Successfully queried fabricLogs collection');
    print('Found ${logsQuery.docs.length} existing logs');
    
    for (var doc in logsQuery.docs) {
      final data = doc.data();
      print('Log: ${data['changeType']} - ${data['quantityChanged']} - ${data['remarks']}');
    }
  } catch (e) {
    print('Error querying fabricLogs: $e');
  }
  
  // Test 2: Check recent logs for a specific fabric
  try {
    final fabricsQuery = await FirebaseFirestore.instance
        .collection('fabrics')
        .limit(1)
        .get();
    
    if (fabricsQuery.docs.isNotEmpty) {
      final fabricId = fabricsQuery.docs.first.id;
      print('Testing with fabric ID: $fabricId');
      
      final logsQuery = await FirebaseFirestore.instance
          .collection('fabricLogs')
          .where('fabricID', isEqualTo: fabricId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      
      if (logsQuery.docs.isNotEmpty) {
        final logData = logsQuery.docs.first.data();
        print('Most recent log for fabric $fabricId:');
        print('  Change Type: ${logData['changeType']}');
        print('  Quantity Changed: ${logData['quantityChanged']}');
        print('  Remarks: ${logData['remarks']}');
        print('  Created By: ${logData['createdBy']}');
        print('  Created At: ${logData['createdAt']}');
      } else {
        print('No logs found for fabric $fabricId');
      }
    }
  } catch (e) {
    print('Error testing fabric logs: $e');
  }
  
  print('Test completed');
}
