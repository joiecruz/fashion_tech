import 'package:flutter/material.dart';
import 'dart:ui';
import 'job_orders/job_order_list_page.dart';
import 'transactions/transaction_dashboard_page.dart';

class JobPage extends StatefulWidget {
  final Function(String)? onTabChanged;

  const JobPage({Key? key, this.onTabChanged}) : super(key: key);

  @override
  State<JobPage> createState() => _JobPageState();
}

class _JobPageState extends State<JobPage>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Widget> _pages = [
    const JobOrderListPage(),
    const TransactionDashboardPage(),
  ];

  final List<Map<String, dynamic>> _tabs = [
    {
      'label': 'Orders',
      'icon': Icons.assignment_rounded,
      'color': Colors.orange,
    },
    {
      'label': 'Transactions',
      'icon': Icons.analytics_rounded,
      'color': Colors.teal,
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    // Notify parent of initial tab
    if (widget.onTabChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onTabChanged!(_tabs[_selectedTab]['label']);
      });
    }
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index != _selectedTab) {
      setState(() {
        _selectedTab = index;
      });
      
      // Reset and play animation
      _animationController.reset();
      _animationController.forward();
      
      // Notify parent of tab change
      if (widget.onTabChanged != null) {
        widget.onTabChanged!(_tabs[index]['label']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          // Main content (full screen, no padding)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _pages[_selectedTab],
                ),
              );
            },
          ),

          // Floating navigation bar
          Positioned(
            bottom: 30,
            left: 60,
            right: 60,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildFloatingNavBar(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.8),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            children: _tabs.asMap().entries.map((entry) {
              final index = entry.key;
              final tab = entry.value;
              final isSelected = index == _selectedTab;
              final color = tab['color'] as Color;
              
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTabSelected(index),
                  child: Container(
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                color.withOpacity(0.2),
                                color.withOpacity(0.1),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            )
                          : null,
                      border: isSelected
                          ? Border.all(
                              color: color.withOpacity(0.3),
                              width: 1,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    margin: const EdgeInsets.all(4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? color.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            tab['icon'],
                            size: 20,
                            color: isSelected ? color : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? color : Colors.grey.shade700,
                            letterSpacing: 0.2,
                          ),
                          child: Text(tab['label']),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
