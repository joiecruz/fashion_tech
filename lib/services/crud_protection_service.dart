/// Service for protecting CRUD operations from spam clicking
/// Provides centralized spam protection for buttons and actions
/// 
/// Usage:
/// ```dart
/// class MyWidget extends StatefulWidget {
///   @override
///   _MyWidgetState createState() => _MyWidgetState();
/// }
/// 
/// class _MyWidgetState extends State<MyWidget> with CrudProtectionMixin {
///   @override
///   Widget build(BuildContext context) {
///     return ElevatedButton(
///       onPressed: isOperationInProgress('save') ? null : () => performProtectedOperation('save', _saveData),
///       child: isOperationInProgress('save') 
///         ? CircularProgressIndicator() 
///         : Text('Save'),
///     );
///   }
///   
///   Future<void> _saveData() async {
///     // Your save logic here
///   }
/// }
/// ```

import 'package:flutter/material.dart';

/// Mixin that provides CRUD operation protection functionality
/// Prevents spam clicking by tracking ongoing operations
mixin CrudProtectionMixin<T extends StatefulWidget> on State<T> {
  final Set<String> _ongoingOperations = <String>{};

  /// Checks if a specific operation is currently in progress
  /// 
  /// [operationKey] - Unique identifier for the operation
  /// Returns true if the operation is ongoing, false otherwise
  bool isOperationInProgress(String operationKey) {
    return _ongoingOperations.contains(operationKey);
  }

  /// Performs an operation with spam protection
  /// 
  /// [operationKey] - Unique identifier for the operation
  /// [operation] - The async function to execute
  /// [onError] - Optional error handler
  /// [onSuccess] - Optional success handler
  /// 
  /// Returns true if operation was started, false if already in progress
  Future<bool> performProtectedOperation(
    String operationKey,
    Future<void> Function() operation, {
    Function(dynamic error)? onError,
    VoidCallback? onSuccess,
  }) async {
    // Prevent spam clicking
    if (_ongoingOperations.contains(operationKey)) {
      return false;
    }

    _ongoingOperations.add(operationKey);
    
    try {
      if (mounted) {
        setState(() {}); // Update UI to show loading state
      }

      await operation();
      
      if (onSuccess != null) {
        onSuccess();
      }
      
      return true;
    } catch (error) {
      if (onError != null) {
        onError(error);
      } else {
        // Default error handling
        debugPrint('Operation $operationKey failed: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Operation failed: ${error.toString()}'),
              backgroundColor: Colors.red[600],
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      return false;
    } finally {
      _ongoingOperations.remove(operationKey);
      if (mounted) {
        setState(() {}); // Update UI to remove loading state
      }
    }
  }

  /// Clears all ongoing operations (useful for cleanup)
  void clearAllOperations() {
    _ongoingOperations.clear();
    if (mounted) {
      setState(() {});
    }
  }

  /// Gets the count of ongoing operations
  int get ongoingOperationsCount => _ongoingOperations.length;

  /// Checks if any operation is in progress
  bool get hasOngoingOperations => _ongoingOperations.isNotEmpty;

  @override
  void dispose() {
    _ongoingOperations.clear();
    super.dispose();
  }
}

/// Widget wrapper that provides CRUD protection for buttons
/// Automatically handles loading states and disabled states
class ProtectedButton extends StatelessWidget {
  final String operationKey;
  final Future<void> Function() onPressed;
  final Widget child;
  final Widget? loadingChild;
  final VoidCallback? onSuccess;
  final Function(dynamic)? onError;
  final ButtonStyle? style;
  final bool enabled;
  final CrudProtectionMixin protectionMixin;

  const ProtectedButton({
    Key? key,
    required this.operationKey,
    required this.onPressed,
    required this.child,
    required this.protectionMixin,
    this.loadingChild,
    this.onSuccess,
    this.onError,
    this.style,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isLoading = protectionMixin.isOperationInProgress(operationKey);
    final isEnabled = enabled && !isLoading;

    return ElevatedButton(
      onPressed: isEnabled
          ? () => protectionMixin.performProtectedOperation(
                operationKey,
                onPressed,
                onError: onError,
                onSuccess: onSuccess,
              )
          : null,
      style: style,
      child: isLoading
          ? (loadingChild ??
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ))
          : child,
    );
  }
}

/// Service class for managing CRUD operations globally
/// Useful for tracking operations across different widgets
class CrudProtectionService {
  static final CrudProtectionService _instance = CrudProtectionService._internal();
  factory CrudProtectionService() => _instance;
  CrudProtectionService._internal();

  final Set<String> _globalOperations = <String>{};

  /// Checks if a global operation is in progress
  bool isGlobalOperationInProgress(String operationKey) {
    return _globalOperations.contains(operationKey);
  }

  /// Starts a global operation
  void startGlobalOperation(String operationKey) {
    _globalOperations.add(operationKey);
  }

  /// Ends a global operation
  void endGlobalOperation(String operationKey) {
    _globalOperations.remove(operationKey);
  }

  /// Performs a global protected operation
  Future<bool> performGlobalProtectedOperation(
    String operationKey,
    Future<void> Function() operation, {
    Function(dynamic error)? onError,
  }) async {
    if (_globalOperations.contains(operationKey)) {
      return false;
    }

    _globalOperations.add(operationKey);

    try {
      await operation();
      return true;
    } catch (error) {
      if (onError != null) {
        onError(error);
      } else {
        debugPrint('Global operation $operationKey failed: $error');
      }
      return false;
    } finally {
      _globalOperations.remove(operationKey);
    }
  }

  /// Clears all global operations
  void clearAllGlobalOperations() {
    _globalOperations.clear();
  }

  /// Gets the count of global operations
  int get globalOperationsCount => _globalOperations.length;
}

/// Configuration class for CRUD protection settings
class CrudProtectionConfig {
  static Duration defaultTimeout = const Duration(seconds: 30);
  static bool enableDebugLogs = false;
  static String defaultErrorMessage = 'Operation failed. Please try again.';
  
  /// Default success message generator
  static String Function(String operationKey) defaultSuccessMessage = 
      (operationKey) => 'Operation completed successfully';
      
  /// Default loading widget
  static Widget defaultLoadingWidget = const SizedBox(
    width: 16,
    height: 16,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
    ),
  );
}

/// Extension methods for easier use with existing widgets
extension CrudProtectionExtension on State {
  /// Quick method to check if an operation is safe to perform
  bool canPerformOperation(String operationKey, Set<String> ongoingOperations) {
    return !ongoingOperations.contains(operationKey);
  }
  
  /// Quick method to show operation feedback
  void showOperationFeedback({
    required bool success,
    required String message,
    Duration? duration,
  }) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: success ? Colors.green[600] : Colors.red[600],
        duration: duration ?? const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
