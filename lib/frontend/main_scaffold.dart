import 'package:flutter/material.dart';
import 'home_dashboard.dart';
import 'inventory_page.dart';
import 'job_page.dart';
import '../backend/login_be.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({Key? key}) : super(key: key);

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  String _inventorySubtab = 'Products';
  String _jobSubtab = 'Orders';

  final List<String> _titles = [
    'Home',
    'Inventory',
    'Job',
  ];

  void _onInventoryTabChanged(String subtab) {
    setState(() {
      _inventorySubtab = subtab;
    });
  }

  void _onJobTabChanged(String subtab) {
    setState(() {
      _jobSubtab = subtab;
    });
  }

  String get _currentTitle {
    if (_selectedIndex == 1) {
      return 'Inventory | $_inventorySubtab';
    } else if (_selectedIndex == 2) {
      return 'Job | $_jobSubtab';
    }
    return _titles[_selectedIndex];
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const HomeDashboard(),
      InventoryPage(onTabChanged: _onInventoryTabChanged),
      JobPage(onTabChanged: _onJobTabChanged),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await LoginBackend.signOut();
                // AuthWrapper will handle redirect to login
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
                child: Text('FL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        backgroundColor: Colors.white,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.black54,
        selectedIconTheme: const IconThemeData(color: Colors.teal),
        unselectedIconTheme: const IconThemeData(color: Colors.black54),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Job'),
        ],
      ),
    );
  }
}