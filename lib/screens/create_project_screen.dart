import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/project.dart';
import '../models/project_form_result.dart';
import '../services/current_user.dart';
import '../services/member_lookup.dart';
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
  final TextEditingController _inviteController = TextEditingController();
  DateTime? selectedDate;

  // Store added members as a map: id -> {name, email, isChecked}
  final Map<String, Map<String, dynamic>> _addedMembers = {};

  @override
  void initState() {
    super.initState();
    // Automatically add the current user (mandatory)
    if (CurrentUser.memberId != null) {
      _addedMembers[CurrentUser.memberId!] = {
        'name': CurrentUser.name ?? CurrentUser.email,
        'email': CurrentUser.email,
        'isChecked': true,
        'isSelf': true,
      };
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _addMemberByIdOrEmail() async {
    final raw = _inviteController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a member ID (e.g. M0002) or email')),
      );
      return;
    }
    try {
      final row = await lookupMemberByIdOrEmail(raw);
      if (!mounted) return;
      if (row == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No member found. They must sign up first.')),
        );
        return;
      }
      final id = row['id'] as String;
      if (_addedMembers.containsKey(id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${row['name'] ?? id} is already in the team')),
        );
        return;
      }
      setState(() {
        _addedMembers[id] = {
          'name': row['name'] ?? id,
          'email': row['email'],
          'isChecked': true,
          'isSelf': false,
        };
        _inviteController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${row['name'] ?? id}')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lookup failed: $e')),
        );
      }
    }
  }

  void _toggleChecked(String id, bool? value) {
    if (id == CurrentUser.memberId) return; // self cannot be unchecked
    setState(() {
      _addedMembers[id]?['isChecked'] = value ?? false;
    });
  }

  void _removeMember(String id) {
    if (id == CurrentUser.memberId) return;
    setState(() {
      _addedMembers.remove(id);
    });
  }

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return "Project name cannot be empty";
    if (value.trim().length < 3) return "Minimum 3 characters";
    if (value.trim().length > 30) return "Maximum 30 characters";
    final exists = widget.existingProjects.any(
          (p) => p.name.toLowerCase().trim() == value.toLowerCase().trim(),
    );
    if (exists) return "Project name already exists";
    return null;
  }

  bool _deadlineInPast(DateTime d) {
    final now = DateTime.now();
    final d0 = DateTime(d.year, d.month, d.day);
    final n0 = DateTime(now.year, now.month, now.day);
    return d0.isBefore(n0);
  }

  void saveProject() {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pick a deadline")));
      return;
    }
    if (_deadlineInPast(selectedDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Deadline cannot be in the past")),
      );
      return;
    }

    final selectedIds = _addedMembers.entries
        .where((entry) => entry.value['isChecked'] == true)
        .map((entry) => entry.key)
        .toList();
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one team member")),
      );
      return;
    }



    final project = Project(
      id: const Uuid().v4(),
      name: nameController.text.trim(),
      description: descController.text.trim(),
      deadline: selectedDate!,
      createdBy: CurrentUser.memberId!,   // add this
      members: selectedIds,
    );

    Navigator.pop(
      context,
      ProjectFormResult(
        project: project,
        memberIds: selectedIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create project")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Project name", border: OutlineInputBorder()),
                    validator: validateName,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: "Description (optional)", border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 24),
                  Text(
                    "Team members",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Add members by Member ID (e.g. M0002) or email address. You (creator) are always included and cannot be removed.",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    softWrap: true,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inviteController,
                          decoration: const InputDecoration(
                            labelText: 'Member ID or email',
                            hintText: 'e.g. M0002 or name@school.edu',
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addMemberByIdOrEmail(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _addMemberByIdOrEmail,
                        icon: const Icon(Icons.person_add),
                        label: const Text("Add"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_addedMembers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text("No team members added yet. Add someone above."),
                    )
                  else
                    Column(
                      children: _addedMembers.entries.map((entry) {
                        final id = entry.key;
                        final data = entry.value;
                        final isSelf = data['isSelf'] == true;
                        final name = data['name'] ?? id;
                        final email = data['email'] ?? '';
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(isSelf ? "$name (you)" : name),
                          subtitle: email.isNotEmpty ? Text(email, maxLines: 1) : null,
                          value: data['isChecked'],
                          onChanged: isSelf ? null : (val) => _toggleChecked(id, val),
                          secondary: isSelf
                              ? null
                              : IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _removeMember(id),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: saveProject,
                    child: const Text("Create"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}