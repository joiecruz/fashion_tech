import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/user_service.dart';
import '../auth/unauthorized_page.dart';
import '../auth/login_page.dart';
import '../logs/productLogs.dart';
import '../logs/jobOrderLogs.dart';
import 'package:intl/intl.dart';


// --- PRODUCT LOGS TAB ---
class ProductLogsTab extends StatefulWidget {
  final bool isAdmin;
  const ProductLogsTab({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<ProductLogsTab> createState() => _ProductLogsTabState();
}

class _ProductLogsTabState extends State<ProductLogsTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _products = [];
  final userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _loading = true);
    Query query = FirebaseFirestore.instance.collection('products').orderBy('updatedAt', descending: true);
    if (!widget.isAdmin && userId != null) {
      query = query.where('createdBy', isEqualTo: userId);
    }
    final snapshot = await query.get();
    setState(() {
      _products = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'category': data['category'] ?? data['categoryID'] ?? '',
          'price': data['price'] ?? 0,
          'stock': data['stock'] ?? data['quantity'] ?? 0,
          'supplier': data['supplier'] ?? data['supplierID'] ?? '',
          'updatedAt': (data['updatedAt'] is Timestamp) ? (data['updatedAt'] as Timestamp).toDate() : null,
        };
      }).toList();
      _loading = false;
    });
  }

  Future<void> _editProduct(BuildContext context, Map<String, dynamic> product) async {
    final nameController = TextEditingController(text: product['name'] ?? '');
    final categoryController = TextEditingController(text: product['category'] ?? '');
    final priceController = TextEditingController(text: product['price'].toString());
    final stockController = TextEditingController(text: product['stock'].toString());
    final supplierController = TextEditingController(text: product['supplier'] ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: stockController,
                  decoration: const InputDecoration(labelText: 'Stock'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: supplierController,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('products').doc(product['id']).update({
                  'name': nameController.text,
                  'category': categoryController.text,
                  'price': double.tryParse(priceController.text) ?? 0,
                  'stock': int.tryParse(stockController.text) ?? 0,
                  'supplier': supplierController.text,
                });
                Navigator.pop(context);
                _fetchProducts();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product updated.'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteProduct(String id) async {
    final docRef = FirebaseFirestore.instance.collection('products').doc(id);
    final docSnap = await docRef.get();
    final deletedData = docSnap.data();

    await docRef.delete();
    _fetchProducts();

    if (mounted && deletedData != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Product deleted.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.white,
            onPressed: () async {
              await docRef.set(deletedData);
              _fetchProducts();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete undone!'), backgroundColor: Colors.green),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _products.isEmpty
                  ? const Center(child: Text('No products found.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          const DataColumn(label: Text('Name')),
                          const DataColumn(label: Text('Category')),
                          const DataColumn(label: Text('Price')),
                          const DataColumn(label: Text('Stock')),
                          const DataColumn(label: Text('Supplier')),
                          const DataColumn(label: Text('Updated At')),
                          if (widget.isAdmin) const DataColumn(label: Text('Edit')),
                          if (widget.isAdmin) const DataColumn(label: Text('Delete')),
                        ],
                        rows: _products.map((product) {
                          return DataRow(
                            cells: [
                              DataCell(Text(product['name'].toString())),
                              DataCell(Text(product['category'].toString())),
                              DataCell(Text(product['price'].toString())),
                              DataCell(Text(product['stock'].toString())),
                              DataCell(Text(product['supplier'].toString())),
                              DataCell(Text(
                                product['updatedAt'] != null
                                    ? DateFormat('yyyy-MM-dd HH:mm').format(product['updatedAt'])
                                    : '',
                              )),
                              if (widget.isAdmin)
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _editProduct(context, product),
                                  ),
                                ),
                              if (widget.isAdmin)
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      await _deleteProduct(product['id']);
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
    );
  }
}

// --- JOB ORDER LOGS TAB ---
class JobOrderLogsTab extends StatefulWidget {
  final bool isAdmin;
  const JobOrderLogsTab({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<JobOrderLogsTab> createState() => _JobOrderLogsTabState();
}

class _JobOrderLogsTabState extends State<JobOrderLogsTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _jobOrders = [];
  final userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _fetchJobOrders();
  }

  Future<void> _fetchJobOrders() async {
    setState(() => _loading = true);
    Query query = FirebaseFirestore.instance.collection('jobOrders').orderBy('updatedAt', descending: true);
    if (!widget.isAdmin && userId != null) {
      query = query.where('createdBy', isEqualTo: userId);
    }
    final snapshot = await query.get();
    setState(() {
      _jobOrders = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'assignedTo': data['assignedTo'] ?? '',
          'status': data['status'] ?? '',
          'price': data['price'] ?? 0,
          'quantity': data['quantity'] ?? 0,
          'updatedAt': (data['updatedAt'] is Timestamp) ? (data['updatedAt'] as Timestamp).toDate() : null,
        };
      }).toList();
      _loading = false;
    });
  }

  Future<void> _editJobOrder(BuildContext context, Map<String, dynamic> jobOrder) async {
    final nameController = TextEditingController(text: jobOrder['name'] ?? '');
    final assignedToController = TextEditingController(text: jobOrder['assignedTo'] ?? '');
    final statusController = TextEditingController(text: jobOrder['status'] ?? '');
    final priceController = TextEditingController(text: jobOrder['price'].toString());
    final quantityController = TextEditingController(text: jobOrder['quantity'].toString());

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Job Order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: assignedToController,
                  decoration: const InputDecoration(labelText: 'Assigned To'),
                ),
                TextField(
                  controller: statusController,
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('jobOrders').doc(jobOrder['id']).update({
                  'name': nameController.text,
                  'assignedTo': assignedToController.text,
                  'status': statusController.text,
                  'price': double.tryParse(priceController.text) ?? 0,
                  'quantity': int.tryParse(quantityController.text) ?? 0,
                });
                Navigator.pop(context);
                _fetchJobOrders();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Job order updated.'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteJobOrder(String id) async {
    final docRef = FirebaseFirestore.instance.collection('jobOrders').doc(id);
    final docSnap = await docRef.get();
    final deletedData = docSnap.data();

    await docRef.delete();
    _fetchJobOrders();

    if (mounted && deletedData != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Job order deleted.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.white,
            onPressed: () async {
              await docRef.set(deletedData);
              _fetchJobOrders();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete undone!'), backgroundColor: Colors.green),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _jobOrders.isEmpty
                  ? const Center(child: Text('No job orders found.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          const DataColumn(label: Text('Name')),
                          const DataColumn(label: Text('Assigned To')),
                          const DataColumn(label: Text('Status')),
                          const DataColumn(label: Text('Price')),
                          const DataColumn(label: Text('Quantity')),
                          const DataColumn(label: Text('Updated At')),
                          if (widget.isAdmin) const DataColumn(label: Text('Edit')),
                          if (widget.isAdmin) const DataColumn(label: Text('Delete')),
                        ],
                        rows: _jobOrders.map((order) {
                          return DataRow(
                            cells: [
                              DataCell(Text(order['name'].toString())),
                              DataCell(Text(order['assignedTo'].toString())),
                              DataCell(Text(order['status'].toString())),
                              DataCell(Text(order['price'].toString())),
                              DataCell(Text(order['quantity'].toString())),
                              DataCell(Text(
                                order['updatedAt'] != null
                                    ? DateFormat('yyyy-MM-dd HH:mm').format(order['updatedAt'])
                                    : '',
                              )),
                              if (widget.isAdmin)
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _editJobOrder(context, order),
                                  ),
                                ),
                              if (widget.isAdmin)
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      await _deleteJobOrder(order['id']);
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
    );
  }
}

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: UserService.isCurrentUserAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.data != true) {
          return const UnauthorizedPage();
        }
        return _AdminDashboard(isAdmin: true);
      },
    );
  }
}

class _AdminDashboard extends StatelessWidget {
  final bool isAdmin;
  const _AdminDashboard({Key? key, required this.isAdmin}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.deepPurple,
          elevation: 0,
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'logout') {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                      (route) => false,
                    );
                  }
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.admin_panel_settings),
                    const SizedBox(width: 4),
                    Text(
                      FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? 'Admin',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
              Tab(text: 'Users', icon: Icon(Icons.people)),
              Tab(text: 'Transactions', icon: Icon(Icons.swap_horiz)),
              Tab(text: 'Product Logs', icon: Icon(Icons.list_alt)),
              Tab(text: 'Job Order Logs', icon: Icon(Icons.receipt_long)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _OverviewTab(),
            _UserTab(),
            _TransactionsTab(),
            ProductLogsTab(isAdmin: isAdmin),
            JobOrderLogsTab(isAdmin: isAdmin),
          ],
        ),
      ),
    );
  }
}
class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. USER STATISTICS
          _modernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('User Statistics', Icons.people),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _StatCard(
                      title: "Total Users",
                      icon: Icons.people,
                      color: Colors.deepPurple,
                      stream: _AdminDashboardState.totalUsersStream,
                    ),
                    _StatCard(
                      title: "Owners",
                      icon: Icons.verified_user,
                      color: Colors.blueGrey,
                      stream: _AdminDashboardState.usersByRoleStream('owner'),
                    ),
                    _StatCard(
                      title: "Admins",
                      icon: Icons.admin_panel_settings,
                      color: Colors.blue,
                      stream: _AdminDashboardState.usersByRoleStream('admin'),
                    ),
                    _StatCard(
                      title: "Staff",
                      icon: Icons.group,
                      color: Colors.teal,
                      stream: _AdminDashboardState.usersByRoleStream('staff'),
                    ),
                    _StatCard(
                      title: "New This Month",
                      icon: Icons.fiber_new,
                      color: Colors.green,
                      stream: _AdminDashboardState.newUsersThisMonthStream,
                    ),
                    _StatCard(
                      title: "Inactive (30d)",
                      icon: Icons.person_off,
                      color: Colors.red,
                      stream: _AdminDashboardState.inactiveUsersStream,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _TopUsersSection()),
                    const SizedBox(width: 24),
                    Expanded(child: _UnderperformingUsersSection()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 2. SYSTEM DATA OVERVIEW
          _modernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('System Data Overview', Icons.dashboard_customize),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _StatCard(
                      title: "Products",
                      icon: Icons.checkroom,
                      color: Colors.blue,
                      stream: _AdminDashboardState.totalProductsStream,
                    ),
                    _StatCard(
                      title: "Variants",
                      icon: Icons.style,
                      color: Colors.orange,
                      stream: _AdminDashboardState.totalVariantsStream,
                    ),
                    _StatCard(
                      title: "Fabrics",
                      icon: Icons.texture,
                      color: Colors.purple,
                      stream: _AdminDashboardState.totalFabricsStream,
                    ),
                    _StatCard(
                      title: "Job Orders",
                      icon: Icons.assignment,
                      color: Colors.green,
                      stream: _AdminDashboardState.totalJobOrdersStream,
                    ),
                    _StatCard(
                      title: "Customers",
                      icon: Icons.person,
                      color: Colors.indigo,
                      stream: _AdminDashboardState.totalCustomersStream,
                    ),
                    _StatCard(
                      title: "Transactions",
                      icon: Icons.swap_horiz,
                      color: Colors.brown,
                      stream: _AdminDashboardState.totalTransactionsStream,
                    ),
                    _StatCard(
                      title: "Categories",
                      icon: Icons.category,
                      color: Colors.cyan,
                      stream: _AdminDashboardState.totalCategoriesStream,
                    ),
                    _StatCard(
                      title: "Colors",
                      icon: Icons.color_lens,
                      color: Colors.pink,
                      stream: _AdminDashboardState.totalColorsStream,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _GrowthStatsSection(),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 3. LOG SNAPSHOT
          _modernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Log Snapshot', Icons.receipt_long),
                const SizedBox(height: 12),
                _LogsPreviewSection(),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 4. SYSTEM HEALTH / ADMIN INSIGHTS
          _modernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('System Health & Warnings', Icons.warning_amber_rounded),
                const SizedBox(height: 12),
                _SystemHealthSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- STAT CARD WIDGET ---
class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Stream<dynamic> stream;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<dynamic>(
      stream: stream,
      builder: (context, snapshot) {
        final value = snapshot.data ?? 0;
        return Container(
          width: 170,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.09),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${value is double ? value.toStringAsFixed(0) : value}",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- SECTION TITLE ---
Widget _sectionTitle(String title, IconData icon) {
  return Row(
    children: [
      Icon(icon, color: Colors.deepPurple[400], size: 22),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    ],
  );
}

// --- MODERN CARD ---
Widget _modernCard({required Widget child}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.07),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: const EdgeInsets.all(20),
    child: child,
  );
}
class _TopUsersSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Fetch all job orders with status 'Done'
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('jobOrders')
          .where('status', isEqualTo: 'Done')
          .get(),
      builder: (context, jobOrderSnap) {
        if (!jobOrderSnap.hasData) return const Center(child: CircularProgressIndicator());
        final jobOrders = jobOrderSnap.data!.docs;

        // Group by assignedTo and count
        final Map<String, int> completedCount = {};
        for (final doc in jobOrders) {
          final data = doc.data() as Map<String, dynamic>;
          final assignedTo = data['assignedTo'];
          if (assignedTo != null && assignedTo.toString().isNotEmpty) {
            completedCount[assignedTo] = (completedCount[assignedTo] ?? 0) + 1;
          }
        }

        if (completedCount.isEmpty) return const Text('No top users found.');

        // Fetch user info for each assignedTo
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('users').get(),
          builder: (context, userSnap) {
            if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
            final users = userSnap.data!.docs;
            final Map<String, Map<String, dynamic>> userMap = {
              for (var u in users) u.id: u.data() as Map<String, dynamic>
            };

            // Build stats list
            final stats = completedCount.entries.map((entry) {
              final userID = entry.key;
              final completed = entry.value;
              final userData = userMap[userID];
              return {
                'userID': userID,
                'fullName': userData?['fullName'] ?? userData?['fullname'] ?? userID,
                'completed': completed,
              };
            }).toList();

            // Sort descending by completed count
            stats.sort((a, b) => b['completed'] - a['completed']);
            final topUsers = stats.take(3).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.trending_up, color: Colors.green, size: 18),
                    SizedBox(width: 6),
                    Text('Top Performing Users', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ...topUsers.map((user) => ListTile(
                  leading: const Icon(Icons.emoji_events, color: Colors.amber),
                  title: Text(user['fullName'] ?? user['userID']),
                  subtitle: Text('Job Orders Completed: ${user['completed']}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                )),
              ],
            );
          },
        );
      },
    );
  }
}

