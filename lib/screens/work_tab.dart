import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../services/database_helper.dart';
import '../widgets/empty_state.dart';
import '../theme.dart';
import 'task_detail_screen.dart';

class WorkTab extends StatefulWidget {
  final List<Project> projects;
  final List<Task> tasks;
  final Function(Project) onProjectTap;
  final Future<void> Function() onRefresh;

  const WorkTab({
    super.key,
    required this.projects,
    required this.tasks,
    required this.onProjectTap,
    required this.onRefresh,
  });

  @override
  State<WorkTab> createState() => _WorkTabState();
}

class _WorkTabState extends State<WorkTab> {
  final _dbHelper = DatabaseHelper();

  void _openTaskDetail(Task task, Project project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          task: task,
          project: project,
          allTasks: widget.tasks,
          onTaskUpdated: (updated) async {
            await _dbHelper.updateTask(updated);
            setState(() {});
          },
          onTaskDeleted: () async {
            await _dbHelper.deleteTask(task.id);
            setState(() {});
          },
        ),
      ),
    ).then((_) => setState(() {}));
  }

  // 安全获取父任务
  Task? _findParentTask(String? parentId, List<Task> projectTasks) {
    if (parentId == null) return null;
    try {
      return projectTasks.firstWhere((t) => t.id == parentId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.projects.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            EmptyState(
              icon: Icons.folder_open,
              title: 'No projects yet',
              subtitle: 'Tap + to create your first project',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'Work by project',
              style: TextStyle(fontSize: AppFontSizes.headlineSmall, fontWeight: FontWeight.w600),
            ),
          ),
          ...widget.projects.map((p) {
            final allProjectTasks = widget.tasks.where((t) => t.projectId == p.id).toList();
            final mainTasks = allProjectTasks.where((t) => t.parentTaskId == null).toList();
            final subtasks = allProjectTasks.where((t) => t.parentTaskId != null).toList();

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ExpansionTile(
                leading: Icon(Icons.folder_outlined, color: AppColors.primary),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('${mainTasks.length} tasks, ${subtasks.length} subtasks'),
                children: [
                  if (allProjectTasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No tasks yet.'),
                    )
                  else
                    ...allProjectTasks.map((t) {
                      final isSubtask = t.parentTaskId != null;
                      final parentTask = _findParentTask(t.parentTaskId, allProjectTasks);
                      return ListTile(
                        contentPadding: EdgeInsets.only(left: isSubtask ? 32 : 16, right: 16),
                        leading: isSubtask
                            ? Icon(Icons.subdirectory_arrow_right, color: AppColors.textSecondary)
                            : Icon(
                          t.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                          color: t.isCompleted ? AppColors.success : AppColors.warning,
                        ),
                        title: Text(
                          t.title,
                          style: TextStyle(
                            decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isSubtask && parentTask != null)
                              Text(
                                '📌 Sub of: ${parentTask.title}',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            Text('Assigned to: ${t.assignedTo}'),
                            if (t.isCompleted && t.completedAt != null)
                              Text(
                                '✓ Completed ${DateFormat('MM/dd HH:mm').format(t.completedAt!)}',
                                style: TextStyle(fontSize: 12, color: AppColors.success),
                              ),
                          ],
                        ),
                        onTap: () => _openTaskDetail(t, p),
                      );
                    }),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton.icon(
                      onPressed: () => widget.onProjectTap(p),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add task'),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}