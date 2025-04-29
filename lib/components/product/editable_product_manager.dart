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
  bool editPopular = false;

  void startEditing(Product product) {
    editingProduct = product;
    nameController.text = product.name;
    priceController.text = product.uPrices.toString();
    descriptionController.text = product.description ?? '';
    discountController.text = product.discount?.toString() ?? '';
    category1Controller.text = product.category1 ?? '';
    category2Controller.text = product.category2 ?? '';
    editPopular = product.popularProduct;
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
  }

  // Build editable cells for the table
  Widget buildEditableNameCell(Product product, Widget thumbnail) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 250),
      child: TextField(
        controller: nameController,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget buildEditablePriceCell() {
    return TextFormField(
      controller: priceController,
      decoration: const InputDecoration(
        isDense: true,
        prefix: Text('\$'),
        contentPadding: EdgeInsets.symmetric(vertical: 8),
        border: InputBorder.none, // Remove border
      ),
      keyboardType: TextInputType.number,
    );
  }

  Widget buildEditableDescriptionCell() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Container(
        height: 80, // Increased height for multiple lines
        child: TextFormField(
          controller: descriptionController,
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
    return TextFormField(
      controller: discountController,
      decoration: const InputDecoration(
        isDense: true,
        suffix: Text('%'),
        contentPadding: EdgeInsets.symmetric(vertical: 8),
        border: InputBorder.none, // Remove border
      ),
      keyboardType: TextInputType.number,
    );
  }

  Widget buildEditableCategory1Cell() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: TextFormField(
        controller: category1Controller,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          border: InputBorder.none, // Remove border
        ),
      ),
    );
  }

  Widget buildEditableCategory2Cell() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: TextFormField(
        controller: category2Controller,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          border: InputBorder.none, // Remove border
        ),
      ),
    );
  }

  Widget buildEditablePopularCell(Function(bool?) onChanged) {
    return Checkbox(value: editPopular, onChanged: onChanged);
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
