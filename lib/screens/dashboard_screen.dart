import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project.dart';
import '../models/project_form_result.dart';
import '../models/task.dart';
import '../services/current_user.dart';
import '../theme.dart';
import 'stream_tab.dart';
import 'work_tab.dart';
import 'people_tab.dart';
import 'grades_tab.dart';
import 'create_project_screen.dart';
import 'edit_project_screen.dart';
import 'project_detail_screen.dart';
import 'report_generator_screen.dart';
import 'profile_screen.dart';
import 'files_tab.dart';

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
  /// Hides the tab FAB while a full-screen route is open (avoids overlap on some devices).
  bool _hideTabFab = false;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadCurrentMemberAndData();
  }

  Future<void> _loadCurrentMemberAndData() async {
    await _loadCurrentMember();
    if (CurrentUser.memberId != null) {
      await _loadData();
    } else if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load user profile. Please log in again.')),
      );
    }
  }

  Future<void> _loadCurrentMember() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      // No user? Should not happen because AuthWrapper handles login.
      return;
    }
    final response = await _supabase
        .from('members')
        .select('id, name, email')
        .eq('auth_uid', user.id)
        .maybeSingle();
    if (response != null) {
      CurrentUser.memberId = response['id'];
      CurrentUser.name = response['name'];
      CurrentUser.email = response['email'];
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (CurrentUser.memberId == null) {
        setState(() => _isLoading = false);
        return;
      }
      // 1. Get project IDs where current member is a member
      final memberProjects = await _supabase
          .from('project_members')
          .select('project_id')
          .eq('member_id', CurrentUser.memberId!);
      final projectIds = memberProjects.map<String>((row) => row['project_id']).toList();

      if (projectIds.isEmpty) {
        if (mounted) {
          setState(() {
            projects = [];
            tasks = [];
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Fetch projects (using in filter)
      final projectsData = await _supabase
          .from('projects')
          .select('*')
          .inFilter('id', projectIds);
      projects = projectsData.map((json) => Project.fromJson(json)).toList();

      // 3. Fetch tasks for those projects
      final tasksData = await _supabase
          .from('tasks')
          .select('*')
          .inFilter('project_id', projectIds);
      tasks = tasksData.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  double getProgress(String projectId) {
    final projectTasks = tasks.where((t) => t.projectId == projectId).toList();
    if (projectTasks.isEmpty) return 0;
    int completed = projectTasks.where((t) => t.isCompleted).length;
    return completed / projectTasks.length;
  }

  Future<void> deleteProject(Project project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete project"),
        content: Text("Are you sure you want to delete '${project.name}'?"),
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

    try {
      // Delete project (cascade will delete project_members, tasks, files, comments)
      await _supabase.from('projects').delete().eq('id', project.id);
      if (mounted) {
        setState(() {
          projects.remove(project);
          tasks.removeWhere((t) => t.projectId == project.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting project: $e')),
        );
      }
    }
  }

  Future<void> _syncProjectMembers(String projectId, List<String> memberIds) async {
    final desired = memberIds.toSet();
    final me = CurrentUser.memberId;
    if (me != null) desired.add(me);

    final rows = await _supabase.from('project_members').select('member_id').eq('project_id', projectId);
    final list = rows as List<dynamic>;
    final existing = list.map((e) => e['member_id'] as String).toSet();

    for (final id in desired.difference(existing)) {
      await _supabase.from('project_members').insert({
        'project_id': projectId,
        'member_id': id,
        'role': id == me ? 'admin' : 'member',
      });
    }
    for (final id in existing.difference(desired)) {
      if (id == me) continue;
      await _supabase.from('project_members').delete().eq('project_id', projectId).eq('member_id', id);
    }
  }

  Future<void> editProject(Project project) async {
    setState(() => _hideTabFab = true);
    ProjectFormResult? result;
    try {
      result = await Navigator.push<ProjectFormResult?>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => EditProjectScreen(project: project, existingProjects: projects),
        ),
      );
    } finally {
      if (mounted) setState(() => _hideTabFab = false);
    }
    if (result != null) {
      try {
        final updatedProject = result.project;
        await _supabase.from('projects').update(updatedProject.toJson()).eq('id', updatedProject.id);
        await _syncProjectMembers(updatedProject.id, result.memberIds);
        final index = projects.indexWhere((p) => p.id == updatedProject.id);
        if (mounted) {
          setState(() {
            projects[index] = updatedProject;
          });
          await _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Project updated")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating project: $e')),
          );
        }
      }
    }
  }

  void _navigateToProjectDetail(Project project) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(
          project: project,
          tasks: tasks.where((t) => t.projectId == project.id).toList(),
          onTasksChanged: _refreshTasks,
        ),
      ),
    );
    await _refreshTasks();
  }

  Future<void> _refreshTasks() async {
    await _loadData(); // reload all data
  }

  Future<void> _createProject() async {
    if (CurrentUser.memberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User profile not loaded. Please restart app.')),
      );
      return;
    }
    setState(() => _hideTabFab = true);
    ProjectFormResult? result;
    try {
      result = await Navigator.push<ProjectFormResult?>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CreateProjectScreen(existingProjects: projects),
        ),
      );
    } finally {
      if (mounted) setState(() => _hideTabFab = false);
    }
    if (result != null) {
      try {
        final newProject = result.project;
        final projectRow = Map<String, dynamic>.from(newProject.toJson());
        if ((projectRow['created_by'] as String?)?.isEmpty ?? true) {
          projectRow['created_by'] = CurrentUser.memberId;
        }
        final response = await _supabase.from('projects').insert(projectRow).select();
        final createdProject = Project.fromJson(response.first);
        final memberIds = result.memberIds.toSet();
        if (CurrentUser.memberId != null) memberIds.add(CurrentUser.memberId!);
        for (final mid in memberIds) {
          await _supabase.from('project_members').insert({
            'project_id': createdProject.id,
            'member_id': mid,
            'role': mid == CurrentUser.memberId ? 'admin' : 'member',
          });
        }
        if (mounted) {
          setState(() {
            projects.add(createdProject);

          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Project created")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating project: $e')),
          );
        }
      }
    }
  }

  Widget? _buildFAB() {
    if (_hideTabFab) return null;
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
      FilesTab(projects: projects, onRefresh: _loadData),
    ];

    final maxTab = tabs.length - 1;
    if (_selectedIndex > maxTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIndex = maxTab);
      });
    }
    final tabIndex = _selectedIndex.clamp(0, maxTab);

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
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: IndexedStack(
        index: tabIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabIndex,
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
                tabIndex == 0 ? Icons.home : Icons.home_outlined,
                key: ValueKey(tabIndex == 0),
              ),
            ),
            label: 'Stream',
          ),
          BottomNavigationBarItem(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                tabIndex == 1 ? Icons.assignment : Icons.assignment_outlined,
                key: ValueKey(tabIndex == 1),
              ),
            ),
            label: 'Work',
          ),
          BottomNavigationBarItem(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                tabIndex == 2 ? Icons.people : Icons.people_outline,
                key: ValueKey(tabIndex == 2),
              ),
            ),
            label: 'People',
          ),
          BottomNavigationBarItem(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                tabIndex == 3 ? Icons.grade : Icons.grade_outlined,
                key: ValueKey(tabIndex == 3),
              ),
            ),
            label: 'Grades',
          ),
          BottomNavigationBarItem(
            icon: Icon(tabIndex == 4 ? Icons.folder : Icons.folder_outlined),
            label: 'Files',
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }
}