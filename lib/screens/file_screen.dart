import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/current_user.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';

class FileScreen extends StatefulWidget {
  final String projectId;
  /// When true (e.g. inside [FilesTab]), no [Scaffold]/[AppBar]; uses a stack with FABs.
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
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

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

  Future<void> _uploadFile(File file, String fileName, String mimeType) async {
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
        'file_size': await file.length(),
        'mime_type': mimeType,
        'uploaded_by': CurrentUser.memberId,
        'file_type': mimeType.startsWith('image/') ? 'image' : 'document',
      });
      _loadFiles();
      _showSnackBar('File uploaded successfully');
    } catch (e) {
      _showSnackBar('Upload failed: $e');
    }
  }

  Future<void> _pickAnyFile() async {   ////////
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
        dateTime = DateTime.parse(dateTimeValue);
      } else if (dateTimeValue is DateTime) {
        dateTime = dateTimeValue;
      } else {
        return '';
      }
      // Example: 23 Apr 2025, 14:30
      return '${_monthAbbr(dateTime.month)} ${dateTime.day}, ${dateTime.year} • ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  String _monthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  //  ///////////
  Widget _fabColumn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'file_camera_${widget.projectId}',
          onPressed: _pickImageFromCamera,
          child: const Icon(Icons.camera_alt),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'file_gallery_${widget.projectId}',
          onPressed: _pickImageFromGallery,
          child: const Icon(Icons.photo_library),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'file_document_${widget.projectId}',
          onPressed: _pickAnyFile,
          child: const Icon(Icons.insert_drive_file),
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
            Center(child: Text('No files for this project yet')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _files.length,
        itemBuilder: (ctx, index) {
          final file = _files[index];
          final isImage = file['mime_type']?.startsWith('image/') ?? false;
          final fileSize = ((file['file_size'] as num?)?.toDouble() ?? 0) / 1024;
          final uploadDate = _formatDateTime(file['uploaded_at']);

          return ListTile(
            leading: isImage ? const Icon(Icons.image) : const Icon(Icons.insert_drive_file),
            title: Text(file['file_name'] as String? ?? ''),
            subtitle: Row(
              children: [
                Text('${fileSize.toStringAsFixed(1)} KB'),
                if (uploadDate.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Text(
                    uploadDate,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _downloadFile(file),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteFile(file),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Stack(
        children: [
          Positioned.fill(child: _bodyContent()),
          Positioned(
            right: 16,
            bottom: 16,
            child: _fabColumn(),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Project Files')),
      body: _bodyContent(),
      floatingActionButton: _fabColumn(),
    );
  }
}
