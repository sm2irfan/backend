import 'dart:convert';
import 'package:flutter/material.dart';
import 'product.dart';
import 'product_details.dart';

/// Mobile-friendly product detail page showing full product information
class MobileProductDetailPage extends StatelessWidget {
  final Product product;

  const MobileProductDetailPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('📱 ${product.name}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Name Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_android, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '📱 Mobile Product Detail Page',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Product Header Card
            _buildHeaderCard(),
            const SizedBox(height: 16),
            
            // Product Image
            if (product.image != null && product.image!.isNotEmpty)
              _buildImageSection(),
            
            const SizedBox(height: 16),
            
            // Basic Information
            _buildSectionTitle('Basic Information', Icons.info_outline),
            const SizedBox(height: 8),
            _buildInfoCard([
              _buildInfoRow('Product ID', '#${product.id}', Icons.tag),
              _buildInfoRow('Name', product.name, Icons.shopping_bag),
              _buildInfoRow('Category', product.category1 ?? 'N/A', Icons.category),
              if (product.category2 != null && product.category2!.isNotEmpty)
                _buildInfoRow('Category 2', product.category2!, Icons.category_outlined),
              _buildInfoRow('Description', product.description ?? 'N/A', Icons.description),
            ]),
            
            const SizedBox(height: 16),
            
            // Status & Flags
            _buildSectionTitle('Status & Flags', Icons.flag),
            const SizedBox(height: 8),
            _buildInfoCard([
              _buildStatusRow('Production', product.production, Icons.factory),
              _buildStatusRow('Popular Product', product.popularProduct, Icons.star),
              _buildInfoRow('Discount', product.discount != null ? '${product.discount}%' : 'None', Icons.local_offer),
            ]),
            
            const SizedBox(height: 16),
            
            // Dates
            _buildSectionTitle('Timestamps', Icons.access_time),
            const SizedBox(height: 8),
            _buildInfoCard([
              _buildInfoRow('Created At', _formatDateTime(product.createdAt), Icons.calendar_today),
              _buildInfoRow('Updated At', _formatDateTime(product.updatedAt), Icons.update),
            ]),
            
            const SizedBox(height: 16),
            
            // Prices Section with Purchase Details
            _buildSectionTitle('Prices & Stock', Icons.attach_money),
            const SizedBox(height: 8),
            _buildPricesSection(context),
            
            const SizedBox(height: 16),
            
            // Matching Words
            if (product.matchingWords != null && product.matchingWords!.isNotEmpty) ...[
              _buildSectionTitle('Matching Words', Icons.text_fields),
              const SizedBox(height: 8),
              _buildInfoCard([
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    product.matchingWords!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 4,
      color: Colors.blue.shade700,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.inventory_2, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: #${product.id}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
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

  Widget _buildImageSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.image, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Product Image',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            height: 250,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: Image.network(
                product.image!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 64, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Failed to load image'),
                      ],
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
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

  Widget _buildStatusRow(String label, bool status, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: status ? Colors.green.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  status ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: status ? Colors.green.shade700 : Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  status ? 'Yes' : 'No',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: status ? Colors.green.shade700 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricesSection(BuildContext context) {
    List<dynamic> priceList = [];
    try {
      if (product.uPrices.isEmpty || product.uPrices == 'null') {
        priceList = [];
      } else {
        priceList = jsonDecode(product.uPrices);
      }
    } catch (e) {
      priceList = [];
    }

    if (priceList.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.money_off, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'No prices available',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Check for global stock
    bool hasGlobalStock = false;
    int globalStockValue = 0;
    Map<String, dynamic>? globalStockItem;

    for (var priceItem in priceList) {
      if (priceItem is Map<String, dynamic>) {
        if (priceItem.containsKey('global_stock') &&
            priceItem['global_stock'] != null) {
          hasGlobalStock = true;
          globalStockValue = int.tryParse(priceItem['global_stock'].toString()) ?? 0;
          globalStockItem = priceItem;
          break;
        }
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasGlobalStock && globalStockItem != null)
              _buildPriceItem(context, globalStockItem, 0, isGlobal: true, globalStock: globalStockValue)
            else
              ...List.generate(
                priceList.length,
                (index) => _buildPriceItem(context, priceList[index], index),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceItem(BuildContext context, Map<String, dynamic> priceItem, int index,
      {bool isGlobal = false, int globalStock = 0}) {
    final price = priceItem['price'] ?? '';
    final unit = priceItem['unit'] ?? '';
    final oldPrice = priceItem['old_price'];
    final priceItemId = priceItem['id'];
    final hasId = priceItemId != null && priceItemId.toString().isNotEmpty;

    String stockText = '';
    Color stockColor = Colors.grey;
    
    if (isGlobal) {
      stockText = 'Global Stock: $globalStock';
      stockColor = Colors.green;
    } else if (priceItem.containsKey('sole_stock') &&
        priceItem['sole_stock'] != null &&
        priceItem['sole_stock'].toString().isNotEmpty) {
      stockText = 'Sole Stock: ${priceItem['sole_stock']}';
      stockColor = Colors.blue;
    } else if (priceItem.containsKey('stock') &&
        priceItem['stock'] != null &&
        priceItem['stock'].toString().isNotEmpty) {
      stockText = 'Stock: ${priceItem['stock']}';
      stockColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: !hasId
            ? Colors.red.shade50
            : oldPrice != null
            ? Colors.orange.shade50
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: !hasId
              ? Colors.red.shade300
              : oldPrice != null
              ? Colors.orange.shade300
              : Colors.green.shade300,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: !hasId
                  ? Colors.red.shade100
                  : oldPrice != null
                  ? Colors.orange.shade100
                  : Colors.green.shade100,
              child: Icon(
                Icons.attach_money,
                color: !hasId
                    ? Colors.red.shade700
                    : oldPrice != null
                    ? Colors.orange.shade700
                    : Colors.green.shade700,
              ),
            ),
            title: Text(
              '$price / $unit',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: !hasId ? Colors.red.shade900 : Colors.black87,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stockText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: stockColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      stockText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
                if (!hasId) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.warning, size: 14, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Missing ID - Cannot view details',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (hasId)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ProductDetailsButtonHandler.handlePriceButtonClick(
                      context: context,
                      productId: product.id,
                      productName: product.name,
                      priceItem: priceItem,
                      priceIndex: index,
                      onStockTypeAdded: () {},
                      onDataFetched: (List<ProductDetails> productDetailsList) {
                        ProductDetailsButtonHandler.showProductDetailsDialog(
                          context: context,
                          productName: product.name,
                          compositeId: ProductDetailsService.generateCompositeId(
                            product.id,
                            priceItemId.toString(),
                          ),
                          productDetailsList: productDetailsList,
                          onStockUpdated: () {},
                        );
                      },
                      onError: (String error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error), backgroundColor: Colors.red),
                          );
                        }
                      },
                    );
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('View Purchase Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
