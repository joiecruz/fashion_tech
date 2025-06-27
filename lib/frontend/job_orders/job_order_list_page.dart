import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_job_order_modal.dart';

class JobOrderListPage extends StatefulWidget {
  const JobOrderListPage({super.key});
  @override
  State<JobOrderListPage> createState() => _JobOrderListPageState();
}

class _JobOrderListPageState extends State<JobOrderListPage> {
  String _selectedStatus = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Remove the inner Scaffold and return the body content directly
    return Stack(
      children: [
        Container(
          color: const Color(0xFFF8F8F8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search orders...',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Text('Filters:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _StatusFilterChip(
                              label: 'All',
                              selected: _selectedStatus == 'All',
                              onTap: () => setState(() => _selectedStatus = 'All'),
                            ),
                            _StatusFilterChip(
                              label: 'Open',
                              selected: _selectedStatus == 'Open',
                              onTap: () => setState(() => _selectedStatus = 'Open'),
                            ),
                            _StatusFilterChip(
                              label: 'In Progress',
                              selected: _selectedStatus == 'In Progress',
                              onTap: () => setState(() => _selectedStatus = 'In Progress'),
                            ),
                            _StatusFilterChip(
                              label: 'Done',
                              selected: _selectedStatus == 'Done',
                              onTap: () => setState(() => _selectedStatus = 'Done'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('jobOrders').orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No job orders found.'));
                    }
                    var jobOrders = snapshot.data!.docs;
                    if (_selectedStatus != 'All') {
                      jobOrders = jobOrders.where((doc) =>
                        (doc.data() as Map<String, dynamic>)['status'] == _selectedStatus
                      ).toList();
                    }
                    if (_searchQuery.isNotEmpty) {
                      jobOrders = jobOrders.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final productName = (data['productName'] ?? '').toString().toLowerCase();
                        final assignedTo = (data['assignedTo'] ?? '').toString().toLowerCase();
                        return productName.contains(_searchQuery) || assignedTo.contains(_searchQuery);
                      }).toList();
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      itemCount: jobOrders.length,
                      itemBuilder: (context, index) {
                        final data = jobOrders[index].data() as Map<String, dynamic>;
                        // NOTE: The following fields are hardcoded for demo purposes.
                        // Replace 'productName', 'assignedTo', 'status', 'isUpcycled', 'createdAt', 'dueDate', and 'quantity'
                        // with the correct field names from your Firebase jobOrders collection once your schema is finalized.
                        final productName = data['productName'] ?? 'Untitled'; // <-- Hardcoded field
                        final assignedTo = data['assignedTo'] ?? ''; // <-- Hardcoded field
                        final status = data['status'] ?? 'Open'; // <-- Hardcoded field
                        final isUpcycled = data['isUpcycled'] ?? false; // <-- Hardcoded field
                        final orderDate = (data['createdAt'] as Timestamp?)?.toDate(); // <-- Hardcoded field
                        final dueDate = (data['dueDate'] as Timestamp?)?.toDate(); // <-- Hardcoded field
                        final totalQty = data['quantity'] ?? 0; // <-- Hardcoded field
                        // END NOTE
                        final overdue = dueDate != null && dueDate.isBefore(DateTime.now())
                            ? 'Overdue (${DateTime.now().difference(dueDate).inDays} days)'
                            : null;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.checkroom, color: Colors.orange, size: 28),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        productName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                      ),
                                    ),
                                    if (isUpcycled)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text('Upcycled', style: TextStyle(color: Colors.blue)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    // The image below is a hardcoded placeholder. Replace with dynamic user images when available.
                                    const CircleAvatar(
                                      radius: 16,
                                      backgroundImage: NetworkImage('https://randomuser.me/api/portraits/men/32.jpg'), // Placeholder
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text('Assigned to: $assignedTo', style: const TextStyle(color: Colors.black54)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Order Date:', style: TextStyle(color: Colors.black54)),
                                          Text(
                                            orderDate != null ? _formatDate(orderDate) : '-',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Text('Due Date:', style: TextStyle(color: Colors.black54)),
                                              if (overdue != null) ...[
                                                const SizedBox(width: 8),
                                                Text(overdue, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
                                              ]
                                            ],
                                          ),
                                          Text(
                                            dueDate != null ? _formatDate(dueDate) : '-',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text('Qty: $totalQty', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const Spacer(),
                                    OutlinedButton(
                                      onPressed: () {
                                        // Navigate to details
                                      },
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        side: const BorderSide(color: Colors.black12),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                        minimumSize: const Size(0, 36),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('View Details'),
                                          SizedBox(width: 4),
                                          Icon(Icons.arrow_forward, size: 16),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton.extended(
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  margin: const EdgeInsets.only(top: 100), // Add space from the top (below notch/appbar)
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: AddJobOrderModal(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Job Order'),
            backgroundColor: Colors.orange,
          ),
        ),
      ],
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _StatusFilterChip({required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: Colors.orange,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
        onSelected: (_) => onTap?.call(),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

Color _statusColor(String status) {
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
