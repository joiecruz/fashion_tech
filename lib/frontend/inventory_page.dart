import 'package:flutter/material.dart';
import 'dart:ui';
import 'products/product_inventory_page.dart';
import 'fabrics/fabric_logbook_page.dart';
import '../../backend/fetch_suppliers.dart';

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
    const SuppliersPage(),
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
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    // Start animation after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _animationController.forward();
        // Notify parent of initial tab
        if (widget.onTabChanged != null) {
          widget.onTabChanged!(_tabs[_selectedTab]['label']);
        }
      }
    });
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
            left: 80,
            right: 80,
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
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSelected ? tab['color'].withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            style: TextStyle(
                              fontSize: isSelected ? 10 : 9,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? tab['color'] : Colors.grey[600],
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
      ),
    );
  }
}

// Suppliers Page with Firestore fetching
class SuppliersPage extends StatelessWidget {
  const SuppliersPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: FetchSuppliersBackend.fetchAllSuppliers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading suppliers',
              style: TextStyle(color: Colors.red[700]),
            ),
          );
        }
        final suppliers = snapshot.data ?? [];
        if (suppliers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 20),
                Text(
                  'No Suppliers Found',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add suppliers to manage your supply chain.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: suppliers.length,
          itemBuilder: (context, index) {
            final supplier = suppliers[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple[100],
                  child: Icon(Icons.local_shipping, color: Colors.purple[700]),
                ),
                title: Text(
                  supplier['supplierName'] ?? 'Unnamed Supplier',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (supplier['contactNum'] != null && supplier['contactNum'].toString().isNotEmpty)
                    Text('Contact: ${supplier['contactNum']}'),
                  if (supplier['location'] != null && supplier['location'].toString().isNotEmpty)
                    Text('Location: ${supplier['location']}'),
                  if (supplier['notes'] != null && supplier['notes'].toString().isNotEmpty)
                    Text('Notes: ${supplier['notes']}'),
                  if (supplier['email'] != null && supplier['email'].toString().isNotEmpty)
                    Text('Email: ${supplier['email']}'),
                ],
              ),
                trailing: supplier['email'] != null && supplier['email'].toString().isNotEmpty
                    ? Icon(Icons.email, color: Colors.purple[400])
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}