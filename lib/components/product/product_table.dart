import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'product.dart';
import 'editable_product_manager.dart';
import 'product_table_mobile.dart';
import 'product_table_desktop.dart';
import 'sync_products_button.dart';

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
  // Controller for vertical scrolling
  final ScrollController _verticalScrollController = ScrollController();

  // State for resizable columns & rows
  late List<double> _columnWidths;
  double _rowHeight = 100.0; // Default row height for large screens
  bool _isMobileView = false;

  // Manager for editable product functionality
  final EditableProductManager _editManager = EditableProductManager();

  @override
  void initState() {
    super.initState();
    // Initialize with default values
    _initializeColumnWidths();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get screen width and determine if mobile view
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;

    if (isMobile != _isMobileView) {
      setState(() {
        _isMobileView = isMobile;
        _initializeColumnWidths();
        // Adjust row height for mobile or desktop
        _rowHeight =
            _isMobileView
                ? ProductTableMobile.getRowHeight()
                : ProductTableDesktop.getRowHeight();
      });
    }
  }

  void _initializeColumnWidths() {
    // Choose appropriate column widths based on device type
    _columnWidths =
        _isMobileView
            ? ProductTableMobile.initializeColumnWidths()
            : ProductTableDesktop.initializeColumnWidths();
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

    return Container(
      color: Colors.grey[300],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sync button at the top
          const SyncProductsButton(),

          const Divider(height: 1),

          // Main content area
          Expanded(
            child:
                widget.products.isEmpty
                    ? const Center(child: Text('No products found'))
                    : _isMobileView
                    ? ProductTableMobile.buildTable(
                      titles: titles,
                      columnWidths: _columnWidths,
                      rowHeight: _rowHeight,
                      verticalScrollController: _verticalScrollController,
                      buildColumnHeader: _buildColumnHeader,
                      buildTableRows: _buildTableRows,
                    )
                    : ProductTableDesktop.buildTable(
                      titles: titles,
                      columnWidths: _columnWidths,
                      rowHeight: _rowHeight,
                      verticalScrollController: _verticalScrollController,
                      buildColumnHeader: _buildColumnHeader,
                      buildTableRows: _buildTableRows,
                    ),
          ),
        ],
      ),
    );
  }

  // Shared header column builder with resize capability
  Widget _buildColumnHeader(String title, int index, TextStyle style) {
    return Stack(
      children: [
        // Selectable text area (main content)
        Container(
          height: _rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          alignment: Alignment.centerLeft,
          child: SelectableText(title, style: style),
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
                  _columnWidths[index] = (_columnWidths[index] + d.delta.dx)
                      .clamp(30.0, double.infinity);
                });
              },
              onVerticalDragUpdate: (d) {
                setState(() {
                  _rowHeight = (_rowHeight + d.delta.dy).clamp(40.0, 200.0);
                });
              },
              child: Container(width: 10, color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }

  // Shared table rows builder
  Widget _buildTableRows(bool isMobile) {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      columnWidths: _columnWidths.asMap().map(
        (i, w) => MapEntry(i, FixedColumnWidth(w)),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (final product in widget.products)
          TableRow(
            decoration: BoxDecoration(
              color:
                  _editManager.editingProduct?.id == product.id
                      ? Colors.white
                      : null,
            ),
            children: List.generate(_columnWidths.length, (i) {
              return SizedBox(
                height: _rowHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 12.0,
                  ),
                  child: _buildCell(product, i, isMobile),
                ),
              );
            }),
          ),
      ],
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

    return SizedBox(
      key: imageKey,
      width: width,
      height: height,
      child: CachedNetworkImage(
        key: ValueKey('${isEnlarged ? 'enlarged' : 'thumbnail'}-$imageUrl'),
        imageUrl: imageUrl,
        fit: fit,
        progressIndicatorBuilder: (context, url, progress) {
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

  // Cell builder with appropriate mobile/desktop styling
  Widget _buildCell(Product product, int columnIndex, bool isMobile) {
    final bool isEditing = _editManager.editingProduct?.id == product.id;
    // Get appropriate text style based on device type
    final TextStyle textStyle =
        isMobile
            ? ProductTableMobile.getTextStyle()
            : ProductTableDesktop.getTextStyle();

    switch (columnIndex) {
      case 0:
        return SelectableText('#${product.id}', style: textStyle);
      case 1:
        return SelectableText(
          '${product.createdAt.day}/${product.createdAt.month}/${product.createdAt.year}',
          style: textStyle,
        );
      case 2: // Image column
        return _buildProductThumbnail(product);
      case 3: // Product name column
        if (isEditing) {
          return _editManager.buildEditableNameCell();
        } else {
          // Get constraints based on device type
          double maxWidth =
              isMobile
                  ? ProductTableMobile.getMaxWidthForColumn(columnIndex)
                  : ProductTableDesktop.getMaxWidthForColumn(columnIndex);
          int maxLines =
              isMobile
                  ? ProductTableMobile.getMaxLinesForColumn(columnIndex)
                  : ProductTableDesktop.getMaxLinesForColumn(columnIndex);

          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SelectableText(
              product.name,
              maxLines: maxLines,
              textAlign: TextAlign.left,
              style: textStyle,
            ),
          );
        }
      case 4: // Price column
        if (isEditing) {
          return _editManager.buildEditablePriceCell();
        } else {
          return SelectableText(product.uPrices, style: textStyle);
        }
      case 5: // Description column
        if (isEditing) {
          return _editManager.buildEditableDescriptionCell();
        } else {
          double maxWidth =
              isMobile
                  ? ProductTableMobile.getMaxWidthForColumn(columnIndex)
                  : ProductTableDesktop.getMaxWidthForColumn(columnIndex);
          int maxLines =
              isMobile
                  ? ProductTableMobile.getMaxLinesForColumn(columnIndex)
                  : ProductTableDesktop.getMaxLinesForColumn(columnIndex);

          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SelectableText(
              product.description ?? '',
              maxLines: maxLines,
              textAlign: TextAlign.left,
              style: textStyle,
            ),
          );
        }
      case 6: // Discount
        if (isEditing) {
          return _editManager.buildEditableDiscountCell();
        } else {
          return SelectableText(
            product.discount != null ? '${product.discount}%' : '-',
            style: textStyle,
          );
        }
      case 7: // Category 1
        if (isEditing) {
          return _editManager.buildEditableCategory1Cell();
        } else {
          double maxWidth =
              isMobile
                  ? ProductTableMobile.getMaxWidthForColumn(columnIndex)
                  : ProductTableDesktop.getMaxWidthForColumn(columnIndex);

          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SelectableText(
              product.category1 ?? '',
              maxLines: 1,
              textAlign: TextAlign.left,
              style: textStyle,
            ),
          );
        }
      case 8: // Category 2
        if (isEditing) {
          return _editManager.buildEditableCategory2Cell();
        } else {
          double maxWidth =
              isMobile
                  ? ProductTableMobile.getMaxWidthForColumn(columnIndex)
                  : ProductTableDesktop.getMaxWidthForColumn(columnIndex);

          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SelectableText(
              product.category2 ?? '',
              maxLines: 1,
              textAlign: TextAlign.left,
              style: textStyle,
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
          double maxWidth =
              isMobile
                  ? ProductTableMobile.getMaxWidthForColumn(columnIndex)
                  : ProductTableDesktop.getMaxWidthForColumn(columnIndex);

          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SelectableText(
              product.matchingWords ?? '',
              maxLines: 1,
              textAlign: TextAlign.left,
              style: textStyle,
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
          return isMobile
              ? ProductTableMobile.buildActionButtons(
                context: context,
                product: product,
                onEdit: _startEditing,
                onDelete: _showDeleteConfirmation,
              )
              : ProductTableDesktop.buildActionButtons(
                context: context,
                product: product,
                onEdit: _startEditing,
                onDelete: _showDeleteConfirmation,
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
      if (confirmed == true && mounted) {
        // Added mounted check before using context after async gap
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted: ${product.name}')));
      }
    });
  }
}
