import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Public bucket for Kanban attachments
const String kTaskAttachmentBucket = 'task_attachments';

class AttachmentService {
  final supabase = Supabase.instance.client;

  /// Upload attachment (image/pdf)
  Future<void> uploadAttachment({
    required String taskId,
    required String fileName,
    Uint8List? bytes,
    String? devicePath,
    required String mimeType,
  }) async {
    final storagePath =
        'task_$taskId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    // upload: prefer device path if available
    if (devicePath != null) {
      final file = File(devicePath);
      await supabase.storage.from(kTaskAttachmentBucket).upload(
        storagePath,
        file,
        fileOptions: const FileOptions(upsert: false),
      );
    } else if (bytes != null) {
      await supabase.storage.from(kTaskAttachmentBucket).uploadBinary(
        storagePath,
        bytes,
      );
    } else {
      throw Exception("No file data available");
    }

    // Public URL (bucket is public)
    final publicUrl =
    supabase.storage.from(kTaskAttachmentBucket).getPublicUrl(storagePath);

    await supabase.from('attachments').insert({
      'task_id': taskId,
      'file_path': storagePath,
      'file_name': fileName,
      'mime_type': mimeType,
      'caption': null,
    });
  }

  Future<List<Map<String, dynamic>>> fetchTasksWithAttachments() async {
    final res = await supabase
        .from('tasks')
        .select('*, attachments(*)')
        .order('order_index', ascending: true)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> updateCaption(String id, String caption) async {
    await supabase.from('attachments').update({'caption': caption}).eq('id', id);
  }

  Future<void> deleteAttachment(String id, String filePath) async {
    await supabase.from('attachments').delete().eq('id', id);

    await supabase.storage
        .from(kTaskAttachmentBucket)
        .remove([filePath]);
  }

  String getPublicUrl(String filePath) {
    return supabase.storage
        .from(kTaskAttachmentBucket)
        .getPublicUrl(filePath); // always a String in v2.6.0
  }
}
