// project.dart – adjusted for Supabase
class Project {
  final String id;
  String name;
  String description;
  DateTime deadline;
  final String createdBy;        // required, no default
  final DateTime createdAt;
  String status;
  List<String> members;          // local only, not stored in projects table

  Project({
    required this.id,
    required this.name,
    this.description = '',
    required this.deadline,
    required this.createdBy,     // now required
    DateTime? createdAt,
    this.status = 'active',
    this.members = const [],     // local use only
  }) : createdAt = createdAt ?? DateTime.now();

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] ?? '',
      deadline: DateTime.parse(json['deadline'] as String),
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: json['status'] as String? ?? 'active',
      members: [],               // not loaded from projects table
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'deadline': deadline.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'status': status,
      // no 'members' here – it belongs to project_members table
    };
  }

  // These toMap/fromMap are for local SQLite (if you still need them)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'deadline': deadline.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'members': members.join(','),
      'created_by': createdBy,
      'status': status,
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      deadline: DateTime.fromMillisecondsSinceEpoch(map['deadline'] as int),
      createdBy: map['created_by'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      status: map['status'] as String? ?? 'active',
      members: map['members'] != null
          ? (map['members'] as String).split(',').where((s) => s.isNotEmpty).toList()
          : [],
    );
  }
}