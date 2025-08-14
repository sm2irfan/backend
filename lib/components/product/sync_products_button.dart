import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'connectivity_helper.dart';
import '../../data/local_database.dart';

class SyncProductsButton extends StatefulWidget {
  /// Callback function to refresh UI data after sync completes successfully
  final VoidCallback? onSyncCompleted;

  const SyncProductsButton({super.key, this.onSyncCompleted});

  @override
  State<SyncProductsButton> createState() => _SyncProductsButtonState();
}

class _SyncProductsButtonState extends State<SyncProductsButton> {
  bool _isSyncing = false;

  Future<void> _syncProducts({bool initialSync = false}) async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      // Check internet connectivity before attempting to sync
      final hasConnection = await ConnectivityHelper.hasInternetConnection();
      
      if (!hasConnection) {
        // Show connectivity error with retry option
        if (mounted) {
          ConnectivityHelper.showConnectivityError(
            context,
            onRetry: () => _syncProducts(initialSync: initialSync),
            customMessage: 'Unable to sync products from cloud. Please check your internet connection and try again.',
          );
          setState(() {
            _isSyncing = false;
          });
        }
        return;
      }

      final LocalDatabase db = LocalDatabase();
      bool sqliteAvailable = await LocalDatabase.isSqliteAvailable();

      if (!sqliteAvailable) {
        if (mounted) {
          _showSqliteInstructionsDialog();
          setState(() {
            _isSyncing = false;
          });
        }
        return;
      }

      // Get last sync time for display
      final lastSyncTime = await db.getConfigValue(
        'last_sync_pre_all_products',
      );
      final String syncTypeInfo =
          initialSync ? 'Full Initial Sync' : 'Incremental Sync';
      final String syncTimeInfo =
          lastSyncTime != null
              ? 'Last sync: ${_formatDateTime(lastSyncTime)}'
              : 'First sync';

      // Perform sync operation
      final result = await db.syncProductsFromSupabase(
        initialSync: initialSync,
      );

      if (!mounted) return;

      if (result['sqlite_missing'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'MORE INFO',
              onPressed: () {
                if (mounted) _showSqliteInstructionsDialog();
              },
            ),
          ),
        );
      } else {
        // Show more detailed sync info
        final String syncMessage =
            result['success']
                ? '${result['message']} ($syncTimeInfo, $syncTypeInfo)'
                : result['message'];

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(syncMessage),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
          ),
        );

        // Call the callback to refresh data if sync was successful
        if (result['success'] && widget.onSyncCompleted != null) {
          widget.onSyncCompleted!();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing products: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  void _showSqliteInstructionsDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('SQLite Installation'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'The SQLite library is not available on your system. '
                    'Local database functionality requires SQLite to be installed.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Installation instructions:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (Platform.isLinux) ...[
                    const Text('For Ubuntu/Debian:'),
                    SelectableText(
                      'sudo apt-get update && sudo apt-get install -y libsqlite3-dev',
                    ),
                    const SizedBox(height: 8),
                    const Text('For Fedora:'),
                    SelectableText('sudo dnf install -y sqlite-devel'),
                    const SizedBox(height: 8),
                    const Text('For Arch Linux:'),
                    SelectableText('sudo pacman -S sqlite'),
                  ] else if (Platform.isWindows) ...[
                    const Text('For Windows:'),
                    const Text(
                      'The SQLite library should be included with the application.',
                    ),
                    const Text(
                      'Try reinstalling the application or contact support.',
                    ),
                  ] else if (Platform.isMacOS) ...[
                    const Text('For macOS:'),
                    SelectableText('brew install sqlite'),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'After installation, please restart the application.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  // Helper method to format ISO date string to a more readable format
  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed:
                _isSyncing ? null : () => _syncProducts(initialSync: true),
            icon: const Icon(Icons.sync_problem),
            label: const Text('Full Sync'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}
