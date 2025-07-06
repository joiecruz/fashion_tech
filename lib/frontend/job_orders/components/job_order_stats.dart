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
                gradient: LinearGradient(
                  colors: [Colors.orange[50]!, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.orange[200]!, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        color: Colors.orange[600],
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
                    children: [
                      if (!isExpanded) ...[
                        Text(
                          '$totalOrders orders • $openOrders open${overdueOrders > 0 ? ' • $overdueOrders overdue' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
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
          // Animated Stats Content
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: isExpanded ? null : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isExpanded ? 1.0 : 0.0,
              child: isExpanded ? Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: overdueOrders > 0
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // First row with main stats
                        Row(
                          children: [
                            Expanded(child: _buildStatCard(
                              icon: Icons.assignment,
                              iconColor: Colors.orange[600]!,
                              title: 'Total\nOrders',
                              value: totalOrders.toString(),
                              isCompact: true,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: _buildStatCard(
                              icon: Icons.access_time,
                              iconColor: Colors.orange[700]!,
                              title: 'Open\nOrders',
                              value: openOrders.toString(),
                              isCompact: true,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: _buildStatCard(
                              icon: Icons.trending_up,
                              iconColor: Colors.orange[500]!,
                              title: 'In\nProgress',
                              value: inProgressOrders.toString(),
                              isCompact: true,
                            )),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Second row with completion and overdue
                        Row(
                          children: [
                            Expanded(child: _buildStatCard(
                              icon: Icons.check_circle,
                              iconColor: Colors.green[600]!,
                              title: 'Completed\nOrders',
                              value: doneOrders.toString(),
                              isCompact: true,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: _buildStatCard(
                              icon: Icons.warning,
                              iconColor: Colors.red[600]!,
                              title: 'Overdue\nOrders',
                              value: overdueOrders.toString(),
                              isCompact: true,
                              isUrgent: true,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: Container()), // Empty space for balance
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildStatCard(
                          icon: Icons.assignment,
                          iconColor: Colors.orange[600]!,
                          title: 'Total\nOrders',
                          value: totalOrders.toString(),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard(
                          icon: Icons.access_time,
                          iconColor: Colors.orange[700]!,
                          title: 'Open\nOrders',
                          value: openOrders.toString(),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard(
                          icon: Icons.trending_up,
                          iconColor: Colors.orange[500]!,
                          title: 'In\nProgress',
                          value: inProgressOrders.toString(),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard(
                          icon: Icons.check_circle,
                          iconColor: Colors.green[600]!,
                          title: 'Completed\nOrders',
                          value: doneOrders.toString(),
                        )),
                      ],
                    ),
              ) : const SizedBox.shrink(),
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
    bool isCompact = false,
    bool isUrgent = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 8 : 16),
      decoration: BoxDecoration(
        gradient: isUrgent
          ? LinearGradient(
              colors: [Colors.red[50]!, Colors.red[100]!.withOpacity(0.3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : LinearGradient(
              colors: [Colors.orange[50]!, Colors.orange[100]!.withOpacity(0.3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent ? Colors.red[200]! : Colors.orange[200]!,
          width: isUrgent ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isUrgent ? Colors.red : Colors.orange).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: isCompact ? 16 : 24,
          ),
          SizedBox(height: isCompact ? 4 : 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCompact ? 9 : 12,
              color: Colors.grey[600],
              height: 1.1,
            ),
          ),
          SizedBox(height: isCompact ? 2 : 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isCompact ? 14 : 20,
              fontWeight: FontWeight.bold,
              color: isUrgent ? Colors.red[700] : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
