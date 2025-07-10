import 'package:flutter/material.dart';
import 'dart:ui';
import 'products/product_inventory_page.dart';
import 'fabrics/fabric_logbook_page.dart';
import 'suppliers/supplier_dashboard_page.dart';
import 'customers/customer_dashboard_page.dart';

class InventoryPage extends StatefulWidget {
  final Function(String)? onTabChanged;

  const InventoryPage({Key? key, this.onTabChanged}) : super(key: key);

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Widget> _pages = [
    const ProductInventoryPage(),
    const FabricLogbookPage(),
    const SupplierDashboardPage(),
    const CustomerDashboardPage(),
  ];

  final List<Map<String, dynamic>> _tabs = [
    {
      'label': 'Products',
      'icon': Icons.grid_view_rounded,
      'color': Colors.blue,
    },
    {
      'label': 'Fabrics',
      'icon': Icons.palette_rounded,
      'color': Colors.green,
    },
    {
      'label': 'Suppliers',
      'icon': Icons.local_shipping_rounded,
      'color': Colors.purple,
    },
    {
      'label': 'Customers',
      'icon': Icons.people_rounded,
      'color': Colors.pink,
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
      begin: 1.0, // Start at full scale instead of 0.0
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut, // Use simpler curve
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero, // Start at normal position
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Start animation immediately without delay
    _animationController.forward();
    
    // Notify parent of initial tab immediately
    if (widget.onTabChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onTabChanged!(_tabs[_selectedTab]['label']);
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          // Main content (full screen, no padding)
          IndexedStack(
            index: _selectedTab,
            children: _pages,
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
      height: 75,
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
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: _tabs.asMap().entries.map((entry) {
                final index = entry.key;
                final tab = entry.value;
                final isSelected = _selectedTab == index;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTab = index;
                      });

                      // Notify parent of tab change
                      if (widget.onTabChanged != null) {
                        widget.onTabChanged!(tab['label']);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSelected ? tab['color'].withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              padding: EdgeInsets.all(isSelected ? 8 : 6),
                              decoration: BoxDecoration(
                                color: isSelected ? tab['color'] : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: tab['color'].withOpacity(0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ] : null,
                              ),
                              child: Icon(
                                tab['icon'],
                                color: isSelected ? Colors.white : Colors.grey[600],
                                size: isSelected ? 18 : 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Flexible(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 250),
                                style: TextStyle(
                                  fontSize: isSelected ? 10 : 9,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: isSelected ? tab['color'] : Colors.grey[600],
                                ),
                                child: Text(
                                  tab['label'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}