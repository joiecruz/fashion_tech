import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsModal extends StatelessWidget {
  const NotificationsModal({super.key});

  Future<List<Map<String, dynamic>>> _getNotifications() async {
    final List<Map<String, dynamic>> notifications = [];

    // 1. Incoming due dates (within next 3 days)
    final now = DateTime.now();
    final threeDays = now.add(const Duration(days: 3));
    final dueOrders = await FirebaseFirestore.instance
        .collection('jobOrders')
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(threeDays))
        .get();
    for (var doc in dueOrders.docs) {
      notifications.add({
        'type': 'due',
        'title': 'Job Order Due Soon',
        'message': 'Job Order "${doc['name'] ?? doc.id}" is due on ${doc['dueDate'].toDate().toString().split(' ').first}',
        'time': doc['dueDate'] is Timestamp ? (doc['dueDate'] as Timestamp).toDate() : null,
      });
    }

    // 2. No stock (quantity == 0)
    final noStock = await FirebaseFirestore.instance
        .collection('products')
        .where('quantity', isEqualTo: 0)
        .get();
    for (var doc in noStock.docs) {
      notifications.add({
        'type': 'no_stock',
        'title': 'Out of Stock',
        'message': 'Product "${doc['name'] ?? doc.id}" is out of stock!',
        'time': null,
      });
    }

    // 3. Low stock (quantity <= 5)
    final lowStock = await FirebaseFirestore.instance
        .collection('products')
        .where('quantity', isGreaterThan: 0)
        .where('quantity', isLessThanOrEqualTo: 5)
        .get();
    for (var doc in lowStock.docs) {
      notifications.add({
        'type': 'low_stock',
        'title': 'Low Stock',
        'message': 'Product "${doc['name'] ?? doc.id}" is low on stock (${doc['quantity']})',
        'time': null,
      });
    }

    // Sort notifications by time if available (most recent first)
    notifications.sort((a, b) {
      final aTime = a['time'] as DateTime?;
      final bTime = b['time'] as DateTime?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return notifications;
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'due':
        return Icons.event;
      case 'no_stock':
        return Icons.error;
      case 'low_stock':
        return Icons.warning;
      default:
        return Icons.notifications;
    }
  }

  Color _iconColorForType(String type) {
    switch (type) {
      case 'due':
        return Colors.blue;
      case 'no_stock':
        return Colors.red;
      case 'low_stock':
        return Colors.orange;
      default:
        return Colors.teal;
    }
  }
@override
Widget build(BuildContext context) {
  return Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Notifications',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 320, // Set your desired modal height here
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _getNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final notifications = snapshot.data ?? [];
                if (notifications.isEmpty) {
                  return const Center(
                    child: Text(
                      'No notifications.',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _iconColorForType(notif['type']).withOpacity(0.15),
                        child: Icon(
                          _iconForType(notif['type']),
                          color: _iconColorForType(notif['type']),
                        ),
                      ),
                      title: Text(
                        notif['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        notif['message'] ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: notif['time'] != null
                          ? Text(
                              _formatTime(notif['time']),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'now';
    }
  }
}