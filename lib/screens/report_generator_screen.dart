import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
  Project? _selectedProject;
  DateTimeRange? _dateRange;
  final List<String> _selectedMetrics = ['进度', '任务列表', '成员贡献'];

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
          ListTile(
            title: Text(_dateRange == null
                ? 'Select Date Range'
                : '${DateFormat.yMMMd().format(_dateRange!.start)} - ${DateFormat.yMMMd().format(_dateRange!.end)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (range != null) setState(() => _dateRange = range);
            },
          ),
          const SizedBox(height: 20),
          const Text('Include Metrics', style: TextStyle(fontWeight: FontWeight.w600)),
          ...['进度', '任务列表', '成员贡献', '工时统计'].map((metric) {
            return CheckboxListTile(
              title: Text(metric),
              value: _selectedMetrics.contains(metric),
              onChanged: (v) {
                setState(() {
                  if (v!) {
                    _selectedMetrics.add(metric);
                  } else {
                    _selectedMetrics.remove(metric);
                  }
                });
              },
            );
          }),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _selectedProject == null ? null : _generateReport,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Generate PDF Report'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateReport() async {
    final project = _selectedProject!;
    var tasks = widget.tasks.where((t) => t.projectId == project.id).toList();
    if (_dateRange != null) {
      tasks = tasks.where((t) =>
      t.createdAt.isAfter(_dateRange!.start) && t.createdAt.isBefore(_dateRange!.end)
      ).toList();
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Header(level: 0, child: pw.Text('Project Report: ${project.name}')),
          pw.Text('Generated on: ${DateFormat.yMMMd().format(DateTime.now())}'),
          pw.Text('Date Range: ${_dateRange != null ? "${DateFormat.yMMMd().format(_dateRange!.start)} - ${DateFormat.yMMMd().format(_dateRange!.end)}" : "All time"}'),
          pw.SizedBox(height: 20),
          if (_selectedMetrics.contains('进度')) ...[
            pw.Text('Progress Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Completed: ${tasks.where((t) => t.isCompleted).length} / ${tasks.length}'),
            pw.SizedBox(height: 10),
          ],
          if (_selectedMetrics.contains('任务列表')) ...[
            pw.Text('Task List', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Table.fromTextArray(
              headers: ['Title', 'Assignee', 'Deadline', 'Status'],
              data: tasks.map((t) => [
                t.title,
                t.assignedTo,
                DateFormat.yMMMd().format(t.deadline),
                t.isCompleted ? 'Done' : 'Pending',
              ]).toList(),
            ),
            pw.SizedBox(height: 20),
          ],
          if (_selectedMetrics.contains('成员贡献')) ...[
            pw.Text('Member Contribution', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ...project.members.map((m) {
              final memberTasks = tasks.where((t) => t.assignedTo == m).toList();
              return pw.Text('$m: ${memberTasks.length} tasks, ${memberTasks.where((t) => t.isCompleted).length} completed');
            }),
          ],


        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}