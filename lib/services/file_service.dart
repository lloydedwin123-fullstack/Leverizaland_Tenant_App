import 'package:supabase_flutter/supabase_flutter.dart';

class FileService {
  final supabase = Supabase.instance.client;

  // Fetch all files related to a record (e.g. payment, lease, etc.)
  Future<List<Map<String, dynamic>>> getFiles(String category, String referenceId) async {
    final res = await supabase
        .from('files')
        .select('id, file_name, file_url, file_type, uploaded_at')
        .eq('category', category)
        .eq('reference_id', referenceId)
        .order('uploaded_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  // Add a file record after upload
  Future<void> addFile({
    required String category,
    required String referenceId,
    required String fileName,
    required String fileUrl,
    String? fileType,
  }) async {
    await supabase.from('files').insert({
      'category': category,
      'reference_id': referenceId,
      'file_name': fileName,
      'file_url': fileUrl,
      'file_type': fileType,
    });
  }

  // Delete file record
  Future<void> deleteFile(String fileId) async {
    await supabase.from('files').delete().eq('id', fileId);
  }
}
