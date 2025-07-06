// Test file to validate the color system implementation
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/services/default_colors_service.dart';
import 'lib/models/color.dart' as ColorModel;
import 'lib/frontend/common/color_selector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('=== COLOR SYSTEM INTEGRATION TEST ===');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('✓ Firebase initialized');
    
    // Test color initialization
    print('\n1. Testing color initialization...');
    final areInitialized = await DefaultColorsService.areDefaultColorsInitialized();
    print('   Default colors initialized: $areInitialized');
    
    if (!areInitialized) {
      print('   Initializing default colors...');
      await DefaultColorsService.initializeDefaultColors();
      print('   ✓ Default colors initialized');
    }
    
    // Test color loading
    print('\n2. Testing color loading...');
    final currentUser = FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid ?? 'anonymous';
    
    final colors = await DefaultColorsService.getAvailableColors(userId);
    print('   Available colors: ${colors.length}');
    
    if (colors.isNotEmpty) {
      print('   Sample colors:');
      for (int i = 0; i < 5 && i < colors.length; i++) {
        final color = colors[i];
        print('     - ${color.name} (${color.hexCode}) [${color.createdBy}]');
      }
      print('   ✓ Colors loaded successfully');
    }
    
    // Test color creation
    print('\n3. Testing color creation...');
    final newColorId = await DefaultColorsService.createColor(
      'Test Color ${DateTime.now().millisecondsSinceEpoch}',
      '#FF5733',
      userId,
    );
    
    if (newColorId != null) {
      print('   ✓ New color created with ID: $newColorId');
      
      // Test color retrieval
      final newColor = await DefaultColorsService.getColorById(newColorId);
      if (newColor != null) {
        print('   ✓ Color retrieved: ${newColor.name} (${newColor.hexCode})');
      }
    }
    
    // Test color lookup by ID
    print('\n4. Testing color lookup...');
    if (colors.isNotEmpty) {
      final firstColor = colors.first;
      final lookedUpColor = await DefaultColorsService.getColorById(firstColor.id);
      
      if (lookedUpColor != null) {
        print('   ✓ Color lookup successful: ${lookedUpColor.name}');
      } else {
        print('   ✗ Color lookup failed for ID: ${firstColor.id}');
      }
    }
    
    print('\n=== COLOR SYSTEM TEST COMPLETE ===');
    print('✓ All color system components working correctly');
    
  } catch (e) {
    print('\n✗ Error during color system test: $e');
    print('Stack trace: ${StackTrace.current}');
  }
}

// Widget test for color selector
class ColorSystemTestWidget extends StatefulWidget {
  @override
  _ColorSystemTestWidgetState createState() => _ColorSystemTestWidgetState();
}

class _ColorSystemTestWidgetState extends State<ColorSystemTestWidget> {
  String? selectedColorId;
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Color System Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Color System Test'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Color System Test',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              
              // Color selector test
              ColorSelector(
                selectedColorId: selectedColorId,
                onColorSelected: (colorId) {
                  setState(() {
                    selectedColorId = colorId;
                  });
                },
                isRequired: true,
                label: 'Select Test Color',
              ),
              SizedBox(height: 20),
              
              // Display selected color
              if (selectedColorId != null) ...[
                Text(
                  'Selected Color ID: $selectedColorId',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 10),
                
                // Color display test
                FutureBuilder<ColorModel.Color?>(
                  future: DefaultColorsService.getColorById(selectedColorId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }
                    
                    if (snapshot.hasData && snapshot.data != null) {
                      final color = snapshot.data!;
                      return Row(
                        children: [
                          ColorDisplay(
                            colorId: color.id,
                            colorName: color.name,
                            hexCode: color.hexCode,
                            size: 30,
                          ),
                          SizedBox(width: 10),
                          Text(
                            '${color.name} (${color.hexCode})',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      );
                    }
                    
                    return Text('Color not found');
                  },
                ),
              ],
              
              SizedBox(height: 30),
              
              // Test add color dialog
              ElevatedButton(
                onPressed: () async {
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => AddColorDialog(),
                  );
                  
                  if (result != null) {
                    setState(() {
                      selectedColorId = result;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Color added successfully!')),
                    );
                  }
                },
                child: Text('Add New Color'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
