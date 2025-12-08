import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/local_database.dart';
import 'product.dart';

// MARK: - Column Visibility Manager

/// Manages the visibility of table columns
class ColumnVisibilityManager {
  /// Column titles for reference
  final List<String> columnTitles;

  /// Key for storing preferences in database
  final String? prefsKey;

  /// Local database instance for persistence
  final LocalDatabase _localDatabase = LocalDatabase();

  final Set<int> _hiddenColumns = <int>{};

  /// Create a new column visibility manager
  ColumnVisibilityManager({required this.columnTitles, this.prefsKey});

  /// Check if a column is visible
  bool isColumnVisible(int columnIndex) =>
      !_hiddenColumns.contains(columnIndex);

  /// Toggle the visibility of a column
  void toggleColumnVisibility(int columnIndex) {
    print('[COLUMN_PREFS] toggleColumnVisibility called for column $columnIndex');
    print('[COLUMN_PREFS] Stack trace: ${StackTrace.current}');
    if (_hiddenColumns.contains(columnIndex)) {
      _hiddenColumns.remove(columnIndex);
      print('[COLUMN_PREFS] Showing column $columnIndex');
    } else {
      _hiddenColumns.add(columnIndex);
      print('[COLUMN_PREFS] Hiding column $columnIndex');
    }
    if (prefsKey != null) {
      _savePreferences();
    }
  }

  /// Get list of visible columns
  List<int> getVisibleColumnIndices() {
    return List.generate(
      columnTitles.length,
      (i) => i,
    ).where((i) => isColumnVisible(i)).toList();
  }

  /// Get visible column widths
  Map<int, TableColumnWidth> getVisibleColumnWidths(
    List<double> allColumnWidths,
  ) {
    final Map<int, TableColumnWidth> visibleWidths = {};
    int visibleIndex = 0;

    for (int i = 0; i < allColumnWidths.length; i++) {
      if (isColumnVisible(i)) {
        visibleWidths[visibleIndex++] = FixedColumnWidth(allColumnWidths[i]);
      }
    }

    return visibleWidths;
  }

  /// Create TableRow with only visible cells
  TableRow buildTableRow({
    required BoxDecoration decoration,
    required List<int> allColumnIndices,
    required Widget Function(int) cellBuilder,
  }) {
    List<Widget> cells = [];

    for (int i in allColumnIndices) {
      if (isColumnVisible(i)) {
        cells.add(cellBuilder(i));
      }
    }

    return TableRow(decoration: decoration, children: cells);
  }

