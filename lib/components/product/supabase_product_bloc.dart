import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Reuse the Product model but add Supabase-specific functionality
class SupabaseProduct extends Equatable {
  final int id; // Changed to non-nullable
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String name;
  final String uPrices;
  final String? image;
  final int? discount;
  final String? description;
  final String? category1;
  final String? category2;
  final bool popularProduct;
  final String? matchingWords;

  const SupabaseProduct({
    required this.id, // Now required
    required this.createdAt,
    this.updatedAt,
    required this.name,
    required this.uPrices,
    this.image,
    this.discount,
    this.description,
    this.category1,
    this.category2,
    required this.popularProduct,
    this.matchingWords,
  });

  // Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id, // Always include id now
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'name': name,
      'uprices': uPrices,
      'image': image,
      'discount': discount,
      'description': description,
      'category_1': category1,
      'category_2': category2,
      'popular_product': popularProduct,
      'matching_words': matchingWords,
    };
  }

  // Factory to create from JSON
  factory SupabaseProduct.fromJson(Map<String, dynamic> json) {
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
          updatedAt = null;
        }
      }

      return SupabaseProduct(
        id: json['id'] as int, // Changed to non-nullable
        createdAt: createdAt,
        updatedAt: updatedAt,
        name: json['name'] as String? ?? 'Unnamed Product',
        uPrices:
            json['uprices'] is String
                ? json['uprices'] as String
                : json['uprices'].toString(),
        image: json['image'] as String?,
        discount: json['discount'] as int?,
        description: json['description'] as String?,
        category1: json['category_1'] as String?,
        category2: json['category_2'] as String?,
        popularProduct: json['popular_product'] as bool? ?? false,
        matchingWords: json['matching_words'] as String?,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Create a copy with some attributes changed
  SupabaseProduct copyWith({
    int? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    String? uPrices,
    String? image,
    int? discount,
    String? description,
    String? category1,
    String? category2,
    bool? popularProduct,
    String? matchingWords,
  }) {
    return SupabaseProduct(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      uPrices: uPrices ?? this.uPrices,
      image: image ?? this.image,
      discount: discount ?? this.discount,
      description: description ?? this.description,
      category1: category1 ?? this.category1,
      category2: category2 ?? this.category2,
      popularProduct: popularProduct ?? this.popularProduct,
      matchingWords: matchingWords ?? this.matchingWords,
    );
  }

  @override
  List<Object?> get props => [
    id,
    createdAt,
    updatedAt,
    name,
    uPrices,
    image,
    discount,
    description,
    category1,
    category2,
    popularProduct,
    matchingWords,
  ];
}

// Repository for Supabase operations
class SupabaseProductRepository {
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  final String _tableName = 'all_products';

  // Create a new product
  Future<SupabaseProduct> createProduct(SupabaseProduct product) async {
    try {
      final response =
          await _supabaseClient
              .from(_tableName)
              .insert(product.toJson())
              .select()
              .single();

      return SupabaseProduct.fromJson(response);
    } catch (e) {
      debugPrint('Error creating product: $e');
      throw Exception('Failed to create product: $e');
    }
  }

  // Update an existing product
  Future<SupabaseProduct> updateProduct(SupabaseProduct product) async {
    try {
      // Always set updated_at to current time
      final productToUpdate = product.copyWith(updatedAt: DateTime.now());

      final response =
          await _supabaseClient
              .from(_tableName)
              .update(productToUpdate.toJson())
              .eq('id', product.id) // No more null check needed
              .select()
              .single();

      return SupabaseProduct.fromJson(response);
    } catch (e) {
      debugPrint('Error updating product: $e');
      throw Exception('Failed to update product: $e');
    }
  }

