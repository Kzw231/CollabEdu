import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../services/database_helper.dart';
import '../theme.dart';
import 'stream_tab.dart';
import 'work_tab.dart';
import 'people_tab.dart';
import 'grades_tab.dart';
import 'create_project_screen.dart';
import 'edit_project_screen.dart';
import 'project_detail_screen.dart';
import 'report_generator_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  List<Project> projects = [];
  List<Task> tasks = [];
  bool _isLoading = true;

  final _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final loadedProjects = await _dbHelper.getAllProjects();
      final loadedTasks = await _dbHelper.getAllTasks();
      setState(() {
        projects = loadedProjects;
        tasks = loadedTasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  double getProgress(String projectId) {
    final projectTasks = tasks.where((t) => t.projectId == projectId).toList();
    if (projectTasks.isEmpty) return 0;
    int completed = projectTasks.where((t) => t.isCompleted).length;
    return completed / projectTasks.length;
  }

  void deleteProject(Project p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete project"),
        content: Text("Are you sure you want to delete '${p.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _dbHelper.deleteProject(p.id);
    setState(() {
      tasks.removeWhere((t) => t.projectId == p.id);
      projects.remove(p);
    });
  }

  void editProject(Project p) async {
    final updatedProject = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProjectScreen(project: p)),
    );
    if (updatedProject != null) {
      await _dbHelper.updateProject(updatedProject);
      await _dbHelper.updateTasksForProject(updatedProject);
      final updatedTasks = await _dbHelper.getAllTasks();
      setState(() {
        int index = projects.indexWhere((x) => x.id == p.id);
        projects[index] = updatedProject;
        tasks = updatedTasks;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Project updated & tasks synced")),
      );
    }
  }

  void _navigateToProjectDetail(Project project) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(
          project: project,
          tasks: tasks,
          onTasksChanged: _refreshTasks,
        ),
      ),
    );
    _refreshTasks();
  }

  Future<void> _refreshTasks() async {
    final updatedTasks = await _dbHelper.getAllTasks();
    setState(() {
      tasks = updatedTasks;
    });
  }

  Future<void> _createProject() async {
    final newProject = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateProjectScreen(existingProjects: projects),
      ),
    );
    if (newProject != null) {
      await _dbHelper.insertProject(newProject);
      setState(() => projects.add(newProject));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Project created")),
      );
    }
  }

  Widget? _buildFAB() {
    switch (_selectedIndex) {
      case 0:
      case 1:
        return FloatingActionButton.extended(
          onPressed: _createProject,
          icon: const Icon(Icons.add),
          label: const Text('Create project'),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tabs = [
      StreamTab(
        projects: projects,
        tasks: tasks,
        onProjectTap: _navigateToProjectDetail,
        onProjectLongPress: deleteProject,
        onProjectDoubleTap: editProject,
        onRefresh: _loadData,
      ),
      WorkTab(
        projects: projects,
        tasks: tasks,
        onProjectTap: _navigateToProjectDetail,
        onRefresh: _loadData,
      ),
      PeopleTab(
        projects: projects,
        onRefresh: _loadData,
      ),
      GradesTab(
        projects: projects,
        tasks: tasks,
        onRefresh: _loadData,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('CollabEdu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportGeneratorScreen(projects: projects, tasks: tasks),
                ),
              );
            },
            tooltip: 'Generate Report',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
        items: [
          BottomNavigationBarItem(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _selectedIndex == 0 ? Icons.home : Icons.home_outlined,
                key: ValueKey(_selectedIndex == 0),
              ),
            ),
            label: 'Stream',
          ),
          BottomNavigationBarItem(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _selectedIndex == 1 ? Icons.assignment : Icons.assignment_outlined,
                key: ValueKey(_selectedIndex == 1),
              ),
            ),
            label: 'Work',
          ),
          BottomNavigationBarItem(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _selectedIndex == 2 ? Icons.people : Icons.people_outline,
                key: ValueKey(_selectedIndex == 2),
              ),
            ),
            label: 'People',
          ),
          BottomNavigationBarItem(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _selectedIndex == 3 ? Icons.grade : Icons.grade_outlined,
                key: ValueKey(_selectedIndex == 3),
              ),
            ),
            label: 'Grades',
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }
}