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

  const CreateTaskScreen({
    super.key,
    required this.projectId,
    required this.projectDeadline,
    required this.memberIds,
    required this.memberNames,
  });

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  late DateTime _selectedDate;
  late String _selectedMemberId;
  late Priority _selectedPriority;
  int _estimatedHours = 0;
  List<String> _selectedTags = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.projectDeadline;
    // 自动推荐工作量最小的成员
    // （这里简单取第一个，调用方可事先计算后传参，我们暂时不计算）
    _selectedMemberId = widget.memberIds.isNotEmpty ? widget.memberIds.first : '';
    _selectedPriority = Priority.medium;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
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
      estimatedHours: _estimatedHours,
    );

    // 直接返回给前一个页面，由它去插入数据库并刷新
    if (mounted) {
      Navigator.pop(context, newTask);
    }
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
              TextFormField(
                initialValue: '0',
                decoration: InputDecoration(
                  labelText: 'Estimated Hours',
                  prefixIcon: const Icon(Icons.timer_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                _estimatedHours = int.tryParse(v) ?? 0,
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
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(DateFormat.yMMMd().format(date)),
      ),
    );
  }
}