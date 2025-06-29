import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';

/// Utility class for handling different types of image sources
class ImageUtils {
  
  /// Determines if the provided imageUrl is a base64 data URL
  static bool isBase64DataUrl(String imageUrl) {
    return imageUrl.startsWith('data:image/');
  }
  
  /// Extracts base64 data from a data URL
  static String extractBase64FromDataUrl(String dataUrl) {
    if (!dataUrl.contains('base64,')) {
      throw ArgumentError('Invalid base64 data URL');
    }
    return dataUrl.split('base64,')[1];
  }
  
  /// Converts base64 string to Uint8List
  static Uint8List base64ToBytes(String base64String) {
    return base64Decode(base64String);
  }
  
  /// Widget that can display both network images and base64 data URLs
  static Widget buildImageWidget({
    required String imageUrl,
    required BoxFit fit,
    double? width,
    double? height,
    Widget? errorWidget,
    Widget? loadingWidget,
  }) {
    if (imageUrl.isEmpty) {
      return errorWidget ?? const Icon(Icons.image, color: Colors.grey);
    }
    
    try {
      if (isBase64DataUrl(imageUrl)) {
        // Handle base64 data URL
        final base64String = extractBase64FromDataUrl(imageUrl);
        final bytes = base64ToBytes(base64String);
        
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ?? const Icon(Icons.broken_image, color: Colors.red);
          },
        );
      } else {
        // Handle network URL
        return Image.network(
          imageUrl,
          fit: fit,
          width: width,
          height: height,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return loadingWidget ?? const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ?? const Icon(Icons.broken_image, color: Colors.red);
          },
        );
      }
    } catch (e) {
      return errorWidget ?? const Icon(Icons.broken_image, color: Colors.red);
    }
  }
}
