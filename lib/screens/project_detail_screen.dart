import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../widgets/empty_state.dart';
import '../widgets/tag_selector.dart';
import '../theme.dart';
import 'task_detail_screen.dart';
import 'gantt_chart_screen.dart';

enum TaskSortBy { deadline, title, assignee, priority }

class ProjectDetailScreen extends StatefulWidget {
  final Project project;
  final List<Task> tasks;
  final Future<void> Function() onRefresh;

  const ProjectDetailScreen({
    super.key,
    required this.project,
    required this.tasks,
    required this.onRefresh,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool showOnlyIncomplete = false;
  TaskSortBy _sortBy = TaskSortBy.deadline;
  bool _sortAscending = true;
  String _searchQuery = '';

  List<String> _projectMemberIds = [];
  Map<String, String> _memberNames = {};

  @override
  void initState() {
    super.initState();
    _loadProjectMembers();
  }

  @override
  void didUpdateWidget(covariant ProjectDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _loadProjectMembers();
    }
  }

  Future<void> _loadProjectMembers() async {
    try {
      final links = await _supabase
          .from('project_members')
          .select('member_id')
          .eq('project_id', widget.project.id);
      final ids = (links as List).map((e) => e['member_id'] as String).toList();
      if (ids.isEmpty) {
        setState(() {
          _projectMemberIds = [];
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
        _projectMemberIds = ids;
        _memberNames = map;
      });
    } catch (e) {
      setState(() {
        _projectMemberIds = [];
        _memberNames.clear();
      });
    }
  }

  List<Task> _sortAndFilterTasks(List<Task> tasks) {
    var filtered = tasks.where((t) {
      if (t.parentTaskId != null) return false;
      if (showOnlyIncomplete && t.isCompleted) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return t.title.toLowerCase().contains(query) ||
            t.description.toLowerCase().contains(query) ||
            t.tags.any((tag) => tag.toLowerCase().contains(query));
      }
      return true;
    }).toList();

    switch (_sortBy) {
      case TaskSortBy.deadline:
        filtered.sort((a, b) => _sortAscending
            ? a.deadline.compareTo(b.deadline)
            : b.deadline.compareTo(a.deadline));
        break;
      case TaskSortBy.title:
        filtered.sort((a, b) => _sortAscending
            ? a.title.compareTo(b.title)
            : b.title.compareTo(a.title));
        break;
      case TaskSortBy.assignee:
        filtered.sort((a, b) => _sortAscending
            ? a.assignedTo.compareTo(b.assignedTo)
            : b.assignedTo.compareTo(a.assignedTo));
        break;
      case TaskSortBy.priority:
        filtered.sort((a, b) => _sortAscending
            ? a.priority.index.compareTo(b.priority.index)
            : b.priority.index.compareTo(a.priority.index));
        break;
    }
    return filtered;
  }

  Future<void> _handleRefresh() async {
    await widget.onRefresh();
    await _loadProjectMembers();
    setState(() {});
  }

  void _openTaskDetail(Task task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          task: task,
          project: widget.project,
          allTasks: widget.tasks,
          onTaskUpdated: (updatedTask) async {
            await _supabase
                .from('tasks')
                .update(updatedTask.toJson())
                .eq('id', updatedTask.id);
            await widget.onRefresh();
            setState(() {});
          },
          onTaskDeleted: () async {
            await _supabase.from('tasks').delete().eq('id', task.id);
            await widget.onRefresh();
            setState(() {});
          },
        ),
      ),
    );
    await widget.onRefresh();
    setState(() {});
  }

  Future<void> _showCreateTaskDialog() async {
    await _loadProjectMembers();

    final _formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descController = TextEditingController();

    final projectTasks = widget.tasks
        .where((t) => t.projectId == widget.project.id && t.parentTaskId == null)
        .toList();
    final memberTaskCount = <String, int>{};
    for (var memberId in _projectMemberIds) {
      memberTaskCount[memberId] =
          projectTasks.where((t) => t.assignedTo == memberId).length;
    }
    String recommendedMemberId = _projectMemberIds.isNotEmpty
        ? memberTaskCount.entries.reduce((a, b) => a.value < b.value ? a : b).key
        : '';
    String recommendedMemberName = _memberNames[recommendedMemberId] ?? recommendedMemberId;

    String selectedMemberId = recommendedMemberId;
    DateTime selectedDate = widget.project.deadline;
    Priority selectedPriority = Priority.medium;
    List<String> selectedTags = [];
    int estimatedHours = 0;
    bool isTitleValid = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Create New Task'),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.large)),
            content: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Task Title *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                      onChanged: (v) => setStateDialog(() => isTitleValid = v != null && v.trim().isNotEmpty),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      maxLines: 3,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
                    const Text('Assign to', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    if (recommendedMemberName.isNotEmpty)
                      Text('✨ Recommended: $recommendedMemberName (lightest workload)',
                          style: TextStyle(fontSize: 12, color: AppColors.success)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedMemberId.isNotEmpty ? selectedMemberId : null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: _projectMemberIds.map((id) {
                        final name = _memberNames[id] ?? id;
                        return DropdownMenuItem(value: id, child: Text(name));
                      }).toList(),
                      onChanged: (v) => setStateDialog(() => selectedMemberId = v!),
                      validator: (v) => v == null ? 'Please select a member' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Deadline', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime.now(),
                          lastDate: widget.project.deadline,
                          initialDate: selectedDate,
                        );
                        if (picked != null) setStateDialog(() => selectedDate = picked);
                      },
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 20, color: AppColors.textSecondary),
                            const SizedBox(width: 12),
                            Text(DateFormat.yMMMd().format(selectedDate), style: const TextStyle(fontSize: 16)),
                            const Spacer(),
                            Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Priority>(
                      value: selectedPriority,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: Priority.values.map((p) => DropdownMenuItem(
                        value: p,
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 12,
                                color: p == Priority.high
                                    ? AppColors.error
                                    : p == Priority.medium
                                    ? AppColors.warning
                                    : AppColors.info),
                            const SizedBox(width: 8),
                            Text(p.name.toUpperCase()),
                          ],
                        ),
                      )).toList(),
                      onChanged: (v) => setStateDialog(() => selectedPriority = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: '0',
                      decoration: const InputDecoration(
                        labelText: 'Estimated Hours',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timer_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => estimatedHours = int.tryParse(v) ?? 0,
                    ),
                    const SizedBox(height: 16),
                    const Text('Tags', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TagSelector(
                      selectedTags: selectedTags,
                      onChanged: (tags) => setStateDialog(() => selectedTags = tags),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isTitleValid && selectedMemberId.isNotEmpty
                    ? () async {
                  if (_formKey.currentState!.validate()) {
                    final newTask = Task(
                      id: const Uuid().v4(),
                      projectId: widget.project.id,
                      title: titleController.text.trim(),
                      description: descController.text.trim(),
                      assignedTo: selectedMemberId,
                      deadline: selectedDate,
                      priority: selectedPriority,
                      tags: selectedTags,
                      estimatedHours: estimatedHours,
                    );
                    await _supabase.from('tasks').insert(newTask.toJson());
                    await widget.onRefresh();
                    Navigator.pop(ctx);
                    setState(() {});
                  }
                }
                    : null,
                child: const Text('Create Task'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectTasks = widget.tasks.where((t) => t.projectId == widget.project.id).toList();
    final mainTasks = _sortAndFilterTasks(projectTasks);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 160,
              backgroundColor: AppColors.primaryLight,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 72, bottom: 16, right: 16),
                title: Text(
                  widget.project.name,
                  style: const TextStyle(fontSize: AppFontSizes.bodyLarge, fontWeight: FontWeight.w600),
                ),
                background: Container(
                  padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.project.name,
                          style: const TextStyle(fontSize: AppFontSizes.headlineMedium, fontWeight: FontWeight.bold)),
                      if (widget.project.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(widget.project.description,
                            style: TextStyle(fontSize: AppFontSizes.bodyMedium, color: AppColors.textSecondary)),
                      ],
                      const SizedBox(height: 8),
                      Text('Owner: You  •  Code: ${widget.project.id.substring(0, 6)}',
                          style: TextStyle(fontSize: AppFontSizes.bodySmall, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('Deadline: ${_formatDate(widget.project.deadline)}',
                            style: TextStyle(fontSize: AppFontSizes.bodySmall, color: AppColors.textSecondary))
                      ]),
                    ],
                  ),
                ),
              ),
              actions: [
                PopupMenuButton<TaskSortBy>(
                  icon: const Icon(Icons.sort),
                  onSelected: (value) => setState(() {
                    if (_sortBy == value) _sortAscending = !_sortAscending;
                    else {
                      _sortBy = value;
                      _sortAscending = true;
                    }
                  }),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: TaskSortBy.deadline, child: Text('Sort by deadline')),
                    PopupMenuItem(value: TaskSortBy.title, child: Text('Sort by title')),
                    PopupMenuItem(value: TaskSortBy.assignee, child: Text('Sort by assignee')),
                    PopupMenuItem(value: TaskSortBy.priority, child: Text('Sort by priority')),
                  ],
                ),
                IconButton(
                  icon: Icon(showOnlyIncomplete ? Icons.filter_alt : Icons.filter_alt_outlined),
                  onPressed: () => setState(() => showOnlyIncomplete = !showOnlyIncomplete),
                  tooltip: 'Show incomplete only',
                ),
                IconButton(
                  icon: const Icon(Icons.timeline),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => GanttChartScreen(project: widget.project, tasks: widget.tasks)));
                  },
                  tooltip: 'View Timeline',
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search tasks...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 16),
                  if (mainTasks.isEmpty)
                    EmptyState(
                        icon: Icons.assignment_outlined,
                        title: 'No tasks found',
                        subtitle: 'Tap + to create a new task')
                  else
                    ...mainTasks.map((task) => _TaskWithSubtasksCard(
                      task: task,
                      allTasks: widget.tasks,
                      memberNames: _memberNames,
                      onTap: () => _openTaskDetail(task),
                    )),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _TaskWithSubtasksCard extends StatelessWidget {
  final Task task;
  final List<Task> allTasks;
  final Map<String, String> memberNames;
  final VoidCallback onTap;

  const _TaskWithSubtasksCard({
    required this.task,
    required this.allTasks,
    required this.memberNames,
    required this.onTap,
  });

  Color _priorityColor(Priority priority) {
    switch (priority) {
      case Priority.low:
        return AppColors.info;
      case Priority.medium:
        return AppColors.warning;
      case Priority.high:
        return AppColors.error;
    }
  }

  List<Task> _getSubtasks() {
    return allTasks.where((t) => t.parentTaskId == task.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    final subtasks = _getSubtasks();
    final isOverdue = task.deadline.isBefore(DateTime.now()) && !task.isCompleted;
    final assigneeName = memberNames[task.assignedTo] ?? task.assignedTo;

    return Card(
      child: Column(
        children: [
          ListTile(
            onTap: onTap,
            leading: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: _priorityColor(task.priority), shape: BoxShape.circle),
            ),
            title: Text(
              task.title,
              style: TextStyle(
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: isOverdue ? AppColors.error : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$assigneeName • Due ${task.deadline.toString().split(' ')[0]}"),
                if (task.isCompleted && task.completedAt != null)
                  Text(
                    '✓ Completed ${DateFormat('MM/dd HH:mm').format(task.completedAt!)}',
                    style: TextStyle(fontSize: 12, color: AppColors.success),
                  ),
                if (task.tags.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    children: task.tags
                        .map((tag) => Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 10)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ))
                        .toList(),
                  ),
              ],
            ),
          ),
          if (subtasks.isNotEmpty)
            ExpansionTile(
              title: Text('Subtasks (${subtasks.length})',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              children: subtasks.map((sub) {
                final subAssigneeName = memberNames[sub.assignedTo] ?? sub.assignedTo;
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.subdirectory_arrow_right, size: 18, color: AppColors.textSecondary),
                  title: Text(
                    sub.title,
                    style: TextStyle(
                      decoration: sub.isCompleted ? TextDecoration.lineThrough : null,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '$subAssigneeName • Due ${DateFormat.MMMd().format(sub.deadline)}',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TaskDetailScreen(
                          task: sub,
                          project: null,
                          allTasks: allTasks,
                          onTaskUpdated: (updated) async {
                            await Supabase.instance.client
                                .from('tasks')
                                .update(updated.toJson())
                                .eq('id', updated.id);
                          },
                          onTaskDeleted: () async {
                            await Supabase.instance.client
                                .from('tasks')
                                .delete()
                                .eq('id', sub.id);
                          },
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}