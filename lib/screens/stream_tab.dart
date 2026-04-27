import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../services/current_user.dart';
import '../theme.dart';
import 'task_detail_screen.dart';

class StreamTab extends StatefulWidget {
  final List<Project> projects;
  final List<Task> tasks;
  final Function(Project) onProjectTap;
  final Function(Project) onProjectEdit;
  final Future<void> Function() onRefresh;
  final int Function(Project) getMemberCount;

  const StreamTab({
    super.key,
    required this.projects,
    required this.tasks,
    required this.onProjectTap,
    required this.onProjectEdit,
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
    return widget.tasks
        .where((t) {
      final deadlineDate =
      DateTime(t.deadline.year, t.deadline.month, t.deadline.day);
      return deadlineDate == today;
    })
        .toList()
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
    final summary = DashboardSummaryCard(
      projects: widget.projects,
      tasks: widget.tasks,
    );

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: Stack(
        children: [
          ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              summary,
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
                ...widget.projects.map((p) {
                  final isOwner = CurrentUser.memberId == p.createdBy;
                  return _ProjectCard(
                    project: p,
                    progress: _getProgress(p),
                    memberCount: widget.getMemberCount(p),
                    onTap: () => widget.onProjectTap(p),
                    onEdit: isOwner ? () => widget.onProjectEdit(p) : null,
                    isOwner: isOwner,
                  );
                }),
              const Divider(height: 32, thickness: 1),
              if (todayTasks.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(children: [
                    Icon(Icons.today, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text("Today's Tasks",
                        style: TextStyle(
                            fontSize: AppFontSizes.headlineSmall,
                            fontWeight: FontWeight.w600)),
                  ]),
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
                  _scrollController.animateTo(0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut);
                },
                child: const Icon(Icons.arrow_upward),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------- DashboardSummaryCard ----------
class DashboardSummaryCard extends StatelessWidget {
  final List<Project> projects;
  final List<Task> tasks;
  const DashboardSummaryCard(
      {super.key, required this.projects, required this.tasks});

  int get totalTasks => tasks.length;
  int get completedTasks => tasks.where((t) => t.isCompleted).length;
  int get overdueTasks =>
      tasks.where((t) => !t.isCompleted && t.deadline.isBefore(DateTime.now())).length;
  int get upcomingProjects =>
      projects.where((p) => p.deadline.difference(DateTime.now()).inDays <= 3).length;
  double get completionRate => totalTasks == 0 ? 0 : completedTasks / totalTasks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.dashboard, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Dashboard',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(label: 'Tasks', value: '$totalTasks'),
                  _StatItem(
                      label: 'Completed',
                      value: '${(completionRate * 100).toInt()}%'),
                  _StatItem(
                      label: 'Overdue',
                      value: '$overdueTasks',
                      color: overdueTasks > 0 ? AppColors.error : null),
                  _StatItem(
                      label: 'Due Soon',
                      value: '$upcomingProjects projects',
                      color: upcomingProjects > 0 ? AppColors.warning : null),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color ?? AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ---------- Optimized Task Card (with tags) ----------
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

  Project? get project {
    try {
      return projects.firstWhere((p) => p.id == task.projectId);
    } catch (_) {
      return null;
    }
  }

  Color _priorityColor() {
    if (project != null) {
      return project!.priorityColor(task.priority);
    }
    switch (task.priority) {
      case Priority.high:
        return AppColors.error;
      case Priority.medium:
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate =
    DateTime(task.deadline.year, task.deadline.month, task.deadline.day);
    final bool isToday = taskDate == today;
    final bool isOverdue =
        task.deadline.isBefore(now) && !task.isCompleted;
    final risk = task.risk;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: _priorityColor(),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: isOverdue
                                ? AppColors.error
                                : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (risk == RiskLevel.high) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.warning_amber_rounded,
                            color: AppColors.error, size: 18),
                      ],
                      if (task.isCompleted)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.check_circle,
                              color: AppColors.success, size: 20),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (isToday && !task.isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Today',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500)),
                          ),
                        if (isToday && !task.isCompleted)
                          const SizedBox(width: 8),
                        Icon(Icons.person_outline,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(task.assignedTo,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        const Spacer(),
                        Icon(Icons.calendar_today,
                            size: 14,
                            color: isOverdue
                                ? AppColors.error
                                : AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(task.deadline),
                          style: TextStyle(
                            fontSize: 12,
                            color: isOverdue
                                ? AppColors.error
                                : AppColors.textSecondary,
                            fontWeight:
                            isOverdue ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    if (task.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: task.tags.map((tag) {
                          final color =
                              project?.tagColor(tag) ?? AppColors.primary;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: color,
                                  fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
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

// ---------- Optimized Project Card ----------
class _ProjectCard extends StatelessWidget {
  final Project project;
  final double progress;
  final int memberCount;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final bool isOwner;

  const _ProjectCard({
    required this.project,
    required this.progress,
    required this.memberCount,
    required this.onTap,
    this.onEdit,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    final bool isNearDeadline =
        project.deadline.difference(DateTime.now()).inDays <= 2;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
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
                if (isOwner)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 20, color: AppColors.textSecondary),
                    onPressed: onEdit,
                    tooltip: 'Edit project',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.folder_outlined, color: AppColors.primary),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.people,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('$memberCount members',
                    style: TextStyle(
                        fontSize: AppFontSizes.bodySmall,
                        color: AppColors.textSecondary)),
                const Spacer(),
                Text(
                  'Deadline ${_formatDate(project.deadline)}',
                  style: TextStyle(
                    fontSize: AppFontSizes.bodySmall,
                    color: isNearDeadline
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.divider,
                color: AppColors.primary,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 6),
              Text('${(progress * 100).toInt()}% completed',
                  style: TextStyle(fontSize: AppFontSizes.bodySmall)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