  // Delete a product
  Future<void> deleteProduct(int productId) async {
    try {
      await _supabaseClient.from('all_products').delete().eq('id', productId);
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  // Get a single product by ID
  Future<SupabaseProduct> getProductById(int id) async {
    try {
      final response =
          await _supabaseClient.from(_tableName).select().eq('id', id).single();

      return SupabaseProduct.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching product: $e');
      throw Exception('Failed to fetch product: $e');
    }
  }
}

// BLoC Events
abstract class SupabaseProductEvent extends Equatable {
  const SupabaseProductEvent();

  @override
  List<Object?> get props => [];
}

class CreateProductEvent extends SupabaseProductEvent {
  final SupabaseProduct product;

  const CreateProductEvent(this.product);

  @override
  List<Object?> get props => [product];
}

class UpdateProductEvent extends SupabaseProductEvent {
  final SupabaseProduct product;

  const UpdateProductEvent(this.product);

  @override
  List<Object?> get props => [product];
}

class DeleteProductEvent extends SupabaseProductEvent {
  final int productId;

  const DeleteProductEvent(this.productId);

  @override
  List<Object?> get props => [productId];
}

class FetchProductEvent extends SupabaseProductEvent {
  final int productId;

  const FetchProductEvent(this.productId);

  @override
  List<Object?> get props => [productId];
}

// BLoC States
abstract class SupabaseProductState extends Equatable {
  const SupabaseProductState();

  @override
  List<Object?> get props => [];
}

class SupabaseProductInitial extends SupabaseProductState {}

class SupabaseProductLoading extends SupabaseProductState {}

class SupabaseProductSuccess extends SupabaseProductState {
  final SupabaseProduct product;
  final String message;

  const SupabaseProductSuccess({required this.product, required this.message});

  @override
  List<Object?> get props => [product, message];
}

class SupabaseProductDeleteSuccess extends SupabaseProductState {
  final int productId;

  const SupabaseProductDeleteSuccess({required this.productId});

  @override
  List<Object?> get props => [productId];
}

class SupabaseProductFetchSuccess extends SupabaseProductState {
  final SupabaseProduct product;

  const SupabaseProductFetchSuccess({required this.product});

  @override
  List<Object?> get props => [product];
}

class SupabaseProductError extends SupabaseProductState {
  final String message;

  const SupabaseProductError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC Implementation
class SupabaseProductBloc
    extends Bloc<SupabaseProductEvent, SupabaseProductState> {
  final SupabaseProductRepository _repository;

  SupabaseProductBloc(this._repository) : super(SupabaseProductInitial()) {
    on<CreateProductEvent>(_onCreateProduct);
    on<UpdateProductEvent>(_onUpdateProduct);
    on<DeleteProductEvent>(_onDeleteProduct);
    on<FetchProductEvent>(_onFetchProduct);
  }

  Future<void> _onCreateProduct(
    CreateProductEvent event,
    Emitter<SupabaseProductState> emit,
  ) async {
    emit(SupabaseProductLoading());
    try {
      final product = await _repository.createProduct(event.product);
      emit(
        SupabaseProductSuccess(
          product: product,
          message: 'Product created successfully',
        ),
      );
    } catch (e) {
      emit(SupabaseProductError('Failed to create product: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateProduct(
    UpdateProductEvent event,
    Emitter<SupabaseProductState> emit,
  ) async {
    emit(SupabaseProductLoading());
    try {
      final product = await _repository.updateProduct(event.product);
      emit(
        SupabaseProductSuccess(
          product: product,
          message: 'Product updated successfully',
        ),
      );
    } catch (e) {
      emit(SupabaseProductError('Failed to update product: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteProduct(
    DeleteProductEvent event,
    Emitter<SupabaseProductState> emit,
  ) async {
    emit(SupabaseProductLoading());
    try {
      await _repository.deleteProduct(event.productId);
      emit(SupabaseProductDeleteSuccess(productId: event.productId));
    } catch (e) {
      emit(SupabaseProductError('Failed to delete product: ${e.toString()}'));
    }
  }

  Future<void> _onFetchProduct(
    FetchProductEvent event,
    Emitter<SupabaseProductState> emit,
  ) async {
    emit(SupabaseProductLoading());
    try {
      final product = await _repository.getProductById(event.productId);
      emit(SupabaseProductFetchSuccess(product: product));
    } catch (e) {
      emit(SupabaseProductError('Failed to fetch product: ${e.toString()}'));
    }
  }
}
