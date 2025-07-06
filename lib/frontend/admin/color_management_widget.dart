import 'package:flutter/material.dart';
import '../../services/color_service.dart';

/// Simple widget to initialize default colors in the database
class ColorInitializationWidget extends StatefulWidget {
  const ColorInitializationWidget({super.key});

  @override
  State<ColorInitializationWidget> createState() => _ColorInitializationWidgetState();
}

class _ColorInitializationWidgetState extends State<ColorInitializationWidget> {
  bool _isInitializing = false;
  bool _isInitialized = false;
  int _colorCount = 0;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final isInitialized = await ColorService.areDefaultColorsInitialized();
    if (isInitialized) {
      final colors = await ColorService.getAllColors();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _colorCount = colors.length;
        });
      }
    }
  }

  Future<void> _initializeColors() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      await ColorService.initializeDefaultColors();
      await _checkStatus(); // Refresh status
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default colors initialized successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize colors: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Default Colors Setup',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _isInitialized 
                ? 'Default colors are initialized ($_colorCount colors available)'
                : 'Default colors need to be initialized for fabric and product color selection',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            if (_isInitialized)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[600]),
                    const SizedBox(width: 8),
                    const Text('✓ Default colors ready for use'),
                  ],
                ),
              )
            else
              ElevatedButton(
                onPressed: _isInitializing ? null : _initializeColors,
                child: _isInitializing
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Initializing...'),
                        ],
                      )
                    : const Text('Initialize Default Colors'),
              ),
          ],
        ),
      ),
    );
  }
}
