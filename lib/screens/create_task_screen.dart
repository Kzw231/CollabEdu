import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../widgets/tag_selector.dart';
import '../theme.dart';

class CreateTaskScreen extends StatefulWidget {
  final String projectId;
  final DateTime projectDeadline;
  final List<String> memberIds;
  final Map<String, String> memberNames;
  final Map<String, int> memberTaskCount;

  const CreateTaskScreen({
    super.key,
    required this.projectId,
    required this.projectDeadline,
    required this.memberIds,
    required this.memberNames,
    required this.memberTaskCount,
  });

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagController = TextEditingController();
  late DateTime _selectedDate;
  late String _selectedMemberId;
  late Priority _selectedPriority;
  List<String> _selectedTags = [];
  bool _isSaving = false;

  String? _recommendedMemberId;
  String? _recommendedMemberName;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.projectDeadline;
    _selectedPriority = Priority.medium;

    // 计算推荐成员（任务数最少的成员）
    if (widget.memberIds.isNotEmpty) {
      int minTasks = widget.memberTaskCount[widget.memberIds.first] ?? 0;
      String recommendedId = widget.memberIds.first;
      for (final id in widget.memberIds) {
        final count = widget.memberTaskCount[id] ?? 0;
        if (count < minTasks) {
          minTasks = count;
          recommendedId = id;
        }
      }
      _recommendedMemberId = recommendedId;
      _recommendedMemberName = widget.memberNames[recommendedId] ?? recommendedId;
      _selectedMemberId = recommendedId;
    } else {
      _selectedMemberId = '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMemberId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an assignee')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final newTask = Task(
      id: const Uuid().v4(),
      projectId: widget.projectId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      assignedTo: _selectedMemberId,
      deadline: _selectedDate,
      priority: _selectedPriority,
      tags: _selectedTags,
      estimatedHours: 0,
    );

    if (mounted) {
      Navigator.pop(context, newTask);
    }
  }

  void _addCustomTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty) return;
    if (_selectedTags.contains(tag)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tag already added')),
      );
      return;
    }
    setState(() {
      _selectedTags = [..._selectedTags, tag];
      _tagController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Task'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.check),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Task Title *',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                autofocus: true,
                validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: const Icon(Icons.description_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              if (_recommendedMemberName != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Recommended: $_recommendedMemberName',
                          style: TextStyle(fontSize: 13, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedMemberId.isNotEmpty ? _selectedMemberId : null,
                decoration: InputDecoration(
                  labelText: 'Assign to',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: widget.memberIds.map((id) {
                  final name = widget.memberNames[id] ?? id;
                  return DropdownMenuItem(value: id, child: Text(name));
                }).toList(),
                onChanged: (v) => setState(() => _selectedMemberId = v!),
                validator: (v) => v == null ? 'Please select a member' : null,
              ),
              const SizedBox(height: 16),
              _buildDateField('Deadline', _selectedDate, () async {
                final pick = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: widget.projectDeadline,
                  initialDate: _selectedDate,
                );
                if (pick != null) setState(() => _selectedDate = pick);
              }),
              const SizedBox(height: 16),
              DropdownButtonFormField<Priority>(
                value: _selectedPriority,
                decoration: InputDecoration(
                  labelText: 'Priority',
                  prefixIcon: const Icon(Icons.flag_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: Priority.values
                    .map((p) => DropdownMenuItem(
                    value: p,
                    child: Row(children: [
                      Icon(Icons.circle,
                          size: 12,
                          color: p == Priority.high
                              ? AppColors.error
                              : p == Priority.medium
                              ? AppColors.warning
                              : AppColors.info),
                      const SizedBox(width: 8),
                      Text(p.name.toUpperCase()),
                    ])))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPriority = v!),
              ),
              const SizedBox(height: 16),
              Text('Tags',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TagSelector(
                selectedTags: _selectedTags,
                onChanged: (tags) => setState(() => _selectedTags = tags),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      decoration: InputDecoration(
                        labelText: 'Add custom tag',
                        prefixIcon: const Icon(Icons.label_outline),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onSubmitted: (_) => _addCustomTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _addCustomTag,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.check),
                label: const Text('Create Task'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(DateFormat.yMMMd().format(date)),
      ),
    );
  }
}
