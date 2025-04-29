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
  // controller for vertical scrolling
  final ScrollController _verticalScrollController = ScrollController();
  // state for resizable columns & rows
  late List<double> _columnWidths;
  double _rowHeight = 60.0;

  @override
  void initState() {
    super.initState();
    // initialize 11 columns at 120px each
    _columnWidths = List.filled(11, 120.0);
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'ID',
      'Created At',
      'Product',
      'Price',
      'Description',
      'Discount',
      'Category 1',
      'Category 2',
      'Popular',
      'Matching Words',
      'Actions',
    ];
    // Calculate total pages
    final int totalPages = (widget.totalItems / widget.pageSize).ceil();

    return Container(
      color: Colors.grey[300],
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
                    : Column(
                      children: [
                        // header row (fixed, no horizontal scroll)
                        Table(
                          border: TableBorder.all(color: Colors.grey),
                          columnWidths: _columnWidths.asMap().map(
                            (i, w) => MapEntry(i, FixedColumnWidth(w)),
                          ),
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                              ),
                              children: List.generate(titles.length, (i) {
                                return MouseRegion(
                                  cursor: SystemMouseCursors.resizeColumn,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onHorizontalDragUpdate: (d) {
                                      setState(() {
                                        _columnWidths[i] = (_columnWidths[i] +
                                                d.delta.dx)
                                            .clamp(50.0, 300.0);
                                      });
                                    },
                                    onVerticalDragUpdate: (d) {
                                      setState(() {
                                        _rowHeight = (_rowHeight + d.delta.dy)
                                            .clamp(40.0, 200.0);
                                      });
                                    },
                                    child: SizedBox(
                                      height: _rowHeight,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                          vertical: 12.0,
                                        ),
                                        child: Text(
                                          titles[i],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                        // scrollable data rows (vertical only)
                        Expanded(
                          child: Table(
                            border: TableBorder.all(color: Colors.grey),
                            columnWidths: _columnWidths.asMap().map(
                              (i, w) => MapEntry(i, FixedColumnWidth(w)),
                            ),
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            children: [
                              for (final product in widget.products)
                                TableRow(
                                  children: List.generate(_columnWidths.length, (
                                    i,
                                  ) {
                                    // map column index to the existing cell widget
                                    Widget cell;
                                    switch (i) {
                                      case 0:
                                        cell = Text('#${product.id}');
                                        break;
                                      case 1:
                                        cell = Text(
                                          '${product.createdAt.day}/${product.createdAt.month}/${product.createdAt.year}',
                                        );
                                        break;
                                      case 2:
                                        cell = ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 220,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _buildProductThumbnail(product),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  product.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        break;
                                      case 3:
                                        cell = Text('\$${product.uPrices}');
                                        break;
                                      case 4:
                                        cell = ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 200,
                                          ),
                                          child: Text(
                                            product.description ?? '',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
                                        );
                                        break;
                                      case 5:
                                        cell = Text(
                                          product.discount != null
                                              ? '${product.discount}%'
                                              : '-',
                                        );
                                        break;
                                      case 6:
                                        cell = ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 120,
                                          ),
                                          child: Text(
                                            product.category1 ?? '',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        );
                                        break;
                                      case 7:
                                        cell = ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 120,
                                          ),
                                          child: Text(
                                            product.category2 ?? '',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        );
                                        break;
                                      case 8:
                                        cell =
                                            product.popularProduct
                                                ? const Icon(
                                                  Icons.star,
                                                  color: Colors.amber,
                                                  size: 20,
                                                )
                                                : const Text('-');
                                        break;
                                      case 9:
                                        cell = ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 150,
                                          ),
                                          child: Text(
                                            product.matchingWords ?? '',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        );
                                        break;
                                      default:
                                        cell = Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                size: 20,
                                              ),
                                              constraints: const BoxConstraints(
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
                                              constraints: const BoxConstraints(
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
                                        );
                                    }
                                    return SizedBox(
                                      height: _rowHeight,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                          vertical: 12.0,
                                        ),
                                        child: cell,
                                      ),
                                    );
                                  }),
                                ),
                            ],
                          ),
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
