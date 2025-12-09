import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'product.dart';
import 'sync_products_button.dart';

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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    print('===== MOBILE VIEW LOADED =====');
    _loadProducts();
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    setState(() {
      _searchQuery = query;
      _currentPage = 1;
    });
    _loadProducts();
  }

  void _loadProducts() {
    final productBloc = BlocProvider.of<ProductBloc>(context);
    if (_searchQuery.isEmpty) {
      productBloc.add(
        LoadPaginatedProducts(
          page: _currentPage,
          pageSize: _pageSize,
        ),
      );
    } else {
      productBloc.add(
        FilterProductsByColumn(
          column: 'name',
          value: _searchQuery,
          page: _currentPage,
          pageSize: _pageSize,
          filterType: 'like',
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile View - Products'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Column(
        children: [
          // Search Field and Sync Button
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
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
                SyncProductsButton(
                  onSyncCompleted: () {
                    setState(() {
                      _currentPage = 1;
                    });
                    _loadProducts();
                  },
                ),
              ],
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
            final products = state.products;
            final totalItems = state.totalItems;
            final hasNextPage = state.hasNextPage;
            final hasPreviousPage = state.hasPreviousPage;

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
                // Page info header
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey.shade100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Page $_currentPage',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Total: $totalItems products',
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

                // Pagination controls
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
    
    return Card(
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
                    Text(
                      'Product ID: ${product.id}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildAttributeRow('Name', product.name, Icons.shopping_bag, isEven),
              _buildAttributeRow('Category', product.category1 ?? 'N/A', Icons.category, isEven),
              _buildAttributeRow('Description', product.description ?? 'N/A', Icons.description, isEven),
              _buildAttributeRow('Created At', product.createdAt.toString(), Icons.calendar_today, isEven),
              _buildAttributeRow('Updated At', product.updatedAt.toString(), Icons.update, isEven),
              _buildAttributeRow('Production', product.production ? 'Yes' : 'No', Icons.factory, isEven),
              _buildAttributeRow('Discount', product.discount != null ? '${product.discount}%' : 'None', Icons.local_offer, isEven),
              _buildAttributeRow('Popular', product.popularProduct ? 'Yes' : 'No', Icons.star, isEven),
              _buildAttributeRow('Image URL', product.image ?? 'No image', Icons.image, isEven, isUrl: true),
              _buildAttributeRow('Prices (JSON)', product.uPrices.isNotEmpty ? product.uPrices : 'N/A', Icons.attach_money, isEven, isPrice: true),
            ],
          ),
        ),
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
