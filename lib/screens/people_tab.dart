import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project.dart';
import '../services/current_user.dart';
import '../services/member_lookup.dart';
import '../widgets/empty_state.dart';
import '../widgets/project_selector.dart';
import 'qr_scanner_screen.dart';

class _ProjectMemberRow {
  final String memberId;
  final String name;
  final String? email;
  final String role;

  const _ProjectMemberRow({
    required this.memberId,
    required this.name,
    this.email,
    required this.role,
  });
}

class PeopleTab extends StatefulWidget {
  final List<Project> projects;
  final Future<void> Function() onRefresh;
  final int Function(Project) getMemberCount;   
  const PeopleTab({
    super.key,
    required this.projects,
    required this.onRefresh,
    required this.getMemberCount,             
  });

  @override
  State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab> {
  List<_ProjectMemberRow> _rows = [];
  bool _loadingMembers = false;
  int _loadGen = 0;
  String? _selectedProjectId;

  Project? get _currentProject {
    if (widget.projects.isEmpty) return null;
    if (_selectedProjectId != null) {
      return widget.projects.firstWhere(
            (p) => p.id == _selectedProjectId,
        orElse: () => widget.projects.first,
      );
    }
    return widget.projects.first;
  }

  @override
  void initState() {
    super.initState();
    if (widget.projects.isNotEmpty) {
      _selectedProjectId = widget.projects.first.id;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMembersForCurrent());
  }

  @override
  void didUpdateWidget(covariant PeopleTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.projects.isEmpty) {
      _selectedProjectId = null;
      return;
    }
    if (_selectedProjectId == null || !widget.projects.any((p) => p.id == _selectedProjectId)) {
      _selectedProjectId = widget.projects.first.id;
    }
    _loadMembersForCurrent();
  }

  Future<void> _loadMembersForCurrent() async {
    final project = _currentProject;
    if (project == null) return;
    final gen = ++_loadGen;
    setState(() {
      _rows = [];
      _loadingMembers = true;
    });
    try {
      final links = await Supabase.instance.client
          .from('project_members')
          .select('member_id, role')
          .eq('project_id', project.id);
      final list = links as List<dynamic>;
      final ids = list.map<String>((e) => e['member_id'] as String).toList();
      if (ids.isEmpty) {
        if (mounted && gen == _loadGen) {
          setState(() => _loadingMembers = false);
        }
        return;
      }
      final members = await Supabase.instance.client
          .from('members')
          .select('id, name, email')
          .inFilter('id', ids);
      final memList = members as List<dynamic>;
      final byId = {for (final m in memList) m['id'] as String: m as Map<String, dynamic>};
      final rows = <_ProjectMemberRow>[];
      for (final link in list) {
        final mid = link['member_id'] as String;
        final role = (link['role'] as String?) ?? 'member';
        final m = byId[mid];
        if (m != null) {
          rows.add(_ProjectMemberRow(
            memberId: mid,
            name: (m['name'] as String?) ?? mid,
            email: m['email'] as String?,
            role: role,
          ));
        }
      }
      rows.sort((a, b) {
        final aYou = a.memberId == CurrentUser.memberId ? 0 : 1;
        final bYou = b.memberId == CurrentUser.memberId ? 0 : 1;
        if (aYou != bYou) return aYou.compareTo(bYou);
        return a.name.compareTo(b.name);
      });
      if (mounted && gen == _loadGen) {
        setState(() {
          _rows = rows;
          _loadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted && gen == _loadGen) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load members: $e')),
        );
        setState(() => _loadingMembers = false);
      }
    }
  }

  Future<void> _showInviteDialog(Project project) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite to project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Look up someone already in the members directory. Use their '
                  'email (exact match) or member ID (e.g. M0001).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Email or member ID',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final input = controller.text.trim();
    controller.dispose();
    if (input.isEmpty) return;

