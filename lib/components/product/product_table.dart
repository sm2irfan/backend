import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'product.dart';
import 'editable_product_manager.dart';
import 'sync_products_button.dart';

// MARK: - Table Configuration

/// Base configuration for responsive product tables
abstract class ProductTableConfig {
  List<double> initializeColumnWidths();
  TextStyle getTextStyle();
  double getRowHeight();
  double getMaxWidthForColumn(int columnIndex);
  int getMaxLinesForColumn(int columnIndex);
  Widget buildActionButtons({
    required BuildContext context,
    required Product product,
    required Function(Product) onEdit,
    required Function(BuildContext, Product) onDelete,
  });

  Widget buildTable({
    required List<String> titles,
    required List<double> columnWidths,
    required double rowHeight,
    required ScrollController verticalScrollController,
    required Widget Function(String, int, TextStyle) buildColumnHeader,
    required Widget Function(bool) buildTableRows,
  });
}

/// Mobile-specific implementation of product table
class MobileTableConfig implements ProductTableConfig {
  @override
  List<double> initializeColumnWidths() {
    List<double> columnWidths = List.filled(13, 120.0);

    // Set specific column widths for mobile
    columnWidths[0] = 50.0; // ID
    columnWidths[1] = 80.0; // Created At
    columnWidths[2] = 50.0; // Image
    columnWidths[3] = 50.0; // Image
    columnWidths[4] = 150.0; // Product name
    columnWidths[5] = 70.0; // Price
    columnWidths[6] = 150.0; // Description
    columnWidths[7] = 60.0; // Discount
    columnWidths[8] = 80.0; // Category 1
    columnWidths[9] = 80.0; // Category 2
    columnWidths[10] = 50.0; // Popular
    columnWidths[11] = 70.0; // Matching Words
    columnWidths[12] = 100.0; // Actions

    return columnWidths;
  }

  @override
  Widget buildTable({
    required List<String> titles,
    required List<double> columnWidths,
    required double rowHeight,
    required ScrollController verticalScrollController,
    required Widget Function(String, int, TextStyle) buildColumnHeader,
    required Widget Function(bool) buildTableRows,
  }) {
    return _buildTableLayout(
      titles: titles,
      columnWidths: columnWidths,
      verticalScrollController: verticalScrollController,
      buildColumnHeader: buildColumnHeader,
      buildTableRows: buildTableRows,
      headerStyle: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold),
      isMobile: true,
    );
  }

  @override
  Widget buildActionButtons({
    required BuildContext context,
    required Product product,
    required Function(Product) onEdit,
    required Function(BuildContext, Product) onDelete,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          onTap: () => onEdit(product),
          size: 36,
          padding: 8,
          iconSize: 18,
          icon: Icons.edit,
        ),
        _buildActionButton(
          onTap: () => onDelete(context, product),
          size: 36,
          padding: 8,
          iconSize: 18,
          icon: Icons.delete,
          iconColor: Colors.red,
        ),
      ],
    );
  }

  @override
  TextStyle getTextStyle() => const TextStyle(fontSize: 11.0);

  @override
  double getRowHeight() => 60.0;

  @override
  double getMaxWidthForColumn(int columnIndex) {
    switch (columnIndex) {
      case 3:
        return 150.0; // Product name
      case 5:
        return 150.0; // Description
      case 7:
        return 80.0; // Category 1
      case 8:
        return 80.0; // Category 2
      case 10:
        return 100.0; // Matching Words
      default:
        return 120.0;
    }
  }

  @override
  int getMaxLinesForColumn(int columnIndex) {
    switch (columnIndex) {
      case 3:
        return 2; // Product name
      case 5:
        return 2; // Description
      default:
        return 1;
    }
  }
}

/// Desktop-specific implementation of product table
class DesktopTableConfig implements ProductTableConfig {
  @override
  List<double> initializeColumnWidths() {
    List<double> columnWidths = List.filled(13, 120.0);

    // Set specific column widths for desktop
    columnWidths[0] = 80.0; // ID
    columnWidths[1] = 120.0; // Created At
    columnWidths[2] = 70.0; // Image
    columnWidths[3] = 70.0; // Image
    columnWidths[4] = 250.0; // Product name
    columnWidths[5] = 300.0; // Price
    columnWidths[6] = 350.0; // Description
    columnWidths[7] = 80.0; // Discount
    columnWidths[8] = 120.0; // Category 1
    columnWidths[9] = 120.0; // Category 2
    columnWidths[10] = 70.0; // Popular
    columnWidths[11] = 100.0; // Matching Words
    columnWidths[12] = 100.0; // Actions

    return columnWidths;
  }

