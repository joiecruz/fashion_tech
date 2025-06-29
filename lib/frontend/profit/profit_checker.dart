import 'package:flutter/material.dart';
import '../../backend/fetch_profit.dart';

class ProfitReportPage extends StatefulWidget {
  const ProfitReportPage({super.key});

  @override
  State<ProfitReportPage> createState() => _ProfitReportPageState();
}

class _ProfitReportPageState extends State<ProfitReportPage> {
  double? _profit;
  List<Map<String, dynamic>> _productProfits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfit();
  }

  Future<void> _loadProfit() async {
    final profit = await fetchUserTotalProfit();
    final productProfits = await fetchUserProductProfits();
    setState(() {
      _profit = profit;
      _productProfits = productProfits;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          fontSize: 20,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfit,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.green[50],
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Profit',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₱${_profit?.toStringAsFixed(2) ?? "0.00"}',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Product Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                    ..._productProfits.map((p) => Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.blue[100],
                                      child: Icon(Icons.checkroom, color: Colors.blue[700]),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        p['name'] ?? 'Unnamed Product',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: p['profit'] >= 0 ? Colors.green[100] : Colors.red[100],
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        p['profit'] >= 0
                                            ? 'Profit'
                                            : 'Loss',
                                        style: TextStyle(
                                          color: p['profit'] >= 0 ? Colors.green[700] : Colors.red[700],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    _buildStatItem(
                                      'Sold',
                                      p['totalQtySold'].toString(),
                                      Icons.shopping_cart_outlined,
                                      Colors.orange[700]!,
                                    ),
                                    _buildStatItem(
                                      'Revenue',
                                      '₱${p['totalRevenue'].toStringAsFixed(2)}',
                                      Icons.attach_money,
                                      Colors.green[700]!,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildStatItem(
                                      'Job Orders',
                                      p['jobOrderCount'].toString(),
                                      Icons.assignment_turned_in,
                                      Colors.blue[700]!,
                                    ),
                                    _buildStatItem(
                                      'Unit Cost',
                                      '₱${p['unitCost'].toStringAsFixed(2)}',
                                      Icons.precision_manufacturing,
                                      Colors.purple[700]!,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'Profit: ₱${p['profit'].toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: p['profit'] >= 0 ? Colors.green[800] : Colors.red[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}