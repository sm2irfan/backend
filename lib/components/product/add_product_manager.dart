import 'package:flutter/material.dart';
import 'product.dart';
import 'editable_product_manager.dart';
import 'product_image_editor.dart';
import 'product_validators.dart';
import 'supabase_product_bloc.dart'; // Add import for Supabase product
import 'connectivity_helper.dart';
import '../../data/local_database.dart'; // Add import for local database

/// A class to manage adding new products in the product table
class AddProductManager {
  // State variables
  bool isAddingNewProduct = false;
  final EditableProductManager editManager;
  final ScrollController scrollController;

  // Callback for when a new product is created
  final Function(Product) onProductCreated;

  // Add a state change callback
  final Function(Function()) onStateChanged;

  // Constructor
  AddProductManager({
    required this.editManager,
    required this.scrollController,
    required this.onProductCreated,
    required this.onStateChanged,
  });

  /// Button to add a new product
  Widget buildAddProductButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('Add Product'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      onPressed: startAddingNewProduct,
    );
  }

  /// Start adding a new product
  void startAddingNewProduct() {
    // If already editing, cancel it first
    if (editManager.editingProduct != null) {
      editManager.cancelEditing();
    }

    // Use the callback to update parent's state
    onStateChanged(() {
      // Initialize form with empty values
      isAddingNewProduct = true;
      editManager.nameController.text = '';
      editManager.priceController.text = '[{"id":"1","price":"100","unit":"Kg"}]'; // Initial template
      editManager.descriptionController.text = '';
      editManager.discountController.text = '';
      editManager.category1Controller.text = '';
      editManager.category2Controller.text = '';
      editManager.matchingWordsController.text = '';
      editManager.imageUrlController.text = '';
      editManager.editPopular = false;
      editManager.editProduction = false; // Initialize production field
    });

    // Scroll to top to see the new row
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Cancel adding a new product with confirmation
  void cancelAddingNewProduct(BuildContext context) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.info_outline,
          color: Colors.blue,
          size: 48,
        ),
        title: const Text(
          'Cancel Adding Product',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel adding this product?',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              'All entered information will be lost.',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'NO, CONTINUE',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'YES, CANCEL',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        onStateChanged(() {
          isAddingNewProduct = false;
        });
      }
    });
  }

  /// Check if currently adding a new product and cancel if needed
  void checkAndCancelAddNewProduct() {
    if (isAddingNewProduct) {
      onStateChanged(() {
        isAddingNewProduct = false;
      });
    }
  }

  /// Save the new product
  void saveNewProduct(BuildContext context) async {
    // Prepare values for validation
    String priceValue = editManager.priceController.text.trim();
    if (priceValue.isEmpty) {
      priceValue = '0'; // Default value
    }

    // Validate all product fields
    final validationResult = ProductValidators.validateProduct(
      price: priceValue,
      discount:
          editManager.discountController.text.isNotEmpty
              ? editManager.discountController.text
              : null,
      category1:
          editManager.category1Controller.text.isNotEmpty
              ? editManager.category1Controller.text
              : null,
      category2:
          editManager.category2Controller.text.isNotEmpty
              ? editManager.category2Controller.text
              : null,
      name: editManager.nameController.text.trim(),
      description: editManager.descriptionController.text.trim(),
      image: editManager.imageUrlController.text.trim(),
    );

    // Show error and return if validation failed
    if (!validationResult.isValid) {
      ProductValidators.showValidationError(context, validationResult);
      return;
    }

    // Use a temporary placeholder ID until the database assigns a real one
    const int tempId = -1;
    final DateTime now = DateTime.now();

    // Create a new product with entered values
    final newProduct = Product(
      id: tempId,
      createdAt: now,
      updatedAt: now,
      name: editManager.nameController.text.trim(),
      uPrices: priceValue,
      description: editManager.descriptionController.text.trim(),
      discount:
          editManager.discountController.text.isNotEmpty
              ? int.tryParse(editManager.discountController.text)
              : null,
      category1:
          editManager.category1Controller.text.isNotEmpty
              ? editManager.category1Controller.text
              : null,
      category2:
          editManager.category2Controller.text.isNotEmpty
              ? editManager.category2Controller.text
              : null,
      popularProduct: editManager.editPopular,
      production: editManager.editProduction, // Add production field
      matchingWords:
          editManager.matchingWordsController.text.isNotEmpty
              ? editManager.matchingWordsController.text
              : null,
      image: editManager.imageUrlController.text.trim(),
    );

    // Print the new product details to console for debugging
    print('New product created: $newProduct');

    // Check internet connectivity BEFORE saving
    final hasConnection = await ConnectivityHelper.hasInternetConnection();

    if (!hasConnection) {
      // Show connectivity error with options
      _showNewProductConnectivityDialog(context, newProduct);
      return;
    }

    try {
      // Save the product to Supabase and get the updated product with real ID
      final int dbGeneratedId = await _saveProductToSupabase(
        context,
        newProduct,
      );

      // Create an updated product with the real database ID
      final updatedProduct = Product(
        id: dbGeneratedId, // Use the real ID from the database
        createdAt: newProduct.createdAt,
        updatedAt: newProduct.updatedAt,
        name: newProduct.name,
        uPrices: newProduct.uPrices,
        description: newProduct.description,
        discount: newProduct.discount,
        category1: newProduct.category1,
        category2: newProduct.category2,
        popularProduct: newProduct.popularProduct,
        matchingWords: newProduct.matchingWords,
        image: newProduct.image,
      );

      print('Product ID updated from temporary to: $dbGeneratedId');

      // Save the updated product with real ID to local database
      await _saveProductToLocalDatabase(context, updatedProduct);

      // Notify parent that a new product has been created with real ID
      onProductCreated(updatedProduct);

      // Reset state
      onStateChanged(() {
        isAddingNewProduct = false;
      });

      // Show success message only if context is still mounted
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New product added: ${newProduct.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      // Show error message if Supabase save failed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );

      // Still notify parent with temporary ID
      onProductCreated(newProduct);

      // Reset state
      onStateChanged(() {
        isAddingNewProduct = false;
      });
    }
  }

  // Show dialog with options when no internet connection for new product
  void _showNewProductConnectivityDialog(
    BuildContext context,
    Product newProduct,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.orange),
              SizedBox(width: 8),
              Text('No Internet Connection'),
            ],
          ),
          content: const Text(
            'Unable to save new product to cloud. You can:\n\n'
            '• Try again when internet is available\n'
            '• Save locally only (product won\'t sync to cloud until connected)',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Keep in add mode - don't cancel adding
              },
              child: const Text('Try Again Later'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Retry connectivity check
                saveNewProduct(context);
              },
              child: const Text('Retry Now'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Save locally without cloud sync
                _proceedWithLocalNewProductOnly(context, newProduct);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Locally Only'),
            ),
          ],
        );
      },
    );
  }

  // Save new product locally only (when user chooses to save without internet)
  Future<void> _proceedWithLocalNewProductOnly(
    BuildContext context,
    Product newProduct,
  ) async {
    try {
      // Save only to local database with temporary ID
      final success = await _saveProductToLocalDatabase(context, newProduct);

      if (success) {
        // Notify parent that a new product has been created
        onProductCreated(newProduct);

        // Reset state
        onStateChanged(() {
          isAddingNewProduct = false;
        });

        // Show warning message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'New product saved locally: ${newProduct.name} (will sync when connected)',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save product locally'),
            backgroundColor: Colors.red,
          ),
        );
        // Keep in add mode since save failed
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving locally: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      // Keep in add mode since save failed
    }
  }

  // Save a product to Supabase database and return the generated ID
  Future<int> _saveProductToSupabase(
    BuildContext context,
    Product product,
  ) async {
    // Create a Supabase repository
    final SupabaseProductRepository supabaseRepo = SupabaseProductRepository();

    // Convert Product to SupabaseProduct
    final supabaseProduct = SupabaseProduct(
      id: -1, // This will be ignored/replaced by Supabase
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
      name: product.name,
      uPrices: product.uPrices,
      description: product.description,
      discount: product.discount,
      category1: product.category1,
      category2: product.category2,
      popularProduct: product.popularProduct,
      matchingWords: product.matchingWords,
      image: product.image,
      production: product.production, // Add production field
    );

    // Create the product in Supabase
    final createdProduct = await supabaseRepo.createProduct(supabaseProduct);

    // Log the result
    print(
      'Product successfully created in Supabase with ID: ${createdProduct.id}, production: ${createdProduct.production}',
    );

    // Show success notification
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product synced to Supabase: ${product.name}'),
          backgroundColor: Colors.green,
        ),
      );
    }

    // Return the database-generated ID
    return createdProduct.id;
  }

  // Save a product to the local database
  Future<bool> _saveProductToLocalDatabase(
    BuildContext context,
    Product product,
  ) async {
    try {
      // Create local database instance
      final LocalDatabase localDB = LocalDatabase();

      // Use insertProduct instead of updateProduct for new products
      final success = await localDB.insertProduct(product);

      // Log result
      if (success) {
        print(
          'Product successfully saved to local database with ID: ${product.id}',
        );
      } else {
        print('Failed to save product to local database');
      }

      return success;
    } catch (error) {
      // Log the error
      print('Error saving product to local database: $error');

      // Show error notification if context is still valid
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save to local database: ${error.toString()}',
            ),
            backgroundColor:
                Colors
                    .orange, // Use different color to distinguish from Supabase errors
          ),
        );
      }

      return false;
    }
  }

  /// Build a cell for a new product row
  Widget buildNewProductCell(
    BuildContext context,
    int columnIndex,
    TextStyle textStyle,
  ) {
    switch (columnIndex) {
      case 0:
        // ID field - auto-generated
        return _buildSimpleTextCell(
          'Auto-generated',
          textStyle.copyWith(fontStyle: FontStyle.italic, color: Colors.grey),
        );
      case 1:
        // Created At - auto-generated
        return _buildSimpleTextCell(
          'Auto-generated',
          textStyle.copyWith(fontStyle: FontStyle.italic, color: Colors.grey),
        );
      case 2:
        // Updated At - auto-generated
        return _buildSimpleTextCell(
          'Auto-generated',
          textStyle.copyWith(fontStyle: FontStyle.italic, color: Colors.grey),
        );
      case 3:
        // Image - now with editor functionality
        return _buildImageCell(context);
      case 4:
        // Product Name
        return editManager.buildEditableNameCell();
      case 5:
        // Price
        return editManager.buildEditablePriceCell();
      case 6:
        // Description
        return editManager.buildEditableDescriptionCell();
      case 7:
        // Discount
        return editManager.buildEditableDiscountCell();
      case 8:
        // Category 1 with autocomplete
        return ProductValidators.buildEditableCategoryCell(
          context,
          editManager.category1Controller,
          "Category 1",
          onStateChanged,
        );
      case 9:
        // Category 2 with autocomplete
        return ProductValidators.buildEditableCategoryCell(
          context,
          editManager.category2Controller,
          "Category 2",
          onStateChanged,
        );
      case 10:
        // Popular
        return editManager.buildEditablePopularCell((value) {
          onStateChanged(() {
            editManager.editPopular = value ?? false;
          });
        });
      case 11:
        // Production
        return editManager.buildEditableProductionCell((value) {
          onStateChanged(() {
            editManager.editProduction = value ?? false;
          });
        });
      case 12:
        // Matching words (shifted)
        return editManager.buildEditableMatchingWordsCell();
      case 13:
        // Actions (shifted)
        return editManager.buildEditableActionCell(
          () => saveNewProduct(context),
          () => cancelAddingNewProduct(context),
        );
      default:
        return const SizedBox();
    }
  }

  // Helper method to build simple text cells
  Widget _buildSimpleTextCell(String text, TextStyle style) {
    return SelectableText(text, style: style);
  }

  // New method to build an image cell with editor functionality
  Widget _buildImageCell(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _editImage(context),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Show image preview or placeholder icon
            editManager.imageUrlController.text.isNotEmpty
                ? ProductImageEditor.buildCachedImage(
                  imageUrl: editManager.imageUrlController.text,
                  fit: BoxFit.cover,
                  width: 40,
                  height: 40,
                )
                : const Center(child: Icon(Icons.image, color: Colors.grey)),

            // Overlay edit icon on hover
            Container(
              width: 40,
              height: 40,
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Icon(Icons.edit, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Method to open the image editor
  void _editImage(BuildContext context) {
    // Create a temporary product to pass to the image editor
    final tempProduct = Product(
      id: -1, // Temporary ID
      name:
          editManager.nameController.text.isEmpty
              ? 'New Product'
              : editManager.nameController.text,
      uPrices: '0',
      createdAt: DateTime.now(),
      image: editManager.imageUrlController.text,
      popularProduct: editManager.editPopular,
    );

    // Show the same image editor dialog used for existing products
    ProductImageEditor.showEditDialog(context, tempProduct, (_, String newUrl) {
      // Update the image URL in the edit manager
      onStateChanged(() {
        editManager.imageUrlController.text = newUrl;
      });
    });
  }
}
