import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import '../../components/common/app_drawer.dart';
import '../../main.dart'; // Import for AppRoutes constants

class ImageUploadPage extends StatefulWidget {
  const ImageUploadPage({super.key});

  @override
  State<ImageUploadPage> createState() => _ImageUploadPageState();
}

class _ImageUploadPageState extends State<ImageUploadPage> {
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isLoading = false;
  String _message = '';
  String? _uploadedImageUrl;
  bool _isDragging = false;

  // New state variables for file listing
  List<FileObject> _bucketFiles = [];
  bool _isLoadingFiles = false;
  String _fileListMessage = '';

  final _supabase = Supabase.instance.client;

  bool get _isDesktop => !kIsWeb && !Platform.isIOS && !Platform.isAndroid;

  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _filenameController =
      TextEditingController(); // Add controller for filename input

  @override
  void initState() {
    super.initState();
    // Load files when the page initializes
    _fetchBucketFiles();
  }

  @override
  void dispose() {
    _pathController.dispose();
    _filenameController.dispose(); // Dispose the new controller
    super.dispose();
  }

  // Modified method to fetch files with better error handling and logging
  Future<void> _fetchBucketFiles() async {
    setState(() {
      _isLoadingFiles = true;
      _fileListMessage = 'Loading files...';
      _bucketFiles = [];
    });

    try {
      print('DEBUG: Starting file fetch operation from bucket product_image');
      final recentFiles = await _fetchRecentFiles();

      setState(() {
        _bucketFiles = recentFiles;
        _isLoadingFiles = false;

        // Update the message to indicate the API limitation if we got exactly 100 files
        // (which suggests there might be more that we can't fetch)
        if (recentFiles.length == 100) {
          _fileListMessage = 'Showing first 100 files (API limit)';
        } else {
          _fileListMessage = 'Found ${recentFiles.length} files';
        }
      });

      print('DEBUG: Fetched ${recentFiles.length} files from bucket');

      // Print the names of files to help with debugging
      if (recentFiles.isNotEmpty) {
        print(
          'DEBUG: First few files: ${recentFiles.take(3).map((f) => f.name).join(", ")}',
        );
      } else {
        print('DEBUG: No files found in the bucket');
      }
    } catch (e) {
      print('DEBUG: Error in _fetchBucketFiles: $e');
      print('DEBUG: Stack trace: ${StackTrace.current}');
      setState(() {
        _isLoadingFiles = false;
        _fileListMessage = 'Error: ${e.toString()}';
      });
    }
  }

  // Improved method to fetch files with acknowledgment of API limits
  Future<List<FileObject>> _fetchRecentFiles() async {
    try {
      print('DEBUG: Starting fetch from Supabase storage');

      // Note: Supabase Storage API typically limits to 100 files per request
      // and the current SDK version doesn't support proper pagination
      print(
        'DEBUG: Fetching files from root directory (limited to ~100 by API)',
      );

      final allFiles = await _supabase.storage
          .from('product_image')
          .list(path: '');

      print(
        'DEBUG: Retrieved ${allFiles.length} files (maximum 100 due to API limitations)',
      );

      // Sort the files to show most recent first
      if (allFiles.isNotEmpty) {
        if (allFiles[0].metadata != null &&
            allFiles[0].metadata!['lastModified'] != null) {
          print('DEBUG: Using lastModified for sorting');
          allFiles.sort((a, b) {
            final aTime = a.metadata?['lastModified'];
            final bTime = b.metadata?['lastModified'];
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime); // Descending order (newest first)
          });
        } else {
          print('DEBUG: lastModified not available, using name for sorting');
          allFiles.sort(
            (a, b) => b.name.compareTo(a.name),
          ); // Reverse alphabetical as a fallback
        }
      }

      print('DEBUG: Returning ${allFiles.length} sorted files');
      return allFiles;
    } catch (e) {
      print('DEBUG: Error in _fetchRecentFiles: $e');
      print('DEBUG: Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Add a method to manually refresh the file list
  void _refreshFileList() {
    print('DEBUG: Manual refresh requested');
    _fetchBucketFiles();
  }

  // Modified method to delete a file from the bucket with confirmation
  Future<void> _deleteFile(String filePath) async {
    // Show confirmation dialog first
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
        false; // Default to false if dialog is dismissed

    // Only proceed if user confirmed
    if (confirmDelete) {
      try {
        await _supabase.storage.from('product_image').remove([filePath]);
        _fetchBucketFiles(); // Refresh list after delete
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted $filePath')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting file: ${e.toString()}')),
        );
      }
    }
  }

  // Add a helper method for platform-specific path formatting
  String _formatPathForDisplay(String filePath) {
    // Windows paths use backslashes, which need to be preserved in UI but escaped in code
    if (Platform.isWindows) {
      return filePath.replaceAll('\\', '\\\\');
    }
    return filePath;
  }

  Future<void> _pickImage() async {
    print('DEBUG: _pickImage method called');
    print('DEBUG: Platform detection - isDesktop: $_isDesktop');
    print('DEBUG: kIsWeb: $kIsWeb');
    print('DEBUG: Platform.isLinux: ${Platform.isLinux}');
    print('DEBUG: Platform.isMacOS: ${Platform.isMacOS}');
    print('DEBUG: Platform.isWindows: ${Platform.isWindows}');
    print('DEBUG: Platform.operatingSystem: ${Platform.operatingSystem}');
    print(
      'DEBUG: Platform.operatingSystemVersion: ${Platform.operatingSystemVersion}',
    );
    print('DEBUG: Platform.localHostname: ${Platform.localHostname}');
    print('DEBUG: Current directory: ${Directory.current.path}');

    if (!_isDesktop) {
      setState(() => _message = 'Available only on desktop platforms');
      return;
    }

    // Special handling for Windows
    if (Platform.isWindows) {
      print('DEBUG: Windows platform detected, using FilePicker');
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true, // Important for Windows to get the file data directly
        );

        print(
          'DEBUG: Windows FilePicker result: ${result != null ? "success" : "cancelled/failed"}',
        );

        if (result != null && result.files.isNotEmpty) {
          final pickedFile = result.files.first;
          print(
            'DEBUG: Windows - Selected file: ${pickedFile.name}, ${pickedFile.size} bytes',
          );

          if (pickedFile.bytes != null) {
            setState(() {
              _selectedImageBytes = pickedFile.bytes;
              _selectedImageName = pickedFile.name;
              _message = 'Selected: ${pickedFile.name}';
              _uploadedImageUrl = null;
            });
            return;
          } else if (pickedFile.path != null) {
            // If bytes aren't available, try to read from path
            await _loadFileFromPath(pickedFile.path!);
            return;
          }
        }

        // If we get here, the FilePicker didn't provide usable data
        setState(() => _message = 'Please try drag and drop instead');
      } catch (e) {
        print('DEBUG: Windows FilePicker error: $e');
        setState(() => _message = 'Error selecting file: ${e.toString()}');
      }
      return;
    }

    if (Platform.isLinux) {
      setState(() {
        _message =
            'Please use drag & drop or enter a file path manually below.';
      });

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
                  const Text(
                    '2. Enter the full path to the image file manually',
                  ),
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

      return;
    }

    print('DEBUG: Attempting alternative file picker approach');
    try {
      print('DEBUG: Calling FilePicker.platform.pickFiles with basic options');
      await FilePicker.platform
          .pickFiles()
          .then((result) {
            print(
              'DEBUG: FilePicker returned: ${result != null ? "not null" : "null"}',
            );
            if (result != null) {
              print('DEBUG: Files count: ${result.files.length}');
              print('DEBUG: First file name: ${result.files.first.name}');
            }
          })
          .catchError((error) {
            print('DEBUG: FilePicker threw error: $error');
            print('DEBUG: Error type: ${error.runtimeType}');
          });
      print('DEBUG: FilePicker call completed');
    } catch (e) {
      print('DEBUG: Exception caught in outer try-catch: $e');
      print('DEBUG: Exception type: ${e.runtimeType}');
      print('DEBUG: Stack trace: ${StackTrace.current}');
    }

    setState(() => _message = 'Please drag and drop an image instead.');

    print('DEBUG: Trying last resort approach with FilePicker');
    try {
      FilePicker.platform.clearTemporaryFiles();
      await Future.delayed(const Duration(milliseconds: 500));

      await Future.any([
        FilePicker.platform
            .pickFiles(type: FileType.any)
            .then(
              (result) =>
                  print('DEBUG: Last resort picker result: ${result != null}'),
            ),
        Future.delayed(
          const Duration(seconds: 5),
        ).then((_) => print('DEBUG: Picker timed out after 5 seconds')),
      ]);
    } catch (e) {
      print('DEBUG: Last resort approach failed: $e');
    }
  }

  Future<void> _loadFileFromPath(String filePath) async {
    if (filePath.isEmpty) {
      setState(() => _message = 'No file path provided');
      return;
    }

    try {
      // Normalize path for platform
      if (Platform.isWindows && !filePath.contains(':\\')) {
        // If Windows path is missing drive letter, show error
        setState(
          () =>
              _message =
                  'Please provide a complete path (e.g., C:\\Users\\...)',
        );
        return;
      }

      final file = File(filePath);
      print('DEBUG: Checking if file exists at: $filePath');
      if (!await file.exists()) {
        setState(() => _message = 'File not found: $filePath');
        return;
      }

      final bytes = await file.readAsBytes();
      final filename = path.basename(filePath);

      // Set the filename field to the original filename
      _filenameController.text = filename;
      print('DEBUG: Set custom filename field to original filename: $filename');

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = filename;
        _message = 'Selected: $filename';
        _uploadedImageUrl = null;
      });
      print('DEBUG: Successfully loaded file from path: $filePath');
    } catch (e) {
      print('DEBUG: Error loading file from path: $e');
      setState(() => _message = 'Error reading file: ${e.toString()}');
    }
  }

  Future<void> _handleDroppedFile(XFile file) async {
    try {
      print('DEBUG: Processing dropped file: ${file.name}');

      final bytes = await file.readAsBytes();

      // Set the filename field to the original filename
      _filenameController.text = file.name;
      print(
        'DEBUG: Set custom filename field to original filename: ${file.name}',
      );

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = file.name;
        _message = 'Selected: ${file.name}';
        _uploadedImageUrl = null;
      });
      print('DEBUG: Successfully loaded dropped file');
    } catch (e) {
      print('DEBUG: Error processing dropped file: $e');
      setState(() => _message = 'Error reading file: ${e.toString()}');
    }
  }

  Future<void> _uploadImage() async {
    print('DEBUG: _uploadImage method called');
    print(
      'DEBUG: _selectedImageBytes: ${_selectedImageBytes != null ? "${_selectedImageBytes!.length} bytes" : "null"}',
    );
    print('DEBUG: _selectedImageName: $_selectedImageName');

    if (_selectedImageBytes == null || _selectedImageName == null) {
      print('DEBUG: No image selected for upload');
      setState(() => _message = 'Please select an image first');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = 'Uploading...';
    });
    print('DEBUG: Set loading state to true');

    try {
      final fileExt = path.extension(_selectedImageName!);

      // Use custom filename if provided, otherwise generate random name
      String fileName;
      final customName = _filenameController.text.trim();

      if (customName.isNotEmpty) {
        // Sanitize the filename (remove invalid characters)
        final sanitizedName = customName.replaceAll(
          RegExp(r'[\\/:*?"<>|]'),
          '_',
        );

        // Make sure we keep the original extension or add it if missing
        if (sanitizedName.endsWith(fileExt)) {
          fileName = sanitizedName;
        } else {
          fileName = '$sanitizedName$fileExt';
        }
      } else {
        // Fall back to random name if no custom name provided
        fileName =
            'image_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}$fileExt';
      }

      print('DEBUG: Using filename for upload: $fileName');

      print('DEBUG: Starting uploadBinary to Supabase');
      await _supabase.storage
          .from('product_image')
          .uploadBinary(fileName, _selectedImageBytes!);
      print('DEBUG: Upload to Supabase completed');

      final imageUrl = _supabase.storage
          .from('product_image')
          .getPublicUrl(fileName);
      print('DEBUG: Got public URL: $imageUrl');

      setState(() {
        _isLoading = false;
        _message = 'Upload successful!';
        _uploadedImageUrl = imageUrl;
        _selectedImageBytes = null;
        _selectedImageName = null;
      });

      // Refresh the file list after a successful upload
      _fetchBucketFiles();

      print('DEBUG: State updated after successful upload');
    } catch (e) {
      print('DEBUG: Exception in _uploadImage: $e');
      print('DEBUG: Stack trace: ${StackTrace.current}');
      setState(() {
        _isLoading = false;
        _message = 'Upload failed: ${e.toString()}';
      });
    }
  }

  // New method to copy URL to clipboard
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

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) {
      return Scaffold(
        appBar: AppBar(title: const Text('Image Upload'), elevation: 0),
        body: const Center(child: Text('Desktop feature only')),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Upload'),
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      drawer: AppDrawer(
        currentPage: 'Image Upload',
        onPageSelected: (page) {
          // The actual navigation is now handled in AppDrawer directly
        },
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.surface, colorScheme.surface.withOpacity(0.7)],
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
                  // Page Title with modern styling
                  Padding(
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
                  ),

                  // Upload Area Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Title
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Upload New Image',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),

                          // Drop Target Area with improved styling
                          DropTarget(
                            onDragDone: (details) async {
                              if (details.files.isNotEmpty) {
                                await _handleDroppedFile(details.files.first);
                              }
                            },
                            onDragEntered:
                                (_) => setState(() => _isDragging = true),
                            onDragExited:
                                (_) => setState(() => _isDragging = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 300,
                              decoration: BoxDecoration(
                                color:
                                    _isDragging
                                        ? colorScheme.primaryContainer
                                        : colorScheme.surfaceVariant
                                            .withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      _isDragging
                                          ? colorScheme.primary
                                          : colorScheme.outlineVariant,
                                  width: _isDragging ? 2 : 1,
                                ),
                                boxShadow:
                                    _isDragging
                                        ? [
                                          BoxShadow(
                                            color: colorScheme.primary
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                        : null,
                              ),
                              child:
                                  _selectedImageBytes != null
                                      ? ClipRRect(
                                        borderRadius: BorderRadius.circular(11),
                                        child: Image.memory(
                                          _selectedImageBytes!,
                                          fit: BoxFit.contain,
                                        ),
                                      )
                                      : _uploadedImageUrl != null
                                      ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            color: colorScheme.primary,
                                            size: 64,
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'Upload Complete!',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextButton.icon(
                                            icon: const Icon(Icons.link),
                                            label: const Text('View URL'),
                                            onPressed:
                                                () => setState(
                                                  () =>
                                                      _message =
                                                          'URL: $_uploadedImageUrl',
                                                ),
                                          ),
                                        ],
                                      )
                                      : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.cloud_upload_rounded,
                                            size: 80,
                                            color: colorScheme.primary
                                                .withOpacity(0.7),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Drag & Drop Image Here',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'or use the select button below',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: colorScheme
                                                  .onSurfaceVariant
                                                  .withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Filename input with improved styling
                          TextField(
                            controller: _filenameController,
                            decoration: InputDecoration(
                              labelText: 'Custom Filename (optional)',
                              hintText: 'Enter desired filename for upload',
                              prefixIcon: const Icon(
                                Icons.drive_file_rename_outline,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceVariant.withOpacity(
                                0.3,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Manual path input for Linux/Windows with improved styling
                          if (Platform.isLinux || Platform.isWindows)
                            Padding(
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
                                        prefixIcon: const Icon(
                                          Icons.folder_open,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: colorScheme.surfaceVariant
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.file_open),
                                    label: const Text('Load'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed:
                                        () => _loadFileFromPath(
                                          _pathController.text.trim(),
                                        ),
                                  ),
                                ],
                              ),
                            ),

                          // Status message with improved styling
                          if (_message.isNotEmpty)
                            AnimatedContainer(
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
                                      ? Row(
                                        children: [
                                          Expanded(
                                            child: SelectableText(
                                              _message,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    _message.contains('fail')
                                                        ? colorScheme
                                                            .onErrorContainer
                                                        : colorScheme
                                                            .onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.copy,
                                              color: colorScheme.primary,
                                            ),
                                            tooltip: 'Copy URL to clipboard',
                                            onPressed: () {
                                              final url = _message.substring(5);
                                              Clipboard.setData(
                                                ClipboardData(text: url.trim()),
                                              );
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: const Text(
                                                    'URL copied to clipboard',
                                                  ),
                                                  backgroundColor:
                                                      colorScheme
                                                          .inverseSurface,
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      )
                                      : Row(
                                        children: [
                                          Icon(
                                            _message.contains('fail')
                                                ? Icons.error_outline
                                                : Icons.info_outline,
                                            color:
                                                _message.contains('fail')
                                                    ? colorScheme
                                                        .onErrorContainer
                                                    : colorScheme
                                                        .onPrimaryContainer,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _message,
                                              style: TextStyle(
                                                color:
                                                    _message.contains('fail')
                                                        ? colorScheme
                                                            .onErrorContainer
                                                        : colorScheme
                                                            .onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                            ),

                          // Action buttons with improved styling
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Select Image'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      colorScheme.secondaryContainer,
                                  foregroundColor:
                                      colorScheme.onSecondaryContainer,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 15,
                                  ),
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
                                label: Text(
                                  _isLoading ? 'Uploading...' : 'Upload',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  disabledBackgroundColor: colorScheme
                                      .onSurfaceVariant
                                      .withOpacity(0.12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed:
                                    _isLoading || _selectedImageBytes == null
                                        ? null
                                        : _uploadImage,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Files list card with improved error handling and retry button
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section header with actions
                          Padding(
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
                                      icon: Icon(
                                        Icons.refresh,
                                        color: colorScheme.primary,
                                      ),
                                      tooltip: 'Refresh file list',
                                      onPressed:
                                          _isLoadingFiles
                                              ? null
                                              : _refreshFileList,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Files list with improved error feedback
                          _isLoadingFiles
                              ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                              : _fileListMessage.contains('Error')
                              ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 40,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 48,
                                        color: colorScheme.error.withOpacity(
                                          0.7,
                                        ),
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
                                          backgroundColor:
                                              colorScheme.errorContainer,
                                          foregroundColor:
                                              colorScheme.onErrorContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              : _bucketFiles.isEmpty
                              ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 40,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.folder_off,
                                        size: 48,
                                        color: colorScheme.onSurfaceVariant
                                            .withOpacity(0.5),
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
                              )
                              : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _bucketFiles.length,
                                separatorBuilder:
                                    (context, index) =>
                                        const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final file = _bucketFiles[index];

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 16,
                                    ),
                                    // Use consistent file icon for all files
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.insert_drive_file,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    title: Text(
                                      file.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${((file.metadata?['size'] ?? 0) / 1024).toStringAsFixed(2)} KB',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.copy,
                                            size: 20,
                                            color: colorScheme.primary,
                                          ),
                                          tooltip: 'Copy URL',
                                          onPressed:
                                              () => _copyUrlToClipboard(
                                                file.name,
                                              ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete,
                                            size: 20,
                                            color: colorScheme.error,
                                          ),
                                          tooltip: 'Delete file',
                                          onPressed:
                                              () => _deleteFile(file.name),
                                        ),
                                      ],
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    hoverColor: colorScheme.surfaceVariant
                                        .withOpacity(0.3),
                                  );
                                },
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
      ),
    );
  }
}
