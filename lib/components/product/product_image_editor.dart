import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'product.dart';

/// A utility class for handling product image editing
class ProductImageEditor {
  /// Shows a dialog to edit a product's image URL
  static Future<void> showEditDialog(
    BuildContext context,
    Product product,
    Function(Product, String) onSaveImageUrl,
  ) {
    // Instead of creating the controller here and disposing it later,
    // we'll create it inside the StatefulBuilder and let Flutter handle disposal
    return showDialog(
      context: context,
      builder: (dialogContext) {
        // Create a StatefulWidget instead of using StatefulBuilder
        return _ProductImageEditorDialog(
          product: product,
          onSaveImageUrl: onSaveImageUrl,
        );
      },
    );
  }

  /// Builds a cached image with loading and error states
  static Widget buildCachedImage({
    required String? imageUrl,
    required BoxFit fit,
    required double width,
    required double height,
    bool isEnlarged = false,
    Key? imageKey,
    bool showLoadingIndicator = false,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: Icon(Icons.image_not_supported, size: isEnlarged ? 50 : 20),
      );
    }

    return SizedBox(
      key: imageKey,
      width: width,
      height: height,
      child: CachedNetworkImage(
        key: ValueKey('${isEnlarged ? 'enlarged' : 'thumbnail'}-$imageUrl'),
        imageUrl: imageUrl,
        fit: fit,
        progressIndicatorBuilder: (context, url, progress) {
          if (progress.totalSize == null) {
            return Center(
              child: SizedBox(
                width: isEnlarged || showLoadingIndicator ? 40 : 20,
                height: isEnlarged || showLoadingIndicator ? 40 : 20,
                child: const CircularProgressIndicator(),
              ),
            );
          } else {
            final percent = progress.downloaded / (progress.totalSize ?? 1);
            return Center(
              child: SizedBox(
                width: isEnlarged || showLoadingIndicator ? 40 : 20,
                height: isEnlarged || showLoadingIndicator ? 40 : 20,
                child: CircularProgressIndicator(
                  strokeWidth: isEnlarged ? 3 : 2,
                  value: percent,
                ),
              ),
            );
          }
        },
        errorWidget: (context, url, error) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: isEnlarged ? 50 : 20,
                color: Colors.red,
              ),
              if (isEnlarged || showLoadingIndicator)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// Create a proper StatefulWidget for the dialog to handle controller lifecycle correctly
class _ProductImageEditorDialog extends StatefulWidget {
  final Product product;
  final Function(Product, String) onSaveImageUrl;

  const _ProductImageEditorDialog({
    required this.product,
    required this.onSaveImageUrl,
  });

  @override
  _ProductImageEditorDialogState createState() =>
      _ProductImageEditorDialogState();
}

class _ProductImageEditorDialogState extends State<_ProductImageEditorDialog> {
  late TextEditingController urlController;
  late String previewUrl;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController(text: widget.product.image ?? '');
    previewUrl = widget.product.image ?? '';
  }

  @override
  void dispose() {
    // Now the controller will be properly disposed with the widget
    urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 8.0,
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with title and close button
            Container(
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  topRight: Radius.circular(16.0),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                children: [
                  const Icon(Icons.image, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    'Edit Product Image',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product name
                      Text(
                        'Product: ${widget.product.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Image preview area
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child:
                              previewUrl.isEmpty
                                  ? const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  )
                                  : ProductImageEditor.buildCachedImage(
                                    imageUrl: previewUrl,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: 200,
                                    showLoadingIndicator: true,
                                  ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // URL input field
                      const Text(
                        'Image URL',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: urlController,
                        decoration: InputDecoration(
                          hintText: 'Enter the URL of the image',
                          prefixIcon: const Icon(Icons.link),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.preview),
                            tooltip: 'Preview image',
                            onPressed: () {
                              setState(() {
                                previewUrl = urlController.text.trim();
                              });
                            },
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.blue[300]!,
                              width: 2,
                            ),
                          ),
                        ),
                        onSubmitted: (value) {
                          setState(() {
                            previewUrl = value.trim();
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Upload options
                      const Text(
                        'Or upload from device',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () {
                          // Use showDialog instead of SnackBar to avoid Scaffold dependency
                          showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('Upload Feature'),
                                  content: const Text(
                                    'File upload functionality would be implemented here',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.cloud_upload,
                                size: 40,
                                color: Colors.blue[400],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Click to browse or drag & drop',
                                style: TextStyle(color: Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'PNG, JPG up to 5MB',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[400]!),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final String newUrl = urlController.text.trim();
                      if (newUrl.isNotEmpty) {
                        widget.onSaveImageUrl(widget.product, newUrl);
                        Navigator.pop(context);
                      } else {
                        // Use AlertDialog instead of SnackBar
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Invalid URL'),
                                content: const Text(
                                  'Please enter a valid image URL',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.save),
                        SizedBox(width: 8),
                        Text('SAVE'),
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
}
