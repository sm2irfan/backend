import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
        title: const Text('📱 Mobile Product List'),
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
              Icon(Icons.attach_money, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(
                'Prices',
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
