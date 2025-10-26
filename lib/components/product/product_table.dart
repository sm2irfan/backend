import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async'; // Important for Timer class
import 'dart:convert'; // For JSON parsing
import '../../data/local_database.dart';
import 'product_validators.dart';
import 'product.dart';
import 'editable_product_manager.dart';
import 'sync_products_button.dart';
import 'product_image_editor.dart';
import 'product_filters.dart';
import 'supabase_product_bloc.dart';
import 'add_product_manager.dart';
import 'product_table_config.dart'; // Updated import
import 'connectivity_helper.dart';
import 'column_visibility_manager.dart' as col_manager;
import 'product_details.dart'; // Add import for product details service

// New Refresh Button Widget
class RefreshButton extends StatefulWidget {
  final int currentPage;
  final int pageSize;

  const RefreshButton({
    Key? key,
    required this.currentPage,
    required this.pageSize,
  }) : super(key: key);

  @override
  State<RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<RefreshButton> {
  bool _isRefreshing = false;

  void _refreshData() {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    // Dispatch the refresh event to the bloc
    final productBloc = BlocProvider.of<ProductBloc>(context);
    productBloc.add(
      RefreshCurrentPage(
        currentPage: widget.currentPage,
        pageSize: widget.pageSize,
      ),
    );

    // Reset the refreshing state after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductBloc, ProductState>(
      listener: (context, state) {
        // Stop refreshing when data is loaded or there's an error
        if (state is ProductsLoaded || state is ProductError) {
          if (mounted && _isRefreshing) {
            setState(() {
              _isRefreshing = false;
            });
          }
        }
      },
      child: Tooltip(
        message: 'Refresh current page data',
        child: ElevatedButton.icon(
          onPressed: _isRefreshing ? null : _refreshData,
          icon:
              _isRefreshing
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : const Icon(Icons.refresh),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
    );
  }
}

// Real-time column filter with debouncing
class ColumnFilterInput extends StatefulWidget {
  final String columnName;
  final int currentPage;
  final int pageSize;
  final Map<String, String> activeFilters;
  // Add new properties for customization
  final double width;
  final double height;
  final String? hintText;

  const ColumnFilterInput({
    Key? key,
    required this.columnName,
    required this.currentPage,
    required this.pageSize,
    required this.activeFilters,
    this.width = 60, // Default width
    this.height = 25, // Default height
    this.hintText,
  }) : super(key: key);

  @override
  State<ColumnFilterInput> createState() => _ColumnFilterInputState();
}

class _ColumnFilterInputState extends State<ColumnFilterInput> {
  late TextEditingController _controller;
  Timer? _debounceTimer;
  // Add a FocusNode to manage focus persistence
  final FocusNode _focusNode = FocusNode();

  // Debounce duration (milliseconds to wait after typing stops)
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    // Initialize with existing filter value if any, removing LIKE: prefix if present
    String initialValue =
        widget.activeFilters[widget.columnName.toLowerCase()] ?? '';

    // Remove LIKE: prefix for display in the text field
    if (initialValue.startsWith('LIKE:')) {
      initialValue = initialValue.substring(5); // Remove 'LIKE:' prefix
    }

    _controller = TextEditingController(text: initialValue);
  }

  @override
  void didUpdateWidget(ColumnFilterInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller if the filter value has changed
    if (oldWidget.activeFilters != widget.activeFilters) {
      String newValue =
          widget.activeFilters[widget.columnName.toLowerCase()] ?? '';

      // Remove 'LIKE:' prefix for display in the text field
      if (newValue.startsWith('LIKE:')) {
        newValue = newValue.substring(5); // Remove 'LIKE:' prefix
      }

      // Skip automatic update if text is substantially the same
      if (_controller.text.trim() != newValue.trim()) {
        // Save cursor position and selection
        final int cursorPosition = _controller.selection.baseOffset;

        // Set value without triggering change events
        _controller.value = TextEditingValue(
          text: newValue,
          selection: TextSelection.collapsed(
            // If cursor position was valid, keep it or adjust it
            offset:
                cursorPosition > -1 && cursorPosition <= newValue.length
                    ? cursorPosition
                    : newValue.length,
          ),
        );

        // Restore focus if it was active before
        if (_focusNode.hasFocus) {
          // Schedule a microtask to ensure focus is restored after the build
          Future.microtask(() => _focusNode.requestFocus());
        }
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel(); // Important: Cancel timer when disposed
    _controller.dispose();
    _focusNode.dispose(); // Dispose the focus node
    super.dispose();
  }

  void _applyFilter(String value) {
    // Cancel any existing timer
    _debounceTimer?.cancel();

    // Store the current value locally
    final String currentText = value;

    // Start a new timer
    _debounceTimer = Timer(_debounceDuration, () {
      if (!mounted) return;

      final productBloc = BlocProvider.of<ProductBloc>(context);

      // Get lowercase column name for comparison
      final String columnLower = widget.columnName.toLowerCase();

      // For name and category1 filtering, preserve spaces exactly as typed
      final String processedValue =
          (columnLower == 'name' || columnLower == 'category1')
              ? currentText.replaceAll('LIKE:', '') // Only remove LIKE: prefix
              : currentText.trim(); // For other columns, just trim

      // Add special handling for name and category1 columns to support partial matching
      if (columnLower == 'name' || columnLower == 'category1') {
        print(
          'Adding ${columnLower} filter with LIKE query: "$processedValue"',
        );
        productBloc.add(
          FilterProductsByColumn(
            column: columnLower,
            value: processedValue,
            page: 1,
            pageSize: widget.pageSize,
            filterType: 'like', // Use LIKE query for partial matching
          ),
        );
      } else {
        productBloc.add(
          FilterProductsByColumn(
            column: columnLower,
            value: processedValue,
            page: 1,
            pageSize: widget.pageSize,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show different hint text based on column type
    final String hintText =
        widget.hintText ??
        (widget.columnName.toLowerCase() == 'id' ? "1,2,3..." : "Filter");

    return Container(
      width: widget.width, // Use customizable width
      height: widget.height, // Use customizable height
      margin: const EdgeInsets.only(top: 4),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode, // Set the focus node
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 6,
          ),
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: widget.width > 60 ? 12 : 10,
            color: Colors.grey,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Theme.of(context).primaryColor),
          ),
        ),
        style: TextStyle(fontSize: widget.width > 60 ? 13 : 11),
        onChanged: _applyFilter,
      ),
    );
  }
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

  // Sorting state
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Replace the isAddingNewProduct flag with the AddProductManager
  late AddProductManager _addProductManager;

  // Add a Set to track product IDs with update errors
  final Set<int> _productsWithErrors = {};

  // Table configuration based on screen size
  late ProductTableConfig _tableConfig;

  // Column visibility manager
  late col_manager.ColumnVisibilityManager _columnVisibilityManager;

  // Table dimensions manager
  late TableDimensionsManager _dimensionsManager;

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
    'Production', // Add new column title
    'Matching Words',
    'Actions',
  ];

  @override
  void initState() {
    super.initState();
    _tableConfig = DesktopTableConfig(); // Default to desktop
    _initializeColumnWidths();

    // Initialize the column visibility manager
    _columnVisibilityManager = col_manager.ColumnVisibilityManager(
      columnTitles: _titles,
      prefsKey: 'product_table_column_visibility',
    );

    // Initialize the dimensions manager
    _dimensionsManager = TableDimensionsManager(
      prefsKey: 'product_table_dimensions',
      initialColumnWidths: _columnWidths,
      defaultRowHeight: _tableConfig.getRowHeight(),
    );

    // Load any saved column visibility preferences with setState callback
    _columnVisibilityManager.loadSavedPreferences().then((_) {
      if (mounted) setState(() {});
    });

    // Load any saved dimensions with setState callback
    _dimensionsManager.loadSavedDimensions(
      onComplete: () {
        if (mounted) {
          setState(() {
            _rowHeight = _dimensionsManager.getRowHeight();
            // Update column widths with saved values
            for (int i = 0; i < _columnWidths.length; i++) {
              _columnWidths[i] = _dimensionsManager.getColumnWidth(i);
            }
          });
        }
      },
    );

    // Initialize the AddProductManager with onStateChanged parameter
    _addProductManager = AddProductManager(
      editManager: _editManager,
      scrollController: _verticalScrollController,
      onProductCreated: (product) {
        setState(() {
          widget.products.insert(0, product);
        });
      },
      onStateChanged: (callback) {
        setState(callback);
      },
    );
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
      color: Colors.blueGrey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add a row containing buttons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SyncProductsButton(
                      onSyncCompleted: () {
                        // Refresh the product list by dispatching an event to the bloc
                        final productBloc = BlocProvider.of<ProductBloc>(
                          context,
                        );
                        productBloc.add(
                          RefreshCurrentPage(
                            currentPage: widget.currentPage,
                            pageSize: widget.pageSize,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    // Replace the Add Product button with the one from the manager
                    _addProductManager.buildAddProductButton(),
                  ],
                ),
                RefreshButton(
                  currentPage: widget.currentPage,
                  pageSize: widget.pageSize,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Add chips for hidden columns
          _columnVisibilityManager.buildHiddenColumnsSection(
            context,
            (columnIndex) => setState(() {
              _columnVisibilityManager.toggleColumnVisibility(columnIndex);
            }),
          ),

          const Divider(height: 1),

          // Header table with filters and column hide options
          Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: _columnVisibilityManager.getVisibleColumnWidths(
              _columnWidths,
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              _columnVisibilityManager.buildTableRow(
                decoration: BoxDecoration(color: Colors.blueGrey.shade100),
                allColumnIndices: List.generate(_titles.length, (i) => i),
                cellBuilder:
                    (i) => _buildColumnHeader(
                      _titles[i],
                      i,
                      _tableConfig.getTextStyle().copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: _isMobileView ? 11.0 : 13.0,
                      ),
                    ),
              ),
            ],
          ),

          // Content area changes based on state
          Expanded(
            child:
                widget.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (_addProductManager.isAddingNewProduct ||
                        widget.products.isNotEmpty)
                    ? SingleChildScrollView(
                      controller: _verticalScrollController,
                      scrollDirection: Axis.vertical,
                      child: _buildTableWithNewRow(),
                    )
                    : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No products found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search or filter criteria',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('Add New Product'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed:
                                () => setState(() {
                                  _addProductManager.startAddingNewProduct();
                                }),
                          ),
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  // Sort products based on column index
  void _sortProducts(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }

      widget.products.sort((a, b) {
        int result = 0;

        switch (columnIndex) {
          case 0: // ID
            result = a.id.compareTo(b.id);
            break;
          case 1: // Created At
            result = a.createdAt.compareTo(b.createdAt);
            break;
          case 2: // Updated At
            result = (a.updatedAt ?? DateTime(1970)).compareTo(
              b.updatedAt ?? DateTime(1970),
            );
            break;
          case 4: // Product Name
            result = a.name.compareTo(b.name);
            break;
          case 5: // Price (by discount amount: old_price - current_price)
            result = a.discountAmount.compareTo(b.discountAmount);
            break;
          case 6: // Description
            result = (a.description ?? '').compareTo(b.description ?? '');
            break;
          case 7: // Discount
            result = (a.discount ?? 0).compareTo(b.discount ?? 0);
            break;
          case 8: // Category 1
            result = (a.category1 ?? '').compareTo(b.category1 ?? '');
            break;
          case 9: // Category 2
            result = (a.category2 ?? '').compareTo(b.category2 ?? '');
            break;
          case 10: // Popular
            result = a.popularProduct ? 1 : 0;
            result = result.compareTo(b.popularProduct ? 1 : 0);
            break;
          case 11: // Production
            result = a.production ? 1 : 0;
            result = result.compareTo(b.production ? 1 : 0);
            break;
          case 12: // Matching Words
            result = (a.matchingWords ?? '').compareTo(b.matchingWords ?? '');
            break;
          default:
            result = 0;
        }

        return _sortAscending ? result : -result;
      });
    });
  }

  // Modify the _buildTableWithNewRow method to use the column visibility manager
  Widget _buildTableWithNewRow() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: _columnVisibilityManager.getVisibleColumnWidths(
        _columnWidths,
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Add new product row if in add mode
        if (_addProductManager.isAddingNewProduct)
          _columnVisibilityManager.buildTableRow(
            decoration: const BoxDecoration(color: Colors.white),
            allColumnIndices: List.generate(_columnWidths.length, (i) => i),
            cellBuilder:
                (i) => SizedBox(
                  height: _rowHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 12.0,
                    ),
                    child: _addProductManager.buildNewProductCell(
                      context,
                      i, // Use original column index
                      _tableConfig.getTextStyle(),
                    ),
                  ),
                ),
          ),

