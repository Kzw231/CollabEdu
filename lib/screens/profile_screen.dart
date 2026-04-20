import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/current_user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;
  Map<String, dynamic>? _memberData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    final response = await supabase
        .from('members')
        .select('id, name, email, bio, avatar_url')
        .eq('auth_uid', user.id)
        .maybeSingle();
    if (response != null) {
      _memberData = response;
      _nameController.text = response['name'] ?? '';
      _bioController.text = response['bio'] ?? '';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Update members table
      await supabase.from('members').update({
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
      }).eq('auth_uid', user.id);

      // Update auth user metadata (optional)
      await supabase.auth.updateUser(
        UserAttributes(data: {'name': _nameController.text.trim()}),
      );

      // Update CurrentUser singleton
      CurrentUser.name = _nameController.text.trim();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      // Reload data to show changes
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Profile')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (_memberData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Profile not found',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                user == null
                    ? 'You are not signed in.'
                    : 'There is no members row for this account (e.g. after a database reset). '
                        'Sign out and register again, or ask an admin to fix your profile.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              if (user?.email != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Signed in as: ${user!.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _confirmLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Avatar placeholder (you can add image picker later)
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blue,
                  child: Text(
                    (_nameController.text.isNotEmpty ? _nameController.text[0] : '?').toUpperCase(),
                    style: const TextStyle(fontSize: 40, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Member ID: ${_memberData!['id']}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v!.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Bio (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Text('Email: ${_memberData!['email']}'),
              const SizedBox(height: 24),
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveProfile,
                      child: const Text('Save Changes'),
                    ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _confirmLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Sign out of CollabEdu on this device?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Pushed routes (e.g. this screen) sit above [AuthWrapper]. Signing out only swaps
    // Dashboard→Login under the stack, so pop to the root route first or Login never shows.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }

    try {
      await Supabase.instance.client.auth.signOut();
      CurrentUser.memberId = null;
      CurrentUser.name = null;
      CurrentUser.email = null;
      messenger?.showSnackBar(const SnackBar(content: Text('Signed out')));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Could not sign out: $e')));
    }
  }
}