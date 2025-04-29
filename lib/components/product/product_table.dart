import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'product.dart';
import 'editable_product_manager.dart';

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
    const tableTextStyle = TextStyle(fontSize: 13.0);
    const tableHeaderStyle = TextStyle(
      fontSize: 13.0,
      fontWeight: FontWeight.bold,
    );

    // Calculate total pages
    // final int totalPages = (widget.totalItems / widget.pageSize).ceil();

    return Container(
      color: Colors.grey[300],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

  Widget _buildProductThumbnail(Product product) {
    return SizedBox(
      width: 40,
      height: 40,
      child:
          product.image != null
              ? Image.network(
                product.image!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.image_not_supported, size: 20);
                },
              )
              : const Icon(Icons.image_not_supported, size: 20),
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
