import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_fabric_modal.dart';
import 'dart:convert';

class FabricLogbookPage extends StatefulWidget {
  const FabricLogbookPage({super.key});

  @override
  State<FabricLogbookPage> createState() => _FabricLogbookPageState();
}

class _FabricLogbookPageState extends State<FabricLogbookPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'All';
  bool _showUpcycledOnly = false;
  bool _showLowStockOnly = false;

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

    // Start animation after a brief delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _filterFabrics(List<QueryDocumentSnapshot> fabrics) {
    String query = _searchController.text.toLowerCase();
    
    return fabrics.where((fabric) {
      final data = fabric.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final type = (data['type'] ?? '').toString().toLowerCase();
      final color = (data['color'] ?? '').toString().toLowerCase();
      final quantity = data['quantity'] ?? 0;
      final isUpcycled = data['isUpcycled'] ?? false;

      bool matchesSearch = query.isEmpty ||
          name.contains(query) ||
          type.contains(query) ||
          color.contains(query);

      bool matchesType = _selectedType == 'All' || type == _selectedType.toLowerCase();
      bool matchesUpcycled = !_showUpcycledOnly || isUpcycled;
      bool matchesLowStock = !_showLowStockOnly || quantity < 5;

      return matchesSearch && matchesType && matchesUpcycled && matchesLowStock;
    }).toList();
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
        onChanged: (value) => setState(() {}), // Trigger rebuild for filtering
        decoration: InputDecoration(
          hintText: 'Search fabrics by name, type, or color...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[500]),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final Set<String> fabricTypes = {'All', 'Cotton', 'Silk', 'Wool', 'Linen', 'Polyester', 'Blend'};
    
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Type filter
                Wrap(
                  spacing: 8,
                  children: fabricTypes.map((type) {
                    final isSelected = _selectedType == type;
                    return FilterChip(
                      label: Text(type),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedType = type;
                        });
                      },
                      backgroundColor: Colors.grey[200],
                      selectedColor: Colors.blue[100],
                      checkmarkColor: Colors.blue[700],
                    );
                  }).toList(),
                ),
                const SizedBox(width: 8),
                // Toggle chips
                FilterChip(
                  label: const Text('Upcycled Only'),
                  selected: _showUpcycledOnly,
                  onSelected: (selected) {
                    setState(() {
                      _showUpcycledOnly = selected;
                    });
                  },
                  backgroundColor: Colors.grey[200],
                  selectedColor: Colors.green[100],
                  checkmarkColor: Colors.green[700],
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Low Stock'),
                  selected: _showLowStockOnly,
                  onSelected: (selected) {
                    setState(() {
                      _showLowStockOnly = selected;
                    });
                  },
                  backgroundColor: Colors.grey[200],
                  selectedColor: Colors.red[100],
                  checkmarkColor: Colors.red[700],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
              value: '₱${totalExpense.toStringAsFixed(2)}',
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

          final allFabrics = snapshot.data!.docs;
          final filteredFabrics = _filterFabrics(allFabrics);

          return FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildSearchBar(),
                _buildFilterChips(),
                _buildStatsSection(allFabrics),
                Expanded(
                  child: _buildFabricsList(filteredFabrics, allFabrics),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 100),
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
                margin: const EdgeInsets.only(top: 100),
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

  Widget _buildFabricsList(List<QueryDocumentSnapshot> filteredFabrics, List<QueryDocumentSnapshot> allFabrics) {
    if (allFabrics.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.palette_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No fabrics added yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'Add your first fabric to get started',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (filteredFabrics.isEmpty) {
      return const Center(
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
      );
    }

    return ListView.builder(
      itemCount: filteredFabrics.length,
      itemBuilder: (context, index) {
        final fabric = filteredFabrics[index].data() as Map<String, dynamic>;
        return _buildFabricCard(fabric);
      },
    );
  }

  Widget _buildFabricCard(Map<String, dynamic> fabric) {
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                          fontSize: 18,
                        ),
                      ),
                      if (type.isNotEmpty)
                        Text(
                          type,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    // Handle edit/delete actions
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Swatch and Details Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Swatch Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: swatchUrl.isNotEmpty
                        ? Image(
                            image: _getSwatchImageProvider(swatchUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.image_not_supported, color: Colors.grey[400]),
                          )
                        : Icon(Icons.palette, color: Colors.grey[400]),
                  ),
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Color and Upcycled
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.color_lens, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  color.isNotEmpty ? color : 'No color',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          if (fabric['isUpcycled'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.recycling, color: Colors.green[700], size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Upcycled',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Quality
                      if (quality.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.grade, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                quality,
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      // Quantity
                      Row(
                        children: [
                          Icon(
                            Icons.inventory,
                            size: 16,
                            color: quantity < 5 ? Colors.red[600] : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$quantity units',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: quantity < 5 ? Colors.red[700] : Colors.black87,
                            ),
                          ),
                          if (quantity < 5) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Low Stock',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            // Date and Reasons
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  createdAt != null ? _formatDate(createdAt) : 'No date',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (reasons != null && reasons.toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[600], size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      reasons.toString(),
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