  @override
  Widget buildTable({
    required List<String> titles,
    required List<double> columnWidths,
    required double rowHeight,
    required ScrollController verticalScrollController,
    required Widget Function(String, int, TextStyle) buildColumnHeader,
    required Widget Function(bool) buildTableRows,
  }) {
    return _buildTableLayout(
      titles: titles,
      columnWidths: columnWidths,
      verticalScrollController: verticalScrollController,
      buildColumnHeader: buildColumnHeader,
      buildTableRows: buildTableRows,
      headerStyle: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold),
      isMobile: false,
    );
  }

  @override
  Widget buildActionButtons({
    required BuildContext context,
    required Product product,
    required Function(Product) onEdit,
    required Function(BuildContext, Product) onDelete,
  }) {
    return SizedBox(
      width: 90,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => onEdit(product),
            ),
          ),
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => onDelete(context, product),
            ),
          ),
        ],
      ),
    );
  }

  @override
  TextStyle getTextStyle() => const TextStyle(fontSize: 13.0);

  @override
  double getRowHeight() => 100.0;

  @override
  double getMaxWidthForColumn(int columnIndex) {
    switch (columnIndex) {
      case 3:
        return 250.0; // Product name
      case 5:
        return 300.0; // Description
      case 7:
        return 120.0; // Category 1
      case 8:
        return 120.0; // Category 2
      case 10:
        return 150.0; // Matching Words
      default:
        return 120.0;
    }
  }

  @override
  int getMaxLinesForColumn(int columnIndex) {
    switch (columnIndex) {
      case 3:
        return 3; // Product name
      case 5:
        return 3; // Description
      default:
        return 1;
    }
  }
}

// Shared function for building table layout
Widget _buildTableLayout({
  required List<String> titles,
  required List<double> columnWidths,
  required ScrollController verticalScrollController,
  required Widget Function(String, int, TextStyle) buildColumnHeader,
  required Widget Function(bool) buildTableRows,
  required TextStyle headerStyle,
  required bool isMobile,
}) {
  return Column(
    children: [
      // Header row (fixed)
      Table(
        border: TableBorder.all(color: Colors.grey),
        columnWidths: columnWidths.asMap().map(
          (i, w) => MapEntry(i, FixedColumnWidth(w)),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.grey[200]),
            children: List.generate(titles.length, (i) {
              return buildColumnHeader(titles[i], i, headerStyle);
            }),
          ),
        ],
      ),

      // Scrollable data rows
      Expanded(
        child: SingleChildScrollView(
          controller: verticalScrollController,
          scrollDirection: Axis.vertical,
          child: buildTableRows(isMobile),
        ),
      ),
    ],
  );
}

// Helper for building action buttons
Widget _buildActionButton({
  required VoidCallback onTap,
  required double size,
  required double padding,
  required double iconSize,
  required IconData icon,
  Color iconColor = Colors.black,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      child: Icon(icon, size: iconSize, color: iconColor),
    ),
  );
}

// MARK: - Main Product Table Widget

