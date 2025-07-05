import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/fetch_profit.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfitReportPage extends StatefulWidget {
  const ProfitReportPage({super.key});

  @override
  State<ProfitReportPage> createState() => _ProfitReportPageState();
}

class _ProfitReportPageState extends State<ProfitReportPage> {
  double? _profit;
  List<Map<String, dynamic>> _productProfits = [];
  bool _loading = true;

  // Statistics
  int _totalProducts = 0;
  int _totalSold = 0;
  int _totalJobOrders = 0;
  final user = FirebaseAuth.instance.currentUser;
  String? userId;
  // Sales vs Expenses
  double? _totalSales;
  double? _totalExpenses;

  // --- UI constants ---
  final _cardRadius = BorderRadius.circular(20);
  final _shadowColor = Colors.black.withOpacity(0.08);
  final _cardElevation = 8.0;

  @override
  void initState() {
    super.initState();
    userId = user?.uid;
    _loadProfit();
  }

  Future<double> _fetchTotalSales() async {
    final salesSnap = await FirebaseFirestore.instance
        .collection('salesLog')
        .where('soldBy', isEqualTo: userId)
        .get();
    double total = 0;
    for (final doc in salesSnap.docs) {
      total += (doc.data()['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  Future<double> _fetchTotalExpenses() async {
    final expenseSnap = await FirebaseFirestore.instance
        .collection('transactions')
        .where('type', isEqualTo: 'expense')
        .get();
    double total = 0;
    for (final doc in expenseSnap.docs) {
      total += (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  Future<void> _loadProfit() async {
    final profit = await fetchUserTotalProfit();
    final productProfits = await fetchUserProductProfits();
    final totalSales = await _fetchTotalSales();
    final totalExpenses = await _fetchTotalExpenses();

    // Calculate statistics
    int totalProducts = productProfits.length;
    int totalSold = 0;
    int totalJobOrders = 0;
    for (final p in productProfits) {
      totalSold += (p['totalQtySold'] ?? 0) as int;
      totalJobOrders += (p['jobOrderCount'] ?? 0) as int;
    }

    setState(() {
      _profit = profit;
      _productProfits = productProfits;
      _totalProducts = totalProducts;
      _totalSold = totalSold;
      _totalJobOrders = totalJobOrders;
      _totalSales = totalSales;
      _totalExpenses = totalExpenses;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final netProfit = ((_totalSales ?? 0) - (_totalExpenses ?? 0));
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Profit Checker'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Total Profit Card (Large, subtle gradient) ---
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 22),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
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
                        const SizedBox(height: 18),
                        Text(
                          '₱${_productProfits
                              .map((p) => (p['totalRevenue'] as num?)?.toDouble() ?? 0.0)
                              .fold<double>(0, (prev, e) => prev + e)
                              .toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 54,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.trending_up, color: Colors.green[700], size: 28),
                            const SizedBox(width: 8),
                            Text(
                              'Sales: ₱${_totalSales?.toStringAsFixed(2) ?? '0.00'}',
                              style: const TextStyle(fontSize: 20, color: Colors.black87),
                            ),
                            const SizedBox(width: 18),
                            Icon(Icons.trending_down, color: Colors.red[700], size: 28),
                            const SizedBox(width: 8),
                            Text(
                              'Expenses: ₱${_totalExpenses?.toStringAsFixed(2) ?? '0.00'}',
                              style: const TextStyle(fontSize: 20, color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Total Profit = Sales - Expenses',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- Stats Row (Lighter gradients) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        // First Stats Row
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildBigStatCard(
                                icon: Icons.trending_up,
                                label: 'Sales',
                                value: '₱${_totalSales?.toStringAsFixed(2) ?? '0.00'}',
                                color: Colors.green,
                                gradientColors: [
                                  Colors.green.withOpacity(0.10),
                                  Colors.white,
                                ],
                                subtitle: 'Total Revenue',
                              ),
                              _buildBigStatCard(
                                icon: Icons.trending_down,
                                label: 'Expenses',
                                value: '₱${_totalExpenses?.toStringAsFixed(2) ?? '0.00'}',
                                color: Colors.red,
                                gradientColors: [
                                  Colors.red.withOpacity(0.10),
                                  Colors.white,
                                ],
                                subtitle: 'Total Costs',
                              ),
                            ],
                          ),
                        ),
                        // Second Stats Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                  const SizedBox(height: 22),

                  // --- Product Breakdown Section ---
                  const Text(
                    'Product Breakdown',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_productProfits.isEmpty)
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
                              'No products found.',
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._productProfits
                        .where((p) => (p['totalRevenue'] ?? 0) != 0)
                        .map((p) => _buildProductBreakdownCard(p)),
                ],
              ),
            ),
    );
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
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
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
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Bigger, White Product Breakdown Card ---
  Widget _buildProductBreakdownCard(Map<String, dynamic> p) {
    final bool isProfit = (p['profit'] ?? 0) >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isProfit
              ? Colors.green.withOpacity(0.08)
              : Colors.red.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue[50],
            radius: 24,
            child: Icon(Icons.checkroom, color: Colors.blue[700], size: 26),
          ),
          const SizedBox(width: 16),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatItem(
                      Icons.shopping_cart_outlined,
                      Colors.orange[700]!,
                      'Sold: ${(p['totalQtySold'] ?? 0)}',
                    ),
                    const SizedBox(width: 16),
                    _buildStatItem(
                      Icons.attach_money,
                      Colors.green[700]!,
                      '₱${(p['totalRevenue'] ?? 0).toStringAsFixed(2)}',
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
                  isProfit ? 'Profit' : 'Loss',
                  style: TextStyle(
                    color: isProfit ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₱${(p['profit'] ?? 0).toStringAsFixed(2)}',
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
    );
  }

  Widget _buildStatItem(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}