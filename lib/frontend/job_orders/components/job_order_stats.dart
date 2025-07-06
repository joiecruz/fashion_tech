import 'package:flutter/material.dart';

class JobOrderStats extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final int totalOrders;
  final int openOrders;
  final int inProgressOrders;
  final int doneOrders;
  final int overdueOrders;

  const JobOrderStats({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.totalOrders,
    required this.openOrders,
    required this.inProgressOrders,
    required this.doneOrders,
    required this.overdueOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Collapse/Expand Button
          InkWell(
            onTap: onToggle,
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
                        'Overview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isExpanded) ...[
                        Container(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(
                            '$totalOrders orders • $openOrders open${overdueOrders > 0 ? ' • $overdueOrders overdue' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
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
          // Animated Stats Content - Using the exact same pattern as inventory page
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            constraints: BoxConstraints(
              maxHeight: isExpanded ? 70 : 0,
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isExpanded ? 1.0 : 0.0,
              child: AnimatedOpacity(
                opacity: 1.0, // This matches the inventory page pattern
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCompactStatCard(
                          icon: Icons.assignment,
                          iconColor: Colors.orange[600]!,
                          title: 'Total Orders',
                          value: totalOrders.toString(),
                        ),
                        const SizedBox(width: 8),
                        _buildCompactStatCard(
                          icon: Icons.access_time,
                          iconColor: Colors.orange[700]!,
                          title: 'Open',
                          value: openOrders.toString(),
                        ),
                        const SizedBox(width: 8),
                        _buildCompactStatCard(
                          icon: Icons.trending_up,
                          iconColor: Colors.blue[600]!,
                          title: 'In Progress',
                          value: inProgressOrders.toString(),
                        ),
                        const SizedBox(width: 8),
                        _buildCompactStatCard(
                          icon: Icons.check_circle,
                          iconColor: Colors.green[600]!,
                          title: 'Completed',
                          value: doneOrders.toString(),
                        ),
                        if (overdueOrders > 0) ...[
                          const SizedBox(width: 8),
                          _buildCompactStatCard(
                            icon: Icons.warning,
                            iconColor: Colors.red[600]!,
                            title: 'Overdue',
                            value: overdueOrders.toString(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    bool isWide = false,
  }) {
    return Container(
      width: isWide ? 130 : 90,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            iconColor.withOpacity(0.12),
            iconColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(3),
            child: Icon(icon, color: iconColor, size: 14),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: iconColor.withOpacity(0.8),
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isWide ? 11 : 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
