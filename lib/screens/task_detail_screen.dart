import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../models/comment.dart';
import '../services/current_user.dart';
import '../widgets/tag_selector.dart';
import '../theme.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  final Project? project;
  final List<Task> allTasks;
  final Function(Task) onTaskUpdated;
  final VoidCallback onTaskDeleted;

  const TaskDetailScreen({
    super.key,
    required this.task,
    this.project,
    required this.allTasks,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _supabase = Supabase.instance.client;
  final _commentController = TextEditingController();
  late Task _task;
  List<Comment> _comments = [];
  List<Task> _subtasks = [];
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late String _selectedMemberId;
  late DateTime _selectedStartDate;
  late DateTime _selectedDeadline;
  late Priority _selectedPriority;
  late int _progressPercent;
  late int _estimatedHours;
  late List<String> _selectedTags;

  List<String> _memberIds = [];
  Map<String, String> _memberNames = {};

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _loadComments();
    _loadSubtasks();
    _loadProjectMembers();
  }

  Future<void> _loadProjectMembers() async {
    if (widget.project == null) return;
    try {
      final links = await _supabase
          .from('project_members')
          .select('member_id')
          .eq('project_id', widget.project!.id);
      final ids =
      (links as List).map((e) => e['member_id'] as String).toList();
      if (ids.isEmpty) {
        setState(() {
          _memberIds = [];
          _memberNames.clear();
        });
        return;
      }
      final members = await _supabase
          .from('members')
          .select('id, name')
          .inFilter('id', ids);
      final map = <String, String>{};
      for (final m in (members as List)) {
        map[m['id']] = m['name'] ?? m['id'];
      }
      setState(() {
        _memberIds = ids;
        _memberNames = map;
      });
    } catch (e) {
      setState(() {
        _memberIds = [];
        _memberNames.clear();
      });
    }
  }

  Future<void> _loadComments() async {
    try {
      final response = await _supabase
          .from('comments')
          .select('*')
          .eq('task_id', _task.id)
          .order('created_at');
      setState(() {
        _comments = (response as List)
            .map((json) => Comment.fromJson(json as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading comments: $e');
    }
  }

  Future<void> _loadSubtasks() async {
    try {
      final response = await _supabase
          .from('tasks')
          .select('*')
          .eq('parent_task_id', _task.id)
          .order('created_at');
      setState(() {
        _subtasks = (response as List)
            .map((json) => Task.fromJson(json as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading subtasks: $e');
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final comment = Comment(
      id: const Uuid().v4(),
      taskId: _task.id,
      author: CurrentUser.name ?? CurrentUser.email ?? 'You',
      content: _commentController.text.trim(),
    );
    try {
      await _supabase.from('comments').insert(comment.toJson());
      _commentController.clear();
      await _loadComments();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add comment: $e')),
      );
    }
  }

  Future<void> _editComment(Comment comment) async {
    final controller = TextEditingController(text: comment.content);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit comment'),
        content: TextField(controller: controller, maxLines: 3),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text('Save')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      try {
        await _supabase
            .from('comments')
            .update({'content': result.trim()})
            .eq('id', comment.id);
        await _loadComments();
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete comment'),
        content: Text('Delete this comment?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _supabase.from('comments').delete().eq('id', comment.id);
        await _loadComments();
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _initEditControllers() {
    _titleController = TextEditingController(text: _task.title);
    _descController = TextEditingController(text: _task.description);
    _selectedMemberId = _task.assignedTo;
    _selectedStartDate = _task.startDate;
    _selectedDeadline = _task.deadline;
    _selectedPriority = _task.priority;
    _progressPercent = _task.progressPercent;
    _estimatedHours = _task.estimatedHours;
    _selectedTags = List.from(_task.tags);
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    _task.title = _titleController.text.trim();
    _task.description = _descController.text.trim();
    _task.assignedTo = _selectedMemberId;
    _task.startDate = _selectedStartDate;
    _task.deadline = _selectedDeadline;
    _task.priority = _selectedPriority;
    _task.progressPercent = _progressPercent;
    _task.estimatedHours = _estimatedHours;
    _task.tags = _selectedTags;
    final wasCompleted = _task.isCompleted;
    _task.isCompleted = _progressPercent == 100;
    if (_task.isCompleted && !wasCompleted) {
      _task.completedAt = DateTime.now();
    } else if (!_task.isCompleted && wasCompleted) {
      _task.completedAt = null;
    }

    try {
      await _supabase
          .from('tasks')
          .update(_task.toJson())
          .eq('id', _task.id);
      widget.onTaskUpdated(_task);
      setState(() => _isEditing = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save task: $e')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final projectDeadline =
        widget.project?.deadline ?? DateTime(2100);
    final initialDate =
    isStart ? _selectedStartDate : _selectedDeadline;
    final firstDate = isStart ? DateTime(2020) : _selectedStartDate;
    final lastDate = isStart ? _selectedDeadline : projectDeadline;
    final picked = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initialDate,
    );
    if (picked != null) {
      setState(() {
        if (isStart) _selectedStartDate = picked;
        else _selectedDeadline = picked;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content:
        Text('Are you sure you want to delete "${_task.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
            ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _supabase.from('tasks').delete().eq('id', _task.id);
        widget.onTaskDeleted();
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete task: $e')),
        );
      }
    }
  }

  Future<void> _toggleComplete() async {
    final newStatus = !_task.isCompleted;
    _task.isCompleted = newStatus;
    _task.progressPercent = newStatus ? 100 : 0;
    _task.completedAt = newStatus ? DateTime.now() : null;
    try {
      await _supabase
          .from('tasks')
          .update(_task.toJson())
          .eq('id', _task.id);
      widget.onTaskUpdated(_task);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newStatus ? 'Task marked as complete' : 'Task reopened')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update task: $e')),
      );
    }
  }

  Future<void> _startTask() async {
    if (_task.actualStartDate != null) return;
    setState(() {
      _task.actualStartDate = DateTime.now();
    });
    try {
      await _supabase.from('tasks').update({
        'actual_start_date':
        _task.actualStartDate!.toIso8601String(),
      }).eq('id', _task.id);
      widget.onTaskUpdated(_task);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start task: $e')),
      );
    }
  }

  Future<void> _showAddSubtaskDialog() async {
    final _formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    DateTime selectedDate = _task.deadline;
    Priority selectedPriority = Priority.medium;
    bool isTitleValid = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Add Subtask'),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration:
                    const InputDecoration(labelText: 'Title *'),
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
                    onChanged: (v) => setStateDialog(() =>
                    isTitleValid = v != null && v.trim().isNotEmpty),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Priority>(
                    value: selectedPriority,
                    items: Priority.values
                        .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.name.toUpperCase())))
                        .toList(),
                    onChanged: (v) =>
                        setStateDialog(() => selectedPriority = v!),
                    decoration:
                    const InputDecoration(labelText: 'Priority'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isTitleValid
                    ? () async {
                  if (_formKey.currentState!.validate()) {
                    final subtask = Task(
                      id: const Uuid().v4(),
                      projectId: _task.projectId,
                      title: titleController.text.trim(),
                      assignedTo: _task.assignedTo,
                      deadline: selectedDate,
                      priority: selectedPriority,
                      parentTaskId: _task.id,
                    );
                    await _supabase
                        .from('tasks')
                        .insert(subtask.toJson());
                    _loadSubtasks();
                    Navigator.pop(ctx);
                  }
                }
                    : null,
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openSubtaskDetail(Task subtask) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          task: subtask,
          project: widget.project,
          allTasks: widget.allTasks,
          onTaskUpdated: (updated) async {
            await _supabase
                .from('tasks')
                .update(updated.toJson())
                .eq('id', updated.id);
            _loadSubtasks();
            widget.onTaskUpdated(_task);
          },
          onTaskDeleted: () async {
            await _supabase
                .from('tasks')
                .delete()
                .eq('id', subtask.id);
            _loadSubtasks();
            widget.onTaskUpdated(_task);
          },
        ),
      ),
    ).then((_) => _loadSubtasks());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isEditing ? _buildEditForm() : _buildDetailView(),
      floatingActionButton: _isEditing || _task.parentTaskId != null
          ? null
          : FloatingActionButton(
        onPressed: () {
          _initEditControllers();
          setState(() => _isEditing = true);
        },
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildDetailView() {
    final completedSubtasks =
        _subtasks.where((s) => s.isCompleted).length;
    final subtaskProgress =
    _subtasks.isEmpty ? 0.0 : completedSubtasks / _subtasks.length;
    final bool isMainTask = _task.parentTaskId == null;
    final projectName =
        widget.project?.name ?? _findProjectName();
    final assigneeName =
        _memberNames[_task.assignedTo] ?? _task.assignedTo;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 120,
          backgroundColor: AppColors.primaryLight,
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
              tooltip: 'Delete task',
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            title: Text(_task.title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            background: Container(
              alignment: Alignment.bottomLeft,
              padding:
              const EdgeInsets.fromLTRB(16, 40, 16, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_task.title,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Project: $projectName',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (!_task.isCompleted &&
                          _task.actualStartDate == null)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _startTask,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start Task'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.info,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      if (!_task.isCompleted &&
                          _task.actualStartDate != null) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _toggleComplete,
                            icon: const Icon(
                                Icons.check_circle_outline),
                            label: const Text('Mark Complete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                      if (_task.isCompleted) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Completed'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _toggleComplete,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reopen'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Overview',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _buildOverviewGrid(assigneeName),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Progress',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value:
                                  _task.progressPercent / 100,
                                  backgroundColor:
                                  AppColors.divider,
                                  color: _task.isCompleted
                                      ? AppColors.success
                                      : AppColors.primary,
                                  strokeWidth: 8,
                                ),
                                Text(
                                  '${_task.progressPercent}%',
                                  style: const TextStyle(
                                      fontWeight:
                                      FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow('Estimated',
                                    '${_task.estimatedHours}h'),
                                const SizedBox(height: 8),
                                _buildInfoRow('Actual Time',
                                    _task.actualTimeDisplay),
                                if (_task.actualStartDate != null)
                                  Text(
                                    'Started: ${DateFormat('MM/dd HH:mm').format(_task.actualStartDate!)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors
                                            .textSecondary),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_task.description.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text('Description',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(_task.description),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text('Description',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text('No description provided.',
                            style: TextStyle(
                                color: AppColors.textHint)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (isMainTask)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Subtasks',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                    FontWeight.w600)),
                            const Spacer(),
                            TextButton.icon(
                              onPressed:
                              _showAddSubtaskDialog,
                              icon: const Icon(Icons.add,
                                  size: 18),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_subtasks.isNotEmpty)
                          LinearProgressIndicator(
                            value: subtaskProgress,
                            backgroundColor:
                            AppColors.divider,
                            color: AppColors.primary,
                          ),
                        const SizedBox(height: 8),
                        Text(
                            '$completedSubtasks of ${_subtasks.length} subtasks completed',
                            style: TextStyle(
                                color:
                                AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        if (_subtasks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16),
                            child: Center(
                              child: Text('No subtasks yet',
                                  style: TextStyle(
                                      color:
                                      AppColors.textHint)),
                            ),
                          )
                        else
                          ExpansionTile(
                            title: Text(
                                'View Subtasks (${_subtasks.length})'),
                            children: _subtasks.map((sub) {
                              final subAssigneeName =
                                  _memberNames[
                                  sub.assignedTo] ??
                                      sub.assignedTo;
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                    Icons
                                        .subdirectory_arrow_right,
                                    size: 18,
                                    color: AppColors
                                        .textSecondary),
                                title: Text(
                                  sub.title,
                                  style: TextStyle(
                                    decoration: sub.isCompleted
                                        ? TextDecoration
                                        .lineThrough
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                    '$subAssigneeName • Due ${DateFormat.MMMd().format(sub.deadline)}'),
                                onTap: () =>
                                    _openSubtaskDetail(sub),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              if (isMainTask) const SizedBox(height: 16),
              if (_task.tags.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text('Tags',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _task.tags
                              .map((tag) => Chip(
                            label: Text(tag),
                            backgroundColor:
                            AppColors.primaryLight,
                            avatar: Icon(Icons.tag,
                                size: 16,
                                color:
                                AppColors.primary),
                          ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_task.tags.isNotEmpty) const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Comments',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('${_comments.length}',
                              style: TextStyle(
                                  color:
                                  AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_comments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16),
                          child: Center(
                            child: Text('No comments yet',
                                style: TextStyle(
                                    color:
                                    AppColors.textHint)),
                          ),
                        )
                      else
                        ..._comments.map((c) => _CommentTile(
                          comment: c,
                          isOwner: c.author ==
                              (CurrentUser.name ??
                                  CurrentUser.email),
                          onEdit: () => _editComment(c),
                          onDelete: () =>
                              _deleteComment(c),
                        )),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller:
                              _commentController,
                              decoration:
                              const InputDecoration(
                                hintText: 'Add a comment...',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send_rounded,
                                color: AppColors.primary),
                            onPressed: _addComment,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ],
    );
  }

  String _findProjectName() {
    return widget.project?.name ?? 'Unknown Project';
  }

  Widget _buildOverviewGrid(String assigneeName) {
    final statusColor =
    _task.isCompleted ? AppColors.success : AppColors.warning;
    final priorityColor = _task.priority == Priority.high
        ? AppColors.error
        : _task.priority == Priority.medium
        ? AppColors.warning
        : AppColors.info;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildOverviewItem(
                    'Status',
                    _task.isCompleted ? 'Completed' : 'Pending',
                    Icons.flag,
                    statusColor)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildOverviewItem(
                    'Priority',
                    _task.priority.name.toUpperCase(),
                    Icons.priority_high,
                    priorityColor)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildOverviewItem('Assigned to',
                    assigneeName, Icons.person)),
            const SizedBox(width: 16),
            Expanded(
              child: _buildOverviewItem(
                'Deadline',
                DateFormat.yMMMd().format(_task.deadline),
                Icons.calendar_today,
                _task.deadline.isBefore(DateTime.now()) &&
                    !_task.isCompleted
                    ? AppColors.error
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildOverviewItem(
                    'Start Date',
                    DateFormat.yMMMd()
                        .format(_task.startDate),
                    Icons.play_arrow)),
            const SizedBox(width: 16),
            Expanded(
              child: _buildOverviewItem(
                'Completed',
                _task.completedAt != null
                    ? DateFormat('MM/dd HH:mm')
                    .format(_task.completedAt!)
                    : '—',
                Icons.check_circle,
                _task.completedAt != null
                    ? AppColors.success
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewItem(
      String label, String value, IconData icon,
      [Color? valueColor]) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(color: AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildEditForm() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Task'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveTask,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedMemberId,
              items: _memberIds.map((id) {
                final name = _memberNames[id] ?? id;
                return DropdownMenuItem(
                    value: id, child: Text(name));
              }).toList(),
              onChanged: (v) =>
                  setState(() => _selectedMemberId = v!),
              decoration: const InputDecoration(
                  labelText: 'Assign to',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            _buildDateSelector('Start Date', _selectedStartDate,
                    () => _selectDate(context, true)),
            const SizedBox(height: 16),
            _buildDateSelector('Deadline', _selectedDeadline,
                    () => _selectDate(context, false)),
            const SizedBox(height: 16),
            DropdownButtonFormField<Priority>(
              value: _selectedPriority,
              items: Priority.values
                  .map((p) => DropdownMenuItem(
                  value: p,
                  child: Text(p.name.toUpperCase())))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedPriority = v!),
              decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Progress:'),
                Expanded(
                  child: Slider(
                    value: _progressPercent.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 10,
                    label: '$_progressPercent%',
                    onChanged: (v) => setState(() =>
                    _progressPercent = v.toInt()),
                  ),
                ),
                Text('$_progressPercent%',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _estimatedHours.toString(),
              decoration: const InputDecoration(
                  labelText: 'Estimated Hours',
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              onSaved: (v) =>
              _estimatedHours = int.tryParse(v ?? '0') ?? 0,
            ),
            const SizedBox(height: 16),
            const Text('Tags',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TagSelector(
                selectedTags: _selectedTags,
                onChanged: (tags) =>
                    setState(() => _selectedTags = tags)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(
      String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(DateFormat.yMMMd().format(date)),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.isOwner,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            child: Text(
                comment.author.isNotEmpty
                    ? comment.author[0]
                    : '?',
                style: TextStyle(color: AppColors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.author,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat.MMMd()
                          .add_jm()
                          .format(comment.createdAt),
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint),
                    ),
                    if (isOwner) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: onEdit,
                        child: const Icon(Icons.edit_outlined,
                            size: 16,
                            color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onDelete,
                        child: const Icon(Icons.delete_outline,
                            size: 16, color: Colors.red),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