  /// Build column header with visibility toggle option
  Widget buildColumnHeaderWithVisibilityToggle({
    required String title,
    required int index,
    required TextStyle style,
    required Function(int) onToggle,
    Widget? filterWidget,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(title, style: style, overflow: TextOverflow.ellipsis),
        ),
        GestureDetector(
          onTap: () => onToggle(index),
          child: Tooltip(
            message: "Hide column",
            child: const Icon(
              Icons.visibility_off,
              size: 16,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  /// Build hidden columns section with SQLite persistence status
  Widget buildHiddenColumnsSection(
    BuildContext context,
    void Function(int) onShowColumn,
  ) {
    if (_hiddenColumns.isEmpty) {
      return Container(); // No hidden columns, don't show section
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Hidden Columns:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.storage, size: 14),
              const SizedBox(width: 4),
              Text(
                'Auto-saved',
                style: TextStyle(fontSize: 12, color: Colors.green.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children:
                _hiddenColumns.map((index) {
                  return InputChip(
                    label: Text(
                      columnTitles[index],
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => onShowColumn(index),
                    deleteIcon: const Icon(Icons.visibility, size: 16),
                    onDeleted: () => onShowColumn(index),
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.1),
                    deleteIconColor: Theme.of(context).primaryColor,
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  /// Load saved preferences from SQLite database
  Future<void> loadSavedPreferences({VoidCallback? onComplete}) async {
    if (prefsKey == null) return;

    try {
      final List<int> hiddenIndices = await _localDatabase.loadColumnVisibility(
        prefsKey!,
      );

      _hiddenColumns.clear();
      _hiddenColumns.addAll(
        hiddenIndices.where((i) => i >= 0 && i < columnTitles.length),
      );

      // Call the callback if provided to refresh UI
      if (onComplete != null) {
        onComplete();
      }
    } catch (e) {
      // Silently fall back to SharedPreferences if database fails
      _loadFromSharedPreferences(onComplete: onComplete);
    }
  }

  /// Save preferences to SQLite database
  Future<void> _savePreferences() async {
    print('[COLUMN_PREFS] _savePreferences called, prefsKey: $prefsKey');
    if (prefsKey == null) {
      print('[COLUMN_PREFS] prefsKey is null, returning');
      return;
    }

    try {
      print(
        '[COLUMN_PREFS] Saving visibility for ${_hiddenColumns.length} hidden columns',
      );
      await _localDatabase.saveColumnVisibility(
        prefsKey!,
        _hiddenColumns.toList(),
      );
      print('[COLUMN_PREFS] Column visibility saved successfully');
    } catch (e, stackTrace) {
      print('Error saving column visibility preferences: $e');
      print('Stack trace: $stackTrace');
      // Fall back to SharedPreferences if database fails
      try {
        await _saveToSharedPreferences();
        print('[COLUMN_PREFS] Saved to SharedPreferences as fallback');
      } catch (fallbackError) {
        print('Error with SharedPreferences fallback: $fallbackError');
      }
    }
  }

  /// Legacy method to load from SharedPreferences as fallback
  Future<void> _loadFromSharedPreferences({VoidCallback? onComplete}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? hiddenIndices = prefs.getStringList(prefsKey!);

      if (hiddenIndices != null) {
        _hiddenColumns.clear();
        _hiddenColumns.addAll(
          hiddenIndices
              .map((s) => int.tryParse(s) ?? -1)
              .where((i) => i >= 0 && i < columnTitles.length),
        );

        // Call the callback if provided
        if (onComplete != null) {
          onComplete();
        }
      }
    } catch (e) {
      print('Error loading from SharedPreferences: $e');
    }
  }

  /// Legacy method to save to SharedPreferences as fallback
  Future<void> _saveToSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        prefsKey!,
        _hiddenColumns.map((i) => i.toString()).toList(),
      );
    } catch (e) {
      print('Error saving to SharedPreferences: $e');
    }
  }
}

/// Manages the table dimensions (column widths and row height)
class TableDimensionsManager {
  /// Key for storing preferences in database
  final String? prefsKey;

  /// Local database instance for persistence
  final LocalDatabase _localDatabase = LocalDatabase();

  /// Map of column indices to their widths
  final Map<int, double> _columnWidths = {};

  /// Current row height
  double _rowHeight;

  /// Default row height to use if no saved value
  final double _defaultRowHeight;

  TableDimensionsManager({
    required this.prefsKey,
    required List<double> initialColumnWidths,
    required double defaultRowHeight,
  }) : _rowHeight = defaultRowHeight,
       _defaultRowHeight = defaultRowHeight {
    // Initialize column widths with default values
    for (int i = 0; i < initialColumnWidths.length; i++) {
      _columnWidths[i] = initialColumnWidths[i];
    }
  }

  /// Get the current width for a column
  double getColumnWidth(int index) => _columnWidths[index] ?? 120.0;

  /// Get the current row height
  double getRowHeight() => _rowHeight;

  /// Set the width for a specific column and save to database
  void setColumnWidth(int index, double width) {
    // Enforce minimum width for Actions column (index 12)
    if (index == 12 && width < 150.0) {
      width = 150.0;
    }
    _columnWidths[index] = width;
    print('[COLUMN_PREFS] Saving column $index width: $width');
    if (prefsKey != null) {
      _saveColumnWidths();
    }
  }

  /// Set the row height and save to database
  void setRowHeight(double height) {
    _rowHeight = height;
    if (prefsKey != null) {
      _saveRowHeight();
    }
  }

  /// Get all column widths as a map
  Map<int, double> get columnWidths => Map.from(_columnWidths);

  /// Load saved dimensions from SQLite database
  Future<void> loadSavedDimensions({VoidCallback? onComplete}) async {
    if (prefsKey == null) return;

    bool needsUpdate = false;

    try {
      // Load column widths
      final savedWidths = await _localDatabase.loadColumnWidths(prefsKey!);
      if (savedWidths.isNotEmpty) {
        print(
          '[COLUMN_PREFS] Loaded ${savedWidths.length} saved column widths',
        );
        _columnWidths.addAll(savedWidths);
        needsUpdate = true;
      }

      // Load row height
      final savedHeight = await _localDatabase.loadRowHeight(prefsKey!);
      if (savedHeight != null) {
        print('[COLUMN_PREFS] Loaded saved row height: $savedHeight');
        _rowHeight = savedHeight;
        needsUpdate = true;
      }

      // Call the callback if provided and if there were changes
      if (needsUpdate && onComplete != null) {
        onComplete();
      }
    } catch (e) {
      print('Error loading table dimensions: $e');
    }
  }

  /// Save column widths to SQLite database
  Future<void> _saveColumnWidths() async {
    if (prefsKey == null) return;

    try {
      await _localDatabase.saveColumnWidths(prefsKey!, _columnWidths);
    } catch (e) {
      print('Error saving column widths: $e');
    }
  }

  /// Save row height to SQLite database
  Future<void> _saveRowHeight() async {
    if (prefsKey == null) return;

    try {
      await _localDatabase.saveRowHeight(prefsKey!, _rowHeight);
    } catch (e) {
      print('Error saving row height: $e');
    }
  }
}

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
    required Function(Product) onCopy,
  });
  Widget buildTable({
    required List<String> titles,
    required List<double> columnWidths,
    required double rowHeight,
    required ScrollController verticalScrollController,
    required Widget Function(String, int, TextStyle) buildColumnHeader,
    required Widget Function(bool) buildTableRows,
  });

  // Update column width in dimensions manager
  void updateColumnWidth(
    int columnIndex,
    double width,
    TableDimensionsManager dimensionsManager,
  ) {
    dimensionsManager.setColumnWidth(columnIndex, width);
  }

  // Update row height in dimensions manager
  void updateRowHeight(
    double height,
    TableDimensionsManager dimensionsManager,
  ) {
    dimensionsManager.setRowHeight(height);
  }
}

/// Mobile-specific implementation of product table
class MobileTableConfig implements ProductTableConfig {
  @override
  List<double> initializeColumnWidths() {
    List<double> columnWidths = List.filled(13, 120.0);

    // Set specific column widths for mobile
    columnWidths[0] = 50.0; // ID
    columnWidths[1] = 80.0; // Created At
    columnWidths[2] = 80.0; // Updated At
    columnWidths[3] = 50.0; // Image
    columnWidths[4] = 150.0; // Product name
    columnWidths[5] = 70.0; // Price
    columnWidths[6] = 150.0; // Description
    columnWidths[7] = 60.0; // Discount
    columnWidths[8] = 80.0; // Category 1
    columnWidths[9] = 80.0; // Category 2
    columnWidths[10] = 50.0; // Popular
    columnWidths[11] = 70.0; // Matching Words
    columnWidths[12] = 200.0; // Actions (increased for copy button)

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
    required Function(Product) onCopy,
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
          onTap: () => onCopy(product),
          size: 36,
          padding: 8,
          iconSize: 18,
          icon: Icons.copy,
          iconColor: Colors.blue,
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

  @override
  void updateColumnWidth(
    int columnIndex,
    double width,
    TableDimensionsManager dimensionsManager,
  ) {
    dimensionsManager.setColumnWidth(columnIndex, width);
  }

  @override
  void updateRowHeight(
    double height,
    TableDimensionsManager dimensionsManager,
  ) {
    dimensionsManager.setRowHeight(height);
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
    columnWidths[12] = 200.0; // Actions (increased for copy button)

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
    required Function(Product) onCopy,
  }) {
    return SizedBox(
      width: 180.0, // Force minimum width
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: SizedBox(
              width: 50,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 50, minHeight: 32),
                icon: const Icon(Icons.edit, size: 16),
                onPressed: () => onEdit(product),
                tooltip: 'Edit product',
              ),
            ),
          ),
          Flexible(
            child: SizedBox(
              width: 50,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 50, minHeight: 32),
                icon: const Icon(Icons.copy, size: 16, color: Colors.blue),
                onPressed: () => onCopy(product),
                tooltip: 'Copy product',
              ),
            ),
          ),
          Flexible(
            child: SizedBox(
              width: 50,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 50, minHeight: 32),
                icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                onPressed: () => onDelete(context, product),
                tooltip: 'Delete product',
              ),
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

  @override
  void updateColumnWidth(
    int columnIndex,
    double width,
    TableDimensionsManager dimensionsManager,
  ) {
    dimensionsManager.setColumnWidth(columnIndex, width);
  }

  @override
  void updateRowHeight(
    double height,
    TableDimensionsManager dimensionsManager,
  ) {
    dimensionsManager.setRowHeight(height);
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
        border: TableBorder.all(color: Colors.grey.shade300),
        columnWidths: columnWidths.asMap().map(
          (i, w) => MapEntry(i, FixedColumnWidth(w)),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.blueGrey.shade100),
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
