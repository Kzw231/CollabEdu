import 'package:flutter/material.dart';
import '../models/project.dart';
import '../widgets/empty_state.dart';
import '../widgets/project_selector.dart';
import '../theme.dart';

class PeopleTab extends StatefulWidget {
  final List<Project> projects;
  final Future<void> Function() onRefresh;

  const PeopleTab({super.key, required this.projects, required this.onRefresh});

  @override
  State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab> {
  Project? _selectedProject;

  @override
  Widget build(BuildContext context) {
    if (widget.projects.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            EmptyState(
              icon: Icons.people_outline,
              title: 'No projects yet',
              subtitle: 'Create a project to add members',
            ),
          ],
        ),
      );
    }

    final currentProject = _selectedProject ?? widget.projects.first;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ProjectSelector(
              projects: widget.projects,
              selectedProject: currentProject,
              onChanged: (p) => setState(() => _selectedProject = p),
            ),
          ),
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Text('Owners', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Invite'),
                      ),
                    ],
                  ),
                ),
                const ListTile(
                  leading: CircleAvatar(child: Text('Y')),
                  title: Text('You'),
                  subtitle: Text('Owner'),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Text('Members', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Invite'),
                      ),
                    ],
                  ),
                ),
                ...currentProject.members.where((m) => m != 'You').map((member) {
                  return ListTile(
                    leading: CircleAvatar(child: Text(member[0])),
                    title: Text(member),
                    subtitle: const Text('Member'),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {},
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}