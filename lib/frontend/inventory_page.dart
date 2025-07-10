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

          // Floating navigation bar - positioned closer to bottom for compact design
          Positioned(
            bottom: 20, // Reduced from 30 to 20 for more compact positioning
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
      height: 60, // Reduced from 75 to 60 for more compact design
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16), // Reduced from 20 to 16
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // Reduced shadow opacity
            blurRadius: 15, // Reduced from 20 to 15
            offset: const Offset(0, 6), // Reduced from 10 to 6
            spreadRadius: 0.5, // Reduced from 1 to 0.5
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // Reduced from 0.06 to 0.04
            blurRadius: 8, // Reduced from 10 to 8
            offset: const Offset(0, 3), // Reduced from 5 to 3
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16), // Match container radius
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16), // Match container radius
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
                      margin: const EdgeInsets.all(3), // Reduced from 4 to 3
                      decoration: BoxDecoration(
                        color: isSelected ? tab['color'].withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(13), // Reduced from 16 to 13
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3), // Reduced vertical from 4 to 3
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              padding: EdgeInsets.all(isSelected ? 6 : 5), // Reduced from 8/6 to 6/5
                              decoration: BoxDecoration(
                                color: isSelected ? tab['color'] : Colors.transparent,
                                borderRadius: BorderRadius.circular(8), // Reduced from 10 to 8
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: tab['color'].withOpacity(0.2), // Reduced from 0.25 to 0.2
                                    blurRadius: 4, // Reduced from 6 to 4
                                    offset: const Offset(0, 2), // Reduced from 3 to 2
                                  ),
                                ] : null,
                              ),
                              child: Icon(
                                tab['icon'],
                                color: isSelected ? Colors.white : Colors.grey[600],
                                size: isSelected ? 16 : 14, // Reduced from 18/16 to 16/14
                              ),
                            ),
                            const SizedBox(height: 2),
                            Flexible(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 250),
                                style: TextStyle(
                                  fontSize: isSelected ? 9 : 8, // Reduced from 10/9 to 9/8
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