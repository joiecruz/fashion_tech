import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_fabric_modal.dart';
import 'dart:convert';
import 'dart:async';

class FabricLogbookPage extends StatefulWidget {
  const FabricLogbookPage({super.key});

  @override
  State<FabricLogbookPage> createState() => _FabricLogbookPageState();
}

class _FabricLogbookPageState extends State<FabricLogbookPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allFabrics = [];
  List<Map<String, dynamic>> _filteredFabrics = [];
  String _selectedType = 'All';
  bool _showUpcycledOnly = false;
  bool _showLowStockOnly = false;
  bool _isStatsExpanded = true;
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _fabricsSubscription;

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

    _initializeFabrics();
    _searchController.addListener(_onSearchChanged);
  }

  void _initializeFabrics() {
    _fabricsSubscription = FirebaseFirestore.instance
        .collection('fabrics')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final fabrics = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        setState(() {
          _allFabrics = fabrics;
          _isLoading = false;
        });

        _applyFilters();
        
        // Start animation on first load
        if (_animationController.status == AnimationStatus.dismissed) {
          _animationController.forward();
        }
      }
    });
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    
    final filtered = _allFabrics.where((fabric) {
      final name = (fabric['name'] ?? '').toString().toLowerCase();
      final type = (fabric['type'] ?? '').toString().toLowerCase();
      final color = (fabric['color'] ?? '').toString().toLowerCase();
      final quantity = fabric['quantity'] ?? 0;
      final isUpcycled = fabric['isUpcycled'] ?? false;

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          type.contains(query) ||
          color.contains(query);

      final matchesType = _selectedType == 'All' || type == _selectedType.toLowerCase();
      final matchesUpcycled = !_showUpcycledOnly || isUpcycled;
      final matchesLowStock = !_showLowStockOnly || quantity < 5;

      return matchesSearch && matchesType && matchesUpcycled && matchesLowStock;
    }).toList();

    if (mounted) {
      setState(() {
        _filteredFabrics = filtered;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _fabricsSubscription?.cancel();
    super.dispose();
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

  int _getLowStockCount(List<Map<String, dynamic>> fabrics) {
    return fabrics.where((fabric) {
      final quantity = fabric['quantity'] ?? 0;
      return quantity < 5;
    }).length;
  }

  double _getTotalExpense(List<Map<String, dynamic>> fabrics) {
    return fabrics.fold(0.0, (total, fabric) {
      final quantity = fabric['quantity'] ?? 0;
      final price = fabric['pricePerUnit'] ?? 0.0;
      return total + (quantity * price);
    });
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    bool isLarge = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
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
            style: TextStyle(
              fontSize: isLarge ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, List<String> options) {
    return PopupMenuButton<String>(
      onSelected: (String newValue) {
        setState(() {
          _selectedType = newValue;
        });
        _applyFilters();
      },
      offset: const Offset(0, 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey[50]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.category_rounded,
                size: 12,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              value == 'All' ? value : value.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) {
        return options.map((String option) {
          String displayOption = option == 'All' ? option : option.toUpperCase();
          return PopupMenuItem<String>(
            value: option,
            child: Row(
              children: [
                Icon(
                  option == 'All' ? Icons.grid_view_rounded : Icons.label_rounded,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  displayOption,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: option == value ? FontWeight.w600 : FontWeight.w400,
                    color: option == value ? Colors.blue[700] : Colors.grey[800],
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  Widget _buildToggleChip(String label, bool isSelected, Function(bool) onToggle) {
    return GestureDetector(
      onTap: () => onToggle(!isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: label == 'Upcycled' 
                      ? [Colors.green[600]!, Colors.green[700]!]
                      : [Colors.red[600]!, Colors.red[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.white, Colors.grey[50]!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? (label == 'Upcycled' ? Colors.green[600]! : Colors.red[600]!)
                : Colors.grey[300]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? (label == 'Upcycled' ? Colors.green[600]! : Colors.red[600]!).withOpacity(0.25)
                  : Colors.black.withOpacity(0.06),
              blurRadius: isSelected ? 6 : 4,
              offset: Offset(0, isSelected ? 2 : 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : (label == 'Upcycled' ? Colors.green[100] : Colors.red[100]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : (label == 'Upcycled' ? Icons.eco_rounded : Icons.warning_amber_rounded),
                size: 12,
                color: isSelected
                    ? Colors.white
                    : (label == 'Upcycled' ? Colors.green[700] : Colors.red[700]),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Fixed Search Bar at top
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Container(
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  // Sticky Filter Chips - Full Width
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('Type', _selectedType, ['All', 'Cotton', 'Silk', 'Wool', 'Linen', 'Polyester', 'Blend']),
                            const SizedBox(width: 12),
                            _buildToggleChip('Upcycled', _showUpcycledOnly, (value) {
                              setState(() {
                                _showUpcycledOnly = value;
                              });
                              _applyFilters();
                            }),
                            const SizedBox(width: 12),
                            _buildToggleChip('Low Stock', _showLowStockOnly, (value) {
                              setState(() {
                                _showLowStockOnly = value;
                              });
                              _applyFilters();
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Scrollable Content
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        // Collapsible Stats Cards
                        SliverToBoxAdapter(
                          child: Container(
                            color: Colors.white,
                            child: Column(
                              children: [
                                // Collapse/Expand Button
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _isStatsExpanded = !_isStatsExpanded;
                                    });
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      border: Border(
                                        bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.analytics_outlined,
                                              color: Colors.grey[600],
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Statistics',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            if (!_isStatsExpanded) ...[
                                              Text(
                                                '${_allFabrics.length} fabrics • ${_getLowStockCount(_allFabrics)} low stock',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            AnimatedRotation(
                                              turns: _isStatsExpanded ? 0.5 : 0.0,
                                              duration: const Duration(milliseconds: 200),
                                              child: Icon(
                                                Icons.keyboard_arrow_down,
                                                color: Colors.grey[600],
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Animated Stats Content
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  constraints: BoxConstraints(
                                    maxHeight: _isStatsExpanded ? 200 : 0,
                                  ),
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 200),
                                    opacity: _isStatsExpanded ? 1.0 : 0.0,
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                                      child: Row(
                                        children: [
                                          Expanded(child: _buildStatCard(
                                            icon: Icons.palette_outlined,
                                            iconColor: Colors.blue[600]!,
                                            title: 'Total\nFabrics',
                                            value: _allFabrics.length.toString(),
                                          )),
                                          const SizedBox(width: 16),
                                          Expanded(child: _buildStatCard(
                                            icon: Icons.warning_outlined,
                                            iconColor: Colors.red[600]!,
                                            title: 'Low Stock\n(<5)',
                                            value: _getLowStockCount(_allFabrics).toString(),
                                          )),
                                          const SizedBox(width: 16),
                                          Expanded(child: _buildStatCard(
                                            icon: Icons.attach_money,
                                            iconColor: Colors.green[600]!,
                                            title: 'Total\nExpense',
                                            value: '₱${_getTotalExpense(_allFabrics).toStringAsFixed(2)}',
                                            isLarge: true,
                                          )),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Add New Item Button
                        SliverToBoxAdapter(
                          child: Container(
                            color: Colors.white,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.green[600]!, Colors.green[700]!],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green[600]!.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () async {
                                          await showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (context) => Container(
                                              margin: const EdgeInsets.only(top: 100),
                                              height: MediaQuery.of(context).size.height - 100,
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                              ),
                                              child: AddFabricModal(),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_circle_outline,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Add New Fabric',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Fabric List
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                          sliver: _buildFabricsList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFabricsList() {
    if (_allFabrics.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.palette_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No fabrics added yet',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your first fabric to get started',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredFabrics.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No fabrics found',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search criteria',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final fabric = _filteredFabrics[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildFabricCard(fabric, index),
          );
        },
        childCount: _filteredFabrics.length,
      ),
    );
  }

  Widget _buildFabricCard(Map<String, dynamic> fabric, int index) {
    final swatchUrl = fabric['swatchImageURL'] ?? '';
    final name = fabric['name'] ?? 'Unnamed Fabric';
    final type = fabric['type'] ?? '';
    final color = fabric['color'] ?? '';
    final quality = fabric['qualityGrade'] ?? '';
    final quantity = fabric['quantity'] ?? 0;
    final pricePerUnit = fabric['pricePerUnit'] ?? 0.0;
    final isUpcycled = fabric['isUpcycled'] ?? false;
    final createdAt = fabric['createdAt'] != null
        ? (fabric['createdAt'] as Timestamp).toDate()
        : null;
    final reasons = fabric['reasons'] ?? '';
    
    // Calculate total value and status
    final totalValue = quantity * pricePerUnit;
    final isLowStock = quantity < 5;
    final isOutOfStock = quantity == 0;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: isOutOfStock 
                    ? Border.all(color: Colors.red[300]!, width: 2)
                    : isLowStock 
                        ? Border.all(color: Colors.orange[300]!, width: 1.5)
                        : null,
                boxShadow: [
                  BoxShadow(
                    color: isOutOfStock 
                        ? Colors.red.withOpacity(0.1)
                        : isLowStock 
                            ? Colors.orange.withOpacity(0.08)
                            : Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Main content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with fabric name and status badges
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
                                      color: Colors.black87,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  if (type.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getFabricTypeColor(type).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _getFabricTypeColor(type).withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          type.toUpperCase(),
                                          style: TextStyle(
                                            color: _getFabricTypeColor(type),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.more_vert, color: Colors.grey[600], size: 18),
                              ),
                              onSelected: (value) {
                                // Handle edit/delete actions
                              },
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 12),
                                      Text('Edit Fabric'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      SizedBox(width: 12),
                                      Text('Delete', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Main visual and info section
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Enhanced swatch with shadow and styling
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey[50],
                                      child: swatchUrl.isNotEmpty
                                          ? Image(
                                              image: _getSwatchImageProvider(swatchUrl),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  _buildFallbackSwatch(color),
                                            )
                                          : _buildFallbackSwatch(color),
                                    ),
                                    // Overlay for out of stock
                                    if (isOutOfStock)
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.inventory_2, color: Colors.white, size: 24),
                                              const SizedBox(height: 4),
                                              Text(
                                                'OUT OF\nSTOCK',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            // Enhanced details section
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Color and quality row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDetailChip(
                                          icon: Icons.palette_outlined,
                                          label: color.isNotEmpty ? color : 'No color',
                                          backgroundColor: Colors.purple[50]!,
                                          textColor: Colors.purple[700]!,
                                          iconColor: Colors.purple[600]!,
                                        ),
                                      ),
                                      if (quality.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        _buildQualityBadge(quality),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Stock status with visual indicator
                                  _buildStockIndicator(quantity, isLowStock, isOutOfStock),
                                  const SizedBox(height: 12),
                                  // Pricing information
                                  if (pricePerUnit > 0)
                                    _buildPricingInfo(pricePerUnit, totalValue),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Status badges row
                        Row(
                          children: [
                            if (isUpcycled)
                              _buildStatusBadge(
                                icon: Icons.eco_outlined,
                                label: 'Eco-Friendly',
                                backgroundColor: Colors.green[50]!,
                                borderColor: Colors.green[300]!,
                                textColor: Colors.green[700]!,
                                iconColor: Colors.green[600]!,
                              ),
                            if (isUpcycled && isLowStock) const SizedBox(width: 8),
                            if (isLowStock && !isOutOfStock)
                              _buildStatusBadge(
                                icon: Icons.warning_amber_outlined,
                                label: 'Low Stock Alert',
                                backgroundColor: Colors.orange[50]!,
                                borderColor: Colors.orange[300]!,
                                textColor: Colors.orange[700]!,
                                iconColor: Colors.orange[600]!,
                              ),
                            if (isOutOfStock)
                              _buildStatusBadge(
                                icon: Icons.block_outlined,
                                label: 'Out of Stock',
                                backgroundColor: Colors.red[50]!,
                                borderColor: Colors.red[300]!,
                                textColor: Colors.red[700]!,
                                iconColor: Colors.red[600]!,
                              ),
                          ],
                        ),
                        // Footer with date and additional info
                        const SizedBox(height: 16),
                        const Divider(thickness: 1, color: Color(0xFFE5E7EB)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.access_time_outlined, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 6),
                            Text(
                              createdAt != null ? 'Added ${_formatDateRelative(createdAt)}' : 'No date',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (pricePerUnit > 0)
                              Text(
                                'Unit: ₱${pricePerUnit.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        // Notes section if available
                        if (reasons != null && reasons.toString().isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[50]!, Colors.blue[100]!.withOpacity(0.3)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.note_outlined, color: Colors.blue[700], size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Production Notes',
                                        style: TextStyle(
                                          color: Colors.blue[800],
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        reasons.toString(),
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper methods for fabric card UI
  Color _getFabricTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'cotton':
        return Colors.green[600]!;
      case 'silk':
        return Colors.purple[600]!;
      case 'wool':
        return Colors.brown[600]!;
      case 'polyester':
        return Colors.blue[600]!;
      case 'linen':
        return Colors.amber[600]!;
      case 'denim':
        return Colors.indigo[600]!;
      case 'leather':
        return Colors.orange[700]!;
      case 'lace':
        return Colors.pink[600]!;
      case 'velvet':
        return Colors.deepPurple[600]!;
      case 'chiffon':
        return Colors.teal[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildFallbackSwatch(String? color) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[200]!,
            Colors.grey[100]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.texture_outlined,
            size: 32,
            color: Colors.grey[500],
          ),
          const SizedBox(height: 8),
          if (color != null && color.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                color,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityBadge(String quality) {
    Color backgroundColor;
    Color textColor;
    Color borderColor;
    
    switch (quality.toLowerCase()) {
      case 'premium':
      case 'high':
        backgroundColor = Colors.amber[50]!;
        textColor = Colors.amber[800]!;
        borderColor = Colors.amber[300]!;
        break;
      case 'good':
      case 'medium':
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue[700]!;
        borderColor = Colors.blue[300]!;
        break;
      case 'standard':
      case 'low':
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        borderColor = Colors.grey[300]!;
        break;
      default:
        backgroundColor = Colors.grey[50]!;
        textColor = Colors.grey[600]!;
        borderColor = Colors.grey[200]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars_outlined, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            quality.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockIndicator(int quantity, bool isLowStock, bool isOutOfStock) {
    Color backgroundColor;
    Color textColor;
    Color iconColor;
    IconData icon;
    String label;

    if (isOutOfStock) {
      backgroundColor = Colors.red[50]!;
      textColor = Colors.red[700]!;
      iconColor = Colors.red[600]!;
      icon = Icons.block_outlined;
      label = '0 units - Out of Stock';
    } else if (isLowStock) {
      backgroundColor = Colors.orange[50]!;
      textColor = Colors.orange[700]!;
      iconColor = Colors.orange[600]!;
      icon = Icons.warning_amber_outlined;
      label = '$quantity units - Low Stock';
    } else {
      backgroundColor = Colors.green[50]!;
      textColor = Colors.green[700]!;
      iconColor = Colors.green[600]!;
      icon = Icons.check_circle_outlined;
      label = '$quantity units - In Stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingInfo(double pricePerUnit, double totalValue) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.green[100]!.withOpacity(0.3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money_outlined, size: 16, color: Colors.green[700]),
              const SizedBox(width: 6),
              Text(
                'Pricing',
                style: TextStyle(
                  color: Colors.green[800],
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Per Unit',
                    style: TextStyle(
                      color: Colors.green[600],
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '₱${pricePerUnit.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.green[800],
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.green[300],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total Value',
                    style: TextStyle(
                      color: Colors.green[600],
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '₱${totalValue.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.green[800],
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateRelative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'just now';
        } else {
          return '${difference.inMinutes}m ago';
        }
      } else {
        return '${difference.inHours}h ago';
      }
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
  }
}
