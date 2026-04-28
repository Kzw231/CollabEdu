import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project.dart';
import '../models/task.dart';

class ReportGeneratorScreen extends StatefulWidget {
  final List<Project> projects;
  final List<Task> tasks;
  const ReportGeneratorScreen({super.key, required this.projects, required this.tasks});
  @override
  State<ReportGeneratorScreen> createState() => _ReportGeneratorScreenState();
}

class _ReportGeneratorScreenState extends State<ReportGeneratorScreen> {
  final _supabase = Supabase.instance.client;
  Project? _selectedProject;
  DateTimeRange? _dateRange;
  String? _quickRange;

  final List<String> _selectedColumns = ['Title', 'Assignee', 'Deadline', 'Status', 'Priority', 'Progress'];
  final List<String> _allColumns = ['Title', 'Assignee', 'Deadline', 'Status', 'Priority', 'Progress', 'Start Date', 'Est. Hours'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<Project>(
            value: _selectedProject,
            decoration: const InputDecoration(labelText: 'Select Project', border: OutlineInputBorder()),
            items: widget.projects.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
            onChanged: (p) => setState(() => _selectedProject = p),
          ),
          const SizedBox(height: 20),
          Text('Date Range', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: Text('This Week'), selected: _quickRange == 'this_week', onSelected: (v) => setState(() { _quickRange = v ? 'this_week' : null; _dateRange = null; })),
            ChoiceChip(label: Text('This Month'), selected: _quickRange == 'this_month', onSelected: (v) => setState(() { _quickRange = v ? 'this_month' : null; _dateRange = null; })),
            ChoiceChip(label: Text('This Year'), selected: _quickRange == 'this_year', onSelected: (v) => setState(() { _quickRange = v ? 'this_year' : null; _dateRange = null; })),
            ChoiceChip(label: Text('All Time'), selected: _quickRange == 'all', onSelected: (v) => setState(() { _quickRange = v ? 'all' : null; _dateRange = null; })),
          ]),
          const SizedBox(height: 8),
          ListTile(
            title: Text(_dateRange == null ? 'Or custom range' : '${DateFormat.yMMMd().format(_dateRange!.start)} - ${DateFormat.yMMMd().format(_dateRange!.end)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final range = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (range != null) setState(() { _dateRange = range; _quickRange = null; });
            },
          ),
          const SizedBox(height: 20),
          Text('Task List Columns', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _allColumns.map((col) => FilterChip(
              label: Text(col),
              selected: _selectedColumns.contains(col),
              onSelected: (sel) {
                setState(() {
                  if (sel) {
                    _selectedColumns.add(col);
                  } else {
                    _selectedColumns.remove(col);
                  }
                });
              },
            )).toList(),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _selectedProject == null ? null : _generateReport,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Generate PDF'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
          ),
        ],
      ),
    );
  }

  DateTimeRange? _getEffectiveRange() {
    if (_dateRange != null) return _dateRange;
    final now = DateTime.now();
    switch (_quickRange) {
      case 'this_week': return DateTimeRange(start: now.subtract(Duration(days: now.weekday - 1)), end: now);
      case 'this_month': return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case 'this_year': return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
      default: return null;
    }
  }

  Future<Map<String, String>> _getMemberNames(String projectId) async {
    final links = await _supabase.from('project_members').select('member_id').eq('project_id', projectId);
    if (links.isEmpty) return {};
    final ids = (links as List).map((e) => e['member_id'] as String).toList();
    final members = await _supabase.from('members').select('id, name').inFilter('id', ids);
    final map = <String, String>{};
    for (final m in (members as List)) map[m['id']] = m['name'] ?? m['id'];
    return map;
  }

  Future<void> _generateReport() async {
    final project = _selectedProject!;
    final memberNames = await _getMemberNames(project.id);
    final effectiveRange = _getEffectiveRange();
    var tasks = widget.tasks.where((t) => t.projectId == project.id).toList();
    if (effectiveRange != null) {
      tasks = tasks.where((t) => t.createdAt.isAfter(effectiveRange.start) && t.createdAt.isBefore(effectiveRange.end.add(const Duration(days: 1)))).toList();
    }

    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(level: 0, child: pw.Text('Project Report: ${project.name}')),
        pw.Text('Generated: ${DateFormat.yMMMd().format(DateTime.now())}'),
        if (effectiveRange != null) pw.Text('Period: ${DateFormat.yMMMd().format(effectiveRange.start)} - ${DateFormat.yMMMd().format(effectiveRange.end)}'),
        pw.SizedBox(height: 20),
        pw.Text('Task List', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: _selectedColumns,
          data: tasks.map((t) {
            final row = <String>[];
            for (final col in _selectedColumns) {
              switch (col) {
                case 'Title': row.add(t.title); break;
                case 'Assignee': row.add(memberNames[t.assignedTo] ?? t.assignedTo); break;
                case 'Deadline': row.add(DateFormat.yMMMd().format(t.deadline)); break;
                case 'Status': row.add(t.isCompleted ? 'Done' : 'Pending'); break;
                case 'Priority': row.add(t.priority.name.toUpperCase()); break;
                case 'Progress': row.add('${t.progressPercent}%'); break;
                case 'Start Date': row.add(DateFormat.yMMMd().format(t.startDate)); break;
                case 'Est. Hours': row.add('${t.estimatedHours}h'); break;
                default: row.add('');
              }
            }
            return row;
          }).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Text('Member Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ...memberNames.entries.map((e) {
          final memberTasks = tasks.where((t) => t.assignedTo == e.key).toList();
          return pw.Text('${e.value}: ${memberTasks.length} tasks, ${memberTasks.where((t) => t.isCompleted).length} completed');
        }),
      ],
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
