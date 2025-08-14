import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'dart:io';

/// Utility class for checking internet connectivity
class ConnectivityHelper {
  static final Connectivity _connectivity = Connectivity();

  /// Check if the device has internet connection
  static Future<bool> hasInternetConnection() async {
    try {
      // First check connectivity status
      final connectivityResult = await _connectivity.checkConnectivity();

      // If no connectivity, return false immediately
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }

      // If we have connectivity, try to ping a reliable server
      // to confirm actual internet access
      try {
        final result = await InternetAddress.lookup('google.com');
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } on SocketException catch (_) {
        // DNS lookup failed, no internet connection
        return false;
      }
    } catch (e) {
      // Any other error, assume no connection
      return false;
    }
  }

  /// Show connectivity error dialog with retry option
  static void showConnectivityError(
    BuildContext context, {
    required VoidCallback onRetry,
    String? customMessage,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red),
              SizedBox(width: 8),
              Text('Connection Error'),
            ],
          ),
          content: Text(
            customMessage ??
                'No internet connection detected. Please check your network settings and try again.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        );
      },
    );
  }

  /// Show a snackbar with connectivity error and retry option
  static void showConnectivitySnackBar(
    BuildContext context, {
    required VoidCallback onRetry,
    String? customMessage,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(customMessage ?? 'No internet connection detected'),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: onRetry,
        ),
      ),
    );
  }
}
