import 'dart:convert';
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
  
  // Track which index to add ID/old_price to next
  int _nextIdIndex = 0;
  int _nextOldPriceIndex = 0;

  void startEditing(Product product) {
    editingProduct = product;
    nameController.text = product.name;
    // If uPrices is empty or null, provide initial template
    if (product.uPrices.isEmpty || product.uPrices == 'null' || product.uPrices == '[]') {
      priceController.text = '[{"id":"1","price":"100","unit":"Kg"}]';
    } else {
      priceController.text = product.uPrices.toString();
    }
    descriptionController.text = product.description ?? '';
    discountController.text = product.discount?.toString() ?? '';
    category1Controller.text = product.category1 ?? '';
    category2Controller.text = product.category2 ?? '';
    matchingWordsController.text = product.matchingWords ?? '';
    imageUrlController.text =
        product.image ?? ''; // Initialize image URL controller
    editPopular = product.popularProduct;
    editProduction = product.production; // Initialize production value
    _nextIdIndex = 0; // Reset counters when starting to edit
    _nextOldPriceIndex = 0;
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
      constraints: const BoxConstraints(maxWidth: 300, minWidth: 250),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action buttons row
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.tag, size: 14),
                label: const Text('Add ID', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 28),
                ),
                onPressed: () => _addIdToAllItems(priceController),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.history, size: 14),
                label: const Text('Add Old Price', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 28),
                ),
                onPressed: () => _addOldPriceToAllItems(priceController),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Text field
          Expanded(
            child: TextFormField(
              controller: priceController,
              style: const TextStyle(fontSize: 11.0, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              keyboardType: TextInputType.multiline,
              maxLines: null,
              expands: true,
            ),
          ),
        ],
      ),
    );
  }

  void _addIdToAllItems(TextEditingController controller) {
    final jsonText = controller.text.trim();
    
    try {
      final decoded = jsonDecode(jsonText);
      
      if (decoded is! List) {
        return; // Silently ignore non-array JSON
      }
      
      // If we've already processed all items, reset to start
      if (_nextIdIndex >= decoded.length) {
        _nextIdIndex = 0;
      }
      
      List<Map<String, dynamic>> updatedList = [];
      for (int i = 0; i < decoded.length; i++) {
        if (decoded[i] is Map<String, dynamic>) {
          Map<String, dynamic> item = Map<String, dynamic>.from(decoded[i]);
          Map<String, dynamic> newItem = {};
          
          // Add id only to the current index
          if (i == _nextIdIndex) {
            newItem['id'] = '${i + 1}';
          } else if (item.containsKey('id')) {
            // Preserve existing id for other items
            newItem['id'] = item['id'];
          }
          
          // Add other properties
          item.forEach((key, value) {
            if (key != 'id') {
              newItem[key] = value;
            }
          });
          
          updatedList.add(newItem);
        }
      }
      
      _nextIdIndex++; // Move to next item for next click
      
      const encoder = JsonEncoder.withIndent('  ');
      controller.text = encoder.convert(updatedList);
    } catch (e) {
      // Silently ignore errors in desktop view
    }
  }

  void _addOldPriceToAllItems(TextEditingController controller) {
    final jsonText = controller.text.trim();
    
    try {
      final decoded = jsonDecode(jsonText);
      
      if (decoded is! List) {
        return; // Silently ignore non-array JSON
      }
      
      // If we've already processed all items, reset to start
      if (_nextOldPriceIndex >= decoded.length) {
        _nextOldPriceIndex = 0;
      }
      
      List<Map<String, dynamic>> updatedList = [];
      for (int i = 0; i < decoded.length; i++) {
        if (decoded[i] is Map<String, dynamic>) {
          Map<String, dynamic> item = Map<String, dynamic>.from(decoded[i]);
          Map<String, dynamic> newItem = {};
          
          // Preserve id if exists
          if (item.containsKey('id')) {
            newItem['id'] = item['id'];
          }
          
          // Add other properties except old_price
          item.forEach((key, value) {
            if (key != 'id' && key != 'old_price') {
              newItem[key] = value;
            }
          });
          
          // Add old_price only to the current index
          if (i == _nextOldPriceIndex) {
            newItem['old_price'] = '1';
          } else if (item.containsKey('old_price')) {
            // Preserve existing old_price for other items
            newItem['old_price'] = item['old_price'];
          }
          
          updatedList.add(newItem);
        }
      }
      
      _nextOldPriceIndex++; // Move to next item for next click
      
      const encoder = JsonEncoder.withIndent('  ');
      controller.text = encoder.convert(updatedList);
    } catch (e) {
      // Silently ignore errors in desktop view
    }
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
          tooltip: 'Save changes (requires internet for cloud sync)',
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
