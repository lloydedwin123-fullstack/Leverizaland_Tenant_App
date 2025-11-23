import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/attachment_service.dart';
import 'task_details_page.dart'; 

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

  String _idToString(dynamic id) {
    if (id == null) return '';
    return id.toString();
  }

  Future<void> _setCompleted(dynamic id, bool value) async {
    final idValue = _idToString(id);
    if (idValue.isEmpty) return;

    try {
      await supabase
          .from('tasks')
          .update({'completed': value, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', idValue);

      await _loadTasks();
      await _completedKey.currentState?.reload();
    } catch (e) {
      debugPrint('_setCompleted error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
    }
  }

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
      final attachments = (task['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final a in attachments) {
        final filePath = (a['file_path'] ?? '').toString();
        final aId = (a['id'] ?? '').toString();
        if (filePath.isNotEmpty) {
          try {
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

      await supabase.from('subtasks').delete().eq('task_id', idValue);
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // ✅ Reduced vertical spacing slightly
      elevation: 1.5, // ✅ Slightly higher elevation for visibility
      shadowColor: Colors.black.withOpacity(0.08), // ✅ Soft shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)), // ✅ Subtle border
      ),
      color: Theme.of(context).cardColor, 
      child: InkWell( // ✅ Make entire card clickable
        onTap: () => _openDetails(t),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14), // ✅ Consistent padding
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _setCompleted(t['id'], !(t['completed'] == true)),
                child: Container(
                  width: 24, // ✅ Smaller checkbox
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (t['completed'] == true) ? Colors.green : Colors.transparent, 
                    border: Border.all(
                      color: (t['completed'] == true) ? Colors.green : Theme.of(context).dividerColor,
                      width: 2
                    ), 
                  ),
                  child: (t['completed'] == true)
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            title, 
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.w600, // ✅ Slightly lighter bold
                              decoration: (t['completed'] == true) ? TextDecoration.lineThrough : null,
                              color: (t['completed'] == true) ? Theme.of(context).disabledColor : null,
                            ) 
                          ),
                        ),
                        if (due.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              due, 
                              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w500) // ✅ Highlighted due date
                            ),
                          ),
                      ],
                    ),

                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        desc, 
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)) 
                      ),
                    ],

                    if (subtasks.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: subtasks.where((s) => s['is_done'] == true).length / subtasks.length,
                        backgroundColor: Theme.of(context).dividerColor.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade300),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${subtasks.where((s) => s['is_done'] == true).length}/${subtasks.length} subtasks",
                        style: TextStyle(fontSize: 11, color: Theme.of(context).disabledColor),
                      )
                    ],

                    if (attachments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.attach_file, size: 14, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            "${attachments.length} attachment${attachments.length > 1 ? 's' : ''}",
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      )
                    ]
                  ],
                ),
              ),
              
              // ✅ 3-dot menu for extra actions, keeping tap clean
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 20, color: Theme.of(context).disabledColor),
                onSelected: (v) async {
                  if (v == 'delete') await _deleteTask(t);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

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

  String _formatDate(dynamic v) {
    if (v == null) return '';
    try {
      final dt = DateTime.tryParse(v.toString());
      if (dt == null) return v.toString();
      return '${dt.month}/${dt.day}'; // ✅ Shorter date format
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
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadTasks,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            // tasks list
            ...tasks.map((t) => _buildTaskCard(t)).toList(),
            const SizedBox(height: 16),
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
      completed = List<Map<String, dynamic>>.from(res ?? []);
    } catch (e) {
      debugPrint('_loadCompleted error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _markUndone(String id) async {
    try {
      await supabase.from('tasks').update({'completed': false}).eq('id', id);
      await _loadCompleted();
      widget.onRefreshParent();
    } catch (e) {
      debugPrint('_markUndone error: $e');
    }
  }

  Future<void> _deleteCompletedTask(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirm != true) return;

    try {
      await supabase.from('subtasks').delete().eq('task_id', id);
      await supabase.from('tasks').delete().eq('id', id);
      await _loadCompleted();
    } catch (e) {
      debugPrint('_deleteCompletedTask error: $e');
    }
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
                CircleAvatar(
                  radius: 12, 
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant, 
                  child: Text('${completed.length}', style: const TextStyle(fontSize: 12))
                ),
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
              leading: IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                tooltip: "Mark as Incomplete",
                onPressed: () => _markUndone(t['id'].toString()),
              ),
              title: Text(
                t['title'] ?? '',
                style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey),
              ),
              subtitle: (t['description'] ?? '').toString().isNotEmpty 
                  ? Text(t['description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis) 
                  : null,
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                onPressed: () => _deleteCompletedTask(t['id'].toString()),
              ),
              onTap: () async {
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
