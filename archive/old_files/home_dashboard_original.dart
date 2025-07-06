import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fashion_tech/frontend/auth/login_page.dart';
import 'package:fashion_tech/frontend/auth/signup_page.dart';
import 'package:fashion_tech/frontend/profit/profit_checker.dart';
import 'package:fashion_tech/frontend/products/product_inventory_page.dart';
import 'design_system.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignSystem.backgroundGrey,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DesignSystem.spaceLG),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Header
                FadeSlideAnimation(
                  delay: 0,
                  child: _buildWelcomeHeader(),
                ),
                
                // Statistics Overview
                FadeSlideAnimation(
                  delay: 100,
                  child: _buildStatsOverview(),
                ),
                
                // Quick Actions
                FadeSlideAnimation(
                  delay: 200,
                  child: _buildQuickActions(),
                ),
                
                // Profit Checker Section
                FadeSlideAnimation(
                  delay: 300,
                  child: _buildProfitChecker(),
                ),
                
                // Recent Activity
                FadeSlideAnimation(
                  delay: 400,
                  child: _buildRecentActivity(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return ModernCard(
      gradient: LinearGradient(
        colors: [
          DesignSystem.primaryOrange.withOpacity(0.1),
          DesignSystem.secondaryTeal.withOpacity(0.1),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  DesignSystem.primaryOrange,
                  DesignSystem.primaryOrange.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(DesignSystem.radiusMD),
            ),
            child: const Icon(
              Icons.dashboard,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: DesignSystem.spaceLG),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back!',
                  style: DesignSystem.headlineStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: DesignSystem.spaceXS),
                Text(
                  'Fashion Tech Dashboard',
                  style: DesignSystem.bodyStyle.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: DesignSystem.spaceLG),
        Text(
          'Inventory Overview',
          style: DesignSystem.titleStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: DesignSystem.spaceMD),
        Row(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('fabrics').snapshots(),
                builder: (context, snapshot) {
                  double totalYards = 0.0;
                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final quantity = data['quantity'];
                      if (quantity != null) {
                        totalYards += (quantity as num).toDouble();
                      }
                    }
                  }
                  return ModernStatCard(
                    icon: Icons.checkroom,
                    value: '${totalYards.toStringAsFixed(1)} yds',
                    label: 'Fabric Units',
                    iconColor: DesignSystem.primaryOrange,
                    isCompact: true,
                  );
                },
              ),
            ),
            const SizedBox(width: DesignSystem.spaceMD),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('products').snapshots(),
                builder: (context, snapshot) {
                  int totalProducts = 0;
                  if (snapshot.hasData) {
                    totalProducts = snapshot.data!.docs.length;
                  }
                  return ModernStatCard(
                    icon: Icons.inventory,
                    value: totalProducts.toString(),
                    label: 'Products',
                    iconColor: DesignSystem.secondaryTeal,
                    isCompact: true,
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignSystem.spaceMD),
        Row(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('suppliers').snapshots(),
                builder: (context, snapshot) {
                  int totalSuppliers = 0;
                  if (snapshot.hasData) {
                    totalSuppliers = snapshot.data!.docs.length;
                  }
                  return ModernStatCard(
                    icon: Icons.business,
                    value: totalSuppliers.toString(),
                    label: 'Suppliers',
                    iconColor: DesignSystem.successGreen,
                    isCompact: true,
                  );
                },
              ),
            ),
            const SizedBox(width: DesignSystem.spaceMD),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('customers').snapshots(),
                builder: (context, snapshot) {
                  int totalCustomers = 0;
                  if (snapshot.hasData) {
                    totalCustomers = snapshot.data!.docs.length;
                  }
                  return ModernStatCard(
                    icon: Icons.people,
                    value: totalCustomers.toString(),
                    label: 'Customers',
                    iconColor: Colors.pink[600]!,
                    isCompact: true,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: DesignSystem.spaceLG),
        Text(
          'Quick Actions',
          style: DesignSystem.titleStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: DesignSystem.spaceMD),
        ModernCard(
          child: Column(
            children: [
              _buildQuickActionTile(
                icon: Icons.inventory_2,
                title: 'Manage Products',
                subtitle: 'View and manage your product inventory',
                color: DesignSystem.primaryOrange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductInventoryPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _buildQuickActionTile(
                icon: Icons.attach_money,
                title: 'Profit Checker',
                subtitle: 'Check your business profitability',
                color: DesignSystem.successGreen,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfitReportPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _buildQuickActionTile(
                icon: Icons.login,
                title: 'Account Access',
                subtitle: 'Login or signup for more features',
                color: DesignSystem.secondaryTeal,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => Container(
                      padding: const EdgeInsets.all(DesignSystem.spaceLG),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Account Access',
                            style: DesignSystem.titleStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: DesignSystem.spaceLG),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LoginPage(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.login),
                                  label: const Text('Login'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: DesignSystem.secondaryTeal,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: DesignSystem.spaceMD),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const SignUpPage(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.person_add),
                                  label: const Text('Sign Up'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: DesignSystem.secondaryTeal,
                                    side: BorderSide(color: DesignSystem.secondaryTeal),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(DesignSystem.radiusMD),
        ),
        child: Icon(
          icon,
          color: color,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: DesignSystem.bodyStyle.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: DesignSystem.captionStyle.copyWith(
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey[400],
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: DesignSystem.spaceMD,
        vertical: DesignSystem.spaceSM,
      ),
    );
  }

  Widget _buildProfitChecker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: DesignSystem.spaceLG),
        Text(
          'Profit Overview',
          style: DesignSystem.titleStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: DesignSystem.spaceMD),
        ModernCard(
          gradient: LinearGradient(
            colors: [
              DesignSystem.successGreen.withOpacity(0.1),
              DesignSystem.successGreen.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(DesignSystem.spaceMD),
                    decoration: BoxDecoration(
                      color: DesignSystem.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(DesignSystem.radiusMD),
                    ),
                    child: Icon(
                      Icons.attach_money,
                      color: DesignSystem.successGreen,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: DesignSystem.spaceLG),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Projected Income',
                          style: DesignSystem.bodyStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: DesignSystem.spaceXS),
                        ValueListenableBuilder<double>(
                          valueListenable: ProductInventoryPage.potentialValueNotifier,
                          builder: (context, projectedIncome, _) {
                            return Text(
                              '₱${projectedIncome.toStringAsFixed(2)}',
                              style: DesignSystem.headlineStyle.copyWith(
                                fontWeight: FontWeight.bold,
                                color: DesignSystem.successGreen,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignSystem.spaceLG),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfitReportPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics),
                  label: const Text('View Detailed Analysis'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignSystem.successGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: DesignSystem.spaceMD,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignSystem.radiusMD),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: DesignSystem.spaceLG),
        Text(
          'Recent Activity',
          style: DesignSystem.titleStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: DesignSystem.spaceMD),
        ModernCard(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('fabric_logs')
                .orderBy('timestamp', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(DesignSystem.spaceLG),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final logs = snapshot.data!.docs;
              
              if (logs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(DesignSystem.spaceLG),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: DesignSystem.spaceMD),
                        Text(
                          'No recent activity',
                          style: DesignSystem.bodyStyle.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: logs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final doc = entry.value;
                  final data = doc.data() as Map<String, dynamic>;
                  
                  return Column(
                    children: [
                      _buildActivityItem(
                        action: data['action'] ?? 'Unknown action',
                        fabricName: data['fabricName'] ?? 'Unknown fabric',
                        time: _timeAgo(data['timestamp']),
                      ),
                      if (index < logs.length - 1) const Divider(height: 1),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ),
        const SizedBox(height: DesignSystem.spaceLG),
      ],
    );
  }

  Widget _buildActivityItem({
    required String action,
    required String fabricName,
    required String time,
  }) {
    IconData icon;
    Color color;
    
    switch (action.toLowerCase()) {
      case 'added':
        icon = Icons.add_circle;
        color = DesignSystem.successGreen;
        break;
      case 'removed':
        icon = Icons.remove_circle;
        color = DesignSystem.errorRed;
        break;
      case 'updated':
        icon = Icons.edit;
        color = DesignSystem.primaryOrange;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey[600]!;
    }

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(DesignSystem.radiusSM),
        ),
        child: Icon(
          icon,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        '$action $fabricName',
        style: DesignSystem.bodyStyle.copyWith(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        time,
        style: DesignSystem.captionStyle.copyWith(
          color: Colors.grey[600],
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: DesignSystem.spaceMD,
        vertical: DesignSystem.spaceXS,
      ),
    );
  }

  String _timeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'Unknown time';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
