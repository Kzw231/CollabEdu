import 'package:flutter/material.dart';
import '../models/project.dart';

class ProjectSelector extends StatelessWidget {
  final List<Project> projects;
  final Project? selectedProject;
  final ValueChanged<Project?> onChanged;
  final String hint;
  final int Function(Project) getMemberCount;              // ✅ 改为函数

  const ProjectSelector({
    super.key,
    required this.projects,
    required this.selectedProject,
    required this.onChanged,
    this.hint = 'Select project',
    required this.getMemberCount,                          // 新增必需参数
  });

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return Card(
        color: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, color: Colors.grey.shade600),
              const SizedBox(width: 12),
              Text('No projects available',
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showProjectPicker(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, color: Colors.green.shade700, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedProject?.name ?? hint,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: selectedProject != null
                            ? Colors.black87
                            : Colors.grey.shade600,
                      ),
                    ),
                    if (selectedProject != null)
                      Text(
                        '${getMemberCount(selectedProject!)} members • Deadline: ${_formatDate(selectedProject!.deadline)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
              Icon(Icons.arrow_drop_down, color: Colors.grey.shade600, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  void _showProjectPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('Select Project',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    final isSelected = selectedProject?.id == project.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                        isSelected ? Colors.green : Colors.grey.shade200,
                        child: Icon(Icons.folder,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                            size: 20),
                      ),
                      title: Text(project.name,
                          style: TextStyle(
                              fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text('${getMemberCount(project)} members'),   // ← 每个项目显示自己的成员数
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () {
                        onChanged(project);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
