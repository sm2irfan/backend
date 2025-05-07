import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the visibility of table columns
class ColumnVisibilityManager {
  /// Set of hidden column indices
  final Set<int> hiddenColumns = {};

  /// Column titles for reference
  final List<String> columnTitles;

  /// Optional key for storing preferences
  final String? prefsKey;

  /// Create a new column visibility manager
  ColumnVisibilityManager({required this.columnTitles, this.prefsKey});

  /// Initialize from saved preferences if available
  Future<void> loadSavedPreferences() async {
    if (prefsKey == null) return;

    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedIndices = prefs.getStringList(prefsKey!);

    if (savedIndices != null) {
      hiddenColumns.clear();
      for (String indexStr in savedIndices) {
        final index = int.tryParse(indexStr);
        if (index != null) {
          hiddenColumns.add(index);
        }
      }
    }
  }

  /// Save current preferences if key is provided
  Future<void> savePreferences() async {
    if (prefsKey == null) return;

    final prefs = await SharedPreferences.getInstance();
    final List<String> indices =
        hiddenColumns.map((i) => i.toString()).toList();
    await prefs.setStringList(prefsKey!, indices);
  }

  /// Toggle the visibility of a column
  void toggleColumnVisibility(int columnIndex) {
    if (hiddenColumns.contains(columnIndex)) {
      hiddenColumns.remove(columnIndex);
    } else {
      hiddenColumns.add(columnIndex);
    }

    savePreferences();
  }

  /// Reset all columns to visible
  void resetToDefaults() {
    hiddenColumns.clear();
    savePreferences();
  }

  /// Get visible column widths, mapping from the visible index to the original column width
  Map<int, TableColumnWidth> getVisibleColumnWidths(
    List<double> allColumnWidths,
  ) {
    final visibleWidths = <int, TableColumnWidth>{};
    int visibleIndex = 0;

    for (
      int originalIndex = 0;
      originalIndex < allColumnWidths.length;
      originalIndex++
    ) {
      if (!hiddenColumns.contains(originalIndex)) {
        visibleWidths[visibleIndex] = FixedColumnWidth(
          allColumnWidths[originalIndex],
        );
        visibleIndex++;
      }
    }

    return visibleWidths;
  }

  /// Convert a visible column index to its original index
  int getOriginalColumnIndex(int visibleIndex) {
    int originalIndex = 0;
    int currentVisibleIndex = 0;

    while (currentVisibleIndex <= visibleIndex &&
        originalIndex < columnTitles.length) {
      if (!hiddenColumns.contains(originalIndex)) {
        if (currentVisibleIndex == visibleIndex) {
          return originalIndex;
        }
        currentVisibleIndex++;
      }
      originalIndex++;
    }

    return originalIndex;
  }

  /// Get widgets for visible columns
  List<Widget> getVisibleCells(
    int rowIndex,
    List<int> allColumnIndices,
    Widget Function(int rowIndex, int originalColumnIndex) cellBuilder,
  ) {
    final visibleCells = <Widget>[];

    for (int originalIndex in allColumnIndices) {
      if (!hiddenColumns.contains(originalIndex)) {
        visibleCells.add(cellBuilder(rowIndex, originalIndex));
      }
    }

    return visibleCells;
  }

  /// Build a table row with just the visible columns
  TableRow buildTableRow({
    required BoxDecoration decoration,
    required List<int> allColumnIndices,
    required Widget Function(int columnIndex) cellBuilder,
  }) {
    return TableRow(
      decoration: decoration,
      children:
          allColumnIndices
              .where((i) => !hiddenColumns.contains(i))
              .map((i) => cellBuilder(i))
              .toList(),
    );
  }

  /// Build a "show column" chip for a hidden column
  Widget buildColumnChip(int columnIndex, Function(int) onToggle) {
    return FilterChip(
      label: Text('Show ${columnTitles[columnIndex]}'),
      onSelected: (_) => onToggle(columnIndex),
      deleteIcon: const Icon(Icons.visibility, size: 18),
      onDeleted: () => onToggle(columnIndex),
      backgroundColor: Colors.blue.shade100,
      labelStyle: const TextStyle(fontSize: 12),
    );
  }

  /// Build the hidden columns chip section
  Widget buildHiddenColumnsSection(
    BuildContext context,
    Function(int) onToggle,
  ) {
    if (hiddenColumns.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children:
            hiddenColumns.map((columnIndex) {
              return buildColumnChip(columnIndex, onToggle);
            }).toList(),
      ),
    );
  }

  /// Build a column header with visibility toggle
  Widget buildColumnHeaderWithVisibilityToggle({
    required String title,
    required int index,
    required TextStyle style,
    required Function(int) onToggle,
    required Widget? filterWidget,
  }) {
    // Exclude certain columns from having the hide option
    bool canHide =
        index !=
        (columnTitles.length -
            1); // Don't allow hiding the last column (actions)

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(title, style: style)),
        if (canHide)
          Tooltip(
            message: 'Hide column',
            child: InkWell(
              onTap: () => onToggle(index),
              child: const Icon(Icons.visibility_off, size: 16),
            ),
          ),
      ],
    );
  }
}
