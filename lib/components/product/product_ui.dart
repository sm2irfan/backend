import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'product.dart';
import 'product_table.dart'; // Import the new file

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
          title: const Text('Product Management'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add New Product',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Add new product feature coming soon'),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: BlocBuilder<ProductBloc, ProductState>(
          builder: (context, state) {
            if (state is ProductLoading && state.isFirstLoad) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is ProductsLoaded) {
              return PaginatedProductTable(
                products: state.products,
                currentPage: state.currentPage,
                totalItems: state.totalItems,
                pageSize: _pageSize,
                hasNextPage: state.hasNextPage,
                hasPreviousPage: state.hasPreviousPage,
                isLoading: state is! ProductsLoaded && state is ProductLoading,
                onPageChanged: (page) {
                  _productBloc.add(
                    LoadPaginatedProducts(page: page, pageSize: _pageSize),
                  );
                },
                onPageSizeChanged: _handlePageSizeChange,
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
