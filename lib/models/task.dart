enum Priority { low, medium, high }

class Task {
  String id;
  String projectId;
  String title;
  String description;
  String assignedTo;
  DateTime startDate;          // 计划开始日期
  DateTime deadline;           // 计划截止日期
  DateTime? actualStartDate;   // 实际开始时间（用户点击“开始任务”时记录）
  int progressPercent;
  int estimatedHours;          // 预估工时（保留手动设置）
  bool isCompleted;
  DateTime? completedAt;       // 实际完成时间
  Priority priority;
  List<String> tags;
  DateTime createdAt;
  String? parentTaskId;

  Task({
    required this.id,
    required this.projectId,
    required this.title,
    this.description = '',
    required this.assignedTo,
    DateTime? startDate,
    required this.deadline,
    this.actualStartDate,
    this.progressPercent = 0,
    this.estimatedHours = 0,
    this.isCompleted = false,
    this.completedAt,
    this.priority = Priority.medium,
    this.tags = const [],
    DateTime? createdAt,
    this.parentTaskId,
  })  : startDate = startDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  // 计算实际耗时（分钟）
  int get actualMinutes {
    if (actualStartDate == null) return 0;
    final end = completedAt ?? DateTime.now();
    return end.difference(actualStartDate!).inMinutes;
  }

  // 格式化实际耗时显示
  String get actualTimeDisplay {
    final minutes = actualMinutes;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'description': description,
      'assignedTo': assignedTo,
      'startDate': startDate.millisecondsSinceEpoch,
      'deadline': deadline.millisecondsSinceEpoch,
      'actualStartDate': actualStartDate?.millisecondsSinceEpoch,
      'progressPercent': progressPercent,
      'estimatedHours': estimatedHours,
      'isCompleted': isCompleted ? 1 : 0,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'priority': priority.index,
      'tags': tags.join(','),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'parentTaskId': parentTaskId,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    final startDate = map['startDate'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['startDate'])
        : DateTime.fromMillisecondsSinceEpoch(map['createdAt']);
    final actualStartDate = map['actualStartDate'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['actualStartDate'])
        : null;
    final completedAt = map['completedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
        : null;
    return Task(
      id: map['id'],
      projectId: map['projectId'],
      title: map['title'],
      description: map['description'] ?? '',
      assignedTo: map['assignedTo'],
      startDate: startDate,
      deadline: DateTime.fromMillisecondsSinceEpoch(map['deadline']),
      actualStartDate: actualStartDate,
      progressPercent: map['progressPercent'] ?? 0,
      estimatedHours: map['estimatedHours'] ?? 0,
      isCompleted: map['isCompleted'] == 1,
      completedAt: completedAt,
      priority: Priority.values[map['priority'] ?? 1],
      tags: map['tags'] != null ? (map['tags'] as String).split(',').where((s) => s.isNotEmpty).toList() : [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      parentTaskId: map['parentTaskId'],
    );
  }
}