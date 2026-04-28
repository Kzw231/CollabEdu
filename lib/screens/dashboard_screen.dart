import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project.dart';
import '../models/project_form_result.dart';
import '../models/task.dart';
import '../services/current_user.dart';
import '../theme.dart';
import 'stream_tab.dart';
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
  bool _hideTabFab = false;
  final _supabase = Supabase.instance.client;

  final Map<String, int> _projectMemberCount = {};

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
        const SnackBar(
          content: Text('Failed to load user profile. Please log in again.'),
        ),
      );
    }
  }

  Future<void> _loadCurrentMember() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
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

      final memberProjects = await _supabase
          .from('project_members')
          .select('project_id')
          .eq('member_id', CurrentUser.memberId!);
      final projectIds =
      memberProjects.map<String>((row) => row['project_id']).toList();

      if (projectIds.isEmpty) {
        setState(() {
          projects = [];
          tasks = [];
          _projectMemberCount.clear();
          _isLoading = false;
        });
        return;
      }

      final projectsData = await _supabase
          .from('projects')
          .select('*')
          .inFilter('id', projectIds);
      projects =
          projectsData.map((json) => Project.fromJson(json)).toList();

      for (final project in projects) {
        final countResp = await _supabase
            .from('project_members')
            .select('*')
            .eq('project_id', project.id)
            .count(CountOption.exact);
        _projectMemberCount[project.id] = countResp.count ?? 0;
      }

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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int getProjectMemberCount(Project project) {
    return _projectMemberCount[project.id] ?? 0;
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
      final filesResp = await _supabase
          .from('files')
          .select('storage_path')
          .eq('project_id', project.id);
      final paths = (filesResp as List)
          .map((f) => f['storage_path'] as String)
          .toList();
      if (paths.isNotEmpty) {
        await _supabase.storage.from('project_files').remove(paths);
      }

      await _supabase.from('projects').delete().eq('id', project.id);

      if (mounted) {
        setState(() {
          projects.remove(project);
          tasks.removeWhere((t) => t.projectId == project.id);
          _projectMemberCount.remove(project.id);
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

  Future<void> _syncProjectMembers(
      String projectId, List<String> memberIds) async {
    final desired = memberIds.toSet();
    final me = CurrentUser.memberId;
    if (me != null) desired.add(me);

    final rows = await _supabase
        .from('project_members')
        .select('member_id')
        .eq('project_id', projectId);
    final existing =
    (rows as List).map((e) => e['member_id'] as String).toSet();

    for (final id in desired.difference(existing)) {
      await _supabase.from('project_members').insert({
        'project_id': projectId,
        'member_id': id,
        'role': id == me ? 'admin' : 'member',
      });
    }
    for (final id in existing.difference(desired)) {
      if (id == me) continue;
      await _supabase
          .from('project_members')
          .delete()
          .eq('project_id', projectId)
          .eq('member_id', id);
    }
    _projectMemberCount[projectId] = desired.length;
  }

  Future<void> editProject(Project project) async {
    setState(() => _hideTabFab = true);
    ProjectFormResult? result;
    try {
      result = await Navigator.push<ProjectFormResult?>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => EditProjectScreen(
            project: project,
            existingProjects: projects,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _hideTabFab = false);
    }

    if (result != null) {
      try {
        final updatedProject = result.project;
        final memberIds = result.memberIds;
        await _supabase
            .from('projects')
            .update(updatedProject.toJson())
            .eq('id', updatedProject.id);
        await _syncProjectMembers(updatedProject.id, memberIds);

        final index = projects.indexWhere((p) => p.id == updatedProject.id);
        if (index != -1) {
          setState(() {
            projects[index] = updatedProject;
            _projectMemberCount[updatedProject.id] = memberIds.length;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Project updated")),
        );
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
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(
          project: project,
          tasks: tasks.where((t) => t.projectId == project.id).toList(),
          onRefresh: _loadData,
        ),
      ),
    );
    if (result == 'edit') {
      await editProject(project);
    } else if (result == 'delete') {
      await _loadData();
    }
  }

  Future<void> _createProject() async {
    if (CurrentUser.memberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User profile not loaded. Please restart app.'),
        ),
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
        final memberIds = result.memberIds;
        final projectRow = Map<String, dynamic>.from(newProject.toJson());
        if ((projectRow['created_by'] as String?)?.isEmpty ?? true) {
          projectRow['created_by'] = CurrentUser.memberId;
        }

        final inserted =
        await _supabase.from('projects').insert(projectRow).select();
        final createdProject = Project.fromJson(inserted.first);

        final memberRows = memberIds.map((mid) => {
          'project_id': createdProject.id,
          'member_id': mid,
          'role': mid == CurrentUser.memberId ? 'admin' : 'member',
        }).toList();
        await _supabase.from('project_members').insert(memberRows);

        if (mounted) {
          setState(() {
            projects.add(createdProject);
            _projectMemberCount[createdProject.id] = memberIds.length;
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
    if (_selectedIndex == 0) {
      return FloatingActionButton(
        onPressed: _createProject,
        child: const Icon(Icons.add),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 在 _DashboardScreenState 的 build 方法中
    final tabs = [
      StreamTab(
        projects: projects,
        tasks: tasks,
        onProjectTap: _navigateToProjectDetail,
        onProjectEdit: editProject,
        onRefresh: _loadData,
        getMemberCount: getProjectMemberCount,          
      ),
      PeopleTab(
        projects: projects,
        onRefresh: _loadData,
        getMemberCount: getProjectMemberCount,         
      ),
      GradesTab(
        projects: projects,
        tasks: tasks,
        onRefresh: _loadData,
        getMemberCount: getProjectMemberCount,          
      ),
      FilesTab(
        projects: projects,
        onRefresh: _loadData,
        getMemberCount: getProjectMemberCount,         
      ),
    ];

    final maxTab = tabs.length - 1;
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
                  builder: (_) => ReportGeneratorScreen(
                    projects: projects,
                    tasks: tasks,
                  ),
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Stream',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'People',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grade_outlined),
            activeIcon: Icon(Icons.grade),
            label: 'Grades',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Files',
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }
}
