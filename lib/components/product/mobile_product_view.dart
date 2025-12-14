import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../common/app_drawer.dart';
import '../../data/local_database.dart';
import 'product.dart';
import 'sync_products_button.dart';
import 'product_details.dart';
import 'mobile_product_detail_page.dart';

/// Mobile-friendly product view with vertical scrolling and pagination
class MobileProductView extends StatefulWidget {
  const MobileProductView({super.key});

  @override
  State<MobileProductView> createState() => _MobileProductViewState();
}

class _MobileProductViewState extends State<MobileProductView> {
  int _currentPage = 1;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _idSearchController = TextEditingController();
  String _searchQuery = '';
  String _idSearchQuery = '';
  String? _selectedCategory;
  List<String> _categories = ['All'];
  bool _showFilters = false; // Track filter visibility
  String? _selectedStockType; // 'sole_stock' or 'global_stock'
  String? _selectedStockValue; // '0', '1', '2', etc.
  String? _activeStockType; // Applied filter
  String? _activeStockValue; // Applied filter
  bool? _selectedProduction; // true or false
  bool? _activeProduction; // Applied filter
  String? _selectedFilterCategory; // Category filter in stock filter section
  String? _activeFilterCategory; // Applied category filter

  @override
  void initState() {
    super.initState();
    print('===== MOBILE VIEW LOADED =====');
    _loadCategories();
    _loadProducts();
  }

  void _loadCategories() async {
    try {
      print('===== LOADING CATEGORIES FROM DATABASE =====');
      
      // Load all products from local database to get all categories
      final LocalDatabase localDB = LocalDatabase();
      final result = await localDB.getLocalPaginatedProducts(1, 100000);
      final allProducts = result['products'] as List<Product>;
      
      print('Total products from database: ${allProducts.length}');
      
      // Get all category1 values
      final allCategory1Values = allProducts.map((p) => p.category1).where((c) => c != null).toList();
      print('Non-null category1 values: ${allCategory1Values.length}');
      
      // Filter and get unique categories (trim whitespace to avoid duplicates)
      final uniqueCategories = allProducts
          .where((p) => p.category1 != null && p.category1!.trim().isNotEmpty)
          .map((p) => p.category1!.trim())
          .toSet()
          .toList();
      uniqueCategories.sort();
      
      print('Unique categories found (${uniqueCategories.length}): $uniqueCategories');
      
      setState(() {
        _categories = ['All', ...uniqueCategories];
        print('Categories set in state (${_categories.length}): $_categories');
      });
    } catch (e) {
      print('Error loading categories: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    setState(() {
      _searchQuery = query;
      _idSearchQuery = ''; // Clear ID search when performing name search
      _currentPage = 1;
      // Clear stock and production filters when performing other searches
      _activeStockType = null;
      _activeStockValue = null;
      _selectedStockType = null;
      _selectedStockValue = null;
      _activeProduction = null;
      _selectedProduction = null;
      _activeFilterCategory = null;
      _selectedFilterCategory = null;
    });
    _loadProducts();
  }

  void _performIdSearch() {
    final query = _idSearchController.text.trim();
    setState(() {
      _idSearchQuery = query;
      _searchQuery = ''; // Clear name search when performing ID search
      _currentPage = 1;
      // Clear stock and production filters when performing other searches
      _activeStockType = null;
      _activeStockValue = null;
      _selectedStockType = null;
      _selectedStockValue = null;
      _activeProduction = null;
      _selectedProduction = null;
      _activeFilterCategory = null;
      _selectedFilterCategory = null;
    });
    _loadProducts();
  }

  void _loadProducts() {
    final productBloc = BlocProvider.of<ProductBloc>(context);
    
    // When stock, production, or category filter is active, load all products for client-side filtering
    if ((_activeStockType != null && _activeStockValue != null) || _activeProduction != null || _activeFilterCategory != null) {
      productBloc.add(
        LoadPaginatedProducts(
          page: 1,
          pageSize: 10000, // Load all products for stock/production filtering
        ),
      );
      return;
    }
    
    // Priority: ID search > category filter > name search > all products
    if (_idSearchQuery.isNotEmpty) {
      // Filter by ID only
      productBloc.add(
        FilterProductsByColumn(
          column: 'id',
          value: _idSearchQuery,
          page: _currentPage,
          pageSize: _pageSize,
          filterType: 'equals',
        ),
      );
    } else if (_selectedCategory != null && _selectedCategory != 'All') {
      // Filter by category only
      productBloc.add(
        FilterProductsByColumn(
          column: 'category1',
          value: _selectedCategory!,
          page: _currentPage,
          pageSize: _pageSize,
          filterType: 'equals',
        ),
      );
    } else if (_searchQuery.isNotEmpty) {
      // Filter by search query only
      productBloc.add(
        FilterProductsByColumn(
          column: 'name',
          value: _searchQuery,
          page: _currentPage,
          pageSize: _pageSize,
          filterType: 'like',
        ),
      );
    } else {
      // No filters
      productBloc.add(
        LoadPaginatedProducts(
          page: _currentPage,
          pageSize: _pageSize,
        ),
      );
    }
  }

