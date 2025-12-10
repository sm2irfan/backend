import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'product_details.dart';

/// Mobile-optimized product details dialog with vertical card layout
class MobileProductDetailsDialog extends StatefulWidget {
  final String productName;
  final String compositeId;
  final List<ProductDetails> productDetailsList;
  final VoidCallback? onStockUpdated;

  const MobileProductDetailsDialog({
    Key? key,
    required this.productName,
    required this.compositeId,
    required this.productDetailsList,
    this.onStockUpdated,
  }) : super(key: key);

  @override
  _MobileProductDetailsDialogState createState() => _MobileProductDetailsDialogState();
}

class _MobileProductDetailsDialogState extends State<MobileProductDetailsDialog> {
  late List<ProductDetails> _productDetailsList;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _productDetailsList = List.from(widget.productDetailsList);
    _productDetailsList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final updatedList = await ProductDetailsService.getProductDetailsByCompositeId(widget.compositeId);
      setState(() {
        _productDetailsList = updatedList;
        _productDetailsList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
      widget.onStockUpdated?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddEditProductDetailDialog(
        compositeId: widget.compositeId,
        onSaved: _refreshData,
      ),
    );
  }

  void _showEditDialog(ProductDetails detail) {
    showDialog(
      context: context,
      builder: (context) => _AddEditProductDetailDialog(
        compositeId: widget.compositeId,
        detail: detail,
        onSaved: _refreshData,
      ),
    );
  }

  Future<void> _deleteDetail(ProductDetails detail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this purchase record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await ProductDetailsService.deleteProductDetail(detail.id);
        await _refreshData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Record deleted successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting record: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.productName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '📱 Mobile Purchase History Dialog',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Composite ID
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  const Icon(Icons.tag, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ID: ${widget.compositeId}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _productDetailsList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'No purchase records yet',
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _showAddDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Record'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _productDetailsList.length,
                          itemBuilder: (context, index) {
                            final detail = _productDetailsList[index];
                            return _buildMobileDetailCard(detail, index);
                          },
                        ),
            ),
            // Footer with Add button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _showAddDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Record'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isLoading ? null : _refreshData,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDetailCard(ProductDetails detail, int index) {
    final isEven = index % 2 == 0;
    final backgroundColor = isEven ? Colors.blue.shade50 : Colors.green.shade50;
    final borderColor = isEven ? Colors.blue.shade300 : Colors.green.shade300;
    final headerColor = isEven ? Colors.blue.shade700 : Colors.green.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with record number
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Purchase Record #${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Attributes
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildAttributeRow('ID', detail.id.toString(), Icons.tag),
                  _buildAttributeRow('Identity ID', detail.identityId, Icons.fingerprint),
                  _buildAttributeRow('Quantity', detail.quantity.toString(), Icons.inventory),
                  _buildAttributeRow('Unit', detail.unit, Icons.scale),
                  _buildAttributeRow('Price', detail.price.toString(), Icons.attach_money),
                  _buildAttributeRow('Supplier', detail.supplier, Icons.business),
                  _buildAttributeRow('Expire Date', _formatDate(detail.expireDate), Icons.event),
                  _buildAttributeRow('Created At', _formatDateTime(detail.createdAt), Icons.access_time),
                ],
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showEditDialog(detail),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _deleteDetail(detail),
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributeRow(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blue.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Add/Edit Product Detail Dialog
class _AddEditProductDetailDialog extends StatefulWidget {
  final String compositeId;
  final ProductDetails? detail;
  final VoidCallback onSaved;

  const _AddEditProductDetailDialog({
    required this.compositeId,
    this.detail,
    required this.onSaved,
  });

  @override
  State<_AddEditProductDetailDialog> createState() => _AddEditProductDetailDialogState();
}

class _AddEditProductDetailDialogState extends State<_AddEditProductDetailDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _quantityController;
  late TextEditingController _unitController;
  late TextEditingController _priceController;
  late TextEditingController _supplierController;
  late TextEditingController _expireDateController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.detail?.quantity.toString() ?? '',
    );
    _unitController = TextEditingController(
      text: widget.detail?.unit ?? '',
    );
    _priceController = TextEditingController(
      text: widget.detail?.price.toString() ?? '',
    );
    _supplierController = TextEditingController(
      text: widget.detail?.supplier ?? '',
    );
    _expireDateController = TextEditingController(
      text: widget.detail != null 
        ? DateFormat('yyyy-MM-dd').format(widget.detail!.expireDate)
        : DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 365))),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _supplierController.dispose();
    _expireDateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Parse the date from the text field
      final DateTime expireDate;
      try {
        expireDate = DateTime.parse(_expireDateController.text);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid date format. Use YYYY-MM-DD'), backgroundColor: Colors.red),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      final productDetail = ProductDetails(
        id: widget.detail?.id ?? 0,
        identityId: widget.compositeId,
        quantity: int.parse(_quantityController.text),
        unit: _unitController.text,
        price: double.parse(_priceController.text),
        supplier: _supplierController.text,
        expireDate: expireDate,
        createdAt: widget.detail?.createdAt ?? DateTime.now(),
      );

      if (widget.detail == null) {
        // Create new
        await ProductDetailsService.createProductDetail(productDetail);
      } else {
        // Update existing
        await ProductDetailsService.updateProductDetail(productDetail);
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.detail == null ? 'Record added successfully' : 'Record updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.detail == null ? Icons.add : Icons.edit,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.detail == null ? 'Add New Record' : 'Edit Record',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      prefixIcon: Icon(Icons.inventory),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      if (int.tryParse(value) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      prefixIcon: Icon(Icons.scale),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      if (double.tryParse(value) == null) return 'Invalid price';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _supplierController,
                    decoration: const InputDecoration(
                      labelText: 'Supplier',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _expireDateController,
                    decoration: const InputDecoration(
                      labelText: 'Expire Date (YYYY-MM-DD)',
                      prefixIcon: Icon(Icons.event),
                      border: OutlineInputBorder(),
                      hintText: '2025-12-31',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      // Validate YYYY-MM-DD format
                      final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                      if (!dateRegex.hasMatch(value)) {
                        return 'Use format: YYYY-MM-DD';
                      }
                      // Try parsing to ensure valid date
                      try {
                        DateTime.parse(value);
                      } catch (e) {
                        return 'Invalid date';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
