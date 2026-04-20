// task
enum Priority { low, medium, high }

class Task {
  final String id;
  final String projectId;
  String title;
  String description;
  String assignedTo;
  final String createdBy;
  DateTime startDate;
  DateTime deadline;
  DateTime? actualStartDate;
  int progressPercent;
  int estimatedHours;
  bool isCompleted;
  DateTime? completedAt;
  Priority priority;
  List<String> tags;
  final DateTime createdAt;
  String? parentTaskId;

  Task({
    required this.id,
    required this.projectId,
    required this.title,
    this.description = '',
    required this.assignedTo,
    this.createdBy = '',
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

  int get actualMinutes {
    if (actualStartDate == null) return 0;
    final end = completedAt ?? DateTime.now();
    return end.difference(actualStartDate!).inMinutes;
  }

  String get actualTimeDisplay {
    final minutes = actualMinutes;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  static List<String> _parseTags(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    return (v as String).split(',').where((s) => s.isNotEmpty).toList();
  }

  static Priority _priorityFromInt(int? v) {
    if (v == null) return Priority.medium;
    final i = v.clamp(0, Priority.values.length - 1);
    return Priority.values[i];
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      projectId: json['project_id'],
      title: json['title'],
      description: json['description'] ?? '',
      assignedTo: json['assigned_to'] ?? '',
      createdBy: json['created_by'] ?? '',
      startDate: DateTime.parse(json['start_date'] ?? json['created_at']),
      deadline: DateTime.parse(json['due_date']),
      actualStartDate: json['actual_start_date'] != null ? DateTime.parse(json['actual_start_date']) : null,
      progressPercent: json['progress_percent'] ?? 0,
      estimatedHours: json['estimated_hours'] ?? 0,
      isCompleted: json['status'] == 'completed',
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      priority: _priorityFromInt(
        json['priority'] is int ? json['priority'] as int : int.tryParse(json['priority']?.toString() ?? ''),
      ),
      tags: _parseTags(json['tags']),
      createdAt: DateTime.parse(json['created_at']),
      parentTaskId: json['parent_task_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'title': title,
      'description': description,
      'assigned_to': assignedTo,
      'created_by': createdBy,
      'start_date': startDate.toIso8601String(),
      'due_date': deadline.toIso8601String(),
      'actual_start_date': actualStartDate?.toIso8601String(),
      'progress_percent': progressPercent,
      'estimated_hours': estimatedHours,
      'status': isCompleted ? 'completed' : 'pending',
      'completed_at': completedAt?.toIso8601String(),
      'priority': priority.index,
      'tags': tags.join(','),
      'created_at': createdAt.toIso8601String(),
      'parent_task_id': parentTaskId,
    };
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
        ? DateTime.fromMillisecondsSinceEpoch(map['startDate'] as int)
        : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int);
    final actualStartDate = map['actualStartDate'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['actualStartDate'] as int)
        : null;
    final completedAt = map['completedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
        : null;
    return Task(
      id: map['id'] as String,
      projectId: map['projectId'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      assignedTo: map['assignedTo'] as String,
      createdBy: '',
      startDate: startDate,
      deadline: DateTime.fromMillisecondsSinceEpoch(map['deadline'] as int),
      actualStartDate: actualStartDate,
      progressPercent: map['progressPercent'] as int? ?? 0,
      estimatedHours: map['estimatedHours'] as int? ?? 0,
      isCompleted: map['isCompleted'] == 1,
      completedAt: completedAt,
      priority: _priorityFromInt(map['priority'] as int?),
      tags: _parseTags(map['tags']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      parentTaskId: map['parentTaskId'] as String?,
    );
  }
}