class _UnderperformingUsersSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Fetch all job orders with status 'Done'
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('jobOrders')
          .where('status', isEqualTo: 'Done')
          .get(),
      builder: (context, jobOrderSnap) {
        if (!jobOrderSnap.hasData) return const Center(child: CircularProgressIndicator());
        final jobOrders = jobOrderSnap.data!.docs;

        // Group by assignedTo and count
        final Map<String, int> completedCount = {};
        for (final doc in jobOrders) {
          final data = doc.data() as Map<String, dynamic>;
          final assignedTo = data['assignedTo'];
          if (assignedTo != null && assignedTo.toString().isNotEmpty) {
            completedCount[assignedTo] = (completedCount[assignedTo] ?? 0) + 1;
          }
        }

        if (completedCount.isEmpty) return const Text('No underperforming users found.');

        // Fetch user info for each assignedTo
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('users').get(),
          builder: (context, userSnap) {
            if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
            final users = userSnap.data!.docs;
            final Map<String, Map<String, dynamic>> userMap = {
              for (var u in users) u.id: u.data() as Map<String, dynamic>
            };

            // Build stats list
            final stats = completedCount.entries.map((entry) {
              final userID = entry.key;
              final completed = entry.value;
              final userData = userMap[userID];
              return {
                'userID': userID,
                'fullName': userData?['fullName'] ?? userData?['fullname'] ?? userID,
                'completed': completed,
              };
            }).toList();

            // Sort ascending by completed count
            stats.sort((a, b) => a['completed'] - b['completed']);
            final bottomUsers = stats.take(3).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.trending_down, color: Colors.red, size: 18),
                    SizedBox(width: 6),
                    Text('Underperforming Users', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ...bottomUsers.map((user) => ListTile(
                  leading: const Icon(Icons.warning, color: Colors.redAccent),
                  title: Text(user['fullName'] ?? user['userID']),
                  subtitle: Text('Job Orders Completed: ${user['completed']}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                )),
              ],
            );
          },
        );
      },
    );
  }
}