        // Existing products
        for (int index = 0; index < widget.products.length; index++)
          _columnVisibilityManager.buildTableRow(
            decoration: BoxDecoration(
              color: _getRowColor(widget.products[index].id),
            ),
            allColumnIndices: List.generate(_columnWidths.length, (i) => i),
            cellBuilder:
                (i) => SizedBox(
                  height: _rowHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 12.0,
                    ),
                    child: _buildCell(widget.products[index], i, _isMobileView),
                  ),
                ),
          ),
      ],
    );
  }

  // Add a helper method to determine row color based on state
  Color _getRowColor(int productId) {
    if (_editManager.editingProduct?.id == productId) {
      return Colors.white; // Editing state
    } else if (_productsWithErrors.contains(productId)) {
      return const Color(0xFFFFCDD2); // Light red for error state
    } else {
      return const Color(0xFFE8F5E9); // Default green
    }
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
        return _buildProductThumbnail(product);
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
        return _buildProductionCell(product, isEditing); // Add production cell
      case 12:
        return _buildMatchingWordsCell(
          product,
          columnIndex,
          isEditing,
          isMobile,
          textStyle,
        );
      case 13: // Shifted one index
        return _buildActionsCell(product, isEditing, isMobile);
      default:
        return const SizedBox();
    }
  }

  // Add new build method for production cell
  Widget _buildProductionCell(Product product, bool isEditing) {
    if (isEditing) {
      return _editManager.buildEditableProductionCell((value) {
        setState(() {
          _editManager.editProduction = value ?? false;
        });
      });
    } else {
      return product.production
          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
          : const SelectableText('-');
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
    if (isEditing) {
      return _editManager.buildEditablePriceCell();
    } else {
      // Parse the JSON string to get the number of price elements
      List<dynamic> priceList = [];
      try {
        priceList = jsonDecode(product.uPrices);
      } catch (e) {
        print('Error parsing uPrices JSON: $e');
        // Fallback to showing the raw string if JSON parsing fails
        return SelectableText(product.uPrices, style: style);
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(product.uPrices, style: style),
              const SizedBox(height: 4),
              Wrap(
                spacing: 2,
                runSpacing: 2,
                children: _buildPriceButtons(priceList, product),
              ),
            ],
          );

          final hasFixedHeight =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite;

          if (!hasFixedHeight) {
            return content;
          }

          return ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: content,
              ),
            ),
          );
        },
      );
    }
  }

  List<Widget> _buildPriceButtons(List<dynamic> priceList, Product product) {
    // Check if ANY element in the priceList has global_stock
    bool hasGlobalStock = false;
    int globalStockValue = 0;
    Map<String, dynamic>? globalStockItem;

    for (var priceItem in priceList) {
      if (priceItem is Map<String, dynamic>) {
        if (priceItem.containsKey('global_stock') &&
            priceItem['global_stock'] != null) {
          // If global_stock exists (even if it's "0"), show single button
          int stockValue =
              int.tryParse(priceItem['global_stock'].toString()) ?? 0;
          hasGlobalStock = true;
          globalStockValue = stockValue;
          globalStockItem = priceItem;
          break; // Found global stock, no need to continue
        }
      }
    }

    // If any element has global_stock, show only one button
    if (hasGlobalStock && globalStockItem != null) {
      final stockItem = globalStockItem; // We checked for null above
      final price = stockItem['price'] ?? '';
      final unit = stockItem['unit'] ?? '';
      final priceItemId = stockItem['id'];
      final hasId = priceItemId != null && priceItemId.toString().isNotEmpty;

      return [
        ElevatedButton(
          onPressed: () async {
            if (priceItemId == null || priceItemId.toString().isEmpty) {
              // Show message to user that ID is required
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.warning,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cannot open product details: This price element needs an ID. Please edit the product and add an ID to the uPrices element.',
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.orange.shade600,
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: 'Edit Product',
                      textColor: Colors.white,
                      onPressed: () {
                        _startEditing(product);
                      },
                    ),
                  ),
                );
              }
              return;
            }

            // Handle global stock button click
            await ProductDetailsButtonHandler.handlePriceButtonClick(
              context: context,
              productId: product.id,
              productName: product.name,
              priceItem: stockItem,
              priceIndex: 0, // Use 0 since we're showing only one button
              onStockTypeAdded: () {
                final productBloc = BlocProvider.of<ProductBloc>(context);
                productBloc.add(
                  UpdateProductStock(
                    productId: product.id,
                    uPriceId: priceItemId.toString(),
                  ),
                );
              },
              onDataFetched: (List<ProductDetails> productDetailsList) {
                ProductDetailsButtonHandler.showProductDetailsDialog(
                  context: context,
                  productName: product.name,
                  compositeId: ProductDetailsService.generateCompositeId(
                    product.id,
                    priceItemId.toString(),
                  ),
                  productDetailsList: productDetailsList,
                  onStockUpdated: () {
                    final productBloc = BlocProvider.of<ProductBloc>(context);
                    productBloc.add(
                      UpdateProductStock(
                        productId: product.id,
                        uPriceId: priceItemId.toString(),
                      ),
                    );
                  },
                );
              },
              onError: (String error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error), backgroundColor: Colors.red),
                  );
                }
              },
            );
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(40, 20),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            backgroundColor: Colors.green.shade100,
            side: BorderSide(color: Colors.green.shade300, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!hasId) ...[
                Icon(Icons.warning, size: 10, color: Colors.red.shade800),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$price/$unit',
                      style: TextStyle(
                        fontSize: 9,
                        color:
                            !hasId
                                ? Colors.red.shade800
                                : Colors.green.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Global: $globalStockValue',
                      style: TextStyle(
                        fontSize: 7,
                        color:
                            !hasId
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ];
    }

    // If no global stock found, create buttons for all price items (original behavior)
    return List.generate(priceList.length, (index) {
      final priceItem = priceList[index];
      final price = priceItem['price'] ?? '';
      final unit = priceItem['unit'] ?? '';
      final oldPrice = priceItem['old_price'];
      final priceItemId = priceItem['id'];
      final hasId = priceItemId != null && priceItemId.toString().isNotEmpty;

      // Get stock information for display - check all stock types
      String stockText = '';
      if (priceItem.containsKey('sole_stock') &&
          priceItem['sole_stock'] != null &&
          priceItem['sole_stock'].toString().isNotEmpty) {
        stockText = ' (Sole: ${priceItem['sole_stock']})';
      } else if (priceItem.containsKey('stock') &&
          priceItem['stock'] != null &&
          priceItem['stock'].toString().isNotEmpty) {
        stockText = ' (Stock: ${priceItem['stock']})';
      }

      return ElevatedButton(
        onPressed: () async {
          if (priceItemId == null || priceItemId.toString().isEmpty) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cannot open product details: This price element needs an ID. Please edit the product and add an ID to the uPrices element.',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.orange.shade600,
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'Edit Product',
                    textColor: Colors.white,
                    onPressed: () {
                      _startEditing(product);
                    },
                  ),
                ),
              );
            }
            return;
          }

          await ProductDetailsButtonHandler.handlePriceButtonClick(
            context: context,
            productId: product.id,
            productName: product.name,
            priceItem: priceItem,
            priceIndex: index,
            onStockTypeAdded: () {
              final productBloc = BlocProvider.of<ProductBloc>(context);
              productBloc.add(
                UpdateProductStock(
                  productId: product.id,
                  uPriceId: priceItemId.toString(),
                ),
              );
            },
            onDataFetched: (List<ProductDetails> productDetailsList) {
              ProductDetailsButtonHandler.showProductDetailsDialog(
                context: context,
                productName: product.name,
                compositeId: ProductDetailsService.generateCompositeId(
                  product.id,
                  priceItemId.toString(),
                ),
                productDetailsList: productDetailsList,
                onStockUpdated: () {
                  final productBloc = BlocProvider.of<ProductBloc>(context);
                  productBloc.add(
                    UpdateProductStock(
                      productId: product.id,
                      uPriceId: priceItemId.toString(),
                    ),
                  );
                },
              );
            },
            onError: (String error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.red),
                );
              }
            },
          );
        },
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(40, 20),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          backgroundColor:
              !hasId
                  ? Colors.red.shade300
                  : oldPrice != null
                  ? Colors.orange
                  : null,
          side:
              !hasId ? BorderSide(color: Colors.red.shade700, width: 1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!hasId) ...[
              Icon(Icons.warning, size: 10, color: Colors.red.shade800),
              const SizedBox(width: 2),
            ],
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$price/$unit',
                    style: TextStyle(
                      fontSize: 9,
                      color: !hasId ? Colors.red.shade800 : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (stockText.isNotEmpty)
                    Text(
                      stockText,
                      style: TextStyle(
                        fontSize: 7,
                        color:
                            !hasId
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    });
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
      return ProductValidators.buildEditableCategoryCell(
        context,
        isCategory1
            ? _editManager.category1Controller
            : _editManager.category2Controller,
        isCategory1 ? "Category 1" : "Category 2",
        (callback) => setState(callback),
      );
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
        onCopy: _copyProduct,
      );
    }
  }

  // MARK: - Image Handling

  Widget _buildProductThumbnail(Product product) {
    final GlobalKey imageKey = GlobalKey();
    OverlayEntry? overlayEntry;
    final String? imageUrl = product.image;
    bool isHovering = false;

    // Check if this product is currently being edited
    final bool isBeingEdited = _editManager.editingProduct?.id == product.id;

    void showEnlargedImage() {
      // Don't show enlarged image if the product is in edit mode
      if (imageUrl == null || isBeingEdited) return;

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
                child: ProductImageEditor.buildCachedImage(
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

    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) {
            setState(() => isHovering = true);
            showEnlargedImage();
          },
          onExit: (_) {
            setState(() => isHovering = false);
            hideEnlargedImage();
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              ProductImageEditor.buildCachedImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: 40,
                height: 40,
                imageKey: imageKey,
              ),
              if (isHovering &&
                  isBeingEdited) // Only show edit button when product is in edit mode
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        hideEnlargedImage();
                        _editProductImage(product);
                      },
                      tooltip: 'Edit product image',
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              // Copy URL button - permanently visible when NOT in edit mode and has image URL
              if (!isBeingEdited && imageUrl != null && imageUrl.isNotEmpty)
                Positioned(
                  top: 2,
                  left: 2,
                  child: Tooltip(
                    message: 'Copy image URL',
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          _copyImageUrlToClipboard(imageUrl, product.name);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.content_copy,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _editProductImage(Product product) {
    ProductImageEditor.showEditDialog(context, product, _saveImageUrl);
  }

  // Helper method to copy image URL to clipboard
  Future<void> _copyImageUrlToClipboard(
    String imageUrl,
    String productName,
  ) async {
    try {
      await Clipboard.setData(ClipboardData(text: imageUrl));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Image URL copied to clipboard for: $productName',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('Failed to copy URL to clipboard'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Helper method to save the image URL
  void _saveImageUrl(Product product, String newUrl) {
    // Create an updated product with the new image URL
    final updatedProduct = Product(
      id: product.id,
      name: product.name,
      uPrices: product.uPrices,
      discount: product.discount,
      description: product.description,
      category1: product.category1,
      category2: product.category2,
      popularProduct: product.popularProduct,
      matchingWords: product.matchingWords,
      createdAt: product.createdAt,
      updatedAt: DateTime.now(),
      image: newUrl, // Update with new URL
    );

    // For immediate visual feedback, update the local state
    setState(() {
      // Find the product in the list and update its image URL
      final index = widget.products.indexWhere((p) => p.id == product.id);
      if (index >= 0) {
        // This modifies the list in place for immediate visual feedback
        widget.products[index] = updatedProduct;
      }

      // If this is the product currently being edited, update the controller too
      if (_editManager.editingProduct?.id == product.id) {
        _editManager.imageUrlController.text = newUrl;
      }
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updated image for: ${product.name}')),
    );
  }

  // MARK: - Event Handlers

  void _startEditing(Product product) {
    // First check if we're adding a new product and cancel that operation
    _addProductManager.checkAndCancelAddNewProduct();

    setState(() {
      _editManager.startEditing(product);
    });
  }

  void _cancelEditing() {
    setState(() {
      _editManager.cancelEditing();
    });
  }

  void _copyProduct(Product product) {
    // First check if we're currently editing and cancel that operation
    if (_editManager.editingProduct != null) {
      _editManager.cancelEditing();
    }

    // Cancel any pending add operation
    _addProductManager.checkAndCancelAddNewProduct();

    // Start adding a new product based on the copied product
    setState(() {
      _addProductManager.isAddingNewProduct = true;

      // Populate the form with copied product data
      _editManager.nameController.text = '${product.name} (Copy)';
      _editManager.priceController.text = product.uPrices.toString();
      _editManager.descriptionController.text = product.description ?? '';
      _editManager.discountController.text = product.discount?.toString() ?? '';
      _editManager.category1Controller.text = product.category1 ?? '';
      _editManager.category2Controller.text = product.category2 ?? '';
      _editManager.matchingWordsController.text = product.matchingWords ?? '';
      _editManager.imageUrlController.text = product.image ?? '';
      _editManager.editPopular = product.popularProduct;
      _editManager.editProduction = product.production;
    });

    // Scroll to top to see the new row
    if (_verticalScrollController.hasClients) {
      _verticalScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // Show confirmation message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Product copied: ${product.name}. You can now edit and save it.',
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _saveChanges() async {
    final originalProduct = _editManager.editingProduct!;

    // Prepare values for validation
    String priceValue = _editManager.priceController.text.trim();
    if (priceValue.isEmpty) {
      priceValue = '0'; // Default value
    }

    // Validate all product fields
    final validationResult = ProductValidators.validateProduct(
      price: priceValue,
      discount:
          _editManager.discountController.text.isNotEmpty
              ? _editManager.discountController.text
              : null,
      category1:
          _editManager.category1Controller.text.isNotEmpty
              ? _editManager.category1Controller.text
              : null,
      category2:
          _editManager.category2Controller.text.isNotEmpty
              ? _editManager.category2Controller.text
              : null,
      name: _editManager.nameController.text.trim(),
      description: _editManager.descriptionController.text.trim(),
      image: _editManager.imageUrlController.text.trim(),
    );

    // Show error and return if validation failed
    if (!validationResult.isValid) {
      ProductValidators.showValidationError(context, validationResult);
      return;
    }

    // Check internet connectivity BEFORE saving locally
    final hasConnection = await ConnectivityHelper.hasInternetConnection();

    if (!hasConnection) {
      // Show connectivity error with options
      _showConnectivityOptionsDialog(originalProduct, priceValue);
      return;
    }

    // If we have connection, proceed with save and sync
    await _proceedWithSave(originalProduct, priceValue);
  }

  // Show dialog with options when no internet connection
  void _showConnectivityOptionsDialog(
    Product originalProduct,
    String priceValue,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.orange),
              SizedBox(width: 8),
              Text('No Internet Connection'),
            ],
          ),
          content: const Text(
            'Unable to sync changes to cloud. You can:\n\n'
            '• Try again when internet is available\n'
            '• Save locally only (changes won\'t sync to cloud until connected)',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Keep in edit mode - don't cancel editing
              },
              child: const Text('Try Again Later'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Retry connectivity check
                _saveChanges();
              },
              child: const Text('Retry Now'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Save locally without cloud sync
                _proceedWithLocalSaveOnly(originalProduct, priceValue);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Locally Only'),
            ),
          ],
        );
      },
    );
  }

  // Proceed with save and sync (when internet is available)
  Future<void> _proceedWithSave(
    Product originalProduct,
    String priceValue,
  ) async {
    final updatedProduct = _buildUpdatedProduct(originalProduct, priceValue);

    // Update the product in the products list for UI refresh
    final index = widget.products.indexWhere((p) => p.id == originalProduct.id);
    if (index >= 0) {
      setState(() {
        widget.products[index] = updatedProduct;
      });
    }

    // Update product in the local database
    final LocalDatabase localDB = LocalDatabase();
    try {
      final success = await localDB.updateProduct(updatedProduct);

      if (success) {
        // Sync to Supabase since we know we have internet
        _updateToSupabase(updatedProduct);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved and synced: ${updatedProduct.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save changes to database'),
            backgroundColor: Colors.red,
          ),
        );
        return; // Don't exit edit mode if save failed
      }
    } catch (e) {
      print('Error updating product in database: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating database: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return; // Don't exit edit mode if save failed
    }

    // Only exit edit mode if everything succeeded
    setState(() {
      _editManager.cancelEditing();
    });
  }

  // Save locally only (when user chooses to save without internet)
  Future<void> _proceedWithLocalSaveOnly(
    Product originalProduct,
    String priceValue,
  ) async {
    final updatedProduct = _buildUpdatedProduct(originalProduct, priceValue);

    // Update the product in the products list for UI refresh
    final index = widget.products.indexWhere((p) => p.id == originalProduct.id);
    if (index >= 0) {
      setState(() {
        widget.products[index] = updatedProduct;
        // Add this product to error tracking to show sync needed
        _productsWithErrors.add(updatedProduct.id);
      });
    }

    // Update product in the local database only
    final LocalDatabase localDB = LocalDatabase();
    try {
      final success = await localDB.updateProduct(updatedProduct);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved locally: ${updatedProduct.name} (will sync when connected)',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save changes to database'),
            backgroundColor: Colors.red,
          ),
        );
        return; // Don't exit edit mode if save failed
      }
    } catch (e) {
      print('Error updating product in database: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating database: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return; // Don't exit edit mode if save failed
    }

    // Exit edit mode since local save succeeded
    setState(() {
      _editManager.cancelEditing();
    });
  }

  // Helper method to build updated product
  Product _buildUpdatedProduct(Product originalProduct, String priceValue) {
    return Product(
      id: originalProduct.id,
      name: _editManager.nameController.text.trim(),
      uPrices: priceValue,
      description: _editManager.descriptionController.text.trim(),
      discount:
          _editManager.discountController.text.isNotEmpty
              ? int.tryParse(_editManager.discountController.text)
              : null,
      category1:
          _editManager.category1Controller.text.isNotEmpty
              ? _editManager.category1Controller.text
              : null,
      category2:
          _editManager.category2Controller.text.isNotEmpty
              ? _editManager.category2Controller.text
              : null,
      popularProduct: _editManager.editPopular,
      production: _editManager.editProduction,
      matchingWords:
          _editManager.matchingWordsController.text.isNotEmpty
              ? _editManager.matchingWordsController.text
              : null,
      image: _editManager.imageUrlController.text.trim(),
      createdAt: originalProduct.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Update the Supabase update method to track errors
  void _updateToSupabase(Product updatedProduct) {
    // Create Supabase repository instance
    final SupabaseProductRepository supabaseRepo = SupabaseProductRepository();

    // Convert Product model to SupabaseProduct model
    final supabaseProduct = SupabaseProduct(
      id: updatedProduct.id,
      createdAt: updatedProduct.createdAt,
      updatedAt: updatedProduct.updatedAt,
      name: updatedProduct.name,
      uPrices: updatedProduct.uPrices,
      image: updatedProduct.image,
      discount: updatedProduct.discount,
      description: updatedProduct.description,
      category1: updatedProduct.category1,
      category2: updatedProduct.category2,
      popularProduct: updatedProduct.popularProduct,
      matchingWords: updatedProduct.matchingWords,
      production: updatedProduct.production, // Include the production field
    );

    // Update in Supabase
    supabaseRepo
        .updateProduct(supabaseProduct)
        .then((updatedSupabaseProduct) {
          print('Product successfully updated in Supabase');
          // Log the updated values for debugging
          print(
            'Updated values in Supabase: production=${updatedSupabaseProduct.production}',
          );

          // Remove this product from error tracking if it was there
          setState(() {
            _productsWithErrors.remove(updatedProduct.id);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Synced to Supabase: ${updatedProduct.name}'),
              backgroundColor: Colors.green,
            ),
          );
        })
        .catchError((error) {
          print('Error updating product in Supabase: $error');

          // Add this product to error tracking
          setState(() {
            _productsWithErrors.add(updatedProduct.id);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sync to Supabase: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
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
        // First, remove the product from the local UI list
        setState(() {
          widget.products.removeWhere((p) => p.id == product.id);
        });

        // Then, delete from the local database
        _deleteProductFromDatabase(product);

        // Also attempt to delete from Supabase if needed
        _deleteProductFromSupabase(product);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted: ${product.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  // Helper method to delete from local database
  void _deleteProductFromDatabase(Product product) {
    final LocalDatabase localDB = LocalDatabase();
    try {
      localDB.deleteProduct(product.id).then((success) {
        if (!success) {
          print('Failed to delete product from local database: ${product.id}');
        }
      });
    } catch (e) {
      print('Error deleting product from database: $e');
    }
  }

  // Helper method to delete from Supabase
  void _deleteProductFromSupabase(Product product) {
    final SupabaseProductRepository supabaseRepo = SupabaseProductRepository();

    supabaseRepo
        .deleteProduct(product.id)
        .then((_) {
          print('Product successfully deleted from Supabase');
        })
        .catchError((error) {
          print('Error deleting product from Supabase: $error');

          // Add this product to error tracking
          setState(() {
            _productsWithErrors.add(product.id);
          });
        });
  }

  void _onPageChanged(int page) {
    final state = BlocProvider.of<ProductBloc>(context).state;
    if (state is ProductsLoaded && state.activeFilters.isNotEmpty) {
      BlocProvider.of<ProductBloc>(context).add(
        FilterProductsByColumn(
          column:
              'id', // This doesn't matter here as we're preserving all filters
          value: '', // This doesn't matter here as we're preserving all filters
          page: page,
          pageSize: widget.pageSize,
        ),
      );
    } else {
      widget.onPageChanged(page);
    }
  }

  // Header column builder with resize capability
  Widget _buildColumnHeader(String title, int index, TextStyle style) {
    // Get active filters from the BLoC state
    Map<String, String> activeFilters = {};
    final state = BlocProvider.of<ProductBloc>(context).state;
    if (state is ProductsLoaded) {
      activeFilters = state.activeFilters;
    }

    // Add filter input to the ID column (index 0), the Product name column (index 4), and Category 1 column (index 8)
    Widget? filterWidget;
    if (index == 0) {
      filterWidget = ColumnFilterInput(
        columnName: 'id',
        currentPage: widget.currentPage,
        pageSize: widget.pageSize,
        activeFilters: activeFilters,
      );
    } else if (index == 4) {
      filterWidget = ColumnFilterInput(
        columnName: 'name',
        currentPage: widget.currentPage,
        pageSize: widget.pageSize,
        activeFilters: activeFilters,
        width: 120, // Larger width for product name filter
        height: 30, // Adjust height if needed
        hintText: "Search by name", // Custom hint text
      );
    } else if (index == 8) {
      filterWidget = ColumnFilterInput(
        columnName: 'category1',
        currentPage: widget.currentPage,
        pageSize: widget.pageSize,
        activeFilters: activeFilters,
        width: 100, // Width for category filter
        height: 30, // Adjust height if needed
        hintText: "Filter category", // Custom hint text
      );
    }

    return Stack(
      children: [
        Container(
          height: _rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Use the visibility manager to build header with hide option
              _columnVisibilityManager.buildColumnHeaderWithVisibilityToggle(
                title: title,
                index: index,
                style: style,
                onToggle:
                    (columnIndex) => setState(() {
                      _columnVisibilityManager.toggleColumnVisibility(
                        columnIndex,
                      );
                    }),
                filterWidget: filterWidget,
                onSort: () => _sortProducts(index),
                isCurrentSortColumn: _sortColumnIndex == index,
                sortAscending: _sortAscending,
              ),
              if (filterWidget != null) filterWidget,
            ],
          ),
        ),

        // Keep existing resize handlers
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
                  // Save column width to database
                  _tableConfig.updateColumnWidth(
                    index,
                    _columnWidths[index],
                    _dimensionsManager,
                  );
                });
              },
              onVerticalDragUpdate: (d) {
                setState(() {
                  _rowHeight = (_rowHeight + d.delta.dy).clamp(40.0, 200.0);
                  // Save row height to database
                  _tableConfig.updateRowHeight(_rowHeight, _dimensionsManager);
                });
              },
              child: Container(width: 10, color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }
}