  void _nextPage() {
    setState(() {
      _currentPage++;
    });
    _loadProducts();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _previousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
      _loadProducts();
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _idSearchController.dispose();
    super.dispose();
  }

  String _buildFilterText() {
    List<String> filters = [];
    
    if (_activeStockType != null && _activeStockValue != null) {
      filters.add('${_activeStockType == 'sole_stock' ? 'Sole Stock' : 'Global Stock'} = $_activeStockValue');
    }
    
    if (_activeProduction != null) {
      filters.add('Production: ${_activeProduction! ? 'Yes' : 'No'}');
    }
    
    if (_activeFilterCategory != null) {
      filters.add('Category: $_activeFilterCategory');
    }
    
    return 'Filtered: ${filters.join(' & ')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📱 Mobile Product List'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      drawer: AppDrawer(
        currentPage: 'products',
        onPageSelected: (page) {
          Navigator.of(context).pushReplacementNamed('/$page');
        },
      ),
      body: Column(
        children: [
          // Toggle button to show/hide filters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.blue.shade50,
            child: InkWell(
              onTap: () {
                setState(() {
                  _showFilters = !_showFilters;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showFilters ? Icons.expand_less : Icons.expand_more,
                    color: Colors.blue.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showFilters ? 'Hide' : 'Show',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Search Field, Category Filter, and Sync Button (collapsible)
          if (_showFilters)
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      // Name Search Row
                      Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search products by name...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _currentPage = 1;
                                      });
                                      _loadProducts();
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _performSearch(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _performSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Search'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ID Search Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _idSearchController,
                          decoration: InputDecoration(
                            hintText: 'Search by Product ID...',
                            prefixIcon: const Icon(Icons.tag),
                            suffixIcon: _idSearchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _idSearchController.clear();
                                      setState(() {
                                        _idSearchQuery = '';
                                        _currentPage = 1;
                                      });
                                      _loadProducts();
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          onSubmitted: (_) => _performIdSearch(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _performIdSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Search'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Stock Filter Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2, color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Stock Filter',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Stock Type Dropdown
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Stock Type',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    value: _selectedStockType,
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    hint: const Text('Select type', style: TextStyle(fontSize: 12)),
                                    items: const [
                                      DropdownMenuItem(value: 'sole_stock', child: Text('Sole Stock', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: 'global_stock', child: Text('Global Stock', style: TextStyle(fontSize: 12))),
                                    ],
                                    onChanged: (String? value) {
                                      setState(() {
                                        _selectedStockType = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Stock Value Dropdown
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Stock Value',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    value: _selectedStockValue,
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    hint: const Text('Select value', style: TextStyle(fontSize: 12)),
                                    items: const [
                                      DropdownMenuItem(value: '0', child: Text('0', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: '1', child: Text('1', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: '2', child: Text('2', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: '3', child: Text('3', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: '4', child: Text('4', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: '5', child: Text('5', style: TextStyle(fontSize: 12))),
                                    ],
                                    onChanged: (String? value) {
                                      setState(() {
                                        _selectedStockValue = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Production Filter
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Production Status',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<bool>(
                              value: _selectedProduction,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              hint: const Text('Select production', style: TextStyle(fontSize: 12)),
                              items: const [
                                DropdownMenuItem(value: true, child: Text('Yes', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: false, child: Text('No', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (bool? value) {
                                setState(() {
                                  _selectedProduction = value;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Category Filter
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Category',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _selectedFilterCategory,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              hint: const Text('Select category', style: TextStyle(fontSize: 12)),
                              menuMaxHeight: 400,
                              items: _categories
                                  .where((cat) => cat != 'All')
                                  .map((String category) {
                                return DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(category, style: const TextStyle(fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: (String? value) {
                                setState(() {
                                  _selectedFilterCategory = value;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: (_selectedStockType != null && _selectedStockValue != null) || _selectedProduction != null || _selectedFilterCategory != null
                                    ? () {
                                        setState(() {
                                          _activeStockType = _selectedStockType;
                                          _activeStockValue = _selectedStockValue;
                                          _activeProduction = _selectedProduction;
                                          _activeFilterCategory = _selectedFilterCategory;
                                          _currentPage = 1;
                                          // Clear other filters when applying stock/production/category filter
                                          _searchQuery = '';
                                          _idSearchQuery = '';
                                          _selectedCategory = null;
                                          _searchController.clear();
                                          _idSearchController.clear();
                                        });
                                        _loadProducts();
                                      }
                                    : null,
                                icon: const Icon(Icons.filter_alt, size: 16),
                                label: const Text('Apply Filter', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            if (_activeStockType != null || _activeStockValue != null || _activeProduction != null || _activeFilterCategory != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedStockType = null;
                                      _selectedStockValue = null;
                                      _activeStockType = null;
                                      _activeStockValue = null;
                                      _selectedProduction = null;
                                      _activeProduction = null;
                                      _selectedFilterCategory = null;
                                      _activeFilterCategory = null;
                                      _currentPage = 1;
                                    });
                                    _loadProducts();
                                  },
                                  icon: const Icon(Icons.clear, size: 16),
                                  label: const Text('Clear Filter', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Category Filter and Sync Button in one row
                  Row(
                    children: [
                      // Category Filter Dropdown (left side)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.category, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButton<String>(
                                  value: _selectedCategory ?? 'All',
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  hint: const Text('Filter by Category'),
                                  menuMaxHeight: 400,
                                  items: _categories.map((String category) {
                                    return DropdownMenuItem<String>(
                                      value: category,
                                      child: Text(
                                        category,
                                        style: TextStyle(
                                          fontWeight: category == 'All' ? FontWeight.bold : FontWeight.normal,
                                          color: category == 'All' ? Colors.blue.shade700 : Colors.black87,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedCategory = newValue == 'All' ? null : newValue;
                                      _currentPage = 1;
                                      // Clear stock and production filters when changing category
                                      _activeStockType = null;
                                      _activeStockValue = null;
                                      _selectedStockType = null;
                                      _selectedStockValue = null;
                                      _activeProduction = null;
                                      _selectedProduction = null;
                                    });
                                    _loadProducts();
                                  },
                                ),
                              ),
                              if (_selectedCategory != null && _selectedCategory != 'All')
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      _selectedCategory = null;
                                      _currentPage = 1;
                                    });
                                    _loadProducts();
                                  },
                                  tooltip: 'Clear filter',
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Sync Button (right side)
                      SyncProductsButton(
                        onSyncCompleted: () {
                          setState(() {
                            _currentPage = 1;
                          });
                          _loadCategories();
                          _loadProducts();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
            ),
          // Products content
          Expanded(
            child: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          if (state is ProductLoading && state.isFirstLoad) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is ProductError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${state.message}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadProducts,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is ProductsLoaded) {
            var products = state.products;
            final totalItems = state.totalItems;
            final hasNextPage = state.hasNextPage;
            final hasPreviousPage = state.hasPreviousPage;

            // Apply stock filter if active
            if (_activeStockType != null && _activeStockValue != null) {
              final targetValue = int.tryParse(_activeStockValue!) ?? -1;
              products = products.where((product) {
                try {
                  if (product.uPrices.isEmpty || product.uPrices == 'null') {
                    return false;
                  }
                  final priceList = jsonDecode(product.uPrices) as List<dynamic>;
                  
                  // Check if any price item has the active stock type with the active value
                  return priceList.any((priceItem) {
                    if (priceItem is Map<String, dynamic>) {
                      if (priceItem.containsKey(_activeStockType!) && priceItem[_activeStockType!] != null) {
                        final stock = int.tryParse(priceItem[_activeStockType!].toString()) ?? -1;
                        return stock == targetValue;
                      }
                    }
                    return false;
                  });
                } catch (e) {
                  return false;
                }
              }).toList();
            }
            
            // Apply production filter if active
            if (_activeProduction != null) {
              products = products.where((product) {
                return product.production == _activeProduction;
              }).toList();
            }
            
            // Apply category filter if active
            if (_activeFilterCategory != null) {
              products = products.where((product) {
                return product.category1 == _activeFilterCategory;
              }).toList();
            }

            if (products.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No products found',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Page info header or filter info
                Container(
                  padding: const EdgeInsets.all(12),
                  color: (_activeStockType != null && _activeStockValue != null) || _activeProduction != null || _activeFilterCategory != null
                      ? Colors.orange.shade100
                      : Colors.grey.shade100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: (_activeStockType != null && _activeStockValue != null) || _activeProduction != null || _activeFilterCategory != null
                            ? Row(
                                children: [
                                  Icon(Icons.filter_alt, color: Colors.orange.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _buildFilterText(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'Page $_currentPage',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                      Text(
                        (_activeStockType != null && _activeStockValue != null) || _activeProduction != null || _activeFilterCategory != null
                            ? 'Found: ${products.length} products'
                            : 'Total: $totalItems products',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Product list - vertical scrolling
                Expanded(
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final isEven = index % 2 == 0;
                      return _buildProductCard(product, isEven);
                    },
                  ),
                ),

                // Pagination controls (hidden when stock, production, or category filter is active)
                if ((_activeStockType == null || _activeStockValue == null) && _activeProduction == null && _activeFilterCategory == null)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: ElevatedButton.icon(
                            onPressed: hasPreviousPage ? _previousPage : null,
                            icon: const Icon(Icons.arrow_back, size: 16),
                            label: const Text('Prev', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                        Flexible(
                          flex: 2,
                          child: Text(
                            'Showing ${(_currentPage - 1) * _pageSize + 1}-${(_currentPage - 1) * _pageSize + products.length} of $totalItems',
                            style: const TextStyle(fontSize: 11),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: ElevatedButton.icon(
                            onPressed: hasNextPage ? _nextPage : null,
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: const Text('Next', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }

          return const SizedBox();
        },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product, bool isEven) {
    final backgroundColor = isEven 
        ? Colors.blue.shade50 
        : Colors.green.shade50;
    final borderColor = isEven 
        ? Colors.blue.shade200 
        : Colors.green.shade200;
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MobileProductDetailPage(product: product),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 4,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: 2),
        ),
        child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product header with ID
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isEven ? Colors.blue.shade700 : Colors.green.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tag, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Product ID: ${product.id}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Product image
              if (product.image != null && product.image!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: product.image!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, 
                              size: 48, 
                              color: Colors.grey.shade400
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Image not available',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              _buildAttributeRow('Name', product.name, Icons.shopping_bag, isEven),
              _buildAttributeRow('Category', product.category1 ?? 'N/A', Icons.category, isEven),
              _buildAttributeRow('Description', product.description ?? 'N/A', Icons.description, isEven),
              _buildAttributeRow('Created At', product.createdAt.toString(), Icons.calendar_today, isEven),
              _buildAttributeRow('Updated At', product.updatedAt.toString(), Icons.update, isEven),
              _buildAttributeRow('Production', product.production ? 'Yes' : 'No', Icons.factory, isEven),
              _buildAttributeRow('Discount', product.discount != null ? '${product.discount}%' : 'None', Icons.local_offer, isEven),
              _buildAttributeRow('Popular', product.popularProduct ? 'Yes' : 'No', Icons.star, isEven),
              // Removed 'Image URL' attribute row for mobile view
              _buildPricesJsonDisplay(product, isEven),
              _buildPriceButtonsRow(product, isEven),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildPriceButtonsRow(Product product, bool isEven) {
    final textColor = isEven ? Colors.blue.shade900 : Colors.green.shade900;
    final iconColor = isEven ? Colors.blue.shade600 : Colors.green.shade600;
    
    // Parse the JSON string to get the price list
    List<dynamic> priceList = [];
    try {
      if (product.uPrices.isEmpty || product.uPrices == 'null') {
        priceList = [];
      } else {
        priceList = jsonDecode(product.uPrices);
      }
    } catch (e) {
      priceList = [];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(
                'Purchase History',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: priceList.isEmpty
                ? const Text(
                    'No prices available',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildPriceButtons(priceList, product),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPriceButtons(List<dynamic> priceList, Product product) {
    // Check if ANY element has global_stock
    bool hasGlobalStock = false;
    int globalStockValue = 0;
    Map<String, dynamic>? globalStockItem;

    for (var priceItem in priceList) {
      if (priceItem is Map<String, dynamic>) {
        if (priceItem.containsKey('global_stock') &&
            priceItem['global_stock'] != null) {
          int stockValue =
              int.tryParse(priceItem['global_stock'].toString()) ?? 0;
          hasGlobalStock = true;
          globalStockValue = stockValue;
          globalStockItem = priceItem;
          break;
        }
      }
    }

    // If global_stock exists, show only one button
    if (hasGlobalStock && globalStockItem != null) {
      final stockItem = globalStockItem;
      final price = stockItem['price'] ?? '';
      final unit = stockItem['unit'] ?? '';
      final priceItemId = stockItem['id'];
      final hasId = priceItemId != null && priceItemId.toString().isNotEmpty;

      return [
        ElevatedButton(
          onPressed: hasId ? () async {
            await ProductDetailsButtonHandler.handlePriceButtonClick(
              context: context,
              productId: product.id,
              productName: product.name,
              priceItem: stockItem,
              priceIndex: 0,
              onStockTypeAdded: () {
                // No need to update stock in mobile view (read-only)
              },
              onDataFetched: (String compositeId, List<ProductDetails> productDetailsList) {
                ProductDetailsButtonHandler.showProductDetailsDialog(
                  context: context,
                  productName: product.name,
                  compositeId: compositeId,
                  productDetailsList: productDetailsList,
                  onStockUpdated: () {
                    // No stock update in mobile view (read-only)
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
          } : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            backgroundColor: hasId ? Colors.green.shade100 : Colors.grey.shade300,
            side: BorderSide(
              color: hasId ? Colors.green.shade400 : Colors.grey.shade400,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!hasId)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.warning, size: 14, color: Colors.red.shade800),
                    ),
                  Text(
                    '$price/$unit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: hasId ? Colors.green.shade900 : Colors.red.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Global Stock: $globalStockValue',
                style: TextStyle(
                  fontSize: 10,
                  color: hasId ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
              if (!hasId)
                const Text(
                  'Missing ID',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ];
    }

    // No global stock - show buttons for all price items
    return List.generate(priceList.length, (index) {
      final priceItem = priceList[index];
      final price = priceItem['price'] ?? '';
      final unit = priceItem['unit'] ?? '';
      final oldPrice = priceItem['old_price'];
      final priceItemId = priceItem['id'];
      final hasId = priceItemId != null && priceItemId.toString().isNotEmpty;

      // Get stock information
      String stockText = '';
      if (priceItem.containsKey('sole_stock') &&
          priceItem['sole_stock'] != null &&
          priceItem['sole_stock'].toString().isNotEmpty) {
        stockText = 'Sole: ${priceItem['sole_stock']}';
      } else if (priceItem.containsKey('stock') &&
          priceItem['stock'] != null &&
          priceItem['stock'].toString().isNotEmpty) {
        stockText = 'Stock: ${priceItem['stock']}';
      }

      return ElevatedButton(
        onPressed: hasId ? () async {
          await ProductDetailsButtonHandler.handlePriceButtonClick(
            context: context,
            productId: product.id,
            productName: product.name,
            priceItem: priceItem,
            priceIndex: index,
            onStockTypeAdded: () {
              // No need to update in mobile view (read-only)
            },
            onDataFetched: (String compositeId, List<ProductDetails> productDetailsList) {
              ProductDetailsButtonHandler.showProductDetailsDialog(
                context: context,
                productName: product.name,
                compositeId: compositeId,
                productDetailsList: productDetailsList,
                onStockUpdated: () {
                  // No stock update in mobile view (read-only)
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
        } : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          backgroundColor:
              !hasId
                  ? Colors.grey.shade300
                  : oldPrice != null
                  ? Colors.orange.shade100
                  : Colors.blue.shade50,
          side: BorderSide(
            color:
                !hasId
                    ? Colors.grey.shade400
                    : oldPrice != null
                    ? Colors.orange.shade400
                    : Colors.blue.shade300,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!hasId)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.warning, size: 14, color: Colors.red.shade800),
                  ),
                Text(
                  '$price/$unit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: !hasId ? Colors.red.shade800 : Colors.black87,
                  ),
                ),
              ],
            ),
            if (stockText.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                stockText,
                style: TextStyle(
                  fontSize: 10,
                  color: hasId ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ],
            if (!hasId)
              const Text(
                'Missing ID',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildPricesJsonDisplay(Product product, bool isEven) {
    final textColor = isEven ? Colors.blue.shade900 : Colors.green.shade900;
    final iconColor = isEven ? Colors.blue.shade600 : Colors.green.shade600;
    
    // Format the JSON for display
    String formattedJson = 'No prices available';
    if (product.uPrices.isNotEmpty && product.uPrices != 'null') {
      try {
        final decoded = jsonDecode(product.uPrices);
        const encoder = JsonEncoder.withIndent('  ');
        formattedJson = encoder.convert(decoded);
      } catch (e) {
        formattedJson = product.uPrices;
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.code, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(
                'Prices (JSON)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SelectableText(
              formattedJson,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeRow(String label, String value, IconData icon, bool isEven, {bool isUrl = false, bool isPrice = false}) {
    final textColor = isEven ? Colors.blue.shade900 : Colors.green.shade900;
    final iconColor = isEven ? Colors.blue.shade600 : Colors.green.shade600;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: isUrl && value != 'No image' && value != 'N/A'
                ? Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight: isPrice ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: isPrice ? 5 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }
}
