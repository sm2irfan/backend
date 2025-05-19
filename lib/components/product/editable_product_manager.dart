import 'package:flutter/material.dart';
import 'product.dart';

class EditableProductManager {
  // Track which product is being edited (null if none)
  Product? editingProduct;

  // Controllers for editable fields
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController discountController = TextEditingController();
  final TextEditingController category1Controller = TextEditingController();
  final TextEditingController category2Controller = TextEditingController();
  final TextEditingController matchingWordsController = TextEditingController();
  final TextEditingController imageUrlController =
      TextEditingController(); // Add image URL controller
  bool editPopular = false;
  bool editProduction = false; // Add production field

  void startEditing(Product product) {
    editingProduct = product;
    nameController.text = product.name;
    priceController.text = product.uPrices.toString();
    descriptionController.text = product.description ?? '';
    discountController.text = product.discount?.toString() ?? '';
    category1Controller.text = product.category1 ?? '';
    category2Controller.text = product.category2 ?? '';
    matchingWordsController.text = product.matchingWords ?? '';
    imageUrlController.text =
        product.image ?? ''; // Initialize image URL controller
    editPopular = product.popularProduct;
    editProduction = product.production; // Initialize production value
  }

  void cancelEditing() {
    editingProduct = null;
  }

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    discountController.dispose();
    category1Controller.dispose();
    category2Controller.dispose();
    matchingWordsController.dispose();
    imageUrlController.dispose(); // Dispose image URL controller
  }

  // Build editable cells for the table
  Widget buildEditableNameCell() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 250),
      child: SizedBox(
        height: 80,
        child: TextFormField(
          controller: nameController,
          style: const TextStyle(fontSize: 13.0),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            border: InputBorder.none,
            alignLabelWithHint: true,
          ),
          maxLines: null,
          keyboardType: TextInputType.multiline,
          expands: true,
        ),
      ),
    );
  }

  Widget buildEditablePriceCell() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: SizedBox(
        height: 80,
        child: TextFormField(
          controller: priceController,
          style: const TextStyle(fontSize: 13.0),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            border: InputBorder.none,
            alignLabelWithHint: true,
          ),
          keyboardType: TextInputType.multiline,
          maxLines: null,
          expands: true, // Fill the available space
        ),
      ),
    );
  }

  Widget buildEditableDescriptionCell() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: SizedBox(
        height: 80, // Increased height for multiple lines
        child: TextFormField(
          controller: descriptionController,
          style: const TextStyle(fontSize: 13.0),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            border: InputBorder.none, // Remove border
            alignLabelWithHint: true,
          ),
          maxLines: null, // Allow unlimited lines
          keyboardType: TextInputType.multiline,
          expands: true, // Fill the available space
        ),
      ),
    );
  }

  Widget buildEditableDiscountCell() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: SizedBox(
        height: 80,
        child: TextFormField(
          controller: discountController,
          style: const TextStyle(fontSize: 13.0),
          decoration: const InputDecoration(
            isDense: true,
            suffix: Text('%'),
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            border: InputBorder.none,
            alignLabelWithHint: true,
          ),
          keyboardType: TextInputType.number,
          maxLines: 1,
          expands: false,
        ),
      ),
    );
  }

  Widget buildEditableCategory1Cell() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: SizedBox(
        height: 80,
        child: TextFormField(
          controller: category1Controller,
          style: const TextStyle(fontSize: 13.0),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            border: InputBorder.none,
            alignLabelWithHint: true,
          ),
          maxLines: null,
          keyboardType: TextInputType.multiline,
          expands: true,
        ),
      ),
    );
  }

  Widget buildEditableCategory2Cell() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: SizedBox(
        height: 80,
        child: TextFormField(
          controller: category2Controller,
          style: const TextStyle(fontSize: 13.0),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            border: InputBorder.none,
            alignLabelWithHint: true,
          ),
          maxLines: null,
          keyboardType: TextInputType.multiline,
          expands: true,
        ),
      ),
    );
  }

  Widget buildEditableMatchingWordsCell() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: SizedBox(
        height: 80,
        child: TextFormField(
          controller: matchingWordsController,
          style: const TextStyle(fontSize: 13.0),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            border: InputBorder.none,
            alignLabelWithHint: true,
          ),
          maxLines: null,
          keyboardType: TextInputType.multiline,
          expands: true,
        ),
      ),
    );
  }

  Widget buildEditablePopularCell(Function(bool?) onChanged) {
    return Checkbox(value: editPopular, onChanged: onChanged);
  }

  Widget buildEditableProductionCell(Function(bool?) onChanged) {
    return Checkbox(value: editProduction, onChanged: onChanged);
  }

  Widget buildEditableActionCell(VoidCallback onSave, VoidCallback onCancel) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check, size: 20, color: Colors.green),
          onPressed: onSave,
          tooltip: 'Save changes',
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 20, color: Colors.red),
          onPressed: onCancel,
          tooltip: 'Cancel editing',
        ),
      ],
    );
  }
}
