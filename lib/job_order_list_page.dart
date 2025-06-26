import 'package:flutter/material.dart';

class JobOrderListPage extends StatelessWidget {
  const JobOrderListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final jobOrders = [
      {
        'productName': 'School Uniforms',
        'orderDate': '2025-06-24',
        'dueDate': '2025-07-01',
        'status': 'In Progress',
        'assignedTo': 'Mang Ernie',
      },
      {
        'productName': 'Sunday Dress',
        'orderDate': '2025-06-23',
        'dueDate': '2025-06-28',
        'status': 'Open',
        'assignedTo': '',
      },
    ];

    return ListView.builder(
      itemCount: jobOrders.length,
      itemBuilder: (context, index) {
        final order = jobOrders[index];
        final statusColor = _getStatusColor(order['status']!);

        return Card(
          margin: const EdgeInsets.all(12),
          child: ListTile(
            title: Text(order['productName']!),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Due: ${order['dueDate']}'),
                if (order['assignedTo']!.isNotEmpty)
                  Text('Assigned: ${order['assignedTo']}'),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                order['status']!,
                style: TextStyle(color: statusColor),
              ),
            ),
            onTap: () {
              // Navigate to Job Order Details page
            },
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Done':
        return Colors.green;
      case 'In Progress':
        return Colors.orange;
      case 'Open':
      default:
        return Colors.red;
    }
  }
}
