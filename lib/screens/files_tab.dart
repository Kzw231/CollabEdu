import 'package:flutter/material.dart';
import '../models/project.dart';
import '../widgets/empty_state.dart';
import '../widgets/project_selector.dart';
import 'file_screen.dart';

class FilesTab extends StatefulWidget {
  final List<Project> projects;
  final Future<void> Function() onRefresh;
  final int Function(Project) getMemberCount;

  const FilesTab({
    super.key,
    required this.projects,
    required this.onRefresh,
    required this.getMemberCount,
  });

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  Project? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.projects.isNotEmpty) {
      _selected = widget.projects.first;
    }
  }

  @override
  void didUpdateWidget(covariant FilesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.projects.isEmpty) {
      _selected = null;
      return;
    }
    if (_selected == null || !widget.projects.any((p) => p.id == _selected!.id)) {
      _selected = widget.projects.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.projects.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: const EmptyState(
                icon: Icons.folder_outlined,
                title: 'Create a project first',
                subtitle:
                'Files are stored per project. On Stream or Work, tap "Create project", then open Files again.',
              ),
            ),
          ],
        ),
      );
    }

    final project = _selected ?? widget.projects.first;
    final memberCount = widget.getMemberCount(project);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: ProjectSelector(
            key: ValueKey(project.id),
            projects: widget.projects,
            selectedProject: project,
            hint: 'Project for files',
            onChanged: (p) {
              if (p != null) setState(() => _selected = p);
            },
            memberCount: memberCount,
          ),
        ),
        Expanded(
          child: FileScreen(
            key: ValueKey(project.id),
            projectId: project.id,
            embedded: true,
          ),
        ),
      ],
    );
  }
}