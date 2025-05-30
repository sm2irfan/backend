import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'product.dart';

/// Column filter input with real-time debouncing capability
/// This widget allows users to filter products based on specific column values
class ColumnFilterInput extends StatefulWidget {
  final String columnName;
  final int currentPage;
  final int pageSize;
  final Map<String, String> activeFilters;

  const ColumnFilterInput({
    Key? key,
    required this.columnName,
    required this.currentPage,
    required this.pageSize,
    required this.activeFilters,
  }) : super(key: key);

  @override
  State<ColumnFilterInput> createState() => _ColumnFilterInputState();
}

class _ColumnFilterInputState extends State<ColumnFilterInput> {
  late TextEditingController _controller;
  Timer? _debounceTimer;

  // Debounce duration (milliseconds to wait after typing stops)
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    // Initialize with existing filter value if any
    _controller = TextEditingController(
      text: widget.activeFilters[widget.columnName.toLowerCase()] ?? '',
    );
  }

  @override
  void didUpdateWidget(ColumnFilterInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller if the filter value has changed
    if (oldWidget.activeFilters != widget.activeFilters) {
      final newValue =
          widget.activeFilters[widget.columnName.toLowerCase()] ?? '';
      if (_controller.text != newValue) {
        _controller.text = newValue;
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel(); // Important: Cancel timer when disposed
    _controller.dispose();
    super.dispose();
  }

  void _applyFilter(String value) {
    // Cancel any existing timer
    _debounceTimer?.cancel();

    // Start a new timer
    _debounceTimer = Timer(_debounceDuration, () {
      if (!mounted) return;

      final productBloc = BlocProvider.of<ProductBloc>(context);

      // Get the lowercase column name for easier comparison
      final String columnLower = widget.columnName.toLowerCase();
      final String trimmedValue = value.trim();

      print('Applying filter for column: $columnLower, value: "$trimmedValue"');

      // Special handling for ID column to support comma-separated values
      if (columnLower == 'id') {
        // Only apply filter if not empty
        if (trimmedValue.isNotEmpty) {
          print('Adding ID filter event with value: $trimmedValue');
          productBloc.add(
            FilterProductsByColumn(
              column: columnLower,
              value:
                  trimmedValue, // BLoC will handle comma-separated processing
              page: 1, // Reset to first page when applying filter
              pageSize: widget.pageSize,
            ),
          );
        } else {
          // If value is empty, clear the filter
          print('Clearing ID filter');
          productBloc.add(
            FilterProductsByColumn(
              column: columnLower,
              value: "", // Empty value to clear the filter
              page: 1,
              pageSize: widget.pageSize,
            ),
          );
        }
      }
      // Special handling for name column to use SQL LIKE query for partial matching
      else if (columnLower == 'name') {
        print('Adding NAME filter with SQL LIKE query: %$trimmedValue%');
        // Apply the filter with trimmed value and SQL LIKE syntax
        productBloc.add(
          FilterProductsByColumn(
            column: columnLower,
            value: trimmedValue,
            page: 1, // Reset to first page when applying filter
            pageSize: widget.pageSize,
            filterType:
                'like', // Use SQL LIKE query operator for partial matches
          ),
        );
        print('NAME filter event added to bloc with LIKE query');
      }
      // Standard filtering for other columns
      else {
        print('Adding standard filter for column: $columnLower');
        productBloc.add(
          FilterProductsByColumn(
            column: columnLower,
            value: trimmedValue,
            page: 1, // Reset to first page when applying filter
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
        widget.columnName.toLowerCase() == 'id' ? "1,2,3..." : "Filter";

    return Container(
      width: 60, // Adjust width as needed
      height: 25,
      margin: const EdgeInsets.only(top: 4),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 6,
          ),
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 10, color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Theme.of(context).primaryColor),
          ),
        ),
        style: const TextStyle(fontSize: 11),
        onChanged: _applyFilter,
      ),
    );
  }
}

/// Filter chip for displaying active filters with removal capability
class FilterChip extends StatelessWidget {
  final String columnName;
  final String value;
  final VoidCallback onRemove;

  const FilterChip({
    Key? key,
    required this.columnName,
    required this.value,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$columnName: $value',
            style: TextStyle(fontSize: 12.0, color: Colors.blue.shade800),
          ),
          const SizedBox(width: 4.0),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(12.0),
            child: Icon(Icons.close, size: 16.0, color: Colors.blue.shade800),
          ),
        ],
      ),
    );
  }
}

/// Filter bar to display active filters with clear option
class FilterBar extends StatelessWidget {
  final Map<String, String> activeFilters;
  final Function(String) onRemoveFilter;
  final VoidCallback onClearAll;

  const FilterBar({
    Key? key,
    required this.activeFilters,
    required this.onRemoveFilter,
    required this.onClearAll,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (activeFilters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          Text(
            'Active filters:',
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    activeFilters.entries.map((entry) {
                      return FilterChip(
                        columnName: entry.key,
                        value: entry.value,
                        onRemove: () => onRemoveFilter(entry.key),
                      );
                    }).toList(),
              ),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.clear_all, size: 16.0),
            label: const Text('Clear all'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue.shade800,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
            ),
            onPressed: onClearAll,
          ),
        ],
      ),
    );
  }
}