// --- GROWTH STATS SECTION ---
class _GrowthStatsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Replace with your actual Firestore queries for growth stats
    return Row(
      children: [
        const Icon(Icons.trending_up, color: Colors.green, size: 18),
        const SizedBox(width: 6),
        Text(
          '+15% job orders vs. last month',
          style: TextStyle(
            color: Colors.green[800],
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
class _LogsPreviewSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LogTypeList(
          title: 'Product Logs',
          icon: Icons.inventory_2,
          color: Colors.indigo,
          collection: 'products',
        ),
        _LogTypeList(
          title: 'Fabric Logs',
          icon: Icons.checkroom,
          color: Colors.pink,
          collection: 'fabrics',
        ),
        _LogTypeList(
          title: 'Job Order Logs',
          icon: Icons.assignment_turned_in,
          color: Colors.deepPurple,
          collection: 'jobOrders',
        ),
        _LogTypeList(
          title: 'Supplier Logs',
          icon: Icons.local_shipping,
          color: Colors.orange,
          collection: 'suppliers',
        ),
        _LogTypeList(
          title: 'Customer Logs',
          icon: Icons.person,
          color: Colors.teal,
          collection: 'customers',
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            DefaultTabController.of(context)?.animateTo(3); // Adjust index if needed
          },
          child: const Text('View All Logs'),
        ),
      ],
    );
  }
}

