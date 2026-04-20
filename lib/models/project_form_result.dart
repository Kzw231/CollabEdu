import 'project.dart';

/// Returned when creating or editing a project so the dashboard can sync [Project] + `project_members`.
class ProjectFormResult {
  final Project project;
  /// Member IDs (`members.id`) to store in `project_members`.
  final List<String> memberIds;

  const ProjectFormResult({
    required this.project,
    required this.memberIds,
  });
}
