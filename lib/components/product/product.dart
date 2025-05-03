import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/local_database.dart';

// Export UI components for easy access
export 'product_ui.dart';

// Product Model - Updated to use direct category fields instead of a map
class Product extends Equatable {
  final int id;
  final DateTime createdAt;
  final DateTime? updatedAt; // Added updatedAt field
  final String name;
  final String uPrices;
  final String? image;
  final int? discount;
  final String? description;
  final String? category1; // Direct field instead of map
  final String? category2; // Direct field instead of map
  final bool popularProduct;
  final String? matchingWords;

  const Product({
    required this.id,
    required this.createdAt,
    this.updatedAt, // Added to constructor
    required this.name,
    required this.uPrices,
    this.image,
    this.discount,
    this.description,
    this.category1, // Changed to optional direct fields
    this.category2, // Changed to optional direct fields
    required this.popularProduct,
    this.matchingWords,
  });

  // Get all non-null categories as a list
  List<String> get categoryList => [
    if (category1 != null) category1!,
    if (category2 != null) category2!,
  ];

  factory Product.fromJson(Map<String, dynamic> json) {
    try {
      // Handle null created_at field by using a fixed fallback date
      DateTime createdAt;
      if (json['created_at'] == null) {
        createdAt = DateTime(2023, 1, 1);
      } else {
        createdAt = DateTime.parse(json['created_at'] as String);
      }

      // Handle the updated_at field
      DateTime? updatedAt;
      if (json['updated_at'] != null) {
        try {
          updatedAt = DateTime.parse(json['updated_at'] as String);
        } catch (e) {
          // If parsing fails, leave as null
          updatedAt = null;
        }
      }

      return Product(
        id: json['id'] as int,
        createdAt: createdAt,
        updatedAt: updatedAt, // Add updatedAt to the constructor
        name: json['name'] as String? ?? 'Unnamed Product',
        uPrices:
            json['uprices'] is String
                ? json['uprices'] as String
                : json['uprices'].toString(),
        image: json['image'] as String?,
        discount: json['discount'] as int?,
        description: json['description'] as String?,
        category1:
            json['category_1'] as String?, // Direct access to category fields
        category2:
            json['category_2'] as String?, // Direct access to category fields
        popularProduct: json['popular_product'] as bool? ?? false,
        matchingWords: json['matching_words'] as String?,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  List<Object?> get props => [
    id,
    createdAt,
    updatedAt, // Add updatedAt to props
    name,
    uPrices,
    image,
    discount,
    description,
    category1, // Updated props list
    category2, // Updated props list
    popularProduct,
    matchingWords,
  ];
}

// Repository with pagination support
class ProductRepository {
  // final SupabaseClient _supabaseClient = Supabase.instance.client;
  final LocalDatabase _localDatabase = LocalDatabase();

  Future<Map<String, dynamic>> getPaginatedProducts(
    int page,
    int pageSize, {
    Map<String, String> filters = const {},
  }) async {
    try {
      // Get data from local database instead of Supabase
      return await _localDatabase.getLocalPaginatedProducts(
        page,
        pageSize,
        filters: filters,
      );
    } catch (e) {
      throw Exception('Failed to load products: $e');
    }
  }

  Future<List<Product>> getPopularProducts() async {
    try {
      // Get all products from local database (with page size 1000 to get all)
      final response = await _localDatabase.getLocalPaginatedProducts(1, 1000);

      // Filter for popular products only
      final products =
          (response['products'] as List<Product>)
              .where((product) => product.popularProduct)
              .toList();

      return products;
    } catch (e) {
      debugPrint('Error fetching popular products: $e');
      throw Exception('Failed to load popular products: $e');
    }
  }

  Future<List<Product>> getProductsByCategory(String category) async {
    try {
      // Get all products from local database (with page size 1000 to get all)
      final response = await _localDatabase.getLocalPaginatedProducts(1, 1000);

      // Filter for products matching the category
      final products =
          (response['products'] as List<Product>)
              .where(
                (product) =>
                    product.category1 == category ||
                    product.category2 == category,
              )
              .toList();

      return products;
    } catch (e) {
      debugPrint('Error fetching products by category: $e');
      throw Exception('Failed to load products by category: $e');
    }
  }
}

// Updated BLoC Events
abstract class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object> get props => [];
}

class LoadProducts extends ProductEvent {
  const LoadProducts();
}

class LoadPaginatedProducts extends ProductEvent {
  final int page;
  final int pageSize;

  const LoadPaginatedProducts({required this.page, required this.pageSize});

  @override
  List<Object> get props => [page, pageSize];
}

class LoadPopularProducts extends ProductEvent {}

class LoadProductsByCategory extends ProductEvent {
  final String category;

  const LoadProductsByCategory(this.category);

  @override
  List<Object> get props => [category];
}

// New event for refreshing current page
class RefreshCurrentPage extends ProductEvent {
  final int currentPage;
  final int pageSize;

  const RefreshCurrentPage({required this.currentPage, required this.pageSize});

  @override
  List<Object> get props => [currentPage, pageSize];
}

// New event for filtering products
class FilterProductsByColumn extends ProductEvent {
  final String column;
  final String value;
  final int page;
  final int pageSize;
  final String? filterType; // Add this parameter

  const FilterProductsByColumn({
    required this.column,
    required this.value,
    required this.page,
    required this.pageSize,
    this.filterType, // Make it optional with default null
  });

  @override
  List<Object> get props => [
    column,
    value,
    page,
    pageSize,
    // Only include filterType when it's not null
    if (filterType != null) filterType!,
  ];
}

// Updated BLoC States
abstract class ProductState extends Equatable {
  const ProductState();

  @override
  List<Object> get props => [];
}

class ProductInitial extends ProductState {}

class ProductLoading extends ProductState {
  final bool isFirstLoad;

  const ProductLoading({this.isFirstLoad = true});

  @override
  List<Object> get props => [isFirstLoad];
}

class ProductsLoaded extends ProductState {
  final List<Product> products;
  final int totalItems;
  final int currentPage;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final Map<String, String> activeFilters; // Add active filters to state

  const ProductsLoaded({
    required this.products,
    required this.totalItems,
    required this.currentPage,
    required this.hasNextPage,
    required this.hasPreviousPage,
    this.activeFilters = const {}, // Default to empty map
  });

  @override
  List<Object> get props => [
    products,
    totalItems,
    currentPage,
    hasNextPage,
    hasPreviousPage,
    activeFilters,
  ];
}

class ProductError extends ProductState {
  final String message;

  const ProductError(this.message);

  @override
  List<Object> get props => [message];
}

// Updated BLoC
class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final ProductRepository _productRepository;

  ProductBloc(this._productRepository) : super(ProductInitial()) {
    on<LoadProducts>(_onLoadProducts);
    on<LoadPaginatedProducts>(_onLoadPaginatedProducts);
    on<LoadPopularProducts>(_onLoadPopularProducts);
    on<LoadProductsByCategory>(_onLoadProductsByCategory);
    on<RefreshCurrentPage>(_onRefreshCurrentPage);
    on<FilterProductsByColumn>(_onFilterProductsByColumn); // Add new handler
  }

  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      // For backward compatibility, use page 1 with a large size
      final result = await _productRepository.getPaginatedProducts(1, 1000);
      emit(
        ProductsLoaded(
          products: result['products'],
          totalItems: result['totalItems'],
          currentPage: 1,
          hasNextPage: false,
          hasPreviousPage: false,
        ),
      );
    } catch (e) {
      emit(ProductError(e.toString()));
    }
  }

  Future<void> _onLoadPaginatedProducts(
    LoadPaginatedProducts event,
    Emitter<ProductState> emit,
  ) async {
    // For page changes, we want to show a loading indicator but not a full-screen one
    final isFirstLoad = state is ProductInitial || state is ProductError;
    emit(ProductLoading(isFirstLoad: isFirstLoad));

    try {
      final result = await _productRepository.getPaginatedProducts(
        event.page,
        event.pageSize,
      );

      emit(
        ProductsLoaded(
          products: result['products'],
          totalItems: result['totalItems'],
          currentPage: event.page,
          hasNextPage: result['hasNextPage'],
          hasPreviousPage: result['hasPreviousPage'],
        ),
      );
    } catch (e) {
      emit(ProductError(e.toString()));
    }
  }

  Future<void> _onLoadPopularProducts(
    LoadPopularProducts event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      final products = await _productRepository.getPopularProducts();
      emit(
        ProductsLoaded(
          products: products,
          totalItems: products.length,
          currentPage: 1,
          hasNextPage: false,
          hasPreviousPage: false,
        ),
      );
    } catch (e) {
      emit(ProductError(e.toString()));
    }
  }

  Future<void> _onLoadProductsByCategory(
    LoadProductsByCategory event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      final products = await _productRepository.getProductsByCategory(
        event.category,
      );
      emit(
        ProductsLoaded(
          products: products,
          totalItems: products.length,
          currentPage: 1,
          hasNextPage: false,
          hasPreviousPage: false,
        ),
      );
    } catch (e) {
      emit(ProductError(e.toString()));
    }
  }

  Future<void> _onRefreshCurrentPage(
    RefreshCurrentPage event,
    Emitter<ProductState> emit,
  ) async {
    // Preserve the current page
    final currentState = state;
    bool isFirstLoad = false;
    Map<String, String> activeFilters = {};

    // Preserve any active filters
    if (currentState is ProductsLoaded) {
      activeFilters = currentState.activeFilters;
    }

    // We're refreshing, not doing a first load, so set isFirstLoad to false
    emit(ProductLoading(isFirstLoad: isFirstLoad));

    try {
      final result = await _productRepository.getPaginatedProducts(
        event.currentPage,
        event.pageSize,
        filters: activeFilters,
      );

      emit(
        ProductsLoaded(
          products: result['products'],
          totalItems: result['totalItems'],
          currentPage: event.currentPage,
          hasNextPage: result['hasNextPage'],
          hasPreviousPage: result['hasPreviousPage'],
          activeFilters: activeFilters,
        ),
      );
    } catch (e) {
      emit(ProductError(e.toString()));
    }
  }

  // New handler for filtering products
  Future<void> _onFilterProductsByColumn(
    FilterProductsByColumn event,
    Emitter<ProductState> emit,
  ) async {
    print(
      'Processing filter event - Column: ${event.column}, Value: "${event.value}", FilterType: ${event.filterType}',
    );

    // For product name filtering, use specialized function
    if (event.column.toLowerCase() == 'name' && event.filterType == 'like') {
      return _onFilterProductsByProductNameColumn(event, emit);
    }

    emit(const ProductLoading(isFirstLoad: false));

    try {
      // Get current active filters
      Map<String, String> activeFilters = {};
      if (state is ProductsLoaded) {
        activeFilters = Map.from((state as ProductsLoaded).activeFilters);
      }

      print('Current active filters before update: $activeFilters');

      // Update the filter for the specified column
      if (event.value.isEmpty) {
        activeFilters.remove(event.column); // Remove filter if value is empty
        print('Removed filter for ${event.column}');
      } else {
        activeFilters[event.column] = event.value; // Add or update filter
        print('Set filter for ${event.column} to "${event.value}"');
      }

      print('Updated active filters: $activeFilters');
      print('Fetching products with filters: $activeFilters');

      final result = await _productRepository.getPaginatedProducts(
        event.page,
        event.pageSize,
        filters: activeFilters,
      );

      print('Fetched ${result['products'].length} products with filters');

      emit(
        ProductsLoaded(
          products: result['products'],
          totalItems: result['totalItems'],
          currentPage: event.page,
          hasNextPage: result['hasNextPage'],
          hasPreviousPage: result['hasPreviousPage'],
          activeFilters: activeFilters,
        ),
      );
      print('Emitted new state with ${result['products'].length} products');
    } catch (e) {
      print('Error processing filter: $e');
      emit(ProductError(e.toString()));
    }
  }

  // Specialized handler for product name filtering with LIKE query
  Future<void> _onFilterProductsByProductNameColumn(
    FilterProductsByColumn event,
    Emitter<ProductState> emit,
  ) async {
    // Make sure to clean up any LIKE: prefix while preserving exact spaces
    final String searchTerm = event.value.replaceAll('LIKE:', '');
    print('Processing name filter with LIKE query: "%$searchTerm%"');
    emit(const ProductLoading(isFirstLoad: false));

    try {
      // Get current active filters
      Map<String, String> activeFilters = {};
      if (state is ProductsLoaded) {
        activeFilters = Map.from((state as ProductsLoaded).activeFilters);
      }

      print('Current active filters before update: $activeFilters');

      // Set special filter value with filterType metadata
      if (searchTerm.trim().isEmpty) {
        // Only check if trimmed value is empty
        activeFilters.remove(event.column); // Remove filter if value is empty
        print('Removed name filter');
      } else {
        // Add or update name filter with a special prefix to indicate LIKE query
        // Store the exact search term including spaces
        activeFilters[event.column] = 'LIKE:$searchTerm';
        print('Set name filter to use LIKE query with: "$searchTerm"');
      }

      print('Updated active filters for name search: $activeFilters');
      print('Fetching products with name filter using LIKE query');

      final result = await _productRepository.getPaginatedProducts(
        event.page,
        event.pageSize,
        filters: activeFilters,
      );

      print('Fetched ${result['products'].length} products with name filter');

      emit(
        ProductsLoaded(
          products: result['products'],
          totalItems: result['totalItems'],
          currentPage: event.page,
          hasNextPage: result['hasNextPage'],
          hasPreviousPage: result['hasPreviousPage'],
          activeFilters: activeFilters,
        ),
      );
      print(
        'Emitted new state with ${result['products'].length} products from name filter',
      );
    } catch (e) {
      print('Error processing name filter: $e');
      emit(ProductError(e.toString()));
    }
  }
}
