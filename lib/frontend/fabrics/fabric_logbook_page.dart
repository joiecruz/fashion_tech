import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_fabric_modal.dart'; // Import the AddFabricModal widget
import 'dart:convert';

class FabricLogbookPage extends StatefulWidget {
  const FabricLogbookPage({super.key});

  @override
  State<FabricLogbookPage> createState() => _FabricLogbookPageState();
}

class _FabricLogbookPageState extends State<FabricLogbookPage> {
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _allFabrics = [];
  List<QueryDocumentSnapshot> _filteredFabrics = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filteredFabrics = _filterFabrics(_allFabrics);
    });
  }

  bool _isBase64Image(String str) {
    return str.startsWith('data:image/') || (str.isNotEmpty && !str.startsWith('http'));
  }

  ImageProvider _getSwatchImageProvider(String swatchUrl) {
    if (_isBase64Image(swatchUrl)) {
      final base64Str = swatchUrl.startsWith('data:image/')
          ? swatchUrl.split(',').last
          : swatchUrl;
      return MemoryImage(base64Decode(base64Str));
    } else {
      return NetworkImage(swatchUrl);
    }
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search fabrics by name, type, or color...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[500]),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterFabrics(List<QueryDocumentSnapshot> fabrics) {
    if (_searchQuery.isEmpty) {
      return fabrics;
    }
    
    return fabrics.where((fabric) {
      final data = fabric.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final type = (data['type'] ?? '').toString().toLowerCase();
      final color = (data['color'] ?? '').toString().toLowerCase();
      
      return name.contains(_searchQuery) ||
             type.contains(_searchQuery) ||
             color.contains(_searchQuery);
    }).toList();
  }

  Widget _buildStatsSection(List<QueryDocumentSnapshot> fabrics) {
    int totalFabrics = fabrics.length;
    int lowStockCount = 0;
    double totalExpense = 0.0;

    for (var fabric in fabrics) {
      final data = fabric.data() as Map<String, dynamic>;
      final quantity = data['quantity'] ?? 0;
      final price = data['pricePerUnit'] ?? 0.0;
      
      // Count low stock (less than 5 units)
      if (quantity < 5) {
        lowStockCount++;
      }
      
      // Calculate total expense
      totalExpense += (quantity * price);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.grid_view_rounded,
              iconColor: Colors.blue,
              title: 'Total\nFabrics',
              value: totalFabrics.toString(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.warning_rounded,
              iconColor: Colors.red,
              title: 'Low Stock\n(<5)',
              value: lowStockCount.toString(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.attach_money_rounded,
              iconColor: Colors.green,
              title: 'Total Fabric\nExpense',
              value: '\$${totalExpense.toStringAsFixed(2)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('fabrics')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading fabrics'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final fabrics = snapshot.data!.docs;
          
          // Update fabrics data if it changed
          if (_allFabrics != fabrics) {
            _allFabrics = fabrics;
            _filteredFabrics = _filterFabrics(fabrics);
          }

          final displayFabrics = _searchQuery.isEmpty ? fabrics : _filteredFabrics;

          if (fabrics.isEmpty) {
            return Column(
              children: [
                _buildSearchBar(),
                _buildStatsSection([]),
                const Expanded(
                  child: Center(child: Text('No fabrics added yet.')),
                ),
              ],
            );
          }

          if (displayFabrics.isEmpty && _searchQuery.isNotEmpty) {
            return Column(
              children: [
                _buildSearchBar(),
                _buildStatsSection(fabrics),
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No fabrics found',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try adjusting your search criteria',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildSearchBar(),
              _buildStatsSection(fabrics),
              Expanded(
                child: ListView.builder(
                  itemCount: displayFabrics.length,
                  itemBuilder: (context, index) {
                    final fabric = displayFabrics[index].data() as Map<String, dynamic>;
                    final swatchUrl = fabric['swatchImageURL'] ?? '';
                    final name = fabric['name'] ?? 'Unnamed Fabric';
                    final type = fabric['type'] ?? '';
                    final color = fabric['color'] ?? '';
                    final quality = fabric['qualityGrade'] ?? '';
                    final quantity = fabric['quantity'] ?? 0;
                    final createdAt = fabric['createdAt'] != null
                        ? (fabric['createdAt'] as Timestamp).toDate()
                        : null;
                    final reasons = fabric['reasons'] ?? '';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                      Text(
                                        type,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton(
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(child: Text('Edit')),
                                    const PopupMenuItem(child: Text('Delete')),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Swatch and Details Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: swatchUrl.isNotEmpty
                                      ? Image(
                                          image: _getSwatchImageProvider(swatchUrl),
                                          width: 80,
                                          height: 80,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Icon(Icons.image_not_supported),
                                        )
                                      : const Icon(Icons.image_not_supported),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text('Color: ',
                                              style: TextStyle(
                                                  color: Colors.black54,
                                                  fontWeight: FontWeight.w500)),
                                          Text(
                                            color,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          if (fabric['isUpcycled'] == true)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 8),
                                              child: Icon(Icons.recycling, color: Colors.green, size: 18),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Text('Quality: ',
                                              style: TextStyle(
                                                  color: Colors.black54,
                                                  fontWeight: FontWeight.w500)),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.lightBlueAccent,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              quality.isNotEmpty ? quality : 'N/A',
                                              style: const TextStyle(
                                                  color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Text('Qty: ',
                                              style: TextStyle(
                                                  color: Colors.black54,
                                                  fontWeight: FontWeight.w500)),
                                          Text(
                                            '$quantity units',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Divider(),
                            // Date and Reasons
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: 'Created date',
                                  child: Text(
                                    createdAt != null
                                        ? "${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}"
                                        : 'No date',
                                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                                  ),
                                ),
                                if (fabric['updatedAt'] != null &&
                                    (fabric['createdAt'] == null ||
                                     (fabric['updatedAt'] as Timestamp).toDate() != createdAt))
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Text(
                                      'Last Updated: ${_formatDate(fabric['updatedAt'] as Timestamp)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (reasons != null && reasons.toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: const [
                                  Icon(Icons.info, color: Colors.red, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Reasons: ',
                                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 24),
                                child: Text(
                                  reasons.toString(),
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 100), // Position above the sub navigation bar
        child: FloatingActionButton.extended(
          onPressed: () async {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              backgroundColor: Colors.transparent,
              builder: (context) => Container(
                margin: const EdgeInsets.only(top: 100), // Add space from the top (below notch/appbar)
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: AddFabricModal(),
              ),
            );
          },
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 8,
          label: const Text(
            'Add Fabric',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          icon: const Icon(Icons.palette_rounded, size: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
