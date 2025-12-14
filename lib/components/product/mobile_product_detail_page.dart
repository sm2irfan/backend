import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'product.dart';
import 'product_details.dart';

/// Mobile-friendly product detail page showing full product information
class MobileProductDetailPage extends StatefulWidget {
  final Product product;

  const MobileProductDetailPage({super.key, required this.product});

  @override
  State<MobileProductDetailPage> createState() => _MobileProductDetailPageState();
}

class _MobileProductDetailPageState extends State<MobileProductDetailPage> {
  late TextEditingController _pricesJsonController;
  bool _isEditing = false;
  bool _isSaving = false;
  late bool _production;
  late bool _popularProduct;
  int _nextIdIndex = 0; // Track which element to add ID to next
  int _nextOldPriceIndex = 0; // Track which element to add old_price to next

  @override
  void initState() {
    super.initState();
    _pricesJsonController = TextEditingController(text: _formatJson(widget.product.uPrices));
    _production = widget.product.production;
    _popularProduct = widget.product.popularProduct;
    _nextIdIndex = 0;
    _nextOldPriceIndex = 0;
  }

  @override
  void dispose() {
    _pricesJsonController.dispose();
    super.dispose();
  }

  String _formatJson(String jsonString) {
    if (jsonString.isEmpty || jsonString == 'null') {
      return '[]';
    }
    try {
      final decoded = jsonDecode(jsonString);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (e) {
      return jsonString;
    }
  }

  bool _validateJson(String jsonString) {
    try {
      jsonDecode(jsonString);
      return true;
    } catch (e) {
      return false;
    }
  }

  void _addIdToAllItems() {
    final jsonText = _pricesJsonController.text.trim();
    
    try {
      final decoded = jsonDecode(jsonText);
      
      // Check if it's a list
      if (decoded is! List) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('JSON must be an array!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
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
      
      // Format and update the text field
      const encoder = JsonEncoder.withIndent('  ');
      setState(() {
        _pricesJsonController.text = encoder.convert(updatedList);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ID to item #${_nextIdIndex}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding IDs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addOldPriceToAllItems() {
    final jsonText = _pricesJsonController.text.trim();
    
    try {
      final decoded = jsonDecode(jsonText);
      
      // Check if it's a list
      if (decoded is! List) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('JSON must be an array!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Find the next item that doesn't have old_price
      int targetIndex = -1;
      for (int i = _nextOldPriceIndex; i < decoded.length; i++) {
        if (decoded[i] is Map<String, dynamic>) {
          Map<String, dynamic> item = decoded[i];
          if (!item.containsKey('old_price')) {
            targetIndex = i;
            break;
          }
        }
      }
      
      // If no item found from current index, search from beginning
      if (targetIndex == -1) {
        for (int i = 0; i < _nextOldPriceIndex; i++) {
          if (decoded[i] is Map<String, dynamic>) {
            Map<String, dynamic> item = decoded[i];
            if (!item.containsKey('old_price')) {
              targetIndex = i;
              break;
            }
          }
        }
      }
      
      // If still no item found, all items already have old_price
      if (targetIndex == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All items already have old_price attribute'),
            backgroundColor: Colors.orange,
          ),
        );
        _nextOldPriceIndex = 0; // Reset for next time
        return;
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
          
          // Add other properties
          item.forEach((key, value) {
            if (key != 'id') {
              newItem[key] = value;
            }
          });
          
          // Add old_price only to the target index if it doesn't have it
          if (i == targetIndex && !item.containsKey('old_price')) {
            newItem['old_price'] = '1';
          }
          
          updatedList.add(newItem);
        }
      }
      
      _nextOldPriceIndex = targetIndex + 1; // Move to next item for next click
      
      // Format and update the text field
      const encoder = JsonEncoder.withIndent('  ');
      setState(() {
        _pricesJsonController.text = encoder.convert(updatedList);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added old_price to item #${targetIndex + 1}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding old_price: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveJson() async {
    final jsonText = _pricesJsonController.text.trim();
    
    // Validate JSON
    if (!_validateJson(jsonText)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid JSON format! Please check your syntax.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Update in Supabase
      await Supabase.instance.client
          .from('pre_all_products')
          .update({
            'uprices': jsonText,
            'production': _production,
            'popular_product': _popularProduct,
          })
          .eq('id', widget.product.id);

      setState(() {
        _isEditing = false;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving product: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('📱 ${widget.product.name}'),
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
            
            // Editable Prices JSON Section
            _buildEditablePricesJson(),
            const SizedBox(height: 16),
            
            // Product Header Card
            _buildHeaderCard(),
            const SizedBox(height: 16),
            
            // Product Image
            if (widget.product.image != null && widget.product.image!.isNotEmpty)
              _buildImageSection(),
            
            const SizedBox(height: 16),
            
            // Basic Information
            _buildSectionTitle('Basic Information', Icons.info_outline),
            const SizedBox(height: 8),
            _buildInfoCard([
              _buildInfoRow('Product ID', '#${widget.product.id}', Icons.tag),
              _buildInfoRow('Name', widget.product.name, Icons.shopping_bag),
              _buildInfoRow('Category', widget.product.category1 ?? 'N/A', Icons.category),
              if (widget.product.category2 != null && widget.product.category2!.isNotEmpty)
                _buildInfoRow('Category 2', widget.product.category2!, Icons.category_outlined),
              _buildInfoRow('Description', widget.product.description ?? 'N/A', Icons.description),
            ]),
            
            const SizedBox(height: 16),
            
            // Status & Flags
            _buildSectionTitle('Status & Flags', Icons.flag),
            const SizedBox(height: 8),
            _buildStatusCard(),
            
            const SizedBox(height: 16),
            
            // Dates
            _buildSectionTitle('Timestamps', Icons.access_time),
            const SizedBox(height: 8),
            _buildInfoCard([
              _buildInfoRow('Created At', _formatDateTime(widget.product.createdAt), Icons.calendar_today),
              _buildInfoRow('Updated At', _formatDateTime(widget.product.updatedAt), Icons.update),
            ]),
            
            const SizedBox(height: 16),
            
            // Prices Section with Purchase Details
            _buildSectionTitle('Prices & Stock', Icons.attach_money),
            const SizedBox(height: 8),
            _buildPricesSection(context),
            
            const SizedBox(height: 16),
            
            // Matching Words
            if (widget.product.matchingWords != null && widget.product.matchingWords!.isNotEmpty) ...[
              _buildSectionTitle('Matching Words', Icons.text_fields),
              const SizedBox(height: 8),
              _buildInfoCard([
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    widget.product.matchingWords!,
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

  Widget _buildEditablePricesJson() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.code, size: 24, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prices JSON Data',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                if (!_isEditing)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                      });
                    },
                  ),
              ],
            ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.tag, size: 16),
                    label: const Text('Add ID'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: _addIdToAllItems,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('Add Old Price'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: _addOldPriceToAllItems,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                        _pricesJsonController.text = _formatJson(widget.product.uPrices);
                        _production = widget.product.production;
                        _popularProduct = widget.product.popularProduct;
                        _nextIdIndex = 0; // Reset counters when canceling
                        _nextOldPriceIndex = 0;
                      });
                    },
                  ),
                  ElevatedButton.icon(
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save, size: 16),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: _isSaving ? null : _saveJson,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isEditing ? Colors.white : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isEditing ? Colors.blue.shade300 : Colors.grey.shade300,
                  width: _isEditing ? 2 : 1,
                ),
              ),
              child: _isEditing
                  ? TextField(
                      controller: _pricesJsonController,
                      maxLines: null,
                      minLines: 10,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter valid JSON array...',
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                  : SelectableText(
                      _pricesJsonController.text,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.yellow.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Make sure your JSON is valid before saving',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Production Toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.factory, size: 20, color: Colors.blue.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Production',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Switch(
                    value: _production,
                    onChanged: _isEditing ? (value) {
                      setState(() {
                        _production = value;
                      });
                    } : null,
                    activeColor: Colors.green,
                  ),
                  if (!_isEditing)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _production ? Colors.green.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _production ? 'Yes' : 'No',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _production ? Colors.green.shade700 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Popular Product Toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, size: 20, color: Colors.blue.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Popular Product',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Switch(
                    value: _popularProduct,
                    onChanged: _isEditing ? (value) {
                      setState(() {
                        _popularProduct = value;
                      });
                    } : null,
                    activeColor: Colors.green,
                  ),
                  if (!_isEditing)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _popularProduct ? Colors.green.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _popularProduct ? 'Yes' : 'No',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _popularProduct ? Colors.green.shade700 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Discount (read-only)
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.local_offer, size: 20, color: Colors.blue.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discount',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.product.discount != null ? '${widget.product.discount}%' : 'None',
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
            ),
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
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: #${widget.product.id}',
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
                widget.product.image!,
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
      if (widget.product.uPrices.isEmpty || widget.product.uPrices == 'null') {
        priceList = [];
      } else {
        priceList = jsonDecode(widget.product.uPrices);
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
                      productId: widget.product.id,
                      productName: widget.product.name,
                      priceItem: priceItem,
                      priceIndex: index,
                      onStockTypeAdded: () {},
                      onDataFetched: (String compositeId, List<ProductDetails> productDetailsList) {
                        ProductDetailsButtonHandler.showProductDetailsDialog(
                          context: context,
                          productName: widget.product.name,
                          compositeId: compositeId,
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
