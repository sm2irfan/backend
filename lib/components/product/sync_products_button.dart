import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../../data/local_database.dart';

class SyncProductsButton extends StatefulWidget {
  const SyncProductsButton({super.key});

  @override
  State<SyncProductsButton> createState() => _SyncProductsButtonState();
}

class _SyncProductsButtonState extends State<SyncProductsButton> {
  bool _isSyncing = false;

  // Method to handle sync operation
  Future<void> _syncProducts() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final LocalDatabase db = LocalDatabase();

      // Check if SQLite is available
      bool sqliteAvailable = await LocalDatabase.isSqliteAvailable();

      if (!sqliteAvailable) {
        // Show a more comprehensive error message with installation instructions
        _showSqliteInstructionsDialog();
        setState(() {
          _isSyncing = false;
        });
        return;
      }

      final result = await db.syncProductsFromSupabase();

      if (result['sqlite_missing'] == true) {
        // Handle the case where SQLite was detected as missing during the operation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'MORE INFO',
              onPressed: () {
                _showSqliteInstructionsDialog();
              },
            ),
          ),
        );
      } else {
        // Normal success/failure handling
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error syncing products: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  void _showSqliteInstructionsDialog() {
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton.icon(
        onPressed: _isSyncing ? null : _syncProducts,
        icon:
            _isSyncing
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                )
                : const Icon(Icons.sync),
        label: Text(_isSyncing ? 'Syncing...' : 'Sync All Products table'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
    );
  }
}
