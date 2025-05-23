import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'product.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

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
  // ===== STATE VARIABLES =====
  late TextEditingController urlController;
  late TextEditingController _pathController;
  late TextEditingController _filenameController;
  late String previewUrl;
  bool _isDragging = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isUploading = false;
  String _uploadMessage = '';

  // ===== SERVICES =====
  final _supabase = Supabase.instance.client;

  // ===== LIFECYCLE METHODS =====
  @override
  void initState() {
    super.initState();
    urlController = TextEditingController(text: widget.product.image ?? '');
    _pathController = TextEditingController();
    _filenameController = TextEditingController();
    previewUrl = widget.product.image ?? '';
  }

  @override
  void dispose() {
    urlController.dispose();
    _pathController.dispose();
    _filenameController.dispose();
    super.dispose();
  }

  // ===== UTILITY METHODS =====
  bool get _isDesktop => !kIsWeb && !Platform.isIOS && !Platform.isAndroid;

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  // ===== FILE HANDLING METHODS =====
  Future<void> _handleDroppedFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = file.name;
        previewUrl = 'dropped_file://${file.name}';
        _pathController.text = file.path;
        _filenameController.text = file.name;
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Failed to read dropped file: ${e.toString()}');
    }
  }

  Future<void> _loadFileFromPath(String filePath) async {
    if (filePath.isEmpty) {
      _showErrorDialog('No file path provided');
      return;
    }

    try {
      if (Platform.isWindows && !filePath.contains(':\\')) {
        _showErrorDialog(
          'Please provide a complete path (e.g., C:\\Users\\...)',
        );
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        if (!mounted) return;
        _showErrorDialog('File not found: $filePath');
        return;
      }

      final bytes = await file.readAsBytes();
      final filename = file.path.split(Platform.pathSeparator).last;

      if (!mounted) return;

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = filename;
        previewUrl = 'file://$filePath';
        _filenameController.text = filename;
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error reading file: ${e.toString()}');
    }
  }

  Future<String> _prepareFileName() async {
    if (_selectedImageName == null) return '';

    final fileExt =
        _selectedImageName!.contains('.')
            ? _selectedImageName!.substring(
              _selectedImageName!.lastIndexOf('.'),
            )
            : '';
    final customName = _filenameController.text.trim();

    if (customName.isNotEmpty) {
      final sanitizedName = customName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      return sanitizedName.endsWith(fileExt)
          ? sanitizedName
          : '$sanitizedName$fileExt';
    } else {
      return 'product_image_${DateTime.now().millisecondsSinceEpoch}$fileExt';
    }
  }

  // ===== UPLOAD METHODS =====
  Future<void> _uploadImage() async {
    if (_selectedImageBytes == null || _selectedImageName == null) {
      _showErrorDialog('Please select an image first');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadMessage = 'Uploading...';
    });

    try {
      final fileName = await _prepareFileName();
      await _supabase.storage
          .from('product_image')
          .uploadBinary(fileName, _selectedImageBytes!);
      final imageUrl = _supabase.storage
          .from('product_image')
          .getPublicUrl(fileName);

      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _uploadMessage = 'Upload successful!';
        urlController.text = imageUrl;
        previewUrl = imageUrl;
      });
    } catch (e) {
      if (!mounted) return;
      _handleUploadError(e);
    }
  }

  void _handleUploadError(dynamic e) {
    // Check for duplicate file error
    bool isDuplicateError = false;
    String errorMessage = 'Failed to upload image';

    if (e is StorageException) {
      if (e.statusCode == 409 ||
          e.error == 'Duplicate' ||
          e.message?.contains('already exists') == true) {
        isDuplicateError = true;
        errorMessage =
            'A file with this name already exists. Please use a different filename.';
      } else {
        errorMessage = '${e.message}';
      }
    }

    setState(() {
      _isUploading = false;
      _uploadMessage =
          isDuplicateError
              ? 'Upload failed: Duplicate file name'
              : 'Upload failed: ${e.toString()}';
    });

    print('Upload error: $e');
    _showErrorDialog(errorMessage);
  }

  // ===== UI BUILDING METHODS =====
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
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProductName(),
                      const SizedBox(height: 20),
                      _buildImagePreview(),
                      const SizedBox(height: 24),
                      _buildUrlInput(),
                      const SizedBox(height: 24),
                      _buildUploadOptions(),
                      if (_isDesktop) _buildFileInputs(),
                      if (_uploadMessage.isNotEmpty) _buildUploadMessage(),
                      if (_selectedImageBytes != null) _buildUploadButton(),
                    ],
                  ),
                ),
              ),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
    );
  }

  Widget _buildProductName() {
    return Text(
      'Product: ${widget.product.name}',
      style: const TextStyle(
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
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
    );
  }

  Widget _buildUrlInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Image URL',
          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
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
              borderSide: BorderSide(color: Colors.blue[300]!, width: 2),
            ),
          ),
          onSubmitted: (value) {
            setState(() {
              previewUrl = value.trim();
            });
          },
        ),
      ],
    );
  }

  Widget _buildFileInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Image File Path',
          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pathController,
                decoration: InputDecoration(
                  hintText:
                      Platform.isWindows
                          ? 'C:\\Users\\username\\Pictures\\image.jpg'
                          : '/path/to/image.jpg',
                  prefixIcon: const Icon(Icons.folder_open),
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
                    borderSide: BorderSide(color: Colors.blue[300]!, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _loadFileFromPath(_pathController.text.trim()),
              icon: const Icon(Icons.file_open),
              label: const Text('Load'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildFilenameInput(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFilenameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Custom Filename (optional)',
          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _filenameController,
          decoration: InputDecoration(
            hintText: 'Enter desired filename for upload',
            prefixIcon: const Icon(Icons.drive_file_rename_outline),
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
              borderSide: BorderSide(color: Colors.blue[300]!, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Or upload from device',
          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        if (_isDesktop) _buildDropTarget() else _buildUploadPlaceholder(),
      ],
    );
  }

  Widget _buildDropTarget() {
    return DropTarget(
      onDragDone: (details) async {
        if (details.files.isNotEmpty) {
          await _handleDroppedFile(details.files.first);
        }
      },
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      child: InkWell(
        onTap: () {
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                _isDragging ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDragging ? Colors.blue : Colors.grey[300]!,
              width: _isDragging ? 2 : 1,
            ),
            boxShadow:
                _isDragging
                    ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                    : null,
          ),
          child:
              _selectedImageBytes != null
                  ? _buildSelectedImagePreview()
                  : _buildDropAreaContent(),
        ),
      ),
    );
  }

  Widget _buildSelectedImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Image.memory(
        _selectedImageBytes!,
        height: 120,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildDropAreaContent() {
    return Column(
      children: [
        Icon(
          Icons.cloud_upload,
          size: 40,
          color: _isDragging ? Colors.blue : Colors.blue[400],
        ),
        const SizedBox(height: 8),
        Text(
          _isDragging
              ? 'Release to drop file'
              : 'Click to browse or drag & drop',
          style: TextStyle(
            color: _isDragging ? Colors.blue : Colors.black87,
            fontWeight: _isDragging ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'PNG, JPG up to 5MB',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildUploadPlaceholder() {
    return InkWell(
      onTap: () {
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
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_upload, size: 40, color: Colors.blue[400]),
            const SizedBox(height: 8),
            const Text(
              'Click to browse or drag & drop',
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              'PNG, JPG up to 5MB',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadMessage() {
    final isError = _uploadMessage.contains('fail');
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isError
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isError
                    ? Colors.red.withOpacity(0.5)
                    : Colors.green.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(_uploadMessage)),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: ElevatedButton.icon(
        onPressed: _isUploading ? null : _uploadImage,
        icon:
            _isUploading
                ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : const Icon(Icons.cloud_upload),
        label: Text(_isUploading ? 'Uploading...' : 'Upload to Supabase'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey[400]!),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('CANCEL'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _saveImageUrl,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.save), SizedBox(width: 8), Text('SAVE')],
            ),
          ),
        ],
      ),
    );
  }

  void _saveImageUrl() {
    final String newUrl = urlController.text.trim();
    if (newUrl.isNotEmpty) {
      widget.onSaveImageUrl(widget.product, newUrl);
      Navigator.pop(context);
    } else {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Invalid URL'),
              content: const Text('Please enter a valid image URL'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  }
}
