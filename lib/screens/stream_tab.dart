import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../theme.dart';
import 'task_detail_screen.dart';

class StreamTab extends StatefulWidget {
  final List<Project> projects;
  final List<Task> tasks;
  final Function(Project) onProjectTap;
  final Function(Project) onProjectLongPress;
  final Function(Project) onProjectDoubleTap;
  final Future<void> Function() onRefresh;
  final int Function(Project) getMemberCount;

  const StreamTab({
    super.key,
    required this.projects,
    required this.tasks,
    required this.onProjectTap,
    required this.onProjectLongPress,
    required this.onProjectDoubleTap,
    required this.onRefresh,
    required this.getMemberCount,
  });

  @override
  State<StreamTab> createState() => _StreamTabState();
}

class _StreamTabState extends State<StreamTab> {
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 300 && !_showBackToTop) {
        setState(() => _showBackToTop = true);
      } else if (_scrollController.offset <= 300 && _showBackToTop) {
        setState(() => _showBackToTop = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _getProgress(Project p) {
    final projectTasks = widget.tasks
        .where((t) => t.projectId == p.id && t.parentTaskId == null)
        .toList();
    if (projectTasks.isEmpty) return 0;
    int completed = projectTasks.where((t) => t.isCompleted).length;
    return completed / projectTasks.length;
  }

  List<Task> _getTodayTasks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return widget.tasks.where((t) {
      final deadlineDate =
      DateTime(t.deadline.year, t.deadline.month, t.deadline.day);
      return deadlineDate == today;
    }).toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
  }

  List<Task> _getUpcomingTasks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return widget.tasks
        .where((t) => !t.isCompleted && t.deadline.isAfter(tomorrow))
        .toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
  }

  Project? _findProject(String projectId) {
    try {
      return widget.projects.firstWhere((p) => p.id == projectId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleRefresh() async {
    await widget.onRefresh();
    setState(() {});
  }

  void _openTaskDetail(Task task) {
    final project = _findProject(task.projectId);
    if (project == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          task: task,
          project: project,
          allTasks: widget.tasks,
          onTaskUpdated: (updated) async {
            await _supabase
                .from('tasks')
                .update(updated.toJson())
                .eq('id', updated.id);
            await widget.onRefresh();
          },
          onTaskDeleted: () async {
            await _supabase.from('tasks').delete().eq('id', task.id);
            await widget.onRefresh();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayTasks = _getTodayTasks();
    final upcoming = _getUpcomingTasks();

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: Stack(
        children: [
          ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  'Your projects',
                  style: TextStyle(
                      fontSize: AppFontSizes.headlineSmall,
                      fontWeight: FontWeight.w600),
                ),
              ),
              if (widget.projects.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No projects yet. Tap + to create one.'),
                )
              else
                ...widget.projects.map((p) => _ProjectCard(
                  project: p,
                  progress: _getProgress(p),
                  memberCount: widget.getMemberCount(p),
                  onTap: () => widget.onProjectTap(p),
                  onLongPress: () => widget.onProjectLongPress(p),
                  onDoubleTap: () => widget.onProjectDoubleTap(p),
                )),
              const Divider(height: 32, thickness: 1),
              if (todayTasks.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.today, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        'Today\'s Tasks',
                        style: TextStyle(
                            fontSize: AppFontSizes.headlineSmall,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                ...todayTasks.map((t) => _StreamTaskCard(
                  task: t,
                  projects: widget.projects,
                  allTasks: widget.tasks,
                  onTap: () => _openTaskDetail(t),
                )),
                const Divider(height: 32, thickness: 1),
              ],
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Upcoming tasks',
                  style: TextStyle(
                      fontSize: AppFontSizes.headlineSmall,
                      fontWeight: FontWeight.w600),
                ),
              ),
              if (upcoming.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No upcoming tasks. Great job!'),
                )
              else
                ...upcoming.map((t) => _StreamTaskCard(
                  task: t,
                  projects: widget.projects,
                  allTasks: widget.tasks,
                  onTap: () => _openTaskDetail(t),
                )),
              const SizedBox(height: 20),
            ],
          ),
          if (_showBackToTop)
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'backToTop',
                backgroundColor: AppColors.primary,
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                child: const Icon(Icons.arrow_upward),
              ),
            ),
        ],
      ),
    );
  }
}

class _StreamTaskCard extends StatelessWidget {
  final Task task;
  final List<Project> projects;
  final List<Task> allTasks;
  final VoidCallback onTap;

  const _StreamTaskCard({
    required this.task,
    required this.projects,
    required this.allTasks,
    required this.onTap,
  });

  String _getProjectName(String projectId) {
    try {
      return projects.firstWhere((p) => p.id == projectId).name;
    } catch (_) {
      return 'Unknown Project';
    }
  }

  String? _getParentTaskTitle() {
    if (task.parentTaskId == null) return null;
    try {
      return allTasks.firstWhere((t) => t.id == task.parentTaskId).title;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubtask = task.parentTaskId != null;
    final parentTitle = _getParentTaskTitle();
    final bool isToday = DateTime.now().difference(task.deadline).inDays == 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isToday && !task.isCompleted ? AppColors.primaryLight : null,
      child: ListTile(
        onTap: onTap,
        leading: isSubtask
            ? Icon(Icons.subdirectory_arrow_right, color: AppColors.textSecondary)
            : Icon(
          task.isCompleted ? Icons.check_circle : Icons.circle_outlined,
          color: task.isCompleted ? AppColors.success : AppColors.warning,
        ),
        title: Row(
          children: [
            if (isSubtask)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.subdirectory_arrow_right,
                    size: 18, color: AppColors.textSecondary),
              ),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  decoration:
                  task.isCompleted ? TextDecoration.lineThrough : null,
                  fontWeight:
                  task.isCompleted ? FontWeight.normal : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSubtask && parentTitle != null)
              Text(
                '📌 Sub of: $parentTitle',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            Text(
              isSubtask
                  ? '${task.assignedTo} • ${_getProjectName(task.projectId)}'
                  : '${task.assignedTo} • Due ${_formatDate(task.deadline)}',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (task.isCompleted && task.completedAt != null)
              Text(
                '✓ Completed ${DateFormat('MM/dd HH:mm').format(task.completedAt!)}',
                style: TextStyle(fontSize: 12, color: AppColors.success),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return '${date.month}/${date.day}';
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final double progress;
  final int memberCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDoubleTap;

  const _ProjectCard({
    required this.project,
    required this.progress,
    required this.memberCount,
    required this.onTap,
    required this.onLongPress,
    required this.onDoubleTap,
  });

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isNearDeadline =
        project.deadline.difference(DateTime.now()).inDays <= 2;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      style: TextStyle(
                        fontSize: AppFontSizes.bodyLarge,
                        fontWeight: FontWeight.w600,
                        color: isNearDeadline
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.folder_outlined, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Deadline: ${_formatDate(project.deadline)}',
                style: TextStyle(
                    color:
                    isNearDeadline ? AppColors.error : AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                '$memberCount members',
                style: TextStyle(
                    fontSize: AppFontSizes.bodySmall,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.divider,
                color: AppColors.primary,
              ),
              const SizedBox(height: 4),
              Text(
                '${(progress * 100).toInt()}% completed',
                style: TextStyle(fontSize: AppFontSizes.bodySmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}