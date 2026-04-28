import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/current_user.dart';
import '../services/network_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';

enum SortOption { nameAsc, nameDesc, sizeAsc, sizeDesc, dateAsc, dateDesc }

class FileScreen extends StatefulWidget {
  final String projectId;
  final bool embedded;

  const FileScreen({
    super.key,
    required this.projectId,
    this.embedded = false,
  });

  @override
  State<FileScreen> createState() => _FileScreenState();
}

class _FileScreenState extends State<FileScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _files = [];
  List<Map<String, dynamic>> _filteredFiles = [];
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  // search & sort
  String _searchQuery = '';
  SortOption _sortBy = SortOption.dateDesc;

  // batch selection
  bool _selectionMode = false;
  final Set<String> _selectedFileIds = {};

  static const int maxFileSizeMB = 10;
  static const int maxFileSizeBytes = maxFileSizeMB * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void didUpdateWidget(covariant FileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _loadFiles();
    }
  }

  Future<void> _loadFiles() async {
    if (!await NetworkService.hasInternet()) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('No internet connection. Cannot load files.');
      }
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('files')
          .select('*')
          .eq('project_id', widget.projectId)
          .order('uploaded_at', ascending: false);
      if (mounted) {
        setState(() {
          _files = List<Map<String, dynamic>>.from(response as List<dynamic>);
          _applyFilterAndSort();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading files: $e');
      }
    }
  }

  void _applyFilterAndSort() {
    List<Map<String, dynamic>> filtered = _files.where((file) {
      final fileName = file['file_name'] as String? ?? '';
      return fileName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    filtered.sort((a, b) {
      switch (_sortBy) {
        case SortOption.nameAsc:
          return (a['file_name'] ?? '').compareTo(b['file_name'] ?? '');
        case SortOption.nameDesc:
          return (b['file_name'] ?? '').compareTo(a['file_name'] ?? '');
        case SortOption.sizeAsc:
          return (a['file_size'] as int).compareTo(b['file_size'] as int);
        case SortOption.sizeDesc:
          return (b['file_size'] as int).compareTo(a['file_size'] as int);
        case SortOption.dateAsc:
          return (a['uploaded_at'] ?? '').compareTo(b['uploaded_at'] ?? '');
        case SortOption.dateDesc:
          return (b['uploaded_at'] ?? '').compareTo(a['uploaded_at'] ?? '');
      }
    });
    setState(() {
      _filteredFiles = filtered;
    });
  }

  Future<void> _uploadFile(File file, String fileName, String mimeType) async {
    // check file size
    final fileSize = await file.length();
    if (fileSize > maxFileSizeBytes) {
      _showSnackBar('File too large. Maximum size is $maxFileSizeMB MB.');
      return;
    }

    // check internet
    if (!await NetworkService.hasInternet()) {
      _showSnackBar('No internet connection. Please try again later.');
      return;
    }

    if (CurrentUser.memberId == null) {
      _showSnackBar('User not logged in');
      return;
    }

    try {
      final storagePath = '${widget.projectId}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _supabase.storage.from('project_files').upload(storagePath, file);

      await _supabase.from('files').insert({
        'project_id': widget.projectId,
        'file_name': fileName,
        'storage_path': storagePath,
        'file_size': fileSize,
        'mime_type': mimeType,
        'uploaded_by': CurrentUser.memberId,
        'file_type': mimeType.startsWith('image/') ? 'image' : 'document',
      });
      _loadFiles();
      _showSnackBar('File uploaded successfully');
    } on StorageException catch (e) {
      // specific Storage errors
      if (e.message.contains('Bucket not found')) {
        _showSnackBar('Storage bucket not configured. Contact support.');
      } else if (e.statusCode == 413) {
        _showSnackBar('File too large for server. Try a smaller file.');
      } else {
        _showSnackBar('Upload failed: ${e.message}');
      }
    } catch (e) {
      _showSnackBar('Upload failed: $e');
    }
  }

  Future<void> _pickAnyFile() async {   // //////
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final mimeType = result.files.single.extension ?? 'application/octet-stream';
      await _uploadFile(file, fileName, mimeType);
    }
  }

  Future<void> _pickImageFromCamera() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      final file = File(photo.path);
      await _uploadFile(file, photo.name, 'image/jpeg');
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final file = File(image.path);
      await _uploadFile(file, image.name, 'image/jpeg');
    }
  }

  Future<void> _downloadFile(Map<String, dynamic> fileMap) async {
    final storagePath = fileMap['storage_path'];
    final fileName = fileMap['file_name'];

    try {
      final bytes = await _supabase.storage.from('project_files').download(storagePath);
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/$fileName');
      await localFile.writeAsBytes(bytes);
      await OpenFile.open(localFile.path); //  open the file
      _showSnackBar('Downloaded to ${localFile.path} and opened');
    } catch (e) {
      _showSnackBar('Download failed: $e');
    }
  }

  Future<void> _deleteFile(Map<String, dynamic> fileMap) async {
    final fileId = fileMap['id'];
    final storagePath = fileMap['storage_path'];
    final uploadedBy = fileMap['uploaded_by'];
    if (uploadedBy != CurrentUser.memberId) {
      _showSnackBar('You can only delete files you uploaded');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Delete "${fileMap['file_name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _supabase.storage.from('project_files').remove([storagePath]);
      await _supabase.from('files').delete().eq('id', fileId);
      _loadFiles();
      _showSnackBar('File deleted');
    } catch (e) {
      _showSnackBar('Delete failed: $e');
    }
  }

  // batch operations: delete selected
  Future<void> _batchDelete() async {
    if (_selectedFileIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete files'),
        content: Text('Delete ${_selectedFileIds.length} file(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      for (final fileId in _selectedFileIds) {
        final file = _files.firstWhere((f) => f['id'] == fileId);
        final storagePath = file['storage_path'];
        await _supabase.storage.from('project_files').remove([storagePath]);
        await _supabase.from('files').delete().eq('id', fileId);
      }
      _loadFiles();
      _exitSelectionMode();
      _showSnackBar('Deleted ${_selectedFileIds.length} file(s)');
    } catch (e) {
      _showSnackBar('Batch delete failed: $e');
      setState(() => _isLoading = false);
    }
  }

  // batch operations: download selected
  Future<void> _batchDownload() async {
    if (_selectedFileIds.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      for (final fileId in _selectedFileIds) {
        final file = _files.firstWhere((f) => f['id'] == fileId);
        final storagePath = file['storage_path'];
        final bytes = await _supabase.storage.from('project_files').download(storagePath);
        final dir = await getApplicationDocumentsDirectory();
        final localFile = File('${dir.path}/${file['file_name']}');
        await localFile.writeAsBytes(bytes);
      }
      _showSnackBar('Downloaded ${_selectedFileIds.length} file(s)');
      _exitSelectionMode();
    } catch (e) {
      _showSnackBar('Batch download failed: $e');
    }
    setState(() => _isLoading = false);
  }

  void _toggleSelection(String fileId) {
    setState(() {
      if (_selectedFileIds.contains(fileId)) {
        _selectedFileIds.remove(fileId);
      } else {
        _selectedFileIds.add(fileId);
      }
      if (_selectedFileIds.isEmpty) _selectionMode = false;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedFileIds.clear();
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // helper to format the upload date/time
  String _formatDateTime(dynamic dateTimeValue) {
    if (dateTimeValue == null) return '';
    try {
      DateTime dateTime;
      if (dateTimeValue is String) {
        dateTime = DateTime.parse(dateTimeValue).toLocal(); // convert to local
      } else if (dateTimeValue is DateTime) {
        dateTime = dateTimeValue.toLocal();               // convert to local
      } else {
        return '';
      }
      return '${_monthAbbr(dateTime.month)} ${dateTime.day}, ${dateTime.year} • ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  String _monthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  //  ///////
  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Upload from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Upload File (PDF, DOC, TXT)'),
              onTap: () {
                Navigator.pop(context);
                _pickAnyFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndSort() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search files...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _applyFilterAndSort();
              },
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<SortOption>(
            value: _sortBy,
            onChanged: (newValue) {
              if (newValue != null) {
                setState(() => _sortBy = newValue);
                _applyFilterAndSort();
              }
            },
            items: const [
              DropdownMenuItem(value: SortOption.nameAsc, child: Text('Name A-Z')),
              DropdownMenuItem(value: SortOption.nameDesc, child: Text('Name Z-A')),
              DropdownMenuItem(value: SortOption.sizeAsc, child: Text('Size ↑')),
              DropdownMenuItem(value: SortOption.sizeDesc, child: Text('Size ↓')),
              DropdownMenuItem(value: SortOption.dateAsc, child: Text('Date ↑')),
              DropdownMenuItem(value: SortOption.dateDesc, child: Text('Date ↓')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatchFABs() {
    if (!_selectionMode || _selectedFileIds.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'batch_delete_${widget.projectId}',
          onPressed: _batchDelete,
          child: const Icon(Icons.delete),
          backgroundColor: Colors.red,
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'batch_download_${widget.projectId}',
          onPressed: _batchDownload,
          child: const Icon(Icons.download),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'batch_cancel_${widget.projectId}',
          onPressed: _exitSelectionMode,
          child: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _bodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_files.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFiles,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 48),
            Center(child: Text('No files match your search or no files yet')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _filteredFiles.length,
        itemBuilder: (ctx, index) {
          final file = _filteredFiles[index];
          final fileId = file['id'];
          final isImage = file['mime_type']?.startsWith('image/') ?? false;
          final fileSize = ((file['file_size'] as num?)?.toDouble() ?? 0) / 1024;
          final uploadDate = _formatDateTime(file['uploaded_at']);
          final isSelected = _selectedFileIds.contains(fileId);
          final storagePath = file['storage_path'];
          final publicUrl = _supabase.storage.from('project_files').getPublicUrl(storagePath);

          return ListTile(
            leading: _selectionMode
                ? Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleSelection(fileId),
            )
                : (isImage
                ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: publicUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Icon(Icons.image, size: 48),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
              ),
            )
                : const Icon(Icons.picture_as_pdf, size: 48)),
            title: Text(file['file_name'] as String? ?? ''),
            subtitle: Text('${fileSize.toStringAsFixed(1)} KB • $uploadDate'),
            trailing: _selectionMode
                ? null
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.download), onPressed: () => _downloadFile(file)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteFile(file)),
              ],
            ),
            onLongPress: () => setState(() => _selectionMode = true),
            onTap: () {
              if (_selectionMode) {
                _toggleSelection(fileId);
                if (_selectedFileIds.isEmpty) _exitSelectionMode();
              } else {
                _downloadFile(file);
              }
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        _buildSearchAndSort(),
        Expanded(child: _bodyContent()),
      ],
    );

    if (widget.embedded) {
      // Embedded mode: no Scaffold, use Stack with custom FABs
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: body),
            Positioned(
              right: 16,
              bottom: 16,
              child: _selectionMode
                  ? _buildBatchFABs()
                  : FloatingActionButton(
                onPressed: _showUploadOptions,
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Files'),
        actions: [
          if (_selectionMode) ...[
            IconButton(icon: const Icon(Icons.delete), onPressed: _batchDelete),
            IconButton(icon: const Icon(Icons.download), onPressed: _batchDownload),
            IconButton(icon: const Icon(Icons.close), onPressed: _exitSelectionMode),
          ] else ...[
            IconButton(icon: const Icon(Icons.upload), onPressed: _showUploadOptions),
          ],
        ],
      ),
      body: body,
      floatingActionButton: _selectionMode ? null : FloatingActionButton(
        onPressed: _showUploadOptions,
        child: const Icon(Icons.add),
      ),
    );
  }
}