class _LogTypeList extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String collection;

  const _LogTypeList({
    required this.title,
    required this.icon,
    required this.color,
    required this.collection,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    String orderByField = collection == 'products' ? 'updatedAt' : 'createdAt';

    return FutureBuilder<QuerySnapshot>(
      future: collection == 'products'
          ? FirebaseFirestore.instance
              .collection(collection)
              .orderBy(orderByField, descending: true)
              .limit(1)
              .get()
          : FirebaseFirestore.instance
              .collection(collection)
              .orderBy(orderByField, descending: true)
              .limit(1)
              .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text('$title: ', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                const Text('No recent logs.', style: TextStyle(color: Colors.black54)),
              ],
            ),
          );
        }
        // Show name for all collections (products, suppliers, customers, etc.)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text('$title:', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              String name = data['name'] ??
                  data['supplierName'] ??
                  data['fullName'] ??
                  '';
              String dateStr = '';
              DateTime? date;
              if (collection == 'products') {
                date = (data['updatedAt'] is Timestamp)
                    ? (data['updatedAt'] as Timestamp).toDate()
                    : null;
              } else {
                date = (data['createdAt'] is Timestamp)
                    ? (data['createdAt'] as Timestamp).toDate()
                    : null;
              }
              if (date != null) {
                dateStr = _formatTimeAgo(date, DateTime.now());
              }
              return Padding(
                padding: const EdgeInsets.only(left: 32, top: 2, bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr,
                        style: const TextStyle(fontSize: 11, color: Colors.black45),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }
}

// Helper for time ago formatting
String _formatTimeAgo(DateTime? date, DateTime now) {
  if (date == null) return '';
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays}d ago';
}

// --- SYSTEM HEALTH / ADMIN INSIGHTS SECTION ---
class _SystemHealthSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fabrics running low in stock
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('fabrics')
              .where('quantity', isLessThan: 10)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.warning, color: Colors.red, size: 18),
                    SizedBox(width: 6),
                    Text('Low Stock Fabrics', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
                ...snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Text('${data['name'] ?? 'Unknown'}: ${data['quantity']} left', style: const TextStyle(color: Colors.red));
                }),
              ],
            );
          },
        ),
        // Products without variants
        FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('products')
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            final products = snapshot.data!.docs;
            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('productVariants').get(),
              builder: (context, variantSnap) {
                if (!variantSnap.hasData) return const SizedBox();
                final variants = variantSnap.data!.docs;
                final productIdsWithVariants = variants.map((v) => (v.data() as Map<String, dynamic>)['productID']).toSet();
                final productsWithoutVariants = products.where((p) => !productIdsWithVariants.contains(p.id)).toList();
                if (productsWithoutVariants.isEmpty) return const SizedBox();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning, color: Colors.orange, size: 18),
                        SizedBox(width: 6),
                        Text('Products without variants', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    ...productsWithoutVariants.map((p) {
                      final data = p.data() as Map<String, dynamic>;
                      return Text('${data['name'] ?? p.id}', style: const TextStyle(color: Colors.orange));
                    }),
                  ],
                );
              },
            );
          },
        ),
        // Job Orders without linked product
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobOrders')
              .where('productID', isNull: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.warning, color: Colors.purple, size: 18),
                    SizedBox(width: 6),
                    Text('Job Orders without linked product', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                  ],
                ),
                ...snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Text('${data['name'] ?? doc.id}', style: const TextStyle(color: Colors.purple));
                }),
              ],
            );
          },
        ),
        // Customers missing info
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('customers')
              .where('contactNum', isNull: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.warning, color: Colors.blue, size: 18),
                    SizedBox(width: 6),
                    Text('Customers missing contact info', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  ],
                ),
                ...snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Text('${data['fullName'] ?? doc.id}', style: const TextStyle(color: Colors.blue));
                }),
              ],
            );
          },
        ),
      ],
    );
  }
}

// --- DASHBOARD STATE STREAMS ---
class _AdminDashboardState {
  static Stream<int> get totalUsersStream => FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> usersByRoleStream(String role) => FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: role)
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> get newUsersThisMonthStream {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    return FirebaseFirestore.instance
        .collection('users')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  static Stream<int> get inactiveUsersStream {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return FirebaseFirestore.instance
        .collection('users')
        .where('lastActive', isLessThan: Timestamp.fromDate(cutoff))
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  static Stream<int> get totalProductsStream => FirebaseFirestore.instance
      .collection('products')
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> get totalVariantsStream => FirebaseFirestore.instance
      .collection('productVariants')
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> get totalFabricsStream => FirebaseFirestore.instance
      .collection('fabrics')
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> get totalJobOrdersStream => FirebaseFirestore.instance
      .collection('jobOrders')
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> get totalCustomersStream => FirebaseFirestore.instance
      .collection('customers')
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> get totalTransactionsStream => FirebaseFirestore.instance
      .collection('transactions')
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> get totalCategoriesStream => FirebaseFirestore.instance
      .collection('categories')
      .snapshots()
      .map((snap) => snap.docs.length);

  static Stream<int> get totalColorsStream => FirebaseFirestore.instance
      .collection('colors')
      .snapshots()
      .map((snap) => snap.docs.length);
}

class _UserTab extends StatelessWidget {
  const _UserTab({Key? key}) : super(key: key);

  Future<void> _deleteUser(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('users').doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User deleted.'), backgroundColor: Colors.red),
    );
  }

  Future<void> _editUser(BuildContext context, String docId, Map<String, dynamic> data) async {
    final nameController = TextEditingController(text: data['fullname'] ?? '');
    final roleController = TextEditingController(text: data['role'] ?? '');
    final emailController = TextEditingController(text: data['email'] ?? '');
    bool isActive = data['isActive'] ?? true;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: roleController,
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              Row(
                children: [
                  const Text('Active'),
                  Switch(
                    value: isActive,
                    onChanged: (val) {
                      isActive = val;
                      // Force rebuild dialog
                      (context as Element).markNeedsBuild();
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('users').doc(docId).update({
                  'fullname': nameController.text,
                  'role': roleController.text,
                  'email': emailController.text,
                  'isActive': isActive,
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User updated.'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _modernCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('All Users', Icons.people),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Text('No users found.');
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Active')),
                      DataColumn(label: Text('Edit')),
                      DataColumn(label: Text('Delete')),
                    ],
                    rows: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DataRow(
                        cells: [
                          DataCell(Text(data['fullname'] ?? '')),
                          DataCell(Text(data['role'] ?? '')),
                          DataCell(Text(data['email'] ?? '')),
                          DataCell(Icon(
                            (data['isActive'] ?? true) ? Icons.check_circle : Icons.cancel,
                            color: (data['isActive'] ?? true) ? Colors.green : Colors.red,
                            size: 18,
                          )),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editUser(context, doc.id, data),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteUser(context, doc.id),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab({Key? key}) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchAllTransactions() async {
    // Fetch from main transactions
    final transactionsSnap = await FirebaseFirestore.instance
        .collection('transactions')
        .orderBy('date', descending: true)
        .get();

    // Fetch from manualIncome
    final manualIncomeSnap = await FirebaseFirestore.instance
        .collection('manualIncome')
        .orderBy('createdAt', descending: true)
        .get();

    // Fetch from manualExpenses
    final manualExpensesSnap = await FirebaseFirestore.instance
        .collection('manualExpenses')
        .orderBy('createdAt', descending: true)
        .get();

    // Normalize and merge all
    List<Map<String, dynamic>> all = [];

    for (var doc in transactionsSnap.docs) {
      final data = doc.data();
      all.add({
        'id': doc.id,
        'type': data['type'] ?? '',
        'amount': data['amount'] ?? 0,
        'date': data['date'],
        'jobOrderID': data['jobOrderID'] ?? '',
        'description': data['description'] ?? '',
        'source': 'transactions',
      });
    }
    for (var doc in manualIncomeSnap.docs) {
      final data = doc.data();
      all.add({
        'id': doc.id,
        'type': data['type'] ?? 'income',
        'amount': data['amount'] ?? 0,
        'date': data['createdAt'],
        'jobOrderID': data['jobOrderID'] ?? '',
        'description': data['description'] ?? '',
        'source': 'manualIncome',
      });
    }
    for (var doc in manualExpensesSnap.docs) {
      final data = doc.data();
      all.add({
        'id': doc.id,
        'type': data['type'] ?? 'expense',
        'amount': data['amount'] ?? 0,
        'date': data['createdAt'],
        'jobOrderID': data['jobOrderID'] ?? '',
        'description': data['description'] ?? '',
        'source': 'manualExpenses',
      });
    }

    // Sort all by date descending
    all.sort((a, b) {
      final aDate = a['date'];
      final bDate = b['date'];
      if (aDate is Timestamp && bDate is Timestamp) {
        return bDate.compareTo(aDate);
      }
      return 0;
    });

    return all;
  }

  Future<void> _deleteTransaction(BuildContext context, String source, String docId) async {
    String collection;
    if (source == 'transactions') {
      collection = 'transactions';
    } else if (source == 'manualIncome') {
      collection = 'manualIncome';
    } else {
      collection = 'manualExpenses';
    }
    await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction deleted.'), backgroundColor: Colors.red),
    );
  }

  Future<void> _editTransaction(BuildContext context, String source, String docId, Map<String, dynamic> data) async {
    final typeController = TextEditingController(text: data['type']?.toString() ?? '');
    final amountController = TextEditingController(text: data['amount']?.toString() ?? '');
    final jobOrderIdController = TextEditingController(text: data['jobOrderID']?.toString() ?? '');
    final descriptionController = TextEditingController(text: data['description']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Transaction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: typeController,
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
              if (source == 'transactions')
                TextField(
                  controller: jobOrderIdController,
                  decoration: const InputDecoration(labelText: 'Job Order ID'),
                ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String collection;
                if (source == 'transactions') {
                  collection = 'transactions';
                } else if (source == 'manualIncome') {
                  collection = 'manualIncome';
                } else {
                  collection = 'manualExpenses';
                }
                final updateData = {
                  'type': typeController.text,
                  'amount': double.tryParse(amountController.text) ?? 0,
                  'description': descriptionController.text,
                };
                if (source == 'transactions') {
                  updateData['jobOrderID'] = jobOrderIdController.text;
                }
                await FirebaseFirestore.instance.collection(collection).doc(docId).update(updateData);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction updated.'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchAllTransactions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!;
        if (docs.isEmpty) return const Text('No transactions found.');
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _modernCard(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Job Order ID')),
                  DataColumn(label: Text('Description')),
                  DataColumn(label: Text('Edit')),
                  DataColumn(label: Text('Delete')),
                ],
                rows: docs.map((data) {
                  return DataRow(
                    cells: [
                      DataCell(Text(data['type'] ?? '')),
                      DataCell(Text('${data['amount'] ?? 0}')),
                      DataCell(Text(
                        data['date'] != null && data['date'] is Timestamp
                            ? DateFormat('yyyy-MM-dd').format((data['date'] as Timestamp).toDate())
                            : '',
                      )),
                      DataCell(Text(data['jobOrderID']?.toString() ?? '')),
                      DataCell(Text(data['description']?.toString() ?? '')),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editTransaction(context, data['source'], data['id'], data),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteTransaction(context, data['source'], data['id']),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}