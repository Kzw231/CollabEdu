import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project.dart';
import '../models/project_form_result.dart';
import '../services/current_user.dart';
import '../services/member_lookup.dart';
import '../theme.dart';

class EditProjectScreen extends StatefulWidget {
  final Project project;
  final List<Project>? existingProjects;

  const EditProjectScreen({super.key, required this.project, this.existingProjects});

  @override
  State<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends State<EditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController descController;
  final TextEditingController _inviteController = TextEditingController();
  DateTime? selectedDate;
  final Set<String> _selectedMemberIds = {};
  List<Map<String, dynamic>> _directory = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.project.name);
    descController = TextEditingController(text: widget.project.description);
    selectedDate = widget.project.deadline;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dir = await Supabase.instance.client
          .from('members')
          .select('id, name, email')
          .order('name');
      final links = await Supabase.instance.client
          .from('project_members')
          .select('member_id')
          .eq('project_id', widget.project.id);

      final directory = (dir as List<dynamic>).cast<Map<String, dynamic>>();
      final onProject = (links as List<dynamic>).map((e) => e['member_id'] as String).toSet();

      if (mounted) {
        setState(() {
          _directory = directory;
          _selectedMemberIds
            ..clear()
            ..addAll(onProject);
          if (CurrentUser.memberId != null) {
            _selectedMemberIds.add(CurrentUser.memberId!);
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
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
        const SnackBar(content: Text('Enter a member ID or email')),
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
      if (_selectedMemberIds.contains(id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${row['name'] ?? id} is already on the team')),
        );
        return;
      }
      setState(() {
        _selectedMemberIds.add(id);
        if (!_directory.any((m) => m['id'] == id)) {
          _directory = [..._directory, Map<String, dynamic>.from(row)]
            ..sort((a, b) => ((a['name'] as String?) ?? '').compareTo((b['name'] as String?) ?? ''));
        }
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

  void save() {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDate == null) return;
    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one team member")),
      );
      return;
    }

    final updatedProject = Project(
      id: widget.project.id,
      name: nameController.text.trim(),
      description: descController.text.trim(),
      deadline: selectedDate!,
      members: _selectedMemberIds.toList(),
      createdBy: widget.project.createdBy,
      createdAt: widget.project.createdAt,
      status: widget.project.status,
    );

    Navigator.pop(
      context,
      ProjectFormResult(
        project: updatedProject,
        memberIds: _selectedMemberIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit project")),
      body: SafeArea(
        child: Padding(
          padding: pagePadding,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Text(
                "Team members",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Use checkboxes or add by member ID / email (must exist in members).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _inviteController,
                enabled: !_loading,
                decoration: InputDecoration(
                  labelText: 'Member ID or email',
                  hintText: 'e.g. M0002 or name@school.edu',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.person_add_alt_1),
                    tooltip: 'Add to team',
                    onPressed: _loading ? null : () => _addMemberByIdOrEmail(),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_loading) _addMemberByIdOrEmail();
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _loading ? null : () => _addMemberByIdOrEmail(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add to team'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else if (_error != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    TextButton(onPressed: _loadData, child: const Text("Retry")),
                  ],
                )
              else
                ..._directory.map((m) {
                  final id = m['id'] as String;
                  final name = (m['name'] as String?) ?? id;
                  final email = m['email'] as String?;
                  final isSelf = id == CurrentUser.memberId;
                  return CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(isSelf ? "$name (you)" : name),
                    subtitle: email != null && email.isNotEmpty ? Text(email, maxLines: 1) : null,
                    value: _selectedMemberIds.contains(id),
                    onChanged: isSelf
                        ? null
                        : (val) {
                            setState(() {
                              if (val == true) {
                                _selectedMemberIds.add(id);
                              } else {
                                _selectedMemberIds.remove(id);
                              }
                            });
                          },
                  );
                }),
              const SizedBox(height: AppSpacing.md + 4),
              ElevatedButton(onPressed: save, child: const Text("Save")),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
