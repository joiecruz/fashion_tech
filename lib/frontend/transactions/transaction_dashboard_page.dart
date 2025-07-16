import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/fetch_profit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/log_helper.dart';

class TransactionDashboardPage extends StatefulWidget {
  const TransactionDashboardPage({Key? key}) : super(key: key);

  @override
  State<TransactionDashboardPage> createState() => _TransactionDashboardPageState();
}

class _TransactionDashboardPageState extends State<TransactionDashboardPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  // Statistics
  int _totalProducts = 0;
  int _totalSold = 0;
  int _totalJobOrders = 0;
  final user = FirebaseAuth.instance.currentUser;
  String? userId;
  String? userEmail;
  // Sales vs Expenses
  double? _totalSales;
  double? _totalExpenses;

  // Fabric breakdown
  List<Map<String, dynamic>> _fabrics = [];
  List<Map<String, dynamic>> _productProfits = [];

  // --- UI constants ---
  final _cardRadius = BorderRadius.circular(20);
  final _shadowColor = Colors.black.withOpacity(0.08);
  final _cardElevation = 8.0;

  // State for modal visibility (removed speed dial)
  // Controllers for manual entry
  final _expenseAmountController = TextEditingController();
  final _expenseDescriptionController = TextEditingController();
  final _incomeAmountController = TextEditingController();
  final _incomeDescriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    userId = user?.uid;
    userEmail = user?.email;
    _fetchFabrics();
    _loadProfit();
  }

  Future<double> _fetchTotalSales() async {
    // Get sales from salesLog
    final salesSnap = await FirebaseFirestore.instance
        .collection('salesLog')
        .where('soldBy', isEqualTo: userId)
        .get();
    print('Found ${salesSnap.docs.length} sales records');
    double total = 0;
    for (final doc in salesSnap.docs) {
      final revenue = (doc.data()['totalRevenue'] as num?)?.toDouble() ?? 0.0;
      total += revenue;
      print('Sale record: revenue = $revenue');
    }

    // Add manual income entries
    final manualIncomeSnap = await FirebaseFirestore.instance
        .collection('manualIncome')
        .where('createdBy', isEqualTo: userId)
        .get();
    print('Found ${manualIncomeSnap.docs.length} manual income records');
    for (final doc in manualIncomeSnap.docs) {
      final amount = (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
      total += amount;
      print('Manual income: amount = $amount');
    }

    return total;
  }

  Future<double> _fetchTotalExpenses() async {
    double totalExpense = 0.0;
    
    // Get fabric expenses
    final snapshot = await FirebaseFirestore.instance
        .collection('fabrics')
        .where('createdBy', isEqualTo: userId)
        .get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final quantity = (data['quantity'] ?? 0) as num;
      final pricePerUnit = (data['pricePerUnit'] ?? 0) as num;
      totalExpense += quantity * pricePerUnit;
    }

    // Add manual expense entries
    final manualExpenseSnap = await FirebaseFirestore.instance
        .collection('manualExpenses')
        .where('createdBy', isEqualTo: userId)
        .get();
    print('Found ${manualExpenseSnap.docs.length} manual expense records');
    for (final doc in manualExpenseSnap.docs) {
      final amount = (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
      totalExpense += amount;
      print('Manual expense: amount = $amount');
    }

    return totalExpense;
  }

  Future<void> _fetchFabrics() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('fabrics')
        .where('createdBy', isEqualTo: userId)
        .get();
    print('Found ${snapshot.docs.length} fabric records');
    setState(() {
      _fabrics = snapshot.docs.map((doc) {
        final data = doc.data();
        final fabric = {
          'name': data['name'] ?? 'Unnamed Fabric',
          'quantity': (data['quantity'] ?? 0) as num,
          'pricePerUnit': (data['pricePerUnit'] ?? 0) as num,
          'image': data['swatchImageURL'] ?? data['imageURL'] ?? data['imageBase64'] ?? '',
        };
        print('Fabric: ${fabric['name']}, Qty: ${fabric['quantity']}, Price: ${fabric['pricePerUnit']}');
        return fabric;
      }).toList();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchProducts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('createdBy', isEqualTo: userId)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'name': data['name'] ?? '',
        'image': data['image'] ?? data['imageURL'] ?? data['imageBase64'] ?? '',
      };
    }).toList();
  }

  Future<void> _loadProfit() async {
    print('Starting data fetch for user: $userId');
    
    final productProfits = await fetchUserProductProfits();
    print('Fetched ${productProfits.length} products');
    
    final totalSales = await _fetchTotalSales();
    print('Total sales: $totalSales');
    
    final totalExpenses = await _fetchTotalExpenses();
    print('Total expenses: $totalExpenses');
    
    final products = await _fetchProducts();
    print('Fetched ${products.length} product details');

    // Calculate statistics and patch image if missing
    int totalProducts = productProfits.length;
    int totalSold = 0;
    int totalJobOrders = 0;
    for (final p in productProfits) {
      totalSold += (p['totalQtySold'] ?? 0) as int;
      totalJobOrders += (p['jobOrderCount'] ?? 0) as int;
      print('Product: ${p['name']}, Sold: ${p['totalQtySold']}, Revenue: ${p['totalRevenue']}');

      // Try to get image from product details
      String image = p['image'] ?? p['imageURL'] ?? p['imageUrl'] ?? p['imageBase64'] ?? '';
      if (image.isEmpty && p['name'] != null) {
        final product = products.firstWhere(
          (prod) => (prod['name'] ?? '').toString().toLowerCase() == p['name'].toString().toLowerCase(),
          orElse: () => {},
        );
        if (product.isNotEmpty) {
          image = product['image'] ?? '';
        }
      }
      // Fallback to fabric image if still empty
      if (image.isEmpty && p['fabricName'] != null) {
        final fabric = _fabrics.firstWhere(
          (f) => (f['name'] ?? '').toString().toLowerCase() == p['fabricName'].toString().toLowerCase(),
          orElse: () => {},
        );
        if (fabric.isNotEmpty) {
          image = fabric['image'] ?? '';
        }
      }
      p['image'] = image;
    }

    print('Total products: $totalProducts, Total sold: $totalSold, Total job orders: $totalJobOrders');
    print('Fabrics with expenses: ${_fabrics.where((f) => ((f['quantity'] ?? 0) as num) * ((f['pricePerUnit'] ?? 0) as num) > 0).length}');

    setState(() {
      _productProfits = productProfits;
      _totalProducts = totalProducts;
      _totalSold = totalSold;
      _totalJobOrders = totalJobOrders;
      _totalSales = totalSales;
      _totalExpenses = totalExpenses;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _expenseAmountController.dispose();
    _expenseDescriptionController.dispose();
    _incomeAmountController.dispose();
    _incomeDescriptionController.dispose();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  final netProfit = ((_totalSales ?? 0) - (_totalExpenses ?? 0));
  final screenWidth = MediaQuery.of(context).size.width;
  final horizontalPadding = screenWidth < 400 ? 10.0 : 20.0;

  return Scaffold(
    backgroundColor: Colors.grey[50],
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: const Text(
        'Transaction Dashboard',
        style: TextStyle(color: Colors.black),
      ),
      centerTitle: true,
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: EdgeInsets.only(
              left: horizontalPadding,
              right: horizontalPadding,
              top: 18,
              bottom: 120, // Add bottom padding to keep content above floating nav bar
            ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Total Profit Card (Large, subtle gradient) ---
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 22),
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth < 400 ? 16 : 24,
                      vertical: screenWidth < 400 ? 16 : 28,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[100]!, Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Profit',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '₱${netProfit.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 18,
                          runSpacing: 8,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.trending_up, color: Colors.green[700], size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Income: ₱${_totalSales?.toStringAsFixed(2) ?? '0.00'}',
                                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.trending_down, color: Colors.red[700], size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Expenses: ₱${_totalExpenses?.toStringAsFixed(2) ?? '0.00'}',
                                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Total Profit = Income - Expenses',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // User Info Banner
                  if (userEmail != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 22),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green[50]!, Colors.green[100]!],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green[100]!.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green[600],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Financial Dashboard',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[800],
                                  ),
                                ),
                                Text(
                                  'Showing only your transactions & data • $userEmail',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // --- Stats Row (Lighter gradients) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Column(
                      children: [
                        // First Stats Row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.green.withOpacity(0.10),
                                          Colors.white,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: _cardRadius,
                                      boxShadow: [
                                        BoxShadow(
                                          color: _shadowColor,
                                          blurRadius: _cardElevation,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      border: Border.all(color: Colors.green.withOpacity(0.08)),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.07),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Icon(Icons.trending_up, color: Colors.green.withOpacity(0.7), size: 32),
                                        ),
                                        const SizedBox(height: 16),
                                        FittedBox(
                                          child: Text(
                                            '₱${_totalSales?.toStringAsFixed(2) ?? '0.00'}',
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 24,
                                              letterSpacing: 0.5,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Income',
                                          style: TextStyle(
                                            color: Colors.green.withOpacity(0.7),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Total Revenue',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 6),
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showAddIncomeModal(),
                                      icon: const Icon(Icons.add, size: 20),
                                      label: const Text(
                                        'Add Income',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[600],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 3,
                                        shadowColor: Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.red.withOpacity(0.10),
                                          Colors.white,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: _cardRadius,
                                      boxShadow: [
                                        BoxShadow(
                                          color: _shadowColor,
                                          blurRadius: _cardElevation,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      border: Border.all(color: Colors.red.withOpacity(0.08)),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.07),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Icon(Icons.trending_down, color: Colors.red.withOpacity(0.7), size: 32),
                                        ),
                                        const SizedBox(height: 16),
                                        FittedBox(
                                          child: Text(
                                            '₱${_totalExpenses?.toStringAsFixed(2) ?? '0.00'}',
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 24,
                                              letterSpacing: 0.5,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Expenses',
                                          style: TextStyle(
                                            color: Colors.red.withOpacity(0.7),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Total Costs',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 6),
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showAddExpenseModal(),
                                      icon: const Icon(Icons.remove, size: 20),
                                      label: const Text(
                                        'Add Expense',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[600],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 3,
                                        shadowColor: Colors.red.withOpacity(0.3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Second Stats Row
                        Row(
                          children: [
                            _buildBigStatCard(
                              icon: Icons.checkroom,
                              label: 'Products',
                              value: _totalProducts.toString(),
                              color: Colors.blue,
                              gradientColors: [
                                Colors.blue.withOpacity(0.10),
                                Colors.white,
                              ],
                              subtitle: 'In Inventory',
                            ),
                            _buildBigStatCard(
                              icon: Icons.shopping_cart,
                              label: 'Sold',
                              value: _totalSold.toString(),
                              color: Colors.orange,
                              gradientColors: [
                                Colors.orange.withOpacity(0.10),
                                Colors.white,
                              ],
                              subtitle: 'Items',
                            ),
                            _buildBigStatCard(
                              icon: Icons.assignment_turned_in,
                              label: 'Job Orders',
                              value: _totalJobOrders.toString(),
                              color: Colors.purple,
                              gradientColors: [
                                Colors.purple.withOpacity(0.10),
                                Colors.white,
                              ],
                              subtitle: 'Active',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // --- Product Breakdown Section ---
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Product Breakdown',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Show debug info
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Debug: ${_productProfits.length} total products, ${_productProfits.where((p) => (p['totalQtySold'] ?? 0) > 0).length} with sales',
                      style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                    ),
                  ),
                  
                  if (_productProfits.where((p) => (p['totalQtySold'] ?? 0) > 0 && (p['totalRevenue'] ?? 0) != 0).isEmpty)
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey[400], size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No products with sales found.\nTotal products in database: ${_productProfits.length}',
                              style: const TextStyle(fontSize: 16, color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._productProfits
                        .where((p) => (p['totalQtySold'] ?? 0) > 0 && (p['totalRevenue'] ?? 0) != 0)
                        .map((p) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: _buildProductBreakdownCard(p),
                            )),

                  // Show all products for debugging
                  if (_productProfits.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'All Products (Debug)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._productProfits.map((p) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${p['name']} - Sold: ${p['totalQtySold']} - Revenue: ₱${(p['totalRevenue'] ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    )),
                  ],

                  // --- Fabric Breakdown Section ---
                  const SizedBox(height: 32),
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.orange[600],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Fabric Breakdown',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_fabrics.where((f) => ((f['quantity'] ?? 0) as num) * ((f['pricePerUnit'] ?? 0) as num) > 0).isEmpty)
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey[400], size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'No fabrics with expenses found.',
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._fabrics
                        .where((f) => ((f['quantity'] ?? 0) as num) * ((f['pricePerUnit'] ?? 0) as num) > 0)
                        .map((f) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: _buildFabricBreakdownCard(f),
                            )),
                ],
              ),
            ),
    );
  }

  // Add Expense Modal
  void _showAddExpenseModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.remove, color: Colors.red[600]),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Add Expense',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _expenseAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (₱)',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _expenseDescriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _expenseAmountController.clear();
                        _expenseDescriptionController.clear();
                        Navigator.pop(context);
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _addExpense(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Add Expense'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add Income Modal
  void _showAddIncomeModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add, color: Colors.green[600]),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Add Income',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _incomeAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (₱)',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _incomeDescriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _incomeAmountController.clear();
                        _incomeDescriptionController.clear();
                        Navigator.pop(context);
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _addIncome(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Add Income'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

Future<String> getNextManualIncomeId() async {
  const prefix = 'manualIncome_';
  final snap = await FirebaseFirestore.instance
      .collection('manualIncome')
      .where('jobOrderID', isGreaterThanOrEqualTo: prefix)
      .where('jobOrderID', isLessThan: '${prefix}z')
      .orderBy('jobOrderID', descending: true)
      .limit(1)
      .get();

  if (snap.docs.isEmpty) {
    return '${prefix}01';
  }
  final lastId = snap.docs.first['jobOrderID'] as String? ?? '';
  final number = int.tryParse(lastId.replaceFirst(prefix, '')) ?? 0;
  final nextNumber = (number + 1).toString().padLeft(2, '0');
  return '$prefix$nextNumber';
}

Future<String> getNextManualExpenseId() async {
  const prefix = 'manualExpense_';
  final snap = await FirebaseFirestore.instance
      .collection('manualExpenses')
      .where('jobOrderID', isGreaterThanOrEqualTo: prefix)
      .where('jobOrderID', isLessThan: '${prefix}z')
      .orderBy('jobOrderID', descending: true)
      .limit(1)
      .get();

  if (snap.docs.isEmpty) {
    return '${prefix}01';
  }
  final lastId = snap.docs.first['jobOrderID'] as String? ?? '';
  final number = int.tryParse(lastId.replaceFirst(prefix, '')) ?? 0;
  final nextNumber = (number + 1).toString().padLeft(2, '0');
  return '$prefix$nextNumber';
}


Future<void> _addExpense() async {
  final amount = double.tryParse(_expenseAmountController.text);
  final description = _expenseDescriptionController.text.trim();

  if (amount == null || amount <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter a valid amount')),
    );
    return;
  }

  if (description.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter a description')),
    );
    return;
  }

  try {
    final jobOrderID = await getNextManualExpenseId();
    await FirebaseFirestore.instance.collection('manualExpenses').add({
      'amount': amount,
      'description': description,
      'createdBy': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'expense',
      'jobOrderID': jobOrderID,
    });

    _expenseAmountController.clear();
    _expenseDescriptionController.clear();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Expense added successfully'),
        backgroundColor: Colors.green,
      ),
    );

    // Refresh data
    _loadProfit();
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error adding expense: $e')),
    );
  }
}
Future<void> _addIncome() async {
  final amount = double.tryParse(_incomeAmountController.text);
  final description = _incomeDescriptionController.text.trim();

  if (amount == null || amount <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter a valid amount')),
    );
    return;
  }

  if (description.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter a description')),
    );
    return;
  }

  try {
    final jobOrderID = await getNextManualIncomeId();
    await FirebaseFirestore.instance.collection('manualIncome').add({
      'amount': amount,
      'description': description,
      'createdBy': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'income',
      'jobOrderID': jobOrderID,
    });

    _incomeAmountController.clear();
    _incomeDescriptionController.clear();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Income added successfully'),
        backgroundColor: Colors.green,
      ),
    );

    // Refresh data
    _loadProfit();
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error adding income: $e')),
    );
  }
}

  Widget _buildBigStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required List<Color> gradientColors,
    String? subtitle,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: _cardRadius,
          boxShadow: [
            BoxShadow(
              color: _shadowColor,
              blurRadius: _cardElevation,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color.withOpacity(0.7), size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper for product/fabric images (base64, network, fallback)
  Widget _buildImage(String? imageUrl, {double size = 48, IconData fallbackIcon = Icons.image}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Icon(fallbackIcon, size: size * 0.5, color: Colors.grey[400]);
    }
    if (imageUrl.startsWith('data:image')) {
      final base64Data = imageUrl.split(',').last;
      try {
        final decoded = base64Decode(base64Data);
        return ClipRRect(
          borderRadius: BorderRadius.circular(size / 4),
          child: Image.memory(
            decoded,
            fit: BoxFit.cover,
            width: size,
            height: size,
          ),
        );
      } catch (e) {
        return Icon(Icons.broken_image, size: size * 0.5, color: Colors.red[300]);
      }
    } else if (Uri.tryParse(imageUrl)?.isAbsolute == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 4),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: size,
          height: size,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) {
            return Icon(fallbackIcon, color: Colors.grey[400], size: size * 0.5);
          },
        ),
      );
    } else {
      return Icon(fallbackIcon, size: size * 0.5, color: Colors.grey[400]);
    }
  }

  // --- Product Breakdown Card ---
  Widget _buildProductBreakdownCard(Map<String, dynamic> p) {
    final bool isProfit = (p['totalRevenue'] ?? 0) >= 0;
    final double unitCost = (p['unitCost'] ?? 0).toDouble();
    final image = p['image'] ?? p['imageURL'] ?? p['imageUrl'] ?? p['imageBase64'] ?? '';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            _buildImage(
              image,
              size: 48,
              fallbackIcon: Icons.checkroom,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p['name'] ?? 'Unnamed Product',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      _buildStatItem(
                        Icons.shopping_cart_outlined,
                        Colors.orange[700]!,
                        'Sold: ${(p['totalQtySold'] ?? 0)}',
                      ),
                      _buildStatItem(
                        Icons.attach_money,
                        Colors.green[700]!,
                        '₱${unitCost.toStringAsFixed(2)}/unit',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isProfit ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isProfit ? 'Sales' : 'Loss',
                    style: TextStyle(
                      color: isProfit ? Colors.green[700] : Colors.red[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '₱${(p['totalRevenue'] ?? 0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isProfit ? Colors.green[800] : Colors.red[800],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Fabric Breakdown Card ---
  Widget _buildFabricBreakdownCard(Map<String, dynamic> fabric) {
    final totalExpense = (fabric['quantity'] as num) * (fabric['pricePerUnit'] as num);
    final pricePerUnit = (fabric['pricePerUnit'] as num).toDouble();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            _buildImage(
              fabric['image'],
              size: 48,
              fallbackIcon: Icons.texture,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fabric['name'] ?? 'Unnamed Fabric',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      _buildStatItem(
                        Icons.inventory_2,
                        Colors.orange[700]!,
                        'Qty: ${fabric['quantity']}',
                      ),
                      _buildStatItem(
                        Icons.attach_money,
                        Colors.green[700]!,
                        '₱${pricePerUnit.toStringAsFixed(2)}/unit',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Expense',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '₱${totalExpense.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, Color color, String text, {Color? valueColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: valueColor ?? Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Edit Transaction (future-proof stub for logging)
  Future<void> _editTransaction(String transactionId, Map<String, dynamic> updatedFields) async {
    try {
      await FirebaseFirestore.instance.collection('transactions').doc(transactionId).update(updatedFields);
      await addLog(
        collection: 'transactionLogs',
        createdBy: FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
        remarks: 'Edited transaction',
        changeType: 'edit',
        extraData: {
          'transactionId': transactionId,
          'updatedFields': updatedFields,
        },
      );
    } catch (e) {
      print('Failed to log transaction edit: $e');
    }
  }

  /// Delete Transaction (future-proof stub for logging)
  Future<void> _deleteTransaction(String transactionId) async {
    try {
      await FirebaseFirestore.instance.collection('transactions').doc(transactionId).delete();
      await addLog(
        collection: 'transactionLogs',
        createdBy: FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
        remarks: 'Deleted transaction',
        changeType: 'delete',
        extraData: {
          'transactionId': transactionId,
        },
      );
    } catch (e) {
      print('Failed to log transaction deletion: $e');
    }
  }
}
