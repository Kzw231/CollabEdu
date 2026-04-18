import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/project.dart';
import '../theme.dart';

class CreateProjectScreen extends StatefulWidget {
  final List<Project> existingProjects;

  const CreateProjectScreen({super.key, required this.existingProjects});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  DateTime? selectedDate;
  List<String> selectedMembers = [];
  final List<String> allMembers = ["You", "Alice", "Bob"];

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return "Project name cannot be empty";
    if (value.trim().length < 3) return "Minimum 3 characters";
    if (value.trim().length > 30) return "Maximum 30 characters";
    bool exists = widget.existingProjects.any(
          (p) => p.name.toLowerCase().trim() == value.toLowerCase().trim(),
    );
    if (exists) return "Project name already exists";
    return null;
  }

  void saveProject() {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pick a deadline")));
      return;
    }
    if (selectedDate!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deadline cannot be in the past")));
      return;
    }
    if (selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least 1 member")));
      return;
    }
    final project = Project(
      id: const Uuid().v4(),
      name: nameController.text.trim(),
      description: descController.text.trim(),
      deadline: selectedDate!,
      members: selectedMembers.toSet().toList(),
    );
    Navigator.pop(context, project);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create project")),
      body: Padding(
        padding: pagePadding,
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Project name", border: OutlineInputBorder()),
                validator: validateName,
              ),
              const SizedBox(height: AppSpacing.md + 4),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Description (optional)", border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md + 4),
              ElevatedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                    initialDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => selectedDate = picked);
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(selectedDate == null ? "Pick Deadline" : selectedDate!.toString().split(" ")[0]),
              ),
              const SizedBox(height: AppSpacing.md + 4),
              Text("Select members", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ...allMembers.map((member) {
                return CheckboxListTile(
                  title: Text(member),
                  value: selectedMembers.contains(member),
                  onChanged: (val) {
                    setState(() {
                      if (val!) selectedMembers.add(member);
                      else selectedMembers.remove(member);
                    });
                  },
                  activeColor: AppColors.primary,
                );
              }),
              const SizedBox(height: AppSpacing.md + 4),
              ElevatedButton(onPressed: saveProject, child: const Text("Create")),
            ],
          ),
        ),
      ),
    );
  }
}