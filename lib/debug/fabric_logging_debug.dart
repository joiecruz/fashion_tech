// Debug helper for fabric logging
// Add this to your app for testing purposes

import 'package:flutter/material.dart';
import '../services/fabric_log_service.dart';
import '../models/fabric_log.dart';

class FabricLoggingDebugWidget extends StatefulWidget {
  final String fabricId;
  
  const FabricLoggingDebugWidget({Key? key, required this.fabricId}) : super(key: key);

  @override
  State<FabricLoggingDebugWidget> createState() => _FabricLoggingDebugWidgetState();
}

class _FabricLoggingDebugWidgetState extends State<FabricLoggingDebugWidget> {
  List<FabricLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await FabricLogService.getFabricLogs(widget.fabricId);
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading logs: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fabric Logs Debug\nFabric ID: ${widget.fabricId}'),
        titleTextStyle: TextStyle(fontSize: 16),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No logs found for this fabric',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getLogIcon(log.changeType),
                                  color: _getLogColor(log.changeType),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '${log.changeType.toString().split('.').last.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _getLogColor(log.changeType),
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  '${log.quantityChanged} units',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            if (log.remarks != null && log.remarks!.isNotEmpty) ...[
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Remarks:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      log.remarks!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[800],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Created by: ${log.createdBy}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '${log.createdAt.day}/${log.createdAt.month}/${log.createdAt.year} ${log.createdAt.hour}:${log.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadLogs,
        child: Icon(Icons.refresh),
        tooltip: 'Refresh logs',
      ),
    );
  }

  IconData _getLogIcon(FabricChangeType changeType) {
    switch (changeType) {
      case FabricChangeType.add:
        return Icons.add_circle;
      case FabricChangeType.deduct:
        return Icons.remove_circle;
      case FabricChangeType.correction:
        return Icons.edit;
    }
  }

  Color _getLogColor(FabricChangeType changeType) {
    switch (changeType) {
      case FabricChangeType.add:
        return Colors.green;
      case FabricChangeType.deduct:
        return Colors.red;
      case FabricChangeType.correction:
        return Colors.orange;
    }
  }
}

// Helper function to show debug widget
void showFabricLogsDebug(BuildContext context, String fabricId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => FabricLoggingDebugWidget(fabricId: fabricId),
    ),
  );
}
