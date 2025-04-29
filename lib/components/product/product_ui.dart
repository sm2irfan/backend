import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'product.dart';
import 'product_table.dart'; // Import the new file
import '../common/app_drawer.dart'; // Import the new drawer component

// Main admin app for product management
class ProductApp extends StatelessWidget {
  const ProductApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Product Management',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          elevation: 1,
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const SimpleAdminDashboard(),
    );
  }
}

// Simple admin dashboard with pagination support
class SimpleAdminDashboard extends StatefulWidget {
  const SimpleAdminDashboard({super.key});

  @override
  State<SimpleAdminDashboard> createState() => _SimpleAdminDashboardState();
}

class _SimpleAdminDashboardState extends State<SimpleAdminDashboard> {
  // Default page size with min 20, max 100
  int _pageSize = 50;
  late ProductBloc _productBloc;
  // Add scroll controller for horizontal scrolling
  final ScrollController _horizontalScrollController = ScrollController();

  // Current selected navigation item
  String _currentPage = 'Products';

  @override
  void initState() {
    super.initState();
    // Initialize bloc in initState instead of in the build method
    _productBloc = ProductBloc(ProductRepository());
    _productBloc.add(LoadPaginatedProducts(page: 1, pageSize: _pageSize));
  }

  @override
  void dispose() {
    // Properly close the bloc when the widget is disposed
    _productBloc.close();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _handlePageSizeChange(int newSize) {
    setState(() {
      _pageSize = newSize;
    });
    _productBloc.add(LoadPaginatedProducts(page: 1, pageSize: _pageSize));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _productBloc, // Use the bloc instance created in initState
      child: Scaffold(
        appBar: AppBar(
          elevation: 2,
          title: Row(
            children: [
              Icon(Icons.inventory_2, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              Flexible(
                child: const Text(
                  'Product Management',
                  style: TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: BlocBuilder<ProductBloc, ProductState>(
              builder: (context, state) {
                if (state is ProductsLoaded) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 12.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Products',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${state.totalItems} items',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        //
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          actions: [
            // Add product button with black styling
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text(
                  'Add Product',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Add new product feature coming soon'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        // Replace the drawer with the new component
        drawer: AppDrawer(
          currentPage: _currentPage,
          onPageSelected: (newPage) {
            setState(() {
              _currentPage = newPage;
            });
          },
        ),
        body: BlocBuilder<ProductBloc, ProductState>(
          builder: (context, state) {
            if (state is ProductLoading && state.isFirstLoad) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is ProductsLoaded) {
              // Calculate total pages for pagination controls
              final int totalPages = (state.totalItems / _pageSize).ceil();

              return Column(
                children: [
                  // Table with horizontal scrollbar
                  Expanded(
                    child: Scrollbar(
                      controller: _horizontalScrollController,
                      scrollbarOrientation: ScrollbarOrientation.bottom,
                      thumbVisibility: false,
                      interactive: true,
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: PaginatedProductTable(
                              products: state.products,
                              currentPage: state.currentPage,
                              totalItems: state.totalItems,
                              pageSize: _pageSize,
                              hasNextPage: state.hasNextPage,
                              hasPreviousPage: state.hasPreviousPage,
                              isLoading:
                                  state is! ProductsLoaded &&
                                  state is ProductLoading,
                              onPageChanged: (page) {
                                _productBloc.add(
                                  LoadPaginatedProducts(
                                    page: page,
                                    pageSize: _pageSize,
                                  ),
                                );
                              },
                              onPageSizeChanged: _handlePageSizeChange,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Pagination controls moved to footer
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 16.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: const Border(
                        top: BorderSide(color: Colors.grey, width: 0.5),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Use compact layout for small screens
                        if (constraints.maxWidth < 400) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Page ${state.currentPage} of $totalPages'),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Dropdown with shorter text
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _pageSize,
                                      isDense: true,
                                      icon: const Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.grey,
                                        size: 18,
                                      ),
                                      items:
                                          const [20, 50, 75, 100].map((
                                            int size,
                                          ) {
                                            return DropdownMenuItem<int>(
                                              value: size,
                                              child: Text('$size'),
                                            );
                                          }).toList(),
                                      onChanged: (int? newValue) {
                                        if (newValue != null &&
                                            newValue != _pageSize) {
                                          _handlePageSizeChange(newValue);
                                        }
                                      },
                                    ),
                                  ),
                                  // Navigation buttons
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.arrow_back,
                                          size: 20,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.all(8),
                                        constraints: const BoxConstraints(),
                                        onPressed:
                                            state.hasPreviousPage
                                                ? () => _productBloc.add(
                                                  LoadPaginatedProducts(
                                                    page: state.currentPage - 1,
                                                    pageSize: _pageSize,
                                                  ),
                                                )
                                                : null,
                                        tooltip: 'Previous Page',
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.arrow_forward,
                                          size: 20,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.all(8),
                                        constraints: const BoxConstraints(),
                                        onPressed:
                                            state.hasNextPage
                                                ? () => _productBloc.add(
                                                  LoadPaginatedProducts(
                                                    page: state.currentPage + 1,
                                                    pageSize: _pageSize,
                                                  ),
                                                )
                                                : null,
                                        tooltip: 'Next Page',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          );
                        }

                        // Use original layout for larger screens
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Page ${state.currentPage} of $totalPages'),
                            Row(
                              children: [
                                // Page size dropdown added here
                                DropdownButton<int>(
                                  value: _pageSize,
                                  underline: Container(),
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.grey,
                                  ),
                                  items:
                                      const [20, 50, 75, 100].map((int size) {
                                        return DropdownMenuItem<int>(
                                          value: size,
                                          child: Text('$size per page'),
                                        );
                                      }).toList(),
                                  onChanged: (int? newValue) {
                                    if (newValue != null &&
                                        newValue != _pageSize) {
                                      _handlePageSizeChange(newValue);
                                    }
                                  },
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed:
                                      state.hasPreviousPage
                                          ? () => _productBloc.add(
                                            LoadPaginatedProducts(
                                              page: state.currentPage - 1,
                                              pageSize: _pageSize,
                                            ),
                                          )
                                          : null,
                                  tooltip: 'Previous Page',
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.arrow_forward),
                                  onPressed:
                                      state.hasNextPage
                                          ? () => _productBloc.add(
                                            LoadPaginatedProducts(
                                              page: state.currentPage + 1,
                                              pageSize: _pageSize,
                                            ),
                                          )
                                          : null,
                                  tooltip: 'Next Page',
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            } else if (state is ProductError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: ${state.message}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        _productBloc.add(
                          LoadPaginatedProducts(page: 1, pageSize: _pageSize),
                        );
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            return const Center(child: Text('No products available'));
          },
        ),
      ),
    );
  }
}

// Product Detail Screen - Simplified version
class ProductDetailScreen extends StatelessWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.image != null)
              Image.network(
                product.image!,
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 250,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image_not_supported, size: 80),
                    ),
                  );
                },
              )
            else
              Container(
                height: 250,
                color: Colors.grey[200],
                child: const Center(child: Icon(Icons.image, size: 80)),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (product.popularProduct)
                        const Chip(
                          label: Text('Popular'),
                          avatar: Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber,
                          ),
                          backgroundColor: Colors.amber,
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '\$${product.uPrices}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (product.discount != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${product.discount}% OFF',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (product.category1 != null || product.category2 != null)
                    Wrap(
                      spacing: 8,
                      children: [
                        if (product.category1 != null)
                          Chip(
                            label: Text(product.category1!),
                            avatar: const Icon(Icons.category, size: 16),
                          ),
                        if (product.category2 != null)
                          Chip(
                            label: Text(product.category2!),
                            avatar: const Icon(Icons.category, size: 16),
                          ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description ?? 'No description available',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
