import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/project.dart';
import '../models/task.dart';

class GanttChartScreen extends StatelessWidget {
  final Project project;
  final List<Task> tasks;

  const GanttChartScreen({super.key, required this.project, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final projectTasks = tasks.where((t) => t.projectId == project.id).toList();

    if (projectTasks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${project.name} - Timeline')),
        body: const Center(child: Text('No tasks with dates to display')),
      );
    }

    // 按开始日期排序
    projectTasks.sort((a, b) => a.startDate.compareTo(b.startDate));

    final minDate = projectTasks.map((t) => t.startDate).reduce((a, b) => a.isBefore(b) ? a : b);
    final maxDate = projectTasks.map((t) => t.deadline).reduce((a, b) => a.isAfter(b) ? a : b);
    final totalDays = maxDate.difference(minDate).inDays + 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('${project.name} - Timeline'),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日期头部
              Container(
                color: Colors.grey.shade100,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 200,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Task', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    ...List.generate(totalDays, (index) {
                      final date = minDate.add(Duration(days: index));
                      return Container(
                        width: 40,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          DateFormat.MMMd().format(date),
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              // 任务行
              ...projectTasks.map((task) {
                final startOffset = task.startDate.difference(minDate).inDays;
                final duration = task.deadline.difference(task.startDate).inDays + 1;
                return Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 200,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(task.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text(
                                task.assignedTo,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ...List.generate(totalDays, (index) {
                        if (index >= startOffset && index < startOffset + duration) {
                          return Container(
                            width: 40,
                            height: 40,
                            color: _getProgressColor(task.progressPercent),
                            child: Center(
                              child: Text(
                                '${task.progressPercent}%',
                                style: const TextStyle(fontSize: 9, color: Colors.white),
                              ),
                            ),
                          );
                        } else {
                          return Container(width: 40, height: 40, color: Colors.transparent);
                        }
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(int progress) {
    if (progress >= 80) return Colors.green;
    if (progress >= 40) return Colors.orange;
    return Colors.red;
  }
}