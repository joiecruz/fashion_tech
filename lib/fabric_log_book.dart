import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Fetch logs from Firestore
Stream<QuerySnapshot<Map<String, dynamic>>> fetchFabricLogs() {
  return FirebaseFirestore.instance
      .collection('fabricLogs')
      .orderBy('createdAT', descending: true)
      .snapshots();
}

// UI Widget to display logs
class FabricLogBookScreen extends StatelessWidget {
  const FabricLogBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fabric Log Book')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: fetchFabricLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No logs found.'));
          }
          final logs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index].data();
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: ListTile(
                  title: Text(
                    '${log['ChangeType'] ?? ''} ${log['amount'] ?? ''} (${log['FabricID'] ?? ''})',
                  ),
                  subtitle: Text(
                    'Note: ${log['note'] ?? ''}\n'
                    'At: ${log['createdAt'] != null ? (log['createdAt'] as Timestamp).toDate() : 'Unknown'}',
                  ),
                  trailing: Text(log['Name'] ?? ''),
                ),
              );
            },
          );
        },
      ),
    );
  }
}