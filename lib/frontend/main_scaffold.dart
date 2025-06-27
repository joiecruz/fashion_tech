import 'package:flutter/material.dart';
import 'home_dashboard.dart';
import 'fabrics/fabric_logbook_page.dart';
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

  final List<Widget> _pages = [
    HomeDashboard(),
    FabricLogbookPage(),
    JobOrderListPage(),
  ];

  final List<String> _titles = [
    'Home',
    'Inventory',
    'Orders',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.bold)),
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
        children: _pages,
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