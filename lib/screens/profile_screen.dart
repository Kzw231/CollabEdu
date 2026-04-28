import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/current_user.dart';
import '../services/network_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isLoading = false;
  bool _isSaving = false;
  Map<String, dynamic>? _memberData;
  final ImagePicker _picker = ImagePicker();

  static const int maxAvatarSizeMB = 2;
  static const int maxAvatarSizeBytes = maxAvatarSizeMB * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!await NetworkService.hasInternet()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection. Cannot load profile.')),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final response = await supabase
          .from('members')
          .select('id, name, email, bio, avatar_url, created_at, last_login')
          .eq('auth_uid', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _memberData = response;
          _nameController.text = response?['name'] ?? '';
          _bioController.text = response?['bio'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (!await NetworkService.hasInternet()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Cannot save profile.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('members').update({
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
      }).eq('auth_uid', user.id);
      await supabase.auth.updateUser(
        UserAttributes(data: {'name': _nameController.text.trim()}),
      );
      CurrentUser.name = _nameController.text.trim();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        String message = 'Error saving profile. ';
        if (e.toString().contains('network')) {
          message = 'Network error. Please try again.';
        } else {
          message += e.toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  // Avatar upload
  Future<void> _pickAndUploadAvatar() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final File file = File(image.path);
    await _uploadAvatar(file);
  }

  Future<void> _takeAndUploadAvatar() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;
    final File file = File(photo.path);
    await _uploadAvatar(file);
  }


  Future<void> _uploadAvatar(File file) async {
    // check file size
    final fileSize = await file.length();
    if (fileSize > maxAvatarSizeBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Avatar too large. Maximum size is $maxAvatarSizeMB MB.')),
      );
      return;
    }

    // check internet
    if (!await NetworkService.hasInternet()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Cannot upload avatar.')),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = fileName;

      // Upload the file
      await supabase.storage.from('avatars').upload(filePath, file);
      final publicUrl = supabase.storage.from('avatars').getPublicUrl(filePath);

      // Update member record
      await supabase.from('members').update({'avatar_url': publicUrl}).eq('auth_uid', user.id);
      await _loadData(); // refresh profile
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated')),
      );
    } on StorageException catch (e) {
      String msg = 'Avatar upload failed: ';
      if (e.message.contains('Bucket not found')) {
        msg = 'Storage bucket not configured. Contact support.';
      } else if (e.statusCode == 413) {
        msg = 'Image too large for server. Try a smaller image.';
      } else {
        msg += e.message;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Avatar upload failed: $e')),
      );
    }
    setState(() => _isSaving = false);
  }


  // change Password
  Future<void> _showChangePasswordDialog() async {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: newPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm new password'),
                validator: (v) => v == newPasswordCtrl.text ? null : 'Passwords do not match',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update')),
        ],
      ),
    );
    if (ok != true) return;
    if (!formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Verify current password by attempting sign-in
      final signInResponse = await supabase.auth.signInWithPassword(
        email: user.email!,
        password: currentPasswordCtrl.text.trim(),
      );
      if (signInResponse.user == null) throw Exception('Incorrect current password');

      // Update password
      await supabase.auth.updateUser(
        UserAttributes(password: newPasswordCtrl.text.trim()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully. Please log in again.')),
      );
      // Optionally sign out and go to login
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/'); // go to AuthWrapper
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password change failed: $e')),
      );
    }
    setState(() => _isSaving = false);
  }

  Future<void> _shareQrCode() async {
    // Give the UI time to render the QR code completely
    await Future.delayed(const Duration(seconds: 1));

    final Uint8List? imageBytes = await _screenshotController.capture();
    if (imageBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture QR code. Try again.')),
        );
      }
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final imageFile = File('${directory.path}/qr_code_${DateTime.now().millisecondsSinceEpoch}.png');
      await imageFile.writeAsBytes(imageBytes);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(imageFile.path, mimeType: 'image/png')],
        text: 'Join my project on CollabEdu\nScan this QR code to add me.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Sign out of CollabEdu on this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

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

  String _formatDate(dynamic dateTimeValue) {
    if (dateTimeValue == null) return 'Unknown';
    try {
      final dateTime = dateTimeValue is String
          ? DateTime.parse(dateTimeValue)
          : dateTimeValue as DateTime;
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatLastLogin(dynamic dateTimeValue) {
    if (dateTimeValue == null) return 'Never';
    try {
      final dateTime = dateTimeValue is String
          ? DateTime.parse(dateTimeValue)
          : dateTimeValue as DateTime;
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Never';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
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
                onPressed: _confirmLogout,
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

    final avatarUrl = _memberData!['avatar_url'] as String?;
    final memberId = _memberData!['id'];

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Avatar section
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue,
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null || avatarUrl.isEmpty
                          ? Text(
                        (_nameController.text.isNotEmpty ? _nameController.text[0] : '?').toUpperCase(),
                        style: const TextStyle(fontSize: 40, color: Colors.white),
                      )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(blurRadius: 2, color: Colors.black26)],
                        ),
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.camera_alt, size: 20),
                          onSelected: (value) {
                            if (value == 'gallery') _pickAndUploadAvatar();
                            else if (value == 'camera') _takeAndUploadAvatar();
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'gallery', child: Text('Choose from gallery')),
                            const PopupMenuItem(value: 'camera', child: Text('Take photo')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Member ID: $memberId'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v!.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Text('Email: ${_memberData!['email']}'),
              const SizedBox(height: 8),
              Text(
                'Joined: ${_formatDate(_memberData!['created_at'])}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                'Last Login: ${_formatLastLogin(_memberData!['last_login'])}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Change Password button
              OutlinedButton.icon(
                onPressed: _showChangePasswordDialog,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Change Password'),
              ),
              const SizedBox(height: 16),

              const Divider(),
              const Text('Your QR Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    Screenshot(
                      controller: _screenshotController,
                      child: Container(
                        width: 184,
                        height: 184,
                        color: Colors.white,
                        child: GestureDetector(
                          onLongPress: _shareQrCode,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: QrImageView(
                              data: memberId,
                              version: QrVersions.auto,
                              size: 160.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share),
                          tooltip: 'Share QR code',
                          onPressed: _shareQrCode,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to share',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Long‑press to share your QR code',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _saveProfile,
                child: const Text('Save Changes'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _confirmLogout,
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
}
