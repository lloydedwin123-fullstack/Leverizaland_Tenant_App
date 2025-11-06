import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class FileService {
  final supabase = Supabase.instance.client;

  /// Presents the user with a choice to pick an image/document from various sources.
  Future<File?> pickFile(BuildContext context) async {
    // Show a dialog to let the user choose the source.
    final source = await showDialog<ImageSource?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select File Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Select a Document'),
              onTap: () => Navigator.pop(context, null), // Special case for file picker
            ),
          ],
        ),
      ),
    );

    if (source != null) { // User chose camera or gallery
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } else { // User chose to select a document
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
    }
    return null;
  }

  /// Fetch files by category + reference (tenant_id, lease_id, etc.)
  Future<List<Map<String, dynamic>>> getFiles(
      String category, String referenceId) async {
    final res = await supabase
        .from('files')
        .select()
        .eq('category', category)
        .eq('reference_id', referenceId)
        .order('uploaded_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Upload file (multi-category support)
  Future<void> uploadFile({
    required String category,       // e.g. 'unit_documents'
    required String referenceId,    // e.g. 'opal_1'
    required File file,
    bool isPublic = false,          // choose bucket
    String? documentType,           // e.g. 'building_permit'
  }) async {
    final bucket = isPublic ? 'public_files' : 'private_files';
    final fileName = path.basename(file.path);
    
    // Generate a unique file path
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final userId = supabase.auth.currentUser?.id ?? 'anon';
    final uniqueFileName = '${timestamp}_${fileName}';
    final storagePath = '$category/$referenceId/$userId/$uniqueFileName';

    try {
      await supabase.storage.from(bucket).upload(
        storagePath,
        file,
        fileOptions: const FileOptions(upsert: false), // Do not upsert to prevent accidental overwrites
      );

      final fileUrl =
      supabase.storage.from(bucket).getPublicUrl(storagePath);

      // Insert record into files table
      await supabase.from('files').insert({
        'category': category,
        'reference_id': referenceId,
        'file_name': fileName, // Keep original filename for display
        'file_url': fileUrl,
        'storage_bucket': bucket,
        'document_type': documentType,
        'uploaded_by': supabase.auth.currentUser?.email, // Log the user's email
        'mime_type': lookupMimeType(fileName), // Basic MIME type lookup
        'file_size': await file.length(),
      });

      debugPrint('✅ File uploaded under $category → $referenceId');
    } catch (e) {
      debugPrint('❌ Upload failed: $e');
      rethrow;
    }
  }

  /// Delete file
  Future<void> deleteFile({
    required String fileId,
    required String fileUrl,
  }) async {
    try {
      final bucket = fileUrl.contains('/public_files/') ? 'public_files' : 'private_files';
      final filePath =
      fileUrl.split('/storage/v1/object/public/$bucket/').last;
      
      await supabase.storage.from(bucket).remove([filePath]);
      await supabase.from('files').delete().eq('id', fileId);
      debugPrint('🗑️ File deleted successfully.');
    } catch (e) {
      debugPrint('❌ Delete failed: $e');
      rethrow;
    }
  }

  String? lookupMimeType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    const mimeTypes = {
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
    };
    return mimeTypes[extension];
  }
}
