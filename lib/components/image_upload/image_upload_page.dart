import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import '../../components/common/app_drawer.dart';

class ImageUploadPage extends StatefulWidget {
  const ImageUploadPage({super.key});

  @override
  State<ImageUploadPage> createState() => _ImageUploadPageState();
}

class _ImageUploadPageState extends State<ImageUploadPage> {
  // Image selection state
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isLoading = false;
  String _message = '';
  String? _uploadedImageUrl;
  bool _isDragging = false;

  // File listing state
  List<FileObject> _bucketFiles = [];
  bool _isLoadingFiles = false;
  String _fileListMessage = '';

  // Controllers & Services
  final _supabase = Supabase.instance.client;
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _filenameController = TextEditingController();

  // Platform helpers
  bool get _isDesktop => !kIsWeb && !Platform.isIOS && !Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    _fetchBucketFiles();
  }

  @override
  void dispose() {
    _pathController.dispose();
    _filenameController.dispose();
    super.dispose();
  }

  // MARK: - File Operations

  String _getReadableFileSize(FileObject file) {
    int? sizeInBytes = file.metadata?['size'] as int?;
    if (sizeInBytes == null) return 'Unknown size';

    if (sizeInBytes < 1024) {
      return '$sizeInBytes B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  Future<void> _fetchBucketFiles() async {
    setState(() {
      _isLoadingFiles = true;
      _fileListMessage = 'Loading files...';
      _bucketFiles = [];
    });

    try {
      final recentFiles = await _fetchRecentFiles();

      if (mounted) {
        setState(() {
          _bucketFiles = recentFiles;
          _isLoadingFiles = false;

          if (recentFiles.length == 100) {
            _fileListMessage = 'Showing first 100 files (API limit)';
          } else {
            _fileListMessage = 'Found ${recentFiles.length} files';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFiles = false;
          _fileListMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  Future<List<FileObject>> _fetchRecentFiles() async {
    try {
      // Directly await the RPC call (no .execute() needed)
      final data = await _supabase.rpc(
        'get_recent_files',
        params: {'p_limit_count': 20},
      );

      return (data as List)
          .map(
            (fileData) => FileObject(
              name: fileData['file_name'] as String,
              bucketId: fileData['file_bucket_id'] as String?,
              owner: fileData['file_owner'] as String?,
              id: fileData['file_id'] as String?,
              updatedAt: _parseTimestamp(fileData['file_updated_at']),
              createdAt: _parseTimestamp(fileData['file_created_at']),
              lastAccessedAt: _parseTimestamp(
                fileData['file_last_accessed_at'],
              ),
              metadata: fileData['file_metadata'] as Map<String, dynamic>?,
              buckets: null,
            ),
          )
          .toList();
    } catch (e) {
      print('Exception occurred while fetching files: $e');
      rethrow;
    }
  }

  String? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is DateTime) return timestamp.toIso8601String();
    if (timestamp is String) return timestamp;
    return null;
  }

  // Future<List<FileObject>> _fetchRecentFiles() async {
  //   try {
  //     List<FileObject> allFiles = [];
  //     const int limit = 100;
  //     int offset = 0;
  //     List<FileObject> batch = [];

  //     do {
  //       batch = await _supabase.storage
  //           .from('product_image')
  //           .list(
  //             path: '',
  //             searchOptions: SearchOptions(limit: limit, offset: offset),
  //           );

  //       if (batch.isEmpty) break;
  //       allFiles.addAll(batch);
  //       offset += batch.length;
  //     } while (batch.length == limit);

  //     // Date-wise sorting with null safety
  //     allFiles.sort((a, b) {
  //       final aTime = _getFileDateTime(a);
  //       final bTime = _getFileDateTime(b);
  //       return bTime.compareTo(aTime); // Descending order
  //     });

  //     return allFiles;
  //   } catch (e) {
  //     rethrow;
  //   }
  // }

  // DateTime _getFileDateTime(FileObject file) {
  //   // First try createdAt
  //   if (file.createdAt != null) {
  //     return DateTime.parse(file.createdAt!);
  //   }

  //   // Then try updatedAt
  //   if (file.updatedAt != null) {
  //     return DateTime.parse(file.updatedAt!);
  //   }

  //   // Then check metadata
  //   return _parseMetadata(file.metadata);
  // }

  // DateTime _parseMetadata(Map<String, dynamic>? metadata) {
  //   if (metadata == null) return DateTime(1970);

  //   // Try different potential metadata fields
  //   final dynamic timestamp =
  //       metadata['created_at'] ??
  //       metadata['createdAt'] ??
  //       metadata['last_modified'] ??
  //       metadata['updated_at'];

  //   if (timestamp == null) return DateTime(1970);

  //   // Handle both string and numeric timestamps
  //   if (timestamp is String) {
  //     return DateTime.tryParse(timestamp) ?? DateTime(1970);
  //   }
  //   if (timestamp is int) {
  //     return DateTime.fromMillisecondsSinceEpoch(timestamp);
  //   }
  //   return DateTime(1970);
  // }

  void _refreshFileList() {
    _fetchBucketFiles();
  }

  Future<void> _deleteFile(String filePath) async {
    final bool confirmDelete =
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Confirm Deletion'),
                content: Text('Are you sure you want to delete "$filePath"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmDelete) return;

    try {
      await _supabase.storage.from('product_image').remove([filePath]);

      if (!mounted) return;

      _fetchBucketFiles();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deleted $filePath')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting file: ${e.toString()}')),
      );
    }
  }

  // MARK: - Image Selection & Upload

  Future<void> _pickImage() async {
    if (!_isDesktop) {
      setState(() => _message = 'Available only on desktop platforms');
      return;
    }

    if (Platform.isWindows) {
      await _pickImageWindows();
    } else if (Platform.isLinux) {
      await _pickImageLinux();
    } else {
      await _pickImageFallback();
    }
  }

  Future<void> _pickImageWindows() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;

        if (pickedFile.bytes != null) {
          setState(() {
            _selectedImageBytes = pickedFile.bytes;
            _selectedImageName = pickedFile.name;
            _message = 'Selected: ${pickedFile.name}';
            _uploadedImageUrl = null;
          });
          return;
        } else if (pickedFile.path != null) {
          await _loadFileFromPath(pickedFile.path!);
          return;
        }
      }

      setState(() => _message = 'Please try drag and drop instead');
    } catch (e) {
      if (mounted) {
        setState(() => _message = 'Error selecting file: ${e.toString()}');
      }
    }
  }

  Future<void> _pickImageLinux() async {
    setState(() {
      _message = 'Please use drag & drop or enter a file path manually below.';
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Linux File Selection'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The file picker dialog is not available on this Linux system. You can:',
                ),
                const SizedBox(height: 10),
                const Text('1. Drag & drop an image onto the drop area'),
                const Text('2. Enter the full path to the image file manually'),
                const SizedBox(height: 15),
                TextField(
                  controller: _pathController,
                  decoration: const InputDecoration(
                    labelText: 'Full path to image file',
                    hintText: '/home/username/Pictures/image.jpg',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadFileFromPath(_pathController.text.trim());
                },
                child: const Text('Load Image'),
              ),
            ],
          ),
    );
  }

  Future<void> _pickImageFallback() async {
    try {
      await FilePicker.platform.pickFiles();
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
    }

    if (!mounted) return;
    setState(() => _message = 'Please drag and drop an image instead.');

    try {
      FilePicker.platform.clearTemporaryFiles();
      await Future.delayed(const Duration(milliseconds: 500));
      await Future.any([
        FilePicker.platform.pickFiles(type: FileType.any),
        Future.delayed(const Duration(seconds: 5)),
      ]);
    } catch (e) {
      // Error handling
    }
  }

  Future<void> _loadFileFromPath(String filePath) async {
    if (filePath.isEmpty) {
      setState(() => _message = 'No file path provided');
      return;
    }

    try {
      if (Platform.isWindows && !filePath.contains(':\\')) {
        setState(
          () =>
              _message =
                  'Please provide a complete path (e.g., C:\\Users\\...)',
        );
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        if (!mounted) return;
        setState(() => _message = 'File not found: $filePath');
        return;
      }

      final bytes = await file.readAsBytes();
      final filename = path.basename(filePath);

      if (!mounted) return;

      _filenameController.text = filename;
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = filename;
        _message = 'Selected: $filename';
        _uploadedImageUrl = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Error reading file: ${e.toString()}');
    }
  }

  Future<void> _handleDroppedFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();

      if (!mounted) return;

      _filenameController.text = file.name;
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = file.name;
        _message = 'Selected: ${file.name}';
        _uploadedImageUrl = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Error reading file: ${e.toString()}');
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImageBytes == null || _selectedImageName == null) {
      setState(() => _message = 'Please select an image first');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = 'Uploading...';
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
        _isLoading = false;
        _message = 'Upload successful!';
        _uploadedImageUrl = imageUrl;
        _selectedImageBytes = null;
        _selectedImageName = null;
      });

      _fetchBucketFiles();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _message = 'Upload failed: ${e.toString()}';
      });
    }
  }

  Future<String> _prepareFileName() async {
    final fileExt = path.extension(_selectedImageName!);
    final customName = _filenameController.text.trim();

    if (customName.isNotEmpty) {
      final sanitizedName = customName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      return sanitizedName.endsWith(fileExt)
          ? sanitizedName
          : '$sanitizedName$fileExt';
    } else {
      return 'image_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}$fileExt';
    }
  }

  void _copyUrlToClipboard(String fileName) {
    final url = _supabase.storage.from('product_image').getPublicUrl(fileName);
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('URL copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // MARK: - UI Building

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) {
      return _buildMobileUnsupported();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: _buildAppBar(colorScheme),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surface,
              colorScheme.surface.withAlpha(
                (colorScheme.surface.a * 0.7).round(),
              ),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(colorScheme),
                  _buildUploadCard(colorScheme),
                  const SizedBox(height: 32),
                  _buildFilesListCard(colorScheme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileUnsupported() {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Upload'), elevation: 0),
      body: const Center(child: Text('Desktop feature only')),
    );
  }

  AppBar _buildAppBar(ColorScheme colorScheme) {
    return AppBar(
      title: const Text('Image Upload'),
      elevation: 0,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          // Check if we can pop the current route
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            // If we can't pop, navigate to a specific route
            // Replace 'home' with your actual route name
            Navigator.of(context).pushReplacementNamed('/');
          }
        },
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Icon(
            Icons.cloud_upload_rounded,
            size: 32,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 16),
          Text(
            'Desktop Image Upload',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Upload New Image', colorScheme),
            _buildDropTarget(colorScheme),
            const SizedBox(height: 24),
            _buildFilenameInput(colorScheme),
            const SizedBox(height: 24),
            if (Platform.isLinux || Platform.isWindows)
              _buildPathInput(colorScheme),
            if (_message.isNotEmpty) _buildStatusMessage(colorScheme),
            _buildActionButtons(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildDropTarget(ColorScheme colorScheme) {
    return DropTarget(
      onDragDone: (details) async {
        if (details.files.isNotEmpty) {
          await _handleDroppedFile(details.files.first);
        }
      },
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 300,
        decoration: BoxDecoration(
          color:
              _isDragging
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainer.withAlpha((255 * 0.5).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                _isDragging ? colorScheme.primary : colorScheme.outlineVariant,
            width: _isDragging ? 2 : 1,
          ),
          boxShadow:
              _isDragging
                  ? [
                    BoxShadow(
                      color: colorScheme.primary.withAlpha((255 * 0.3).round()),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                  : null,
        ),
        child: _buildDropTargetContent(colorScheme),
      ),
    );
  }

  Widget _buildDropTargetContent(ColorScheme colorScheme) {
    if (_selectedImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.memory(_selectedImageBytes!, fit: BoxFit.contain),
      );
    } else if (_uploadedImageUrl != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: colorScheme.primary, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Upload Complete!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.link),
            label: const Text('View URL'),
            onPressed:
                () => setState(() => _message = 'URL: $_uploadedImageUrl'),
          ),
        ],
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_upload_rounded,
            size: 80,
            color: colorScheme.primary.withAlpha((255 * 0.7).round()),
          ),
          const SizedBox(height: 16),
          Text(
            'Drag & Drop Image Here',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'or use the select button below',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant.withAlpha(
                (255 * 0.7).round(),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildFilenameInput(ColorScheme colorScheme) {
    return TextField(
      controller: _filenameController,
      decoration: InputDecoration(
        labelText: 'Custom Filename (optional)',
        hintText: 'Enter desired filename for upload',
        prefixIcon: const Icon(Icons.drive_file_rename_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: colorScheme.surfaceContainer.withAlpha((255 * 0.3).round()),
      ),
    );
  }

  Widget _buildPathInput(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _pathController,
              decoration: InputDecoration(
                labelText: 'Image File Path',
                hintText:
                    Platform.isWindows
                        ? 'C:\\Users\\username\\Pictures\\image.jpg'
                        : '/path/to/image.jpg',
                prefixIcon: const Icon(Icons.folder_open),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainer.withAlpha(
                  (255 * 0.3).round(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.file_open),
            label: const Text('Load'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _loadFileFromPath(_pathController.text.trim()),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage(ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            _message.contains('fail')
                ? colorScheme.errorContainer
                : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child:
          _message.startsWith('URL:')
              ? _buildUrlMessage(colorScheme)
              : _buildInfoMessage(colorScheme),
    );
  }

  Widget _buildUrlMessage(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: SelectableText(
            _message,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color:
                  _message.contains('fail')
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.copy, color: colorScheme.primary),
          tooltip: 'Copy URL to clipboard',
          onPressed: () {
            final url = _message.substring(5);
            Clipboard.setData(ClipboardData(text: url.trim()));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('URL copied to clipboard'),
                backgroundColor: colorScheme.inverseSurface,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInfoMessage(ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(
          _message.contains('fail') ? Icons.error_outline : Icons.info_outline,
          color:
              _message.contains('fail')
                  ? colorScheme.onErrorContainer
                  : colorScheme.onPrimaryContainer,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _message,
            style: TextStyle(
              color:
                  _message.contains('fail')
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.photo_library),
          label: const Text('Select Image'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isLoading ? null : _pickImage,
        ),
        const SizedBox(width: 20),
        ElevatedButton.icon(
          icon:
              _isLoading
                  ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                  : const Icon(Icons.upload),
          label: Text(_isLoading ? 'Uploading...' : 'Upload'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            disabledBackgroundColor: colorScheme.onSurfaceVariant.withAlpha(
              (255 * 0.12).round(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed:
              _isLoading || _selectedImageBytes == null ? null : _uploadImage,
        ),
      ],
    );
  }

  Widget _buildFilesListCard(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilesHeader(colorScheme),
            _buildFilesContent(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesHeader(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Recent Files',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: colorScheme.primary,
            ),
          ),
          Row(
            children: [
              Text(
                _fileListMessage,
                style: TextStyle(
                  color:
                      _fileListMessage.contains('Error')
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.refresh, color: colorScheme.primary),
                tooltip: 'Refresh file list',
                onPressed: _isLoadingFiles ? null : _refreshFileList,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilesContent(ColorScheme colorScheme) {
    if (_isLoadingFiles) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_fileListMessage.contains('Error')) {
      return _buildFilesErrorState(colorScheme);
    } else if (_bucketFiles.isEmpty) {
      return _buildFilesEmptyState(colorScheme);
    } else {
      return _buildFilesList(colorScheme);
    }
  }

  Widget _buildFilesErrorState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: colorScheme.error.withAlpha((255 * 0.7).round()),
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading files',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _refreshFileList,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.errorContainer,
                foregroundColor: colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.folder_off,
              size: 48,
              color: colorScheme.onSurfaceVariant.withAlpha(
                (255 * 0.5).round(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No files found in bucket',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesList(ColorScheme colorScheme) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _bucketFiles.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder:
          (context, index) =>
              _buildFileListTile(_bucketFiles[index], colorScheme),
    );
  }

  Widget _buildFileListTile(FileObject file, ColorScheme colorScheme) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.insert_drive_file, color: colorScheme.primary),
      ),
      title: Text(
        file.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _getReadableFileSize(file),
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 100),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.copy, size: 20, color: colorScheme.primary),
              tooltip: 'Copy URL',
              onPressed: () => _copyUrlToClipboard(file.name),
            ),
            IconButton(
              icon: Icon(Icons.delete, size: 20, color: colorScheme.error),
              tooltip: 'Delete file',
              onPressed: () => _deleteFile(file.name),
            ),
          ],
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tileColor: Colors.transparent,
      selectedTileColor: colorScheme.surfaceContainer.withAlpha(
        (255 * 0.3).round(),
      ),
    );
  }
}
