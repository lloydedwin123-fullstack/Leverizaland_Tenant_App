// lib/pages/tasks_page.dart
// Replace your current tasks_page.dart with this file.
//
// NOTE: your TaskDetailsPage (used for details/edit screen) is expected at:
// /mnt/data/task_details_page.dart  (your uploaded file path)
//
// Imports
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/attachment_service.dart';
import 'task_details_page.dart'; // make sure this file exists in lib/pages

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final supabase = Supabase.instance.client;
  final AttachmentService attachmentService = AttachmentService();

  bool loading = true;
  List<Map<String, dynamic>> tasks = [];

  final GlobalKey<_CompletedSectionState> _completedKey = GlobalKey<_CompletedSectionState>();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // --- Load active tasks (completed = false)
  Future<void> _loadTasks() async {
    setState(() => loading = true);
    try {
      final res = await supabase
          .from('tasks')
          .select('*, subtasks(*), attachments(*)')
          .eq('completed', false)
          .order('order_index', ascending: true)
          .order('created_at', ascending: true);

      tasks = List<Map<String, dynamic>>.from(res ?? []);
    } catch (e) {
      debugPrint('loadTasks error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load tasks: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Safe ID handling for UUID string ids
  String _idToString(dynamic id) {
    if (id == null) return '';
    return id.toString();
  }

  // Robust mark complete/incomplete
  Future<void> _setCompleted(dynamic id, bool value) async {
    final idValue = _idToString(id);
    if (idValue.isEmpty) {
      debugPrint('_setCompleted abort: id empty');
      return;
    }

    try {
      // update, return updated row(s)
      final updated = await supabase
          .from('tasks')
          .update({'completed': value, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', idValue)
          .select();

      debugPrint('_setCompleted updated: $updated');

      // quick validation read
      final check = await supabase.from('tasks').select('id, title, completed').eq('id', idValue).maybeSingle();
      debugPrint('_setCompleted check: $check');

      // reload lists
      await _loadTasks();
      await _completedKey.currentState?.reload();
    } catch (e) {
      debugPrint('_setCompleted error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
    }
  }

  // Delete entire task (subtasks + attachments + task row)
  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('Delete task and its subtasks/attachments?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => loading = true);

    try {
      final idValue = _idToString(task['id']);
      // delete attachments from storage and row
      final attachments = (task['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final a in attachments) {
        final filePath = (a['file_path'] ?? '').toString();
        final aId = (a['id'] ?? '').toString();
        if (filePath.isNotEmpty) {
          try {
            // remove from storage bucket
            await supabase.storage.from('task_attachments').remove([filePath]);
          } catch (e) {
            debugPrint('failed to remove storage file $filePath: $e');
          }
        }
        if (aId.isNotEmpty) {
          try {
            await supabase.from('attachments').delete().eq('id', aId);
          } catch (e) {
            debugPrint('failed to delete attachments row $aId: $e');
          }
        }
      }

      // delete subtasks
      await supabase.from('subtasks').delete().eq('task_id', idValue);

      // delete task
      await supabase.from('tasks').delete().eq('id', idValue);

      await _loadTasks();
      await _completedKey.currentState?.reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task deleted')));
    } catch (e) {
      debugPrint('deleteTask error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Create a quick task and open details
  Future<void> _createQuickTask() async {
    try {
      final insert = await supabase.from('tasks').insert({
        'title': 'New task',
        'description': '',
        'completed': false,
        'order_index': 9999,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      final newId = insert['id'];
      final full = await supabase.from('tasks').select('*, subtasks(*), attachments(*)').eq('id', newId).maybeSingle();
      final taskMap = (full != null) ? Map<String, dynamic>.from(full as Map) : Map<String, dynamic>.from(insert as Map);

      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailsPage(task: taskMap)));
      if (result != null) {
        await _loadTasks();
        await _completedKey.currentState?.reload();
      } else {
        await _loadTasks();
      }
    } catch (e) {
      debugPrint('_createQuickTask error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    }
  }

  // Open details: reload single task before push
  Future<void> _openDetails(Map<String, dynamic> t) async {
    try {
      final idValue = _idToString(t['id']);
      final res = await supabase.from('tasks').select('*, subtasks(*), attachments(*)').eq('id', idValue).maybeSingle();
      final full = res != null ? Map<String, dynamic>.from(res as Map) : t;
      final changed = await Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailsPage(task: full)));
      if (changed != null) {
        await _loadTasks();
        await _completedKey.currentState?.reload();
      }
    } catch (e) {
      debugPrint('_openDetails error: $e');
    }
  }

  Widget _buildTaskCard(Map<String, dynamic> t) {
    final title = (t['title'] ?? '').toString();
    final desc = (t['description'] ?? '').toString();
    final due = _formatDate(t['due_date']);
    final subtasks = (t['subtasks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final attachments = (t['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Check circle
            GestureDetector(
              onTap: () => _setCompleted(t['id'], !(t['completed'] == true)),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (t['completed'] == true) ? Colors.green : Colors.white,
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: (t['completed'] == true)
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
            ),

            const SizedBox(width: 12),

            // Title / description / subtasks
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + date aligned right
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      if (due.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(due, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Description (full, multi-line)
                  if (desc.isNotEmpty)
                    InkWell(
                      onTap: () => _openDetails(t), // full card is clickable; also allow direct open on description
                      child: Text(desc, style: TextStyle(fontSize: 14, color: Colors.grey[800])),
                    ),

                  // Subtasks: indented bullet-like list, markable
                  if (subtasks.isNotEmpty) const SizedBox(height: 12),
                  if (subtasks.isNotEmpty)
                    Column(
                      children: subtasks.map((s) {
                        final done = s['is_done'] == true;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 6.0),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _toggleSubtask(s),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey.shade400),
                                    color: done ? Colors.green : Colors.transparent,
                                  ),
                                  child: done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  s['title'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: done ? Colors.grey : Colors.black87,
                                    decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteSubtask(s),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  // Attachments preview (horizontal row)
                  if (attachments.isNotEmpty) const SizedBox(height: 12),
                  if (attachments.isNotEmpty)
                    SizedBox(
                      height: 82,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: attachments.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final a = attachments[i];
                          final publicUrl = attachmentService.getPublicUrl(a['file_path'] ?? '');
                          final fileName = a['file_name'] ?? '';
                          final mime = a['mime_type'] ?? '';
                          final isPdf = (mime as String).contains('pdf') || fileName.toString().toLowerCase().endsWith('.pdf');

                          return GestureDetector(
                            onTap: () {
                              // open details (or preview implementation)
                              _openDetails(t);
                            },
                            child: Container(
                              width: 160,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(6),
                                      image: !isPdf && publicUrl != null && publicUrl.isNotEmpty
                                          ? DecorationImage(image: NetworkImage(publicUrl), fit: BoxFit.cover)
                                          : null,
                                    ),
                                    child: isPdf
                                        ? Center(child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.picture_as_pdf, size: 28, color: Colors.red),
                                        SizedBox(height: 4),
                                      ],
                                    ))
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(fileName.toString(), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // Popup (three dots) - open, complete, delete
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'open') {
                  await _openDetails(t);
                } else if (v == 'complete') {
                  await _setCompleted(t['id'], true);
                } else if (v == 'delete') {
                  await _deleteTask(t);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'open', child: Text('Open')),
                PopupMenuItem(value: 'complete', child: Text('Mark as complete')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // toggle subtask done
  Future<void> _toggleSubtask(Map<String, dynamic> s) async {
    try {
      final idVal = _idToString(s['id']);
      if (idVal.isEmpty) return;
      final current = s['is_done'] == true;
      await supabase.from('subtasks').update({'is_done': !current}).eq('id', idVal);
      await _loadTasks();
      await _completedKey.currentState?.reload();
    } catch (e) {
      debugPrint('_toggleSubtask error: $e');
    }
  }

  Future<void> _deleteSubtask(Map<String, dynamic> s) async {
    try {
      final idVal = _idToString(s['id']);
      if (idVal.isEmpty) return;
      await supabase.from('subtasks').delete().eq('id', idVal);
      await _loadTasks();
    } catch (e) {
      debugPrint('_deleteSubtask error: $e');
    }
  }

  // format a basic date string
  String _formatDate(dynamic v) {
    if (v == null) return '';
    try {
      final dt = DateTime.tryParse(v.toString());
      if (dt == null) return v.toString();
      return '${dt.year.toString().padLeft(4,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
    } catch (_) {
      return v.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black87,
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadTasks,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('My Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            // tasks list
            ...tasks.map((t) => _buildTaskCard(t)).toList(),
            const SizedBox(height: 16),
            // Completed collapsible
            _CompletedSection(key: _completedKey, onRefreshParent: _loadTasks),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createQuickTask,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Completed section widget
class _CompletedSection extends StatefulWidget {
  final Future<void> Function() onRefreshParent;
  const _CompletedSection({super.key, required this.onRefreshParent});

  @override
  State<_CompletedSection> createState() => _CompletedSectionState();
}

class _CompletedSectionState extends State<_CompletedSection> {
  final supabase = Supabase.instance.client;
  bool expanded = false;
  bool loading = false;
  List<Map<String, dynamic>> completed = [];

  Future<void> reload() async => _loadCompleted();

  Future<void> showAndReload() async {
    await _loadCompleted();
    if (mounted) setState(() => expanded = true);
  }

  Future<void> _loadCompleted() async {
    setState(() => loading = true);
    try {
      final res = await supabase.from('tasks').select('id, title, description, updated_at').eq('completed', true).order('updated_at', ascending: false);
      debugPrint('_loadCompleted raw: $res');
      completed = List<Map<String, dynamic>>.from(res ?? []);
      debugPrint('_loadCompleted parsed count: ${completed.length}');
    } catch (e) {
      debugPrint('_loadCompleted error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () async {
            setState(() => expanded = !expanded);
            if (expanded) await _loadCompleted();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text('Completed', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                CircleAvatar(radius: 12, backgroundColor: Colors.grey.shade200, child: Text('${completed.length}', style: const TextStyle(fontSize: 12))),
                const Spacer(),
                Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
              ],
            ),
          ),
        ),
        if (expanded)
          loading
              ? const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())
              : Column(
            children: completed
                .map((t) => ListTile(
              title: Text(t['title'] ?? ''),
              subtitle: (t['description'] ?? '').toString().isNotEmpty ? Text(t['description'] ?? '') : null,
              onTap: () async {
                // open details for completed
                final idVal = t['id']?.toString() ?? '';
                final full = await supabase.from('tasks').select('*, subtasks(*), attachments(*)').eq('id', idVal).maybeSingle();
                if (full != null) {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailsPage(task: Map<String, dynamic>.from(full as Map))));
                  widget.onRefreshParent();
                  await _loadCompleted();
                }
              },
            ))
                .toList(),
          ),
      ],
    );
  }
}
