import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/file_service.dart';

class FileSectionWidget extends StatefulWidget {
  final String category;       // e.g. 'payment_proofs', 'tenant_documents'
  final String referenceId;    // e.g. payment_id, tenant_id
  final bool isPublic;         // decides which bucket
  final String title;          // section label (optional)

  const FileSectionWidget({
    super.key,
    required this.category,
    required this.referenceId,
    this.isPublic = false,
    this.title = 'Attached Files',
  });

  @override
  State<FileSectionWidget> createState() => _FileSectionWidgetState();
}

class _FileSectionWidgetState extends State<FileSectionWidget> {
  final fileService = FileService();
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchFiles();
  }

  Future<void> _fetchFiles() async {
    setState(() => _loading = true);
    try {
      final files =
      await fileService.getFiles(widget.category, widget.referenceId);
      setState(() {
        _files = files;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading files: $e')),
      );
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );
      if (result == null) return;

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploading $fileName...')),
      );

      await fileService.uploadFile(
        category: widget.category,
        referenceId: widget.referenceId,
        file: file,
        isPublic: widget.isPublic,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File uploaded successfully!')),
      );

      _fetchFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  Future<void> _deleteFile(String fileId, String fileName, String fileUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text('Remove "$fileName" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await fileService.deleteFile(fileId: fileId, fileUrl: fileUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $fileName')),
      );
      _fetchFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(12.0),
        child: CircularProgressIndicator(),
      ));
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==== Header ====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.upload_file, color: Colors.blue),
                  tooltip: 'Attach New File',
                  onPressed: _pickAndUploadFile,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ==== Empty state ====
            if (_files.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'No attached files found.',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              Column(
                children: _files.map((f) {
                  final fileName = f['file_name'] ?? 'Unnamed file';
                  final fileUrl = f['file_url'] ?? '';
                  final fileId = f['id'].toString();

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 0.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.attach_file, color: Colors.blue),
                      title: Text(
                        fileName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteFile(fileId, fileName, fileUrl),
                      ),
                      onTap: () async {
                        final uri = Uri.parse(fileUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open the file link.'),
                            ),
                          );
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
