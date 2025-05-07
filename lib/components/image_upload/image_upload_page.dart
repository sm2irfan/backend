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

  // Modified method to fetch only the most recent files
  Future<void> _fetchBucketFiles() async {
    setState(() {
      _isLoadingFiles = true;
      _fileListMessage = 'Loading recent files...';
      _bucketFiles = []; // Reset the list before fetching
    });

    try {
      // Get only the most recently updated files
      final recentFiles = await _fetchRecentFiles();

      setState(() {
        _bucketFiles = recentFiles;
        _isLoadingFiles = false;
        _fileListMessage = 'Found ${recentFiles.length} recent files';
      });

      print('DEBUG: Fetched ${recentFiles.length} recent files from bucket');
    } catch (e) {
      setState(() {
        _isLoadingFiles = false;
        _fileListMessage = 'Error loading files: ${e.toString()}';
      });
      print('DEBUG: Error fetching files: $e');
    }
  }

  // New method to fetch only the most recently updated files
  Future<List<FileObject>> _fetchRecentFiles() async {
    try {
      // Get all files at root level since sorting parameters aren't available
      final allFiles = await _supabase.storage
          .from('product_image')
          .list(path: '');

      // Sort files manually based on lastModified or other metadata
      // Note: If lastModified isn't available, we may need to fall back to alphabetical sorting
      if (allFiles.isNotEmpty &&
          allFiles[0].metadata != null &&
          allFiles[0].metadata!['lastModified'] != null) {
        // Sort by lastModified if available
        allFiles.sort((a, b) {
          final aTime = a.metadata?['lastModified'];
          final bTime = b.metadata?['lastModified'];
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime); // Descending order (newest first)
        });
      } else {
        // Fallback to sorting by name
        allFiles.sort((a, b) => a.name.compareTo(b.name));
      }

      // Return only the first 10 files (or fewer if there aren't 10)
      final recentFiles = allFiles.take(10).toList();

      print(
        'DEBUG: Successfully fetched and sorted ${recentFiles.length} recent files',
      );
      return recentFiles;
    } catch (e) {
      print('DEBUG: Error in _fetchRecentFiles: $e');
      // Return empty list on error
      return [];
    }
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
        appBar: AppBar(title: const Text('Image Upload')),
        body: const Center(child: Text('Desktop feature only')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Image Upload')),
      drawer: AppDrawer(
        currentPage: 'Image Upload',
        onPageSelected: (page) {
          // The actual navigation is now handled in AppDrawer directly
          // We just need to set the current page state
        },
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 800,
          ), // Increased width for file list
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Desktop Image Upload',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                DropTarget(
                  onDragDone: (details) async {
                    if (details.files.isNotEmpty) {
                      await _handleDroppedFile(details.files.first);
                    }
                  },
                  onDragEntered: (_) => setState(() => _isDragging = true),
                  onDragExited: (_) => setState(() => _isDragging = false),
                  child: Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color:
                          _isDragging ? Colors.blue.shade100 : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isDragging ? Colors.blue : Colors.grey,
                        width: _isDragging ? 2 : 1,
                      ),
                    ),
                    child:
                        _selectedImageBytes != null
                            ? Image.memory(
                              _selectedImageBytes!,
                              fit: BoxFit.contain,
                            )
                            : _uploadedImageUrl != null
                            ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 50,
                                ),
                                const SizedBox(height: 10),
                                const Text('Upload Complete!'),
                                TextButton(
                                  child: const Text('View URL'),
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
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.cloud_upload,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Drag & Drop Image Here',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),
                const SizedBox(height: 20),
                // Add filename input field after the drop area
                TextField(
                  controller: _filenameController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Filename (optional)',
                    hintText: 'Enter desired filename for upload',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.drive_file_rename_outline),
                  ),
                ),
                const SizedBox(height: 20),
                // Show the manual path input for both Linux and Windows
                if (Platform.isLinux || Platform.isWindows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
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
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed:
                              () => _loadFileFromPath(
                                _pathController.text.trim(),
                              ),
                          child: const Text('Load'),
                        ),
                      ],
                    ),
                  ),
                if (_message.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          _message.contains('fail')
                              ? Colors.red[100]
                              : Colors.green[100],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child:
                        _message.startsWith('URL:')
                            ? Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    _message,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  tooltip: 'Copy URL to clipboard',
                                  onPressed: () {
                                    final url = _message.substring(
                                      5,
                                    ); // Remove "URL: " prefix
                                    Clipboard.setData(
                                      ClipboardData(text: url.trim()),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'URL copied to clipboard',
                                        ),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            )
                            : Text(_message),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Select Image'),
                      onPressed: _isLoading ? null : _pickImage,
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.upload),
                      label: Text(_isLoading ? 'Uploading...' : 'Upload'),
                      onPressed:
                          _isLoading || _selectedImageBytes == null
                              ? null
                              : _uploadImage,
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // File listing section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Bucket Files',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Text(_fileListMessage),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _isLoadingFiles ? null : _fetchBucketFiles,
                          tooltip: 'Refresh file list',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Simple file list - filenames only
                _isLoadingFiles
                    ? const Center(child: CircularProgressIndicator())
                    : _bucketFiles.isEmpty
                    ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text('No files found in bucket'),
                      ),
                    )
                    : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _bucketFiles.length,
                      separatorBuilder:
                          (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final file = _bucketFiles[index];
                        return ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(file.name),
                          subtitle: Text(
                            '${(file.metadata?['size'] ?? 0) / 1024} KB',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy),
                                tooltip: 'Copy URL',
                                onPressed: () => _copyUrlToClipboard(file.name),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                tooltip: 'Delete file',
                                onPressed: () => _deleteFile(file.name),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
