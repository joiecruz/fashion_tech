import 'package:flutter/material.dart';

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
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange[50]!, Colors.grey[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange[200]!.withOpacity(0.3)),
            ),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search job orders by name, customer, or assignee...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Status and Category filter dropdowns with refresh button
          Row(
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
              const Spacer(),
              // Refresh button
              Tooltip(
                message: 'Refresh job orders',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: isRefreshing ? null : onRefresh,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: isRefreshing
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[600]!),
                              ),
                            )
                          : AnimatedRotation(
                              turns: isRefreshing ? 1 : 0,
                              duration: const Duration(milliseconds: 500),
                              child: Icon(
                                Icons.refresh,
                                color: Colors.orange[600],
                                size: 20,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown() {
    final statusOptions = ['All', 'Open', 'In Progress', 'Done', 'Archived'];

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
                color: Colors.blue[600]!.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.category,
                size: 12,
                color: Colors.blue[600],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              selectedCategory,
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
        return categoryOptions.map<PopupMenuEntry<String>>((option) {
          return PopupMenuItem<String>(
            value: option,
            child: Row(
              children: [
                Icon(
                  Icons.category,
                  size: 14,
                  color: Colors.blue[600],
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Open':
        return Colors.orange[600]!;
      case 'In Progress':
        return Colors.orange[500]!;
      case 'Done':
        return Colors.green[600]!;
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
      case 'Archived':
        return Icons.archive;
      default:
        return Icons.filter_list;
    }
  }
}
