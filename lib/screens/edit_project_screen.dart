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

  const EditProjectScreen({
    super.key,
    required this.project,
    this.existingProjects,
  });

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

  // Appearance settings state
  Map<String, Color> _priorityColors = {
    'low': AppColors.info,
    'medium': AppColors.warning,
    'high': AppColors.error,
  };
  Map<String, Color> _tagColors = {};
  List<String> _projectTags = []; // from existing tags

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.project.name);
    descController = TextEditingController(text: widget.project.description);
    selectedDate = widget.project.deadline;

    // Load existing settings
    final settings = widget.project.settings;
    if (settings != null) {
      final pc = settings['priorityColors'];
      if (pc is Map) {
        for (final entry in pc.entries) {
          if (entry.value is String) {
            _priorityColors[entry.key] = Color(int.parse(entry.value));
          }
        }
      }
      final tc = settings['tagColors'];
      if (tc is Map) {
        for (final entry in tc.entries) {
          if (entry.value is String) {
            _tagColors[entry.key] = Color(int.parse(entry.value));
          }
        }
      }
    }
    // Collect existing tags from project tasks (done later, placeholder)
    _projectTags = []; // could be loaded from tasks table

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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDate == null) return;
    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one team member")),
      );
      return;
    }

    // Build settings map
    final settingsMap = <String, dynamic>{
      'priorityColors': _priorityColors.map((key, value) => MapEntry(key, value.value.toRadixString(16))),
      'tagColors': _tagColors.map((key, value) => MapEntry(key, value.value.toRadixString(16))),
    };

    final updatedProject = Project(
      id: widget.project.id,
      name: nameController.text.trim(),
      description: descController.text.trim(),
      deadline: selectedDate!,
      members: _selectedMemberIds.toList(),
      createdBy: widget.project.createdBy,
      createdAt: widget.project.createdAt,
      status: widget.project.status,
      settings: settingsMap,
    );

    Navigator.pop(
      context,
      ProjectFormResult(
        project: updatedProject,
        memberIds: _selectedMemberIds.toList(),
      ),
    );
  }

  Future<Color?> _showColorPicker(Color currentColor) async {
    // Simple color picker using predefined palette
    return showDialog<Color>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Choose a color'),
          content: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: Colors.primaries.map((color) {
              return GestureDetector(
                onTap: () => Navigator.pop(ctx, color),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: color == currentColor ? Colors.black : Colors.grey),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit project"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            TextButton(onPressed: _loadData, child: const Text('Retry')),
          ]),
        )
            : Padding(
          padding: pagePadding,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Project name",
                      prefixIcon: const Icon(Icons.folder),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v!.trim().isEmpty ? "Enter name" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: "Description",
                      prefixIcon: const Icon(Icons.description_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _buildDateField(),
                  const SizedBox(height: 24),
                  Text("Team members", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text("Use checkboxes or add by member ID / email.", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inviteController,
                          decoration: InputDecoration(
                            labelText: 'Member ID or email',
                            hintText: 'e.g. M0002 or name@school.edu',
                            prefixIcon: const Icon(Icons.person_add_alt_1),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addMemberByIdOrEmail(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _addMemberByIdOrEmail,
                        icon: const Icon(Icons.add),
                        label: const Text("Add"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 24),
                  // ---------- Appearance Settings ----------
                  ExpansionTile(
                    title: const Text("Appearance Settings"),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Priority Colors", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            ..._priorityColors.entries.map((entry) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(entry.key.toUpperCase()),
                                trailing: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: entry.value,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey),
                                  ),
                                ),
                                onTap: () async {
                                  Color? selected = await _showColorPicker(entry.value);
                                  if (selected != null) {
                                    setState(() {
                                      _priorityColors[entry.key] = selected;
                                    });
                                  }
                                },
                              );
                            }),
                            const Divider(),
                            Text("Tag Colors", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            if (_projectTags.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text("No tags yet. Colors will apply once tags are created."),
                              )
                            else
                              ..._projectTags.map((tag) {
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(tag),
                                  trailing: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: _tagColors[tag] ?? AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey),
                                    ),
                                  ),
                                  onTap: () async {
                                    Color? selected = await _showColorPicker(_tagColors[tag] ?? AppColors.primary);
                                    if (selected != null) {
                                      setState(() {
                                        _tagColors[tag] = selected;
                                      });
                                    }
                                  },
                                );
                              }),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _save,
                    child: const Text("Save"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime.now(),
          lastDate: DateTime(2100),
          initialDate: selectedDate ?? widget.project.deadline,
        );
        if (picked != null) setState(() => selectedDate = picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Deadline',
          prefixIcon: const Icon(Icons.calendar_today),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          selectedDate != null
              ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
              : 'Select date',
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ),
    );
  }
}
