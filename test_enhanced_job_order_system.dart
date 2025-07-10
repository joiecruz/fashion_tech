import 'package:flutter/material.dart';
import 'lib/frontend/job_orders/job_order_list_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enhanced Job Order System',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: TestPage(),
    );
  }
}

class TestPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enhanced Job Order System'),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey[50],
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              '✨ Job Order System Enhancements',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            
            // Features list
            Text(
              'New Features Implemented:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            
            // Feature cards
            _buildFeatureCard(
              icon: Icons.assignment_turned_in,
              title: 'Dynamic Status Workflow',
              description: 'Smart status transitions:\n• Open → "Start Work" → In Progress\n• In Progress → "Mark as Done" → Done\n• Done → "Archive" → Archived',
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            
            _buildFeatureCard(
              icon: Icons.filter_list_alt,
              title: 'Enhanced Filters',
              description: 'New filtering options:\n• Status: All, Open, In Progress, Done, Archived\n• Category: Filter by product categories\n• Search: Multiple fields supported',
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            
            _buildFeatureCard(
              icon: Icons.note_alt,
              title: 'Notes & Category Display',
              description: 'Enhanced job order cards:\n• Notes display with icon\n• Category badges with icons\n• Improved visual hierarchy',
              color: Colors.purple,
            ),
            const SizedBox(height: 12),
            
            _buildFeatureCard(
              icon: Icons.archive,
              title: 'Archive System',
              description: 'Complete lifecycle management:\n• Archive completed orders\n• View archived orders in filters\n• Clean interface separation',
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            
            // Launch button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => JobOrderListPage()),
                  );
                },
                icon: Icon(Icons.launch, size: 20),
                label: Text('Open Enhanced Job Order System'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: color[100]!.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color[200]!, width: 1),
            ),
            child: Icon(icon, color: color[600], size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
