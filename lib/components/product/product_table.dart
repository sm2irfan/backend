import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'product.dart';
import 'editable_product_manager.dart';
import '../../data/local_database.dart';

// Paginated product table with navigation controls
class PaginatedProductTable extends StatefulWidget {
  final List<Product> products;
  final int currentPage;
  final int totalItems;
  final int pageSize;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final bool isLoading;
  final Function(int) onPageChanged;
  final Function(int) onPageSizeChanged;

  const PaginatedProductTable({
    super.key,
    required this.products,
    required this.currentPage,
    required this.totalItems,
    required this.pageSize,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.isLoading,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  @override
  State<PaginatedProductTable> createState() => _PaginatedProductTableState();
}

class _PaginatedProductTableState extends State<PaginatedProductTable> {
  // controller for vertical scrolling
  final ScrollController _verticalScrollController = ScrollController();
  // state for resizable columns & rows
  late List<double> _columnWidths;
  double _rowHeight = 100.0; // Increased initial row height

  // Manager for editable product functionality
  final EditableProductManager _editManager = EditableProductManager();

  // Add this property to track sync status
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    // Initialize columns with custom widths - now for 12 columns (added image column)
    _columnWidths = List.filled(12, 120.0);
    // Set custom widths for columns
    _columnWidths[0] = 80.0; // ID column can be narrower
    _columnWidths[1] = 120.0; // Created At column
    _columnWidths[2] = 70.0; // Image column - just for thumbnail
    _columnWidths[3] = 250.0; // Product name column
    _columnWidths[4] = 300.0; // Description column gets more space
    _columnWidths[5] = 350.0; // Description column gets more space
    _columnWidths[6] = 80.0; // Description column gets more space
  }

  void _startEditing(Product product) {
    setState(() {
      _editManager.startEditing(product);
    });
  }

  void _cancelEditing() {
    setState(() {
      _editManager.cancelEditing();
    });
  }

  void _saveChanges() {
    // Here you would implement the logic to save the changes
    // For now we'll just show a snackbar and exit edit mode
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved changes to: ${_editManager.editingProduct!.name}'),
      ),
    );
    setState(() {
      _editManager.cancelEditing();
    });
  }

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
  void dispose() {
    _editManager.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'ID',
      'Created At',
      'Image',
      'Product',
      'Price',
      'Description',
      'Discount',
      'Category 1',
      'Category 2',
      'Popular',
      'Matching Words',
      'Actions',
    ];

    // Define smaller text style for the entire table
    const tableHeaderStyle = TextStyle(
      fontSize: 13.0,
      fontWeight: FontWeight.bold,
    );

    return Container(
      color: Colors.grey[300],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add sync button here
          Padding(
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
              label: Text(
                _isSyncing ? 'Syncing...' : 'Sync All Products table',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                widget.products.isEmpty
                    ? const Center(child: Text('No products found'))
                    : Column(
                      children: [
                        // header row (fixed, no horizontal scroll)
                        Table(
                          border: TableBorder.all(color: Colors.grey),
                          columnWidths: _columnWidths.asMap().map(
                            (i, w) => MapEntry(i, FixedColumnWidth(w)),
                          ),
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                              ),
                              children: List.generate(titles.length, (i) {
                                return Stack(
                                  children: [
                                    // Selectable text area (main content)
                                    Container(
                                      height: _rowHeight,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 12.0,
                                      ),
                                      alignment: Alignment.centerLeft,
                                      child: SelectableText(
                                        titles[i],
                                        style: tableHeaderStyle,
                                      ),
                                    ),
                                    // Resize handle (positioned at right edge)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      bottom: 0,
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.resizeColumn,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.translucent,
                                          onHorizontalDragUpdate: (d) {
                                            setState(() {
                                              _columnWidths[i] =
                                                  (_columnWidths[i] +
                                                          d.delta.dx)
                                                      .clamp(
                                                        30.0,
                                                        double.infinity,
                                                      );
                                            });
                                          },
                                          onVerticalDragUpdate: (d) {
                                            setState(() {
                                              _rowHeight = (_rowHeight +
                                                      d.delta.dy)
                                                  .clamp(40.0, 200.0);
                                            });
                                          },
                                          child: Container(
                                            width: 10,
                                            color: Colors.transparent,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ],
                        ),
                        // scrollable data rows (vertical only)
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _verticalScrollController,
                            scrollDirection: Axis.vertical,
                            child: Table(
                              border: TableBorder.all(color: Colors.grey),
                              columnWidths: _columnWidths.asMap().map(
                                (i, w) => MapEntry(i, FixedColumnWidth(w)),
                              ),
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              children: [
                                for (final product in widget.products)
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color:
                                          _editManager.editingProduct?.id ==
                                                  product.id
                                              ? Colors.white
                                              : null,
                                    ),
                                    children: List.generate(
                                      _columnWidths.length,
                                      (i) {
                                        return SizedBox(
                                          height: _rowHeight,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                              vertical: 12.0,
                                            ),
                                            child: _buildCell(product, i),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  // Reusable cached image widget
  Widget _buildCachedImage({
    required String? imageUrl,
    required BoxFit fit,
    required double width,
    required double height,
    bool isEnlarged = false,
    Key? imageKey,
  }) {
    if (imageUrl == null) {
      return SizedBox(
        width: width,
        height: height,
        child: Icon(Icons.image_not_supported, size: isEnlarged ? 50 : 20),
      );
    }

    final String logPrefix = isEnlarged ? 'Enlarged image' : 'Thumbnail';

    return SizedBox(
      key: imageKey,
      width: width,
      height: height,
      child: CachedNetworkImage(
        key: ValueKey('${isEnlarged ? 'enlarged' : 'thumbnail'}-$imageUrl'),
        imageUrl: imageUrl,
        fit: fit,
        progressIndicatorBuilder: (context, url, progress) {
          // Log the loading source
          if (progress.totalSize == null) {
            return isEnlarged
                ? const SizedBox()
                : const SizedBox(width: 20, height: 20);
          } else {
            final percent = progress.downloaded / (progress.totalSize ?? 1);

            return Center(
              child: SizedBox(
                width: isEnlarged ? 40 : 20,
                height: isEnlarged ? 40 : 20,
                child: CircularProgressIndicator(
                  strokeWidth: isEnlarged ? 3 : 2,
                  value: percent,
                ),
              ),
            );
          }
        },
        errorWidget: (context, url, error) {
          return Icon(Icons.error_outline, size: isEnlarged ? 50 : 20);
        },
      ),
    );
  }

  Widget _buildProductThumbnail(Product product) {
    final GlobalKey imageKey = GlobalKey();
    OverlayEntry? overlayEntry;
    final String? imageUrl = product.image;

    // Create an overlay with larger image
    void showEnlargedImage() {
      if (imageUrl == null) return;

      overlayEntry = OverlayEntry(
        builder: (context) {
          // Get position of the thumbnail to position enlarged image
          final RenderBox? renderBox =
              imageKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox == null) return const SizedBox();

          final position = renderBox.localToGlobal(Offset.zero);
          final size = renderBox.size;

          return Positioned(
            left: position.dx + size.width + 5,
            top: position.dy - 100, // Position a bit higher than thumbnail
            child: Material(
              elevation: 8,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  color: Colors.white,
                ),
                width: 500,
                height: 500,
                child: _buildCachedImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  width: 500,
                  height: 500,
                  isEnlarged: true,
                ),
              ),
            ),
          );
        },
      );

      Overlay.of(context).insert(overlayEntry!);
    }

    // Remove the overlay
    void hideEnlargedImage() {
      overlayEntry?.remove();
      overlayEntry = null;
    }

    return MouseRegion(
      onEnter: (_) => showEnlargedImage(),
      onExit: (_) => hideEnlargedImage(),
      child: _buildCachedImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: 40,
        height: 40,
        imageKey: imageKey,
      ),
    );
  }

  Widget _buildCell(Product product, int columnIndex) {
    final bool isEditing = _editManager.editingProduct?.id == product.id;

    switch (columnIndex) {
      case 0:
        return SelectableText(
          '#${product.id}',
          style: const TextStyle(fontSize: 13.0),
        );
      case 1:
        return SelectableText(
          '${product.createdAt.day}/${product.createdAt.month}/${product.createdAt.year}',
          style: const TextStyle(fontSize: 13.0),
        );
      case 2: // Image column
        return _buildProductThumbnail(product);
      case 3: // Product name column (no image)
        if (isEditing) {
          return _editManager.buildEditableNameCell();
        } else {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: SelectableText(
              product.name,
              maxLines: 3,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 13.0),
            ),
          );
        }
      case 4: // Price column
        if (isEditing) {
          return _editManager.buildEditablePriceCell();
        } else {
          return SelectableText(
            '\$${product.uPrices}',
            style: const TextStyle(fontSize: 13.0),
          );
        }
      case 5: // Description column
        if (isEditing) {
          return _editManager.buildEditableDescriptionCell();
        } else {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: SelectableText(
              product.description ?? '',
              maxLines: 3,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 13.0),
            ),
          );
        }
      case 6: // Discount
        if (isEditing) {
          return _editManager.buildEditableDiscountCell();
        } else {
          return SelectableText(
            product.discount != null ? '${product.discount}%' : '-',
            style: const TextStyle(fontSize: 13.0),
          );
        }
      case 7: // Category 1
        if (isEditing) {
          return _editManager.buildEditableCategory1Cell();
        } else {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: SelectableText(
              product.category1 ?? '',
              maxLines: 1,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 13.0),
            ),
          );
        }
      case 8: // Category 2
        if (isEditing) {
          return _editManager.buildEditableCategory2Cell();
        } else {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: SelectableText(
              product.category2 ?? '',
              maxLines: 1,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 13.0),
            ),
          );
        }
      case 9: // Popular
        if (isEditing) {
          return _editManager.buildEditablePopularCell((value) {
            setState(() {
              _editManager.editPopular = value ?? false;
            });
          });
        } else {
          return product.popularProduct
              ? const Icon(Icons.star, color: Colors.amber, size: 20)
              : const SelectableText('-');
        }
      case 10: // Matching Words
        if (isEditing) {
          return _editManager.buildEditableMatchingWordsCell();
        } else {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: SelectableText(
              product.matchingWords ?? '',
              maxLines: 1,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 13.0),
            ),
          );
        }
      default: // Actions column
        if (isEditing) {
          return _editManager.buildEditableActionCell(
            _saveChanges,
            _cancelEditing,
          );
        } else {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _startEditing(product),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                onPressed: () {
                  _showDeleteConfirmation(context, product);
                },
              ),
            ],
          );
        }
    }
  }

  void _showDeleteConfirmation(BuildContext context, Product product) {
    showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete Product'),
            content: Text('Are you sure you want to delete "${product.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  'DELETE',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    ).then((confirmed) {
      if (confirmed == true) {
        // Show SnackBar after dialog is dismissed, using the original context
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted: ${product.name}')));
      }
    });
  }
}
