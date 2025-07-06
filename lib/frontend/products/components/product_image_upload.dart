import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class ProductImageUpload extends StatelessWidget {
  final List<File> productImages;
  final List<String> productImageUrls;
  final int primaryImageIndex;
  final bool uploadingImages;
  final VoidCallback onPickImages;
  final Function(int) onSetPrimary;
  final Function(int) onRemoveImage;

  const ProductImageUpload({
    super.key,
    required this.productImages,
    required this.productImageUrls,
    required this.primaryImageIndex,
    required this.uploadingImages,
    required this.onPickImages,
    required this.onSetPrimary,
    required this.onRemoveImage,
  });

  double _calculateContainerHeight() {
    final imageCount = kIsWeb ? productImageUrls.length : productImages.length;
    if (imageCount == 0) return 160;
    
    final canAddMore = imageCount < 6;
    final totalSlots = canAddMore ? imageCount + 1 : imageCount;
    
    const crossAxisCount = 3;
    final rows = (totalSlots / crossAxisCount).ceil();
    final gridHeight = rows * 100.0 + (rows - 1) * 8.0;
    
    return gridHeight + 16;
  }

  Widget _buildImagePreview() {
    if (uploadingImages) {
      return const Center(child: CircularProgressIndicator());
    } else if (productImageUrls.isNotEmpty) {
      return _buildImageGrid();
    } else if (!kIsWeb && productImages.isNotEmpty) {
      return _buildImageGrid();
    } else {
      return GestureDetector(
        onTap: onPickImages,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, color: Colors.orange, size: 40),
            const SizedBox(height: 8),
            Text(
              'Tap to upload product images',
              style: TextStyle(color: Colors.orange.shade700),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.upload, color: Colors.orange, size: 18),
                  SizedBox(width: 6),
                  Text('Upload Images', style: TextStyle(color: Colors.orange)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Max size 5MB each, JPG/PNG',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildImageGrid() {
    final imageCount = kIsWeb ? productImageUrls.length : productImages.length;
    final canAddMore = imageCount < 6;
    final totalSlots = canAddMore ? imageCount + 1 : imageCount;
    
    const crossAxisCount = 3;
    final rows = (totalSlots / crossAxisCount).ceil();
    final gridHeight = rows * 100.0 + (rows - 1) * 8.0;
    
    return Container(
      height: gridHeight,
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: totalSlots,
        itemBuilder: (context, index) {
          if (canAddMore && index == imageCount) {
            return GestureDetector(
              onTap: onPickImages,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[400]!, width: 2),
                  color: Colors.grey[100],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Colors.grey[600], size: 32),
                    const SizedBox(height: 4),
                    Text(
                      'Add',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          return GestureDetector(
            onTap: () => onSetPrimary(index),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: index == primaryImageIndex ? Colors.orange : Colors.grey[300]!,
                  width: index == primaryImageIndex ? 3 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (kIsWeb)
                      Image.network(productImageUrls[index], fit: BoxFit.cover)
                    else
                      Image.file(productImages[index], fit: BoxFit.cover),
                    if (index == primaryImageIndex)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.star, color: Colors.white, size: 16),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => onRemoveImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: Colors.orange[600], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Product Images',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: (productImages.isNotEmpty || productImageUrls.isNotEmpty) 
                  ? _calculateContainerHeight() 
                  : 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (productImages.isNotEmpty || productImageUrls.isNotEmpty)
                      ? Colors.orange[300]!
                      : Colors.grey[300]!,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                color: (productImages.isNotEmpty || productImageUrls.isNotEmpty)
                    ? Colors.orange[50]
                    : Colors.grey[50],
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: _buildImagePreview()),
                  if ((productImageUrls.isNotEmpty || productImages.isNotEmpty) && !uploadingImages)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '${kIsWeb ? productImageUrls.length : productImages.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (productImageUrls.isNotEmpty || productImages.isNotEmpty)
              Text(
                'Tap images to select primary thumbnail. Orange star = primary image.',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              )
            else
              Text(
                'Upload product images. Select one or multiple images at once.',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
