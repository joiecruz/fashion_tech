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
    final minOrder = fabric['minOrder'] ?? 0;
    final isUpcycled = fabric['isUpcycled'] ?? false;
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
          offset: Offset(0, 10 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: isOutOfStock 
                    ? Border.all(color: Colors.red[400]!, width: 2)
                    : isLowStock 
                        ? Border.all(color: Colors.orange[400]!, width: 1.5)
                        : Border.all(color: Colors.grey[200]!, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: isOutOfStock 
                        ? Colors.red.withOpacity(0.12)
                        : isLowStock 
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Enhanced fabric swatch
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: swatchUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image(
                                  image: _getSwatchImageProvider(swatchUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildEnhancedFallbackSwatch(color),
                                ),
                              )
                            : _buildEnhancedFallbackSwatch(color),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (type.isNotEmpty)
                                        Text(
                                          type.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: _getFabricTypeColor(type),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Status labels section in upper right corner
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isUpcycled)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green[100],
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Eco',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green[700],
                                              ),
                                            ),
                                          ),
                                        if (quality.isNotEmpty)
                                          Container(
                                            margin: EdgeInsets.only(left: isUpcycled ? 4 : 0),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getQualityColor(quality),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              quality,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: _getQualityTextColor(quality),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (isLowStock || isOutOfStock) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isOutOfStock ? Colors.red[50] : Colors.orange[50],
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isOutOfStock ? Colors.red[200]! : Colors.orange[200]!,
                                          ),
                                        ),
                                        child: Text(
                                          isOutOfStock ? 'Out of Stock' : 'Low Stock',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isOutOfStock ? Colors.red[700] : Colors.orange[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            // Show color, quality and notes if available
                            if (color.isNotEmpty || quality.isNotEmpty || (reasons != null && reasons.toString().trim().isNotEmpty)) ...[
                              const SizedBox(height: 6),
                              // Color and Quality as a cohesive visual unit
                              if (color.isNotEmpty || quality.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (color.isNotEmpty) ...[
                                        Icon(
                                          Icons.palette,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          color,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                      if (color.isNotEmpty && quality.isNotEmpty) ...[
                                        Container(
                                          width: 1,
                                          height: 14,
                                          margin: const EdgeInsets.symmetric(horizontal: 8),
                                          color: Colors.grey[300],
                                        ),
                                      ],
                                      if (quality.isNotEmpty) ...[
                                        Icon(
                                          Icons.star,
                                          size: 14,
                                          color: _getQualityTextColor(quality),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          quality,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _getQualityTextColor(quality),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              if (reasons != null && reasons.toString().trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  reasons.toString().length > 60 
                                      ? '${reasons.toString().substring(0, 60)}...'
                                      : reasons.toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (pricePerUnit > 0)
                            Text(
                              '₱${pricePerUnit.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          const SizedBox(height: 2),
                          // Stock and minOrder as a cohesive visual unit
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isOutOfStock 
                                  ? Colors.red[50]
                                  : isLowStock 
                                      ? Colors.orange[50]
                                      : Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isOutOfStock 
                                    ? Colors.red[200]!
                                    : isLowStock 
                                        ? Colors.orange[200]!
                                        : Colors.blue[200]!,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2,
                                  size: 14,
                                  color: isOutOfStock 
                                      ? Colors.red[600]
                                      : isLowStock 
                                          ? Colors.orange[600]
                                          : Colors.blue[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$quantity units',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isOutOfStock 
                                        ? Colors.red[600]
                                        : isLowStock 
                                            ? Colors.orange[600]
                                            : Colors.blue[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (minOrder > 0) ...[
                                  Container(
                                    width: 1,
                                    height: 12,
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    color: Colors.grey[300],
                                  ),
                                  Icon(
                                    Icons.shopping_cart,
                                    size: 12,
                                    color: Colors.blue[600],
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Min $minOrder',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (totalValue > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green[50]!, Colors.green[100]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Text(
                            'Value: ₱${totalValue.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.more_vert, color: Colors.grey[600], size: 16),
                        ),
                        onSelected: (value) {
                          // Handle edit/delete actions
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 16),
                                SizedBox(width: 8),
                                Text('Edit Fabric'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedFallbackSwatch(String? color) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[200]!,
            Colors.grey[100]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.texture_outlined,
            size: 24,
            color: Colors.grey[500],
          ),
          if (color != null && color.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                color.length > 10 ? '${color.substring(0, 10)}...' : color,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getQualityColor(String quality) {
    switch (quality.toLowerCase()) {
      case 'premium':
      case 'high':
        return Colors.amber[100]!;
      case 'good':
      case 'medium':
        return Colors.blue[100]!;
      case 'standard':
      case 'low':
        return Colors.grey[200]!;
      default:
        return Colors.grey[100]!;
    }
  }

  Color _getQualityTextColor(String quality) {
    switch (quality.toLowerCase()) {
      case 'premium':
      case 'high':
        return Colors.amber[700]!;
      case 'good':
      case 'medium':
        return Colors.blue[700]!;
      case 'standard':
      case 'low':
        return Colors.grey[700]!;
      default:
        return Colors.grey[600]!;
    }
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
}
