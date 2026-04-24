import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../widgets/empty_state.dart';
import '../widgets/project_selector.dart';
import '../theme.dart';

class GradesTab extends StatefulWidget {
  final List<Project> projects;
  final List<Task> tasks;
  final Future<void> Function() onRefresh;

  const GradesTab({
    super.key,
    required this.projects,
    required this.tasks,
    required this.onRefresh,
  });

  @override
  State<GradesTab> createState() => _GradesTabState();
}

class _GradesTabState extends State<GradesTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Project? _selectedProject;
  final _supabase = Supabase.instance.client;

  final Map<String, String> _memberNames = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final links = await _supabase
          .from('project_members')
          .select('member_id')
          .eq('project_id', projectId);
      final ids =
      (links as List).map((e) => e['member_id'] as String).toList();
      if (ids.isEmpty) {
        setState(() => _memberNames.clear());
        return;
      }
      final members = await _supabase
          .from('members')
          .select('id, name')
          .inFilter('id', ids);
      final map = <String, String>{};
      for (final m in (members as List)) {
        map[m['id']] = m['name'] ?? m['id'];
      }
      setState(() {
        _memberNames.clear();
        _memberNames.addAll(map);
      });
    } catch (e) {
      setState(() => _memberNames.clear());
    }
  }

  List<Task> get projectTasks => _selectedProject == null
      ? []
      : widget.tasks
      .where((t) => t.projectId == _selectedProject!.id)
      .toList();

  List<String> get memberIds => _memberNames.keys.toList();

  @override
  Widget build(BuildContext context) {
    if (widget.projects.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            EmptyState(
              icon: Icons.grade_outlined,
              title: 'No projects yet',
              subtitle: 'Create a project to see analytics',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await widget.onRefresh();
        if (_selectedProject != null) {
          await _loadMembersForProject(_selectedProject!.id);
        }
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ProjectSelector(
              key: ValueKey(_selectedProject?.id),
              projects: widget.projects,
              selectedProject: _selectedProject,
              onChanged: (p) {
                setState(() => _selectedProject = p);
                if (p != null) _loadMembersForProject(p.id);
              },
              memberCount: _memberNames.length,
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Burndown'),
              Tab(text: 'Workload'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildBurndownTab(),
                _buildWorkloadTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final tasks = projectTasks;
    final completed = tasks.where((t) => t.isCompleted).length;
    final total = tasks.length;
    final progress = total == 0 ? 0.0 : completed / total;
    final healthScore = _calculateHealthScore(tasks);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(AppBorderRadius.large)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Project Health',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: _getHealthColor(healthScore),
                          borderRadius:
                          BorderRadius.circular(20)),
                      child: Text('$healthScore%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                    value: healthScore / 100,
                    backgroundColor: AppColors.divider,
                    color: _getHealthColor(healthScore),
                    minHeight: 10),
                const SizedBox(height: 8),
                Text(_getHealthMessage(healthScore)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(AppBorderRadius.large)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Overall Progress',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 150,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                            value: completed.toDouble(),
                            color: AppColors.success,
                            title: completed > 0
                                ? '$completed'
                                : '',
                            radius: 50,
                            titleStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        PieChartSectionData(
                            value:
                            (total - completed).toDouble(),
                            color: AppColors.divider,
                            title: (total - completed) > 0
                                ? '${total - completed}'
                                : '',
                            radius: 45,
                            titleStyle: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                    '$completed of $total tasks completed (${(progress * 100).toInt()}%)'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(AppBorderRadius.large)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Member Progress',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (memberIds.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child:
                    Text('No members in this project'),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Member')),
                        DataColumn(label: Text('Completed')),
                        DataColumn(label: Text('Progress')),
                      ],
                      rows: memberIds.map((memberId) {
                        final memberName =
                            _memberNames[memberId] ?? memberId;
                        final memberTasks = tasks
                            .where((t) =>
                        t.assignedTo == memberId)
                            .toList();
                        final memberCompleted = memberTasks
                            .where((t) => t.isCompleted)
                            .length;
                        final percentage = memberTasks.isEmpty
                            ? 0.0
                            : memberCompleted /
                            memberTasks.length;
                        return DataRow(cells: [
                          DataCell(Text(memberName)),
                          DataCell(Text(
                              '$memberCompleted/${memberTasks.length}')),
                          DataCell(SizedBox(
                              width: 120,
                              child: Row(children: [
                                Expanded(
                                    child:
                                    LinearProgressIndicator(
                                      value: percentage,
                                      backgroundColor:
                                      AppColors.divider,
                                      color: AppColors.primary,
                                    )),
                                const SizedBox(width: 8),
                                Text(
                                    '${(percentage * 100).toInt()}%')
                              ]))),
                        ]);
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBurndownTab() {
    final tasks = projectTasks;
    if (tasks.isEmpty)
      return const Center(
          child: Text('No tasks to display burndown chart'));

    final now = DateTime.now();
    final startDate = tasks
        .map((t) => t.startDate)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final endDate = tasks
        .map((t) => t.deadline)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final totalDays = endDate.difference(startDate).inDays + 1;

    final idealRemaining = <FlSpot>[];
    final totalEstimate =
    tasks.fold<int>(0, (sum, t) => sum + t.estimatedHours);
    for (int i = 0; i <= totalDays; i++) {
      final day = startDate.add(Duration(days: i));
      if (day.isAfter(now)) break;
      idealRemaining.add(
          FlSpot(i.toDouble(), totalEstimate * (1 - i / totalDays)));
    }

    final actualRemaining = <FlSpot>[];
    for (int i = 0; i <= totalDays; i++) {
      final day = startDate.add(Duration(days: i));
      if (day.isAfter(now)) break;
      int remaining = 0;
      for (var task in tasks) {
        if (task.deadline.isBefore(day) ||
            task.startDate.isAfter(day)) continue;
        remaining += (task.estimatedHours *
            (100 - task.progressPercent) /
            100)
            .round();
      }
      actualRemaining
          .add(FlSpot(i.toDouble(), remaining.toDouble()));
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(AppBorderRadius.large)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Burndown Chart',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                Container(
                    width: 12,
                    height: 12,
                    color: AppColors.textSecondary),
                const SizedBox(width: 4),
                const Text('Ideal',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Container(
                    width: 12,
                    height: 12,
                    color: AppColors.error),
                const SizedBox(width: 4),
                const Text('Actual',
                    style: TextStyle(fontSize: 12))
              ]),
              const SizedBox(height: 16),
              SizedBox(
                height: 250,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                        show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40)),
                      bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) =>
                                  Text(
                                      DateFormat.MMMd().format(
                                          startDate.add(Duration(
                                              days: value
                                                  .toInt()))),
                                      style: const TextStyle(
                                          fontSize: 10)))),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                          spots: idealRemaining,
                          color: AppColors.textSecondary,
                          dotData:
                          const FlDotData(show: false),
                          barWidth: 2,
                          dashArray: [5, 5]),
                      LineChartBarData(
                          spots: actualRemaining,
                          color: AppColors.error,
                          dotData:
                          const FlDotData(show: true),
                          barWidth: 3),
                    ],
                    minY: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkloadTab() {
    final tasks = projectTasks;
    if (memberIds.isEmpty)
      return const Center(
          child: Text('No members in this project'));

    final memberTasksCount = <String, int>{};
    for (var memberId in memberIds) {
      memberTasksCount[memberId] =
          tasks.where((t) => t.assignedTo == memberId).length;
    }

    final sorted = memberTasksCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final busiest = sorted.isNotEmpty ? sorted.first : null;
    final lightest = sorted.isNotEmpty ? sorted.last : null;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.work,
                            color: AppColors.error),
                        const SizedBox(height: 8),
                        Text('Busiest',
                            style: TextStyle(
                                color:
                                AppColors.textSecondary)),
                        Text(
                            _memberNames[busiest?.key] ??
                                'N/A',
                            style: const TextStyle(
                                fontWeight:
                                FontWeight.bold)),
                        Text(
                            '${busiest?.value ?? 0} tasks'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.beach_access,
                            color: AppColors.success),
                        const SizedBox(height: 8),
                        Text('Lightest',
                            style: TextStyle(
                                color:
                                AppColors.textSecondary)),
                        Text(
                            _memberNames[
                            lightest?.key] ??
                                'N/A',
                            style: const TextStyle(
                                fontWeight:
                                FontWeight.bold)),
                        Text(
                            '${lightest?.value ?? 0} tasks'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(AppBorderRadius.large)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Member Workload',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: memberTasksCount.values.isEmpty
                            ? 1
                            : memberTasksCount.values
                            .reduce((a, b) =>
                        a > b ? a : b)
                            .toDouble() +
                            1,
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true)),
                          bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget:
                                      (value, meta) {
                                    final index =
                                    value.toInt();
                                    if (index <
                                        memberIds.length) {
                                      final name = _memberNames[
                                      memberIds[
                                      index]] ??
                                          memberIds[
                                          index];
                                      return Padding(
                                        padding:
                                        const EdgeInsets
                                            .only(top: 8),
                                        child: Text(
                                          name.length > 6
                                              ? '${name.substring(0, 6)}…'
                                              : name,
                                          style: const TextStyle(
                                              fontSize: 10),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  })),
                        ),
                        barGroups: memberIds
                            .asMap()
                            .entries
                            .map((entry) {
                          final index = entry.key;
                          final memberId = entry.value;
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: (memberTasksCount[
                                memberId] ??
                                    0)
                                    .toDouble(),
                                color: AppColors.info,
                                width: 20,
                                borderRadius:
                                const BorderRadius.vertical(
                                    top:
                                    Radius.circular(
                                        4)),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _calculateHealthScore(List<Task> tasks) {
    if (tasks.isEmpty) return 100;
    int score = 100;
    final now = DateTime.now();
    score -= tasks
        .where((t) =>
    !t.isCompleted && t.deadline.isBefore(now))
        .length *
        10;
    for (var task in tasks) {
      if (task.isCompleted) continue;
      final totalDuration =
          task.deadline.difference(task.startDate).inDays;
      final elapsed = now.difference(task.startDate).inDays;
      if (totalDuration > 0) {
        final expectedProgress =
        (elapsed / totalDuration * 100).clamp(0, 100);
        if (task.progressPercent < expectedProgress - 20)
          score -= 5;
      }
    }
    return score.clamp(0, 100);
  }

  Color _getHealthColor(int score) {
    if (score >= 70) return AppColors.success;
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
  }

  String _getHealthMessage(int score) {
    if (score >= 70) return 'Project is on track!';
    if (score >= 40) return 'Project needs attention.';
    return 'Project is at risk!';
  }
}
