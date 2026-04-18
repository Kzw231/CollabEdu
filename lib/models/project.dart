class Project {
  String id;
  String name;
  String description;
  DateTime deadline;
  DateTime createdAt;
  List<String> members;

  Project({
    required this.id,
    required this.name,
    this.description = '',
    required this.deadline,
    required this.members,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'deadline': deadline.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'members': members.join(','),
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
      deadline: DateTime.fromMillisecondsSinceEpoch(map['deadline']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      members: map['members'] != null ? (map['members'] as String).split(',') : [],
    );
  }
}