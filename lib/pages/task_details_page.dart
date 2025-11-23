// lib/pages/task_details_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/attachment_service.dart';

class TaskDetailsPage extends StatefulWidget {
  final Map<String, dynamic> task;
  const TaskDetailsPage({super.key, required this.task});

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  final supabase = Supabase.instance.client;
  final AttachmentService attachmentService = AttachmentService();

  late Map<String, dynamic> task;
  List<Map<String, dynamic>> attachments = [];
  List<Map<String, dynamic>> subtasks = [];
  List<Map<String, dynamic>> tempAttachments = [];

  bool isLoading = true;
  bool isSaving = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _subtaskController = TextEditingController();
  bool _addingSubtask = false;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    task = Map<String, dynamic>.from(widget.task);
    _titleController.text = task['title'] ?? '';
    _descController.text = task['description'] ?? '';
    _dueDate = _parseDate(task['due_date']);
    _loadDetails();
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  Future<void> _loadDetails() async {
    setState(() => isLoading = true);
    try {
      if (task['id'] != null) {
        final t = await supabase.from('tasks').select('*, attachments(*)').eq('id', task['id']).maybeSingle();
        if (t != null) {
          task = Map<String, dynamic>.from(t as Map);
          attachments = (task['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _titleController.text = task['title'] ?? '';
          _descController.text = task['description'] ?? '';
          _dueDate = _parseDate(task['due_date']);
        }
        final st = await supabase.from('subtasks').select().eq('task_id', task['id']).order('order_index', ascending: true);
        subtasks = List<Map<String, dynamic>>.from(st ?? []);
      }
    } catch (e) {
      debugPrint('loadDetails error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _saveBasicInfo({bool popAfter = false}) async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final due = _dueDate != null ? _dueDate!.toIso8601String().split('T').first : null;

    setState(() => isSaving = true);
    try {
      if (task['id'] == null) {
        final res = await supabase.from('tasks').insert({'title': title, 'description': desc, 'due_date': due}).select().maybeSingle();
        if (res == null) throw Exception('Task save failed');
        task = Map<String, dynamic>.from(res);

        for (var temp in List<Map<String, dynamic>>.from(tempAttachments)) {
          final File file = temp['file'] as File;
          await _uploadFile(file);
        }
        tempAttachments.clear();
      } else {
        await supabase.from('tasks').update({'title': title, 'description': desc, 'due_date': due}).eq('id', task['id']);
      }
      await _loadDetails();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      if (popAfter && mounted) Navigator.pop(context, task);
    } catch (e) {
      debugPrint('save error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // ---------------- File picking (safe) ----------------
  Future<void> _pickAndUploadAttachment() async {
    if (isSaving) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Take Photo'), onTap: () => Navigator.pop(ctx, 'camera')),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choose Image'), onTap: () => Navigator.pop(ctx, 'gallery')),
          ListTile(leading: const Icon(Icons.folder_open), title: const Text('Pick File'), onTap: () => Navigator.pop(ctx, 'file')),
          const SizedBox(height: 8),
        ]),
      ),
    );

    if (choice == null) return;
    File? pickedFile;

    try {
      if (choice == 'camera' || choice == 'gallery') {
        final picker = ImagePicker();
        final ImageSource source = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
        final XFile? picked = await picker.pickImage(source: source, maxWidth: 4000, maxHeight: 4000, imageQuality: 85);
        final String? pickedPath = picked?.path;
        if (pickedPath == null || pickedPath.isEmpty) return;
        pickedFile = File(pickedPath);
      } else if (choice == 'file') {
        final res = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
        if (res == null || res.files.isEmpty) return;
        final String? pickedPath = res.files.first.path;
        if (pickedPath == null || pickedPath.isEmpty) return;
        pickedFile = File(pickedPath);
      }

      if (pickedFile == null) return;

      final mimeType = lookupMimeType(pickedFile.path) ?? 'application/octet-stream';

      if (task['id'] == null) {
        final String safePath = pickedFile.path;
        final String fileName = safePath.split(Platform.pathSeparator).last;
        setState(() {
          tempAttachments.add({'file': pickedFile, 'fileName': fileName, 'mime_type': mimeType, 'isTemp': true});
        });
      } else {
        await _uploadFile(pickedFile);
      }
    } catch (e) {
      debugPrint('pick/upload error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attachment failed: $e')));
    }
  }

  Future<void> _uploadFile(File file) async {
    final String safePath = file.path;
    if (safePath.isEmpty) return;
    final String fileName = safePath.split(Platform.pathSeparator).last;
    final String mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';

    setState(() => isSaving = true);
    try {
      await attachmentService.uploadAttachment(taskId: task['id'].toString(), fileName: fileName, devicePath: safePath, mimeType: mimeType);
      await _loadDetails();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attachment uploaded')));
    } catch (e) {
      debugPrint('upload error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // ---------------- Delete attachment ----------------
  Future<void> _deleteAttachment(Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete attachment'),
        content: const Text('Delete this attachment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    if (a['isTemp'] == true) {
      setState(() => tempAttachments.remove(a));
    } else {
      await attachmentService.deleteAttachment(a['id'].toString(), a['file_path'].toString());
      await _loadDetails();
    }
  }

  // ---------------- UI / helpers ----------------
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme; // ✅ Used for theme colors
    final titleStyle = TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: colorScheme.onSurface); // ✅ Themed text color

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Task Details'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // ✅ Themed
        foregroundColor: colorScheme.onSurface, // ✅ Themed
      ),
      bottomNavigationBar: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, border: Border(top: BorderSide(color: Theme.of(context).dividerColor))), // ✅ Themed
        child: SafeArea(
          top: false,
          child: Row(children: [
            const Spacer(),
            TextButton(
              onPressed: () => _saveBasicInfo(popAfter: true),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  backgroundColor: colorScheme.primaryContainer, // ✅ Themed
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text('Save', style: TextStyle(color: colorScheme.onPrimaryContainer)), // ✅ Themed
            ),
          ]),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 12),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
                controller: _titleController,
                decoration: const InputDecoration.collapsed(hintText: 'Add title'),
                style: titleStyle,
                onSubmitted: (_) => _saveBasicInfo()
            ),
            const SizedBox(height: 16),
            _buildDetailsRowInlinePreview(),
            _buildDueRowCompact(),
            _subtasksAreaCompact(),
            _attachmentsList(),
            const SizedBox(height: 120),
          ]),
        ),
      ),
    );
  }

  Widget _buildDetailsRowInlinePreview() {
    final previewText = _descController.text.trim();
    final colorScheme = Theme.of(context).colorScheme; // ✅

    return InkWell(
      onTap: () async {
        final controller = TextEditingController(text: _descController.text);
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Add details'),
            content: TextField(controller: controller, maxLines: 8, decoration: const InputDecoration(hintText: 'Add details')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
            ],
          ),
        );
        if (ok == true) {
          _descController.text = controller.text;
          await _saveBasicInfo();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.menu, size: 22, color: colorScheme.onSurface.withOpacity(0.6)), // ✅ Themed
          const SizedBox(width: 14),
          Expanded(child: Text(previewText.isEmpty ? 'Add details' : previewText, softWrap: true, style: TextStyle(fontSize: 16, color: previewText.isEmpty ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.8)))), // ✅ Themed
        ]),
      ),
    );
  }

  Widget _buildDueRowCompact() {
    final colorScheme = Theme.of(context).colorScheme; // ✅

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(Icons.calendar_today, size: 22, color: colorScheme.onSurface.withOpacity(0.6)), // ✅ Themed
        const SizedBox(width: 14),
        if (_dueDate == null)
          InkWell(onTap: _pickDueDate, child: Text('Add date/time', style: TextStyle(fontSize: 16, color: colorScheme.onSurface))) // ✅ Themed
        else
          InputChip(label: Text(_dueDate!.toLocal().toIso8601String().split('T').first), onDeleted: _clearDueDate),
      ]),
    );
  }

  Widget _subtasksAreaCompact() {
    final colorScheme = Theme.of(context).colorScheme; // ✅

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(onTap: () => setState(() => _addingSubtask = true), child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [Icon(Icons.subdirectory_arrow_right, size: 22, color: colorScheme.onSurface.withOpacity(0.6)), SizedBox(width: 14), Text('Add subtasks', style: TextStyle(fontSize: 16, color: colorScheme.onSurface))]))), // ✅ Themed
      if (_addingSubtask)
        Padding(
          padding: const EdgeInsets.only(left: 44.0, right: 8.0, bottom: 6.0),
          child: Row(children: [
            Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colorScheme.outline))), // ✅ Themed
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _subtaskController, autofocus: true, decoration: const InputDecoration.collapsed(hintText: 'Enter title'), onSubmitted: (v) async => await _addSubtask(v))),
            IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () => setState(() {
              _addingSubtask = false;
              _subtaskController.clear();
            })),
          ]),
        ),
      ...subtasks.map((s) {
        return Padding(
          padding: const EdgeInsets.only(left: 44.0),
          child: Row(children: [
            GestureDetector(
              onTap: () => _toggleSubtask(s),
              child: s['is_done'] == true ? Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.green), child: const Icon(Icons.check, size: 16, color: Colors.white)) : Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colorScheme.outline))), // ✅ Themed
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(s['title'] ?? '', style: TextStyle(fontSize: 15, color: colorScheme.onSurface))), // ✅ Themed
            IconButton(icon: Icon(Icons.delete_outline, color: colorScheme.error), onPressed: () => _deleteSubtask(s)), // ✅ Themed
          ]),
        );
      }).toList(),
    ]);
  }

  Widget _attachmentsList() {
    final colorScheme = Theme.of(context).colorScheme; // ✅
    final allAttachments = [...attachments, ...tempAttachments];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Row(children: [
        Icon(Icons.attach_file, size: 22, color: colorScheme.onSurface.withOpacity(0.6)), // ✅ Themed
        const SizedBox(width: 14),
        Text('Attachments', style: TextStyle(fontSize: 16, color: colorScheme.onSurface)), // ✅ Themed
        const Spacer(),
        IconButton(icon: isSaving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.add_photo_alternate_outlined, color: colorScheme.primary), onPressed: isSaving ? null : _pickAndUploadAttachment), // ✅ Themed
      ]),
      const SizedBox(height: 8),
      if (allAttachments.isNotEmpty)
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: allAttachments.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final a = allAttachments[i];
              final isTemp = a['isTemp'] == true;
              final mime = (a['mime_type'] ?? '').toString();
              final caption = (a['caption'] ?? '').toString();

              if (isTemp) {
                final file = a['file'] as File;
                final fileName = (a['fileName'] ?? file.path.split(Platform.pathSeparator).last).toString();
                return Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: mime.startsWith('image/')
                        ? Image.file(file, width: 140, height: 80, fit: BoxFit.cover)
                        : Container(width: 140, height: 80, color: colorScheme.surfaceVariant, child: Center(child: Icon(Icons.picture_as_pdf, color: colorScheme.error))), // ✅ Themed
                  ),
                  Positioned(top: 0, right: 0, child: GestureDetector(onTap: () => setState(() => tempAttachments.remove(a)), child: Container(decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: const Icon(Icons.close, size: 14, color: Colors.white)))),
                ]);
              } else {
                final url = attachmentService.getPublicUrl(a['file_path']);
                if (mime.startsWith('image/')) {
                  return GestureDetector(onTap: () => _openImage(url!), onLongPress: () => _deleteAttachment(a), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: url!, width: 140, height: 80, fit: BoxFit.cover)));
                } else {
                  return GestureDetector(
                    onTap: () => _openPdf(url!),
                    onLongPress: () => _deleteAttachment(a),
                    child: Container(width: 180, padding: const EdgeInsets.all(8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: colorScheme.surfaceVariant), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ // ✅ Themed
                       Row(children: [Icon(Icons.picture_as_pdf, color: colorScheme.error), SizedBox(width: 8), Text('PDF', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant))]), // ✅ Themed
                      const SizedBox(height: 6),
                      Text(a['file_name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: colorScheme.onSurfaceVariant)), // ✅ Themed
                      if (caption.isNotEmpty) Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)), // ✅ Themed
                    ])),
                  );
                }
              }
            },
          ),
        ),
    ]);
  }

  // ---------------- subtasks helpers ----------------
  Future<void> _addSubtask(String title) async {
    if (title.trim().isEmpty) return;
    await supabase.from('subtasks').insert({'task_id': task['id'], 'title': title.trim()});
    _subtaskController.clear();
    setState(() => _addingSubtask = false);
    await _loadDetails();
  }

  Future<void> _toggleSubtask(Map<String, dynamic> s) async {
    final newVal = !(s['is_done'] == true);
    await supabase.from('subtasks').update({'is_done': newVal}).eq('id', s['id']);
    await _loadDetails();
  }

  Future<void> _deleteSubtask(Map<String, dynamic> s) async {
    await supabase.from('subtasks').delete().eq('id', s['id']);
    await _loadDetails();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(context: context, initialDate: _dueDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked == null) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    _dueDate = time != null ? DateTime(picked.year, picked.month, picked.day, time.hour, time.minute) : DateTime(picked.year, picked.month, picked.day);
    await _saveBasicInfo();
  }

  Future<void> _clearDueDate() async {
    _dueDate = null;
    await _saveBasicInfo();
  }

  void _openPdf(String url) => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('PDF Viewer')), body: SfPdfViewer.network(url))));
  void _openImage(String url) => showDialog(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: CachedNetworkImage(imageUrl: url))));
}