/// Paginated product table with navigation controls
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
  // Controllers and state
  final ScrollController _verticalScrollController = ScrollController();
  late List<double> _columnWidths;
  double _rowHeight = 100.0;
  bool _isMobileView = false;
  final EditableProductManager _editManager = EditableProductManager();

  // Table configuration based on screen size
  late ProductTableConfig _tableConfig;

  // Column titles
  final List<String> _titles = [
    'ID',
    'Created At',
    'Updated At',
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

  @override
  void initState() {
    super.initState();
    _tableConfig = DesktopTableConfig(); // Default to desktop
    _initializeColumnWidths();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateResponsiveLayout();
  }

  void _updateResponsiveLayout() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;

    if (isMobile != _isMobileView) {
      setState(() {
        _isMobileView = isMobile;
        _tableConfig = isMobile ? MobileTableConfig() : DesktopTableConfig();
        _initializeColumnWidths();
        _rowHeight = _tableConfig.getRowHeight();
      });
    }
  }

  void _initializeColumnWidths() {
    var initialWidths = _tableConfig.initializeColumnWidths();
    _columnWidths = List<double>.from(initialWidths);

    // Ensure enough columns for all titles
    while (_columnWidths.length < _titles.length) {
      _columnWidths.add(100.0);
    }
  }

  @override
  void dispose() {
    _editManager.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[300],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SyncProductsButton(),
          const Divider(height: 1),
          Expanded(
            child:
                widget.products.isEmpty
                    ? const Center(child: Text('No products found'))
                    : _tableConfig.buildTable(
                      titles: _titles,
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

  // MARK: - UI Components

  // Header column builder with resize capability
  Widget _buildColumnHeader(String title, int index, TextStyle style) {
    return Stack(
      children: [
        Container(
          height: _rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          alignment: Alignment.centerLeft,
          child: SelectableText(title, style: style),
        ),
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

  // Table rows builder
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

  // Cell builder based on column index
  Widget _buildCell(Product product, int columnIndex, bool isMobile) {
    final bool isEditing = _editManager.editingProduct?.id == product.id;
    final TextStyle textStyle = _tableConfig.getTextStyle();

    // Use a switch case for different column types
    switch (columnIndex) {
      case 0:
        return _buildSimpleTextCell('#${product.id}', textStyle);
      case 1:
        return _buildDateCell(product.createdAt, textStyle);
      case 2:
        return _buildDateCell(product.updatedAt, textStyle);
      case 3:
        return _buildImageCell(product);
      case 4:
        return _buildNameCell(
          product,
          columnIndex,
          isEditing,
          isMobile,
          textStyle,
        );
      case 5:
        return _buildPriceCell(product, isEditing, textStyle);
      case 6:
        return _buildDescriptionCell(
          product,
          columnIndex,
          isEditing,
          isMobile,
          textStyle,
        );
      case 7:
        return _buildDiscountCell(product, isEditing, textStyle);
      case 8:
        return _buildCategoryCell(
          product,
          columnIndex,
          isEditing,
          isMobile,
          textStyle,
          isCategory1: true,
        );
      case 9:
        return _buildCategoryCell(
          product,
          columnIndex,
          isEditing,
          isMobile,
          textStyle,
          isCategory1: false,
        );
      case 10:
        return _buildPopularCell(product, isEditing);
      case 11:
        return _buildMatchingWordsCell(
          product,
          columnIndex,
          isEditing,
          isMobile,
          textStyle,
        );
      case 12:
        return _buildActionsCell(product, isEditing, isMobile);
      default:
        return const SizedBox();
    }
  }

  // MARK: - Cell Type Builders

  Widget _buildSimpleTextCell(String text, TextStyle style) {
    return SelectableText(text, style: style);
  }

  Widget _buildDateCell(DateTime? date, TextStyle style) {
    final String text =
        date != null ? '${date.day}/${date.month}/${date.year}' : '-';
    return SelectableText(text, style: style);
  }

  Widget _buildImageCell(Product product) {
    return _buildProductThumbnail(product);
  }

  Widget _buildNameCell(
    Product product,
    int columnIndex,
    bool isEditing,
    bool isMobile,
    TextStyle style,
  ) {
    if (isEditing) {
      return _editManager.buildEditableNameCell();
    } else {
      double maxWidth = _tableConfig.getMaxWidthForColumn(columnIndex);
      int maxLines = _tableConfig.getMaxLinesForColumn(columnIndex);

      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SelectableText(product.name, style: style),
      );
    }
  }

  Widget _buildPriceCell(Product product, bool isEditing, TextStyle style) {
    return isEditing
        ? _editManager.buildEditablePriceCell()
        : SelectableText(product.uPrices, style: style);
  }

  Widget _buildDescriptionCell(
    Product product,
    int columnIndex,
    bool isEditing,
    bool isMobile,
    TextStyle style,
  ) {
    if (isEditing) {
      return _editManager.buildEditableDescriptionCell();
    } else {
      double maxWidth = _tableConfig.getMaxWidthForColumn(columnIndex);
      int maxLines = _tableConfig.getMaxLinesForColumn(columnIndex);

      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SelectableText(product.description ?? '', style: style),
      );
    }
  }

  Widget _buildDiscountCell(Product product, bool isEditing, TextStyle style) {
    return isEditing
        ? _editManager.buildEditableDiscountCell()
        : SelectableText(
          product.discount != null ? '${product.discount}%' : '-',
          style: style,
        );
  }

  Widget _buildCategoryCell(
    Product product,
    int columnIndex,
    bool isEditing,
    bool isMobile,
    TextStyle style, {
    required bool isCategory1,
  }) {
    if (isEditing) {
      return isCategory1
          ? _editManager.buildEditableCategory1Cell()
          : _editManager.buildEditableCategory2Cell();
    } else {
      final String text =
          isCategory1 ? (product.category1 ?? '') : (product.category2 ?? '');
      double maxWidth = _tableConfig.getMaxWidthForColumn(columnIndex);

      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SelectableText(text, style: style),
      );
    }
  }

  Widget _buildPopularCell(Product product, bool isEditing) {
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
  }

  Widget _buildMatchingWordsCell(
    Product product,
    int columnIndex,
    bool isEditing,
    bool isMobile,
    TextStyle style,
  ) {
    if (isEditing) {
      return _editManager.buildEditableMatchingWordsCell();
    } else {
      double maxWidth = _tableConfig.getMaxWidthForColumn(columnIndex);

      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SelectableText(product.matchingWords ?? '', style: style),
      );
    }
  }

  Widget _buildActionsCell(Product product, bool isEditing, bool isMobile) {
    if (isEditing) {
      return _editManager.buildEditableActionCell(_saveChanges, _cancelEditing);
    } else {
      return _tableConfig.buildActionButtons(
        context: context,
        product: product,
        onEdit: _startEditing,
        onDelete: _showDeleteConfirmation,
      );
    }
  }

  // MARK: - Image Handling

  Widget _buildProductThumbnail(Product product) {
    final GlobalKey imageKey = GlobalKey();
    OverlayEntry? overlayEntry;
    final String? imageUrl = product.image;

    void showEnlargedImage() {
      if (imageUrl == null) return;

      overlayEntry = OverlayEntry(
        builder: (context) {
          final RenderBox? renderBox =
              imageKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox == null) return const SizedBox();

          final position = renderBox.localToGlobal(Offset.zero);
          final size = renderBox.size;

          return Positioned(
            left: position.dx + size.width + 5,
            top: position.dy - 100,
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

  // MARK: - Event Handlers

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved changes to: ${_editManager.editingProduct!.name}'),
      ),
    );
    setState(() {
      _editManager.cancelEditing();
    });
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted: ${product.name}')));
      }
    });
  }
}
