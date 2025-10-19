import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class FileService {
  final supabase = Supabase.instance.client;

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
    String? uploadedBy,             // optional: staff name or tenant
  }) async {
    final bucket = isPublic ? 'public_files' : 'private_files';
    final fileName = path.basename(file.path);
    final storagePath = '$category/$referenceId/$fileName';

    // 🧠 Check Supabase session
    final auth = supabase.auth;
    var session = auth.currentSession;
    if (session == null) {
      debugPrint('⚠️ No Supabase session before upload. Creating one...');
      await auth.signInAnonymously();
      session = auth.currentSession;
    }

    // 🧠 Upload to Storage
    try {
      await supabase.storage.from(bucket).upload(
        storagePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      final fileUrl =
      supabase.storage.from(bucket).getPublicUrl(storagePath);

      // 🧩 Insert record into files table
      await supabase.from('files').insert({
        'category': category,
        'reference_id': referenceId,
        'file_name': fileName,
        'file_url': fileUrl,
        'storage_bucket': bucket,
        'document_type': documentType,
        'uploaded_by': uploadedBy,
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
      final filePath =
      fileUrl.split('/storage/v1/object/public/').last.split('/').skip(1).join('/');
      await supabase.storage.from('private_files').remove([filePath]);
      await supabase.from('files').delete().eq('id', fileId);
      debugPrint('🗑️ File deleted successfully.');
    } catch (e) {
      debugPrint('❌ Delete failed: $e');
    }
  }
}
