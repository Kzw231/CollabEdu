import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../widgets/empty_state.dart';
import '../widgets/project_selector.dart';
import '../theme.dart';

class GradesTab extends StatefulWidget {
  final List<Project> projects;
  final List<Task> tasks;
  final Future<void> Function() onRefresh;
  final int Function(Project) getMemberCount;   // ✅ 新增

  const GradesTab({
    super.key,
    required this.projects,
    required this.tasks,
    required this.onRefresh,
    required this.getMemberCount,               // ✅ 新增
  });
  @override
  State<GradesTab> createState() => _GradesTabState();
}

class _GradesTabState extends State<GradesTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Project? _selectedProject;
  final _supabase = Supabase.instance.client;
  final Map<String, String> _memberNames = {};
  DateTimeRange? _dateRange;
  final GlobalKey _overviewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.projects.isNotEmpty) {
      _selectedProject = widget.projects.first;
      _loadMembersForProject(_selectedProject!.id);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMembersForProject(String projectId) async {
    try {
      final links = await _supabase.from('project_members').select('member_id').eq('project_id', projectId);
      final ids = (links as List).map((e) => e['member_id'] as String).toList();
      if (ids.isEmpty) {
        setState(() => _memberNames.clear());
        return;
      }
      final members = await _supabase.from('members').select('id, name').inFilter('id', ids);
      final map = <String, String>{};
      for (final m in (members as List)) {
        map[m['id']] = m['name'] ?? m['id'];
      }
      setState(() { _memberNames.clear(); _memberNames.addAll(map); });
    } catch (e) {
      setState(() => _memberNames.clear());
    }
  }

  List<Task> get projectTasks {
    var tasks = _selectedProject == null
        ? <Task>[]
        : widget.tasks.where((t) => t.projectId == _selectedProject!.id);
    if (_dateRange != null) {
      tasks = tasks.where((t) =>
      t.createdAt.isAfter(_dateRange!.start) &&
          t.createdAt.isBefore(_dateRange!.end.add(const Duration(days: 1))));
    }
    return tasks.toList();
  }

  List<String> get memberIds => _memberNames.keys.toList();

  Future<void> _exportOverview() async {
    try {
      final boundary = _overviewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/grades_overview.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      debugPrint('Export error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.projects.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
          EmptyState(icon: Icons.grade_outlined, title: 'No projects yet', subtitle: 'Create a project to see analytics'),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await widget.onRefresh();
        if (_selectedProject != null) await _loadMembersForProject(_selectedProject!.id);
      },
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ProjectSelector(
            key: ValueKey(_selectedProject?.id),
            projects: widget.projects,
            selectedProject: _selectedProject,
            onChanged: (p) { setState(() => _selectedProject = p); if (p != null) _loadMembersForProject(p.id); },
            getMemberCount: widget.getMemberCount,    ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (range != null) setState(() => _dateRange = range);
                },
                label: Text(_dateRange == null
                    ? 'All time'
                    : '${DateFormat.MMMd().format(_dateRange!.start)} - ${DateFormat.MMMd().format(_dateRange!.end)}'),
              ),
            ),
            if (_dateRange != null)
              IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _dateRange = null)),
          ]),
        ),
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Workload')],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildWorkloadTab(),
            ],
          ),
        ),
      ]),
    );
  }

  // ---------- Overview Tab ----------
  Widget _buildOverviewTab() {
    final tasks = projectTasks;
    final completed = tasks.where((t) => t.isCompleted).length;
    final total = tasks.length;
    final pending = total - completed;
    final overdue = tasks.where((t) => !t.isCompleted && t.deadline.isBefore(DateTime.now())).length;

    Widget overviewSection = RepaintBoundary(
      key: _overviewKey,
      child: Column(children: [
        Row(
          children: [
            Expanded(child: _buildStatCard('Total Tasks', '$total', Icons.task, AppColors.primary)),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard('Completed', '$completed', Icons.check_circle, AppColors.success)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildStatCard('Pending', '$pending', Icons.hourglass_empty, AppColors.warning)),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard('Overdue', '$overdue', Icons.warning_amber, overdue > 0 ? AppColors.error : AppColors.success)),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.large)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text('Task Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(height: 150, child: PieChart(PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(value: completed.toDouble(), color: AppColors.success, title: '$completed', radius: 45, titleStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  PieChartSectionData(value: (total - completed).toDouble(), color: AppColors.warning, title: '${total - completed}', radius: 45, titleStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ))),
              const SizedBox(height: 8),
              Text('$completed completed, ${total - completed} pending'),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        _buildMemberProgressTable(tasks),
      ]),
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Align(alignment: Alignment.topRight, child: IconButton(icon: Icon(Icons.share), onPressed: _exportOverview)),
        overviewSection,
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _buildMemberProgressTable(List<Task> tasks) {
    if (memberIds.isEmpty) return const SizedBox();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.large)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Member Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Member')),
                  DataColumn(label: Text('Completed')),
                  DataColumn(label: Text('Progress')),
                ],
                rows: memberIds.map((memberId) {
                  final memberName = _memberNames[memberId] ?? memberId;
                  final memberTasks = tasks.where((t) => t.assignedTo == memberId).toList();
                  final memberCompleted = memberTasks.where((t) => t.isCompleted).length;
                  final percentage = memberTasks.isEmpty ? 0.0 : memberCompleted / memberTasks.length;
                  return DataRow(cells: [
                    DataCell(Text(memberName)),
                    DataCell(Text('$memberCompleted/${memberTasks.length}')),
                    DataCell(SizedBox(
                      width: 120,
                      child: Row(children: [
                        Expanded(child: LinearProgressIndicator(value: percentage, backgroundColor: AppColors.divider, color: AppColors.primary)),
                        const SizedBox(width: 8),
                        Text('${(percentage * 100).toInt()}%'),
                      ]),
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Workload Tab (完全修复) ----------
  Widget _buildWorkloadTab() {
    final tasks = projectTasks;
    if (memberIds.isEmpty) {
      return const Center(child: Text('No members in this project'));
    }

    final memberTasksCount = <String, int>{};
    for (var memberId in memberIds) {
      memberTasksCount[memberId] = tasks.where((t) => t.assignedTo == memberId).length;
    }

    if (memberTasksCount.values.every((v) => v == 0)) {
      return const Center(child: Text('No tasks assigned yet'));
    }

    final sorted = memberTasksCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final busiest = sorted.isNotEmpty ? sorted.first : null;
    final lightest = sorted.isNotEmpty ? sorted.last : null;

    // 计算合理的 maxY，至少为 1，避免除零
    final maxTasks = memberTasksCount.values.reduce((a, b) => a > b ? a : b);
    final double chartMaxY = maxTasks > 0 ? maxTasks.toDouble() + 1 : 2.0;

    Widget chart = Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.large)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Member Workload', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMaxY,
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < memberIds.length) {
                          final name = _memberNames[memberIds[index]] ?? memberIds[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              name.length > 10 ? '${name.substring(0, 10)}…' : name,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false),
                barGroups: memberIds.asMap().entries.map((entry) {
                  final index = entry.key;
                  final memberId = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: (memberTasksCount[memberId] ?? 0).toDouble(),
                        color: AppColors.info,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ]),
      ),
    );

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Icon(Icons.work, color: AppColors.error),
            Text('Busiest', style: TextStyle(color: AppColors.textSecondary)),
            Text(_memberNames[busiest?.key] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${busiest?.value ?? 0} tasks'),
          ])))),
          const SizedBox(width: 16),
          Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Icon(Icons.beach_access, color: AppColors.success),
            Text('Lightest', style: TextStyle(color: AppColors.textSecondary)),
            Text(_memberNames[lightest?.key] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${lightest?.value ?? 0} tasks'),
          ])))),
        ]),
        const SizedBox(height: 16),
        chart,
      ]),
    );
  }

  // 为了兼容性保留的占位方法（可删除，不影响）
  int _calculateHealthScore(List<Task> tasks) => 100;
  Color _getHealthColor(int score) => AppColors.success;
  String _getHealthMessage(int score) => '';
}
