import 'package:flutter/material.dart';
import '../models/project.dart';
import '../theme.dart';

class EditProjectScreen extends StatefulWidget {
  final Project project;

  const EditProjectScreen({super.key, required this.project});

  @override
  State<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends State<EditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController descController;
  DateTime? selectedDate;
  late List<String> selectedMembers;
  final List<String> allMembers = ["You", "Alice", "Bob"];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.project.name);
    descController = TextEditingController(text: widget.project.description);
    selectedDate = widget.project.deadline;
    selectedMembers = List.from(widget.project.members);
  }

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    super.dispose();
  }

  void save() {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDate == null) return;
    if (selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least 1 member")));
      return;
    }
    final updatedProject = Project(
      id: widget.project.id,
      name: nameController.text.trim(),
      description: descController.text.trim(),
      deadline: selectedDate!,
      members: selectedMembers,
      createdAt: widget.project.createdAt,
    );
    Navigator.pop(context, updatedProject);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit project")),
      body: Padding(
        padding: pagePadding,
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Project name", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Enter name" : null,
              ),
              const SizedBox(height: AppSpacing.md + 4),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md + 4),
              ElevatedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                    initialDate: selectedDate!,
                  );
                  if (picked != null) setState(() => selectedDate = picked);
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(selectedDate!.toString().split(" ")[0]),
              ),
              const SizedBox(height: AppSpacing.md + 4),
              Text("Members", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ...allMembers.map((m) {
                return CheckboxListTile(
                  title: Text(m),
                  value: selectedMembers.contains(m),
                  onChanged: (val) {
                    setState(() {
                      if (val!) selectedMembers.add(m);
                      else selectedMembers.remove(m);
                    });
                  },
                  activeColor: AppColors.primary,
                );
              }),
              const SizedBox(height: AppSpacing.md + 4),
              ElevatedButton(onPressed: save, child: const Text("Save")),
            ],
          ),
        ),
      ),
    );
  }
}