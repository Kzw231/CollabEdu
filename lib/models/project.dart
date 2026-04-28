import 'package:flutter/material.dart';
import 'task.dart';
import '../theme.dart';

class Project {
  final String id;
  String name;
  String description;
  DateTime deadline;
  final String createdBy;
  final DateTime createdAt;
  String status;
  List<String> members;
  Map<String, dynamic>? settings;

  Project({
    required this.id,
    required this.name,
    this.description = '',
    required this.deadline,
    required this.createdBy,
    DateTime? createdAt,
    this.status = 'active',
    this.members = const [],
    this.settings,
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
      members: [],
      settings: json['settings'] is Map
          ? Map<String, dynamic>.from(json['settings'] as Map)
          : null,
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
      'settings': settings,
    };
  }

  Color priorityColor(Priority priority) {
    final colors = settings?['priorityColors'] as Map?;
    if (colors != null) {
      final colorHex = colors[priority.name];
      if (colorHex != null && colorHex is String) {
        return Color(int.parse(colorHex, radix: 16));
      }
    }
    switch (priority) {
      case Priority.high: return AppColors.error;
      case Priority.medium: return AppColors.warning;
      case Priority.low: return AppColors.info;
    }
  }

  Color tagColor(String tag) {
    final colors = settings?['tagColors'] as Map?;
    if (colors != null && colors[tag] != null) {
      final colorHex = colors[tag];
      if (colorHex is String) {
        return Color(int.parse(colorHex, radix: 16));
      }
    }
    return AppColors.primary;
  }

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
