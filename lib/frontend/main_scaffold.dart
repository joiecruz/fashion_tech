import 'package:flutter/material.dart';
import 'home_dashboard.dart';
import 'inventory_page.dart';
import 'job_orders/job_order_list_page.dart';
import 'auth/login_be.dart';

// main_scaffold.dart
class MainScaffold extends StatefulWidget {
  const MainScaffold({Key? key}) : super(key: key);

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  String _inventorySubtab = 'Products'; // Track the current inventory subtab

  final List<String> _titles = [
    'Home',
    'Inventory',
    'Orders',
  ];

  // Method to handle inventory tab changes
  void _onInventoryTabChanged(String subtab) {
    setState(() {
      _inventorySubtab = subtab;
    });
  }

  // Get the appropriate title based on current selection
  String get _currentTitle {
    if (_selectedIndex == 1) {
      return 'Inventory | $_inventorySubtab';
    }
    return _titles[_selectedIndex];
  }

  @override
  Widget build(BuildContext context) {
    // Update the inventory page with the callback
    final List<Widget> pages = [
      const HomeDashboard(),
      InventoryPage(onTabChanged: _onInventoryTabChanged),
      const JobOrderListPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await LoginBackend.signOut();
                // Navigation will be handled automatically by AuthWrapper
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                backgroundColor: Colors.teal,
                child: Text('FL', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Orders'),
        ],
      ),
    );
  }
}