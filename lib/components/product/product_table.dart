import 'package:flutter/material.dart';
import 'product.dart';

// Paginated product table with navigation controls
class PaginatedProductTable extends StatefulWidget {
  final List<Product> products;
  final int currentPage;
  final int totalItems;
  final int pageSize;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final bool isLoading;
  final Function(int) onPageChanged;
  final Function(int) onPageSizeChanged;

  const PaginatedProductTable({
    super.key,
    required this.products,
    required this.currentPage,
    required this.totalItems,
    required this.pageSize,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.isLoading,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  @override
  State<PaginatedProductTable> createState() => _PaginatedProductTableState();
}

class _PaginatedProductTableState extends State<PaginatedProductTable> {
  // ScrollController for horizontal scrolling
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    // Dispose the controller when the widget is disposed
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total pages
    final int totalPages = (widget.totalItems / widget.pageSize).ceil();

    return Container(
      color: Colors.grey[300], // Making the background a bit darker
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Products',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text('Total: ${widget.totalItems} items'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                widget.products.isEmpty
                    ? const Center(child: Text('No products found'))
                    : Stack(
                      children: [
                        SingleChildScrollView(
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            child: Scrollbar(
                              controller: _horizontalScrollController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              thickness: 8,
                              child: SingleChildScrollView(
                                controller: _horizontalScrollController,
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 16.0,
                                  headingRowHeight: 48.0,
                                  dataRowMinHeight: 64.0,
                                  dataRowMaxHeight: 72.0,
                                  columns: const [
                                    DataColumn(label: Text('ID')),
                                    DataColumn(label: Text('Created At')),
                                    DataColumn(label: Text('Product')),
                                    DataColumn(label: Text('Price')),
                                    DataColumn(label: Text('Description')),
                                    DataColumn(label: Text('Discount')),
                                    DataColumn(label: Text('Category 1')),
                                    DataColumn(label: Text('Category 2')),
                                    DataColumn(label: Text('Popular')),
                                    DataColumn(label: Text('Matching Words')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows:
                                      widget.products.map((product) {
                                        return DataRow(
                                          cells: [
                                            DataCell(Text('#${product.id}')),
                                            // Created At column
                                            DataCell(
                                              Text(
                                                '${product.createdAt.day}/${product.createdAt.month}/${product.createdAt.year}',
                                              ),
                                            ),
                                            // Product name column
                                            DataCell(
                                              ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                      maxWidth: 220,
                                                    ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    _buildProductThumbnail(
                                                      product,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        product.name,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        maxLines: 2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // Price column
                                            DataCell(
                                              Text('\$${product.uPrices}'),
                                            ),
                                            // Description column
                                            DataCell(
                                              ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                      maxWidth: 200,
                                                    ),
                                                child: Text(
                                                  product.description ?? '',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 2,
                                                ),
                                              ),
                                            ),
                                            // Discount column
                                            DataCell(
                                              Text(
                                                product.discount != null
                                                    ? '${product.discount}%'
                                                    : '-',
                                              ),
                                            ),
                                            // Category 1 column
                                            DataCell(
                                              ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                      maxWidth: 120,
                                                    ),
                                                child: Text(
                                                  product.category1 ?? '',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ),
                                            // Category 2 column
                                            DataCell(
                                              ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                      maxWidth: 120,
                                                    ),
                                                child: Text(
                                                  product.category2 ?? '',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ),
                                            // Popular column
                                            DataCell(
                                              product.popularProduct
                                                  ? const Icon(
                                                    Icons.star,
                                                    color: Colors.amber,
                                                    size: 20,
                                                  )
                                                  : const Text('-'),
                                            ),
                                            // Matching Words column
                                            DataCell(
                                              ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                      maxWidth: 150,
                                                    ),
                                                child: Text(
                                                  product.matchingWords ?? '',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ),
                                            // Actions column
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.edit,
                                                      size: 20,
                                                    ),
                                                    constraints:
                                                        const BoxConstraints(
                                                          maxWidth: 40,
                                                        ),
                                                    padding: EdgeInsets.zero,
                                                    onPressed: () {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Edit: ${product.name}',
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      size: 20,
                                                      color: Colors.red,
                                                    ),
                                                    constraints:
                                                        const BoxConstraints(
                                                          maxWidth: 40,
                                                        ),
                                                    padding: EdgeInsets.zero,
                                                    onPressed: () {
                                                      _showDeleteConfirmation(
                                                        context,
                                                        product,
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (widget.isLoading)
                          const Positioned.fill(
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      ],
                    ),
          ),
          // Pagination controls with page size selector
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: const Border(
                top: BorderSide(color: Colors.grey, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Page ${widget.currentPage} of $totalPages'),
                Row(
                  children: [
                    // Page size dropdown added here
                    DropdownButton<int>(
                      value: widget.pageSize,
                      underline: Container(),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey,
                      ),
                      items:
                          const [20, 50, 75, 100].map((int size) {
                            return DropdownMenuItem<int>(
                              value: size,
                              child: Text('$size per page'),
                            );
                          }).toList(),
                      onChanged: (int? newValue) {
                        if (newValue != null && newValue != widget.pageSize) {
                          widget.onPageSizeChanged(newValue);
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed:
                          widget.hasPreviousPage
                              ? () =>
                                  widget.onPageChanged(widget.currentPage - 1)
                              : null,
                      tooltip: 'Previous Page',
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed:
                          widget.hasNextPage
                              ? () =>
                                  widget.onPageChanged(widget.currentPage + 1)
                              : null,
                      tooltip: 'Next Page',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductThumbnail(Product product) {
    return SizedBox(
      width: 40,
      height: 40,
      child:
          product.image != null
              ? Image.network(
                product.image!,
                fit: BoxFit.cover,
                width: 40,
                height: 40,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.image_not_supported, size: 20);
                },
              )
              : const Icon(Icons.image_not_supported, size: 20),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Product'),
            content: Text('Are you sure you want to delete "${product.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deleted: ${product.name}')),
                  );
                },
                child: const Text(
                  'DELETE',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}
