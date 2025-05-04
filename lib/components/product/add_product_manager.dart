import 'package:flutter/material.dart';
import 'product.dart';
import 'editable_product_manager.dart';
import 'product_image_editor.dart';
import '../../utils/product_validators.dart';

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
      editManager.priceController.text = '';
      editManager.descriptionController.text = '';
      editManager.discountController.text = '';
      editManager.category1Controller.text = '';
      editManager.category2Controller.text = '';
      editManager.matchingWordsController.text = '';
      editManager.imageUrlController.text = '';
      editManager.editPopular = false;
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

  /// Cancel adding a new product
  void cancelAddingNewProduct() {
    onStateChanged(() {
      isAddingNewProduct = false;
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
  void saveNewProduct(BuildContext context) {
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

    // Generate a temporary ID (in a real app, this would come from the database)
    final int tempId = DateTime.now().millisecondsSinceEpoch;
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
      matchingWords:
          editManager.matchingWordsController.text.isNotEmpty
              ? editManager.matchingWordsController.text
              : null,
      image: editManager.imageUrlController.text.trim(),
    );

    // Notify parent that a new product has been created
    onProductCreated(newProduct);

    // Reset state
    onStateChanged(() {
      isAddingNewProduct = false;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('New product added: ${newProduct.name}'),
        backgroundColor: Colors.green,
      ),
    );

    // NOTE: In a real app, you would also save to the database here
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
        // Matching words
        return editManager.buildEditableMatchingWordsCell();
      case 12:
        // Actions
        return editManager.buildEditableActionCell(
          () => saveNewProduct(context),
          cancelAddingNewProduct,
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

  // Helper method to build category cells with autocomplete
  Widget _buildEditableCategoryCell(
    BuildContext context,
    TextEditingController controller,
    String label,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return ProductValidators.validCategories;
          }
          return ProductValidators.validCategories.where(
            (category) => category.toLowerCase().contains(
              textEditingValue.text.toLowerCase(),
            ),
          );
        },
        onSelected: (String selection) {
          onStateChanged(() {
            controller.text = selection;
          });
        },
        fieldViewBuilder: (
          BuildContext context,
          TextEditingController fieldController,
          FocusNode fieldFocusNode,
          VoidCallback onFieldSubmitted,
        ) {
          // Sync the autocomplete controller with our actual controller
          fieldController.text = controller.text;

          return TextField(
            controller: fieldController,
            focusNode: fieldFocusNode,
            style: const TextStyle(fontSize: 13.0),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 10,
              ),
              border: InputBorder.none,
              hintText: label,
              suffixIcon: const Icon(Icons.arrow_drop_down, size: 16),
            ),
            onChanged: (value) {
              // Update our actual controller when text changes
              controller.text = value;
            },
          );
        },
        optionsViewBuilder: (
          BuildContext context,
          AutocompleteOnSelected<String> onSelected,
          Iterable<String> options,
        ) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 200,
                  maxWidth: 200,
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String option = options.elementAt(index);
                    return InkWell(
                      onTap: () {
                        onSelected(option);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          option,
                          style: const TextStyle(fontSize: 13.0),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
