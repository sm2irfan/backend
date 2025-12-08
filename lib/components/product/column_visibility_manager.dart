import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the visibility of table columns
class ColumnVisibilityManager {
  /// Column titles for reference
  final List<String> columnTitles;

  /// Optional key for storing preferences
  final String? prefsKey;

  final Set<int> _hiddenColumns = <int>{};

  /// Create a new column visibility manager
  ColumnVisibilityManager({required this.columnTitles, this.prefsKey});

  /// Check if a column is visible
  bool isColumnVisible(int columnIndex) =>
      !_hiddenColumns.contains(columnIndex);

  /// Toggle the visibility of a column
  void toggleColumnVisibility(int columnIndex) {
    if (_hiddenColumns.contains(columnIndex)) {
      _hiddenColumns.remove(columnIndex);
    } else {
      _hiddenColumns.add(columnIndex);
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
    VoidCallback? onSort,
    bool? isSortable,
    bool? isCurrentSortColumn,
    bool? sortAscending,
  }) {
    // Check if this column is sortable (default sortable columns)
    final sortable =
        isSortable ?? [0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12].contains(index);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              // Make the title clickable for sorting if sortable
              if (sortable && onSort != null)
                Expanded(
                  child: GestureDetector(
                    onTap: onSort,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: style,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Show sort indicator
                        if (isCurrentSortColumn == true)
                          Icon(
                            sortAscending == true
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 14,
                            color: Colors.blue.shade600,
                          )
                        else
                          Icon(
                            Icons.unfold_more,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                      ],
                    ),
                  ),
                )
              else
                // Non-sortable column
                Expanded(
                  child: Text(
                    title,
                    style: style,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
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

  /// Build chips section for hidden columns
  Widget buildHiddenColumnsSection(
    BuildContext context,
    Function(int) onShowColumn,
  ) {
    if (_hiddenColumns.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
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
    );
  }

  /// Load saved preferences
  Future<void> loadSavedPreferences() async {
    if (prefsKey == null) return;

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
      }
    } catch (e) {
      // Silently ignore errors loading preferences
    }
  }

  /// Save preferences
  Future<void> _savePreferences() async {
    if (prefsKey == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        prefsKey!,
        _hiddenColumns.map((i) => i.toString()).toList(),
      );
    } catch (e) {
      print('Error saving column visibility preferences: $e');
    }
  }
}
