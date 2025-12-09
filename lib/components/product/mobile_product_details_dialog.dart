import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _productDetailsList = List.from(widget.productDetailsList);
    _productDetailsList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
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
              child: _productDetailsList.isEmpty
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
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
