import 'package:flutter/material.dart';
import '../../common/gradient_search_bar.dart';

class JobOrderFilters extends StatelessWidget {
  final String selectedStatus;
  final String selectedCategory;
  final String searchQuery;
  final TextEditingController searchController;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final List<Map<String, dynamic>> categories;

  const JobOrderFilters({
    super.key,
    required this.selectedStatus,
    required this.selectedCategory,
    required this.searchQuery,
    required this.searchController,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onRefresh,
    required this.isRefreshing,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          GradientSearchBar(
            controller: searchController,
            hintText: 'Search job orders by name, customer, or assignee...',
            primaryColor: Colors.orange,
            onChanged: (value) {
              // The parent widget will handle the search through the controller
            },
            onClear: () {
              searchController.clear();
            },
          ),
          const SizedBox(height: 16),

          // Status and Category filter dropdowns with refresh button
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Filters:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 12),
                _buildStatusDropdown(),
                const SizedBox(width: 12),
                _buildCategoryDropdown(),
                const SizedBox(width: 12),
                // Refresh button
                GradientFilterChip(
                  label: 'Refresh',
                  isSelected: false,
                  onTap: isRefreshing ? () {} : onRefresh,
                  primaryColor: Colors.orange,
                  icon: isRefreshing ? null : Icons.refresh,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown() {
    final statusOptions = ['All', 'Open', 'In Progress', 'Done', 'Cancelled', 'Archived'];

    return PopupMenuButton<String>(
      onSelected: onStatusChanged,
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
                color: _getStatusColor(selectedStatus).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.filter_list,
                size: 12,
                color: _getStatusColor(selectedStatus),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              selectedStatus,
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
        return statusOptions.map((String option) {
          return PopupMenuItem<String>(
            value: option,
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(option),
                  size: 14,
                  color: _getStatusColor(option),
                ),
                const SizedBox(width: 8),
                Text(
                  option,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  Widget _buildCategoryDropdown() {
    final categoryOptions = ['All Categories', ...categories.map((cat) => cat['displayName'] ?? cat['name'])];

    return PopupMenuButton<String>(
      onSelected: onCategoryChanged,
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
                color: Colors.orange[600]!.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                selectedCategory == 'All Categories' ? Icons.category : _getCategoryIcon(selectedCategory),
                size: 12,
                color: Colors.orange[600],
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                selectedCategory,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
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
        return categoryOptions.map<PopupMenuEntry<String>>((option) {
          return PopupMenuItem<String>(
            value: option,
            child: Row(
              children: [
                Icon(
                  option == 'All Categories' ? Icons.category : _getCategoryIcon(option),
                  size: 14,
                  color: Colors.orange[600],
                ),
                const SizedBox(width: 8),
                Text(
                  option,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'all categories':
        return Icons.category;
      case 'top':
      case 'tops':
        return Icons.checkroom;
      case 'bottom':
      case 'bottoms':
        return Icons.straighten;
      case 'outerwear':
        return Icons.ac_unit;
      case 'dress':
      case 'dresses':
        return Icons.woman;
      case 'activewear':
      case 'sportswear':
        return Icons.sports;
      case 'underwear':
      case 'underwear & intimates':
      case 'intimates':
        return Icons.favorite;
      case 'sleepwear':
      case 'pajamas':
        return Icons.bedtime;
      case 'swimwear':
        return Icons.pool;
      case 'footwear':
      case 'shoes':
        return Icons.directions_walk;
      case 'accessories':
        return Icons.watch;
      case 'bags':
      case 'handbags':
        return Icons.shopping_bag;
      case 'jewelry':
        return Icons.diamond;
      case 'hats':
      case 'caps':
        return Icons.mood;
      case 'belts':
        return Icons.link;
      case 'formal':
      case 'formal wear':
        return Icons.star;
      case 'casual':
        return Icons.weekend;
      case 'business':
        return Icons.business_center;
      case 'vintage':
        return Icons.auto_awesome;
      case 'plus size':
        return Icons.accessibility_new;
      case 'maternity':
        return Icons.pregnant_woman;
      case 'kids':
      case 'children':
        return Icons.child_care;
      case 'baby':
        return Icons.baby_changing_station;
      case 'uncategorized':
      default:
        return Icons.category_outlined;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Open':
        return Colors.orange[600]!;
      case 'In Progress':
        return Colors.orange[500]!;
      case 'Done':
        return Colors.green[600]!;
      case 'Cancelled':
        return Colors.red[600]!;
      case 'Archived':
        return Colors.grey[600]!;
      default:
        return Colors.orange[400]!;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Open':
        return Icons.access_time;
      case 'In Progress':
        return Icons.trending_up;
      case 'Done':
        return Icons.check_circle;
      case 'Cancelled':
        return Icons.cancel;
      case 'Archived':
        return Icons.archive;
      default:
        return Icons.filter_list;
    }
  }
}
