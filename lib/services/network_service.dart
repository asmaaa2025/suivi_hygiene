import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Network connectivity service
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();

  /// Check if device has network connectivity
  Future<bool> hasConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      // Check if any connection type is available (not none)
      return !results.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('[Network] Error checking connectivity: $e');
      return false;
    }
  }

  /// Stream of connectivity changes
  Stream<ConnectivityResult> get connectivityStream {
    return _connectivity.onConnectivityChanged.map((results) {
      // Return the first non-none result, or none if all are none
      final nonNone =
          results.where((r) => r != ConnectivityResult.none).toList();
      return nonNone.isNotEmpty ? nonNone.first : ConnectivityResult.none;
    });
  }

  /// Get current connectivity status
  Future<ConnectivityResult> getCurrentStatus() async {
    try {
      final results = await _connectivity.checkConnectivity();
      // Return the first non-none result, or none if all are none
      final nonNone =
          results.where((r) => r != ConnectivityResult.none).toList();
      return nonNone.isNotEmpty ? nonNone.first : ConnectivityResult.none;
    } catch (e) {
      debugPrint('[Network] Error getting status: $e');
      return ConnectivityResult.none;
    }
  }
}