    try {
      final member = await lookupMemberByIdOrEmail(input);
      if (member == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No member found. Check email or ID.')),
          );
        }
        return;
      }
      final memberId = member['id'] as String;
      final existing = await Supabase.instance.client
          .from('project_members')
          .select('member_id')
          .eq('project_id', project.id)
          .eq('member_id', memberId)
          .maybeSingle();
      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That person is already on this project.')),
          );
        }
        return;
      }
      await Supabase.instance.client.from('project_members').insert({
        'project_id': project.id,
        'member_id': memberId,
        'role': 'member',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${member['name'] ?? memberId}')),
        );
        await _loadMembersForCurrent();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add member: $e')),
        );
      }
    }
  }

  Future<void> _scanAndInviteMember(Project project) async {
    final scannedId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );
    if (scannedId == null || scannedId.isEmpty) return;

    try {
      final member = await lookupMemberByIdOrEmail(scannedId);
      if (member == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No member found for that QR code.')),
          );
        }
        return;
      }
      final memberId = member['id'] as String;
      final existing = await Supabase.instance.client
          .from('project_members')
          .select('member_id')
          .eq('project_id', project.id)
          .eq('member_id', memberId)
          .maybeSingle();
      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That person is already on this project.')),
          );
        }
        return;
      }
      await Supabase.instance.client.from('project_members').insert({
        'project_id': project.id,
        'member_id': memberId,
        'role': 'member',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${member['name'] ?? memberId}')),
        );
        await _loadMembersForCurrent();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add member: $e')),
        );
      }
    }
  }

  bool _canDeleteMember(_ProjectMemberRow member, Project project) {
    // Cannot delete yourself
    if (member.memberId == CurrentUser.memberId) return false;
    // Cannot delete the project owner unless you are the owner
    if (member.memberId == project.createdBy && CurrentUser.memberId != project.createdBy) {
      return false;
    }
    return true;
  }

  Future<void> _confirmRemoveMember(_ProjectMemberRow member, Project project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member'),
        content: Text('Remove ${member.name} from "${project.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('project_members')
          .delete()
          .eq('project_id', project.id)
          .eq('member_id', member.memberId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed ${member.name} from the project')),
        );
        await _loadMembersForCurrent();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove member: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.projects.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            EmptyState(
              icon: Icons.people_outline,
              title: 'No projects yet',
              subtitle: 'Create a project to add members',
            ),
          ],
        ),
      );
    }

    final currentProject = _currentProject!;

    return RefreshIndicator(
      onRefresh: () async {
        await widget.onRefresh();
        await _loadMembersForCurrent();
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ProjectSelector(
              key: ValueKey(_selectedProjectId ?? widget.projects.first.id),
              projects: widget.projects,
              selectedProject: _currentProject,
              onChanged: (p) {
                if (p != null) {
                  _selectedProjectId = p.id;
                  setState(() {});
                  _loadMembersForCurrent();
                }
              },
              getMemberCount: widget.getMemberCount,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  'Team',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showInviteDialog(currentProject),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Invite'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Scan member QR code',
                  onPressed: () => _scanAndInviteMember(currentProject),
                ),
              ],
            ),
          ),
          if (_loadingMembers && _rows.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No members loaded. Pull to refresh or check your connection and table policies.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ..._rows.map((row) {
                      final isYou = row.memberId == CurrentUser.memberId;
                      final isCreator = row.memberId == currentProject.createdBy;
                      String roleText = row.role;
                      if (isCreator) roleText = 'Owner · $roleText';
                      if (isYou) roleText = '$roleText · You';
                      final subtitle = [
                        if (row.email != null && row.email!.isNotEmpty) row.email!,
                        roleText,
                      ].join(' · ');
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            row.name.isNotEmpty ? row.name[0].toUpperCase() : '?',
                          ),
                        ),
                        title: Text(row.name),
                        subtitle: Text(subtitle),
                        trailing: _canDeleteMember(row, currentProject)
                            ? IconButton(
                          icon: const Icon(Icons.person_remove, color: Colors.red),
                          tooltip: 'Remove from project',
                          onPressed: () => _confirmRemoveMember(row, currentProject),
                        )
                            : null,
                      );
                    }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
