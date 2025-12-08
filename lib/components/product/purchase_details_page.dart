import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'purchase_detail_model.dart';
import 'purchase_detail_service.dart';
import '../common/app_drawer.dart';

class PurchaseDetailsPage extends StatefulWidget {
  const PurchaseDetailsPage({super.key});

  @override
  State<PurchaseDetailsPage> createState() => _PurchaseDetailsPageState();
}

class _PurchaseDetailsPageState extends State<PurchaseDetailsPage> {
  final PurchaseDetailService _service = PurchaseDetailService();
  final TextEditingController _searchController = TextEditingController();

  List<PurchaseDetail> _purchaseDetails = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Pagination variables
  int _currentPage = 1;
  int _pageSize = 50;
  int _totalPages = 1;
  int _totalCount = 0;

  // Date range filter
  DateTime? _startDate;
  DateTime? _endDate;
  String _dateFilterField = 'expire_date'; // Track which date field to filter

  // Sorting
  String _sortColumn = 'created_at';
  bool _sortAscending = false;

  String _selectedPage = 'Purchase Details';

  @override
  void initState() {
    super.initState();
    _loadPurchaseDetails();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPurchaseDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.fetchPurchaseDetails(
        page: _currentPage,
        pageSize: _pageSize,
        searchQuery: _searchController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        dateFilterField: _dateFilterField,
        sortColumn: _sortColumn,
        sortAscending: _sortAscending,
      );

      setState(() {
        _purchaseDetails = result['data'] as List<PurchaseDetail>;
        _totalCount = result['totalCount'] as int;
        _totalPages = result['totalPages'] as int;
        _currentPage = result['currentPage'] as int;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages && page != _currentPage) {
      setState(() {
        _currentPage = page;
      });
      _loadPurchaseDetails();
    }
  }

  void _onSearch() {
    setState(() {
      _currentPage = 1; // Reset to first page on search
    });
    _loadPurchaseDetails();
  }

  void _changePageSize(int newSize) {
    setState(() {
      _pageSize = newSize;
      _currentPage = 1; // Reset to first page when changing page size
    });
    _loadPurchaseDetails();
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _currentPage = 1;
    });
    _loadPurchaseDetails();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDateRange:
          _startDate != null && _endDate != null
              ? DateTimeRange(start: _startDate!, end: _endDate!)
              : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _currentPage = 1;
      });
      _loadPurchaseDetails();
    }
  }

  Future<void> _selectDateRangeForColumn(String columnName) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDateRange:
          _startDate != null &&
                  _endDate != null &&
                  _dateFilterField == columnName
              ? DateTimeRange(start: _startDate!, end: _endDate!)
              : null,
    );

    if (picked != null) {
      setState(() {
        _dateFilterField = columnName;
        _startDate = picked.start;
        _endDate = picked.end;
        _currentPage = 1;
      });
      _loadPurchaseDetails();
    }
  }

  void _sortByColumn(String columnName) {
    setState(() {
      if (_sortColumn == columnName) {
        // Toggle sort direction if same column
        _sortAscending = !_sortAscending;
      } else {
        // New column, default to ascending
        _sortColumn = columnName;
        _sortAscending = true;
      }
      _currentPage = 1;
    });
    _loadPurchaseDetails();
  }

  void _showAddEditDialog({PurchaseDetail? detail}) {
    final isEdit = detail != null;
    final identityController = TextEditingController(
      text: detail?.identityId ?? '',
    );
    final quantityController = TextEditingController(
      text: detail?.quantity.toString() ?? '',
    );
    final unitController = TextEditingController(text: detail?.unit ?? '');
    final priceController = TextEditingController(
      text: detail?.price.toString() ?? '',
    );
    final supplierController = TextEditingController(
      text: detail?.supplier ?? '',
    );
    DateTime selectedExpireDate =
        detail?.expireDate ?? DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    isEdit ? 'Edit Purchase Detail' : 'Add Purchase Detail',
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: identityController,
                          decoration: const InputDecoration(
                            labelText: 'Identity ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: unitController,
                          decoration: const InputDecoration(
                            labelText: 'Unit (e.g., kg, pcs)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: priceController,
                          decoration: const InputDecoration(
                            labelText: 'Price',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: supplierController,
                          decoration: const InputDecoration(
                            labelText: 'Supplier',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedExpireDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 3650),
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedExpireDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Expire Date',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              DateFormat(
                                'yyyy-MM-dd',
                              ).format(selectedExpireDate),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          final newDetail = PurchaseDetail(
                            id: detail?.id,
                            identityId: identityController.text.trim(),
                            createdAt: detail?.createdAt ?? DateTime.now(),
                            quantity: int.parse(quantityController.text.trim()),
                            unit: unitController.text.trim(),
                            price: double.parse(priceController.text.trim()),
                            supplier: supplierController.text.trim(),
                            expireDate: selectedExpireDate,
                          );

                          if (isEdit) {
                            await _service.updatePurchaseDetail(newDetail);
                          } else {
                            await _service.addPurchaseDetail(newDetail);
                          }

                          Navigator.pop(context);
                          _loadPurchaseDetails();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEdit
                                      ? 'Purchase detail updated'
                                      : 'Purchase detail added',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      child: Text(isEdit ? 'Update' : 'Add'),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPurchaseDetails,
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: AppDrawer(
        currentPage: _selectedPage,
        onPageSelected: (page) {
          setState(() {
            _selectedPage = page;
          });
        },
      ),
      body: Column(
        children: [
          // Search bar and filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search by Identity ID or Supplier',
                          border: OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon:
                              _searchController.text.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearch();
                                    },
                                  )
                                  : null,
                        ),
                        onSubmitted: (_) => _onSearch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _onSearch,
                      child: const Text('Search'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Date range filter
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectDateRange,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _startDate != null && _endDate != null
                              ? '${_dateFilterField == 'expire_date' ? 'Expire' : 'Created'}: ${DateFormat('yyyy-MM-dd').format(_startDate!)} - ${DateFormat('yyyy-MM-dd').format(_endDate!)}'
                              : 'Click column header to filter',
                        ),
                      ),
                    ),
                    if (_startDate != null && _endDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _clearDateFilter,
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear Date Filter',
                      ),
                    ],
                    const SizedBox(width: 16),
                    // Page size selector
                    const Text('Items per page:'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _pageSize,
                      items: const [
                        DropdownMenuItem(value: 50, child: Text('50')),
                        DropdownMenuItem(value: 200, child: Text('200')),
                        DropdownMenuItem(value: 500, child: Text('500')),
                        DropdownMenuItem(value: 1000, child: Text('1000')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _changePageSize(value);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 60,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text('Error: $_errorMessage'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadPurchaseDetails,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                    : _purchaseDetails.isEmpty
                    ? const Center(child: Text('No purchase details found'))
                    : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: [
                            DataColumn(
                              label: InkWell(
                                onTap: () => _sortByColumn('id'),
                                child: Row(
                                  children: [
                                    const Text('ID'),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortColumn == 'id'
                                          ? (_sortAscending
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward)
                                          : Icons.unfold_more,
                                      size: 16,
                                      color:
                                          _sortColumn == 'id'
                                              ? Colors.blue
                                              : Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataColumn(
                              label: InkWell(
                                onTap: () => _sortByColumn('identity_id'),
                                child: Row(
                                  children: [
                                    const Text('Identity ID'),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortColumn == 'identity_id'
                                          ? (_sortAscending
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward)
                                          : Icons.unfold_more,
                                      size: 16,
                                      color:
                                          _sortColumn == 'identity_id'
                                              ? Colors.blue
                                              : Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataColumn(
                              label: InkWell(
                                onTap: () => _sortByColumn('quantity'),
                                child: Row(
                                  children: [
                                    const Text('Quantity'),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortColumn == 'quantity'
                                          ? (_sortAscending
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward)
                                          : Icons.unfold_more,
                                      size: 16,
                                      color:
                                          _sortColumn == 'quantity'
                                              ? Colors.blue
                                              : Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataColumn(
                              label: InkWell(
                                onTap: () => _sortByColumn('unit'),
                                child: Row(
                                  children: [
                                    const Text('Unit'),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortColumn == 'unit'
                                          ? (_sortAscending
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward)
                                          : Icons.unfold_more,
                                      size: 16,
                                      color:
                                          _sortColumn == 'unit'
                                              ? Colors.blue
                                              : Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataColumn(
                              label: InkWell(
                                onTap: () => _sortByColumn('price'),
                                child: Row(
                                  children: [
                                    const Text('Price'),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortColumn == 'price'
                                          ? (_sortAscending
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward)
                                          : Icons.unfold_more,
                                      size: 16,
                                      color:
                                          _sortColumn == 'price'
                                              ? Colors.blue
                                              : Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataColumn(
                              label: InkWell(
                                onTap: () => _sortByColumn('supplier'),
                                child: Row(
                                  children: [
                                    const Text('Supplier'),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortColumn == 'supplier'
                                          ? (_sortAscending
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward)
                                          : Icons.unfold_more,
                                      size: 16,
                                      color:
                                          _sortColumn == 'supplier'
                                              ? Colors.blue
                                              : Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataColumn(
                              label: InkWell(
                                onTap: () => _sortByColumn('expire_date'),
                                child: Row(
                                  children: [
                                    const Text('Expire Date'),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortColumn == 'expire_date'
                                          ? (_sortAscending
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward)
                                          : Icons.unfold_more,
                                      size: 16,
                                      color:
                                          _sortColumn == 'expire_date'
                                              ? Colors.blue
                                              : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.filter_alt,
                                      size: 16,
                                      color:
                                          _dateFilterField == 'expire_date' &&
                                                  _startDate != null
                                              ? Colors.orange
                                              : Colors.grey[400],
                                    ),
                                  ],
                                ),
                                onLongPress:
                                    () => _selectDateRangeForColumn(
                                      'expire_date',
                                    ),
                              ),
                            ),
                            DataColumn(
                              label: InkWell(
                                onTap: () => _sortByColumn('created_at'),
                                child: Row(
                                  children: [
                                    const Text('Created At'),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortColumn == 'created_at'
                                          ? (_sortAscending
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward)
                                          : Icons.unfold_more,
                                      size: 16,
                                      color:
                                          _sortColumn == 'created_at'
                                              ? Colors.blue
                                              : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.filter_alt,
                                      size: 16,
                                      color:
                                          _dateFilterField == 'created_at' &&
                                                  _startDate != null
                                              ? Colors.orange
                                              : Colors.grey[400],
                                    ),
                                  ],
                                ),
                                onLongPress:
                                    () =>
                                        _selectDateRangeForColumn('created_at'),
                              ),
                            ),
                            const DataColumn(label: Text('Actions')),
                          ],
                          rows:
                              _purchaseDetails.map((detail) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(detail.id.toString())),
                                    DataCell(Text(detail.identityId)),
                                    DataCell(Text(detail.quantity.toString())),
                                    DataCell(Text(detail.unit)),
                                    DataCell(
                                      Text(
                                        '\$${detail.price.toStringAsFixed(2)}',
                                      ),
                                    ),
                                    DataCell(Text(detail.supplier)),
                                    DataCell(
                                      Text(
                                        DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(detail.expireDate),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        DateFormat(
                                          'yyyy-MM-dd HH:mm',
                                        ).format(detail.createdAt),
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        onPressed:
                                            () => _showAddEditDialog(
                                              detail: detail,
                                            ),
                                        tooltip: 'Edit',
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                        ),
                      ),
                    ),
          ),

          // Pagination controls
          if (_totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${(_currentPage - 1) * _pageSize + 1} - ${(_currentPage * _pageSize > _totalCount) ? _totalCount : _currentPage * _pageSize} of $_totalCount',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.first_page),
                        onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed:
                            _currentPage > 1
                                ? () => _goToPage(_currentPage - 1)
                                : null,
                      ),
                      ...List.generate(_totalPages > 5 ? 5 : _totalPages, (
                        index,
                      ) {
                        int pageNumber;
                        if (_totalPages <= 5) {
                          pageNumber = index + 1;
                        } else if (_currentPage <= 3) {
                          pageNumber = index + 1;
                        } else if (_currentPage >= _totalPages - 2) {
                          pageNumber = _totalPages - 4 + index;
                        } else {
                          pageNumber = _currentPage - 2 + index;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ElevatedButton(
                            onPressed: () => _goToPage(pageNumber),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _currentPage == pageNumber
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey[300],
                              foregroundColor:
                                  _currentPage == pageNumber
                                      ? Colors.white
                                      : Colors.black,
                              minimumSize: const Size(40, 40),
                            ),
                            child: Text('$pageNumber'),
                          ),
                        );
                      }),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed:
                            _currentPage < _totalPages
                                ? () => _goToPage(_currentPage + 1)
                                : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.last_page),
                        onPressed:
                            _currentPage < _totalPages
                                ? () => _goToPage(_totalPages)
                                : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
        tooltip: 'Add Purchase Detail',
      ),
    );
  }
}
