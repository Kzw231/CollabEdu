import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/deep_link_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final Uri? link;
  const ResetPasswordScreen({super.key, this.link});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _isExchanging = true;
  bool _isLinkValid = true;
  String? _errorMessage;
  bool _exchangeAttempted = false;


  @override
  void initState() {
    super.initState();
    if (!_exchangeAttempted) {
      _exchangeAttempted = true;
      _handleResetLink();
    }
  }

  @override
  void dispose() {
    DeepLinkService.isResetLinkPending = false;
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleResetLink() async {
    if (!_exchangeAttempted) return;
    setState(() => _isExchanging = true);
    final supabase = Supabase.instance.client;
    final code = widget.link?.queryParameters['code'];

    // Supabase may already establish a recovery session before we parse the link.
    if (code == null && supabase.auth.currentSession != null) {
      setState(() {
        _isLinkValid = true;
        _isExchanging = false;
      });
      return;
    }

    if (code == null) {
      setState(() {
        _isLinkValid = false;
        _errorMessage = 'Invalid reset link: no code provided.';
        _isExchanging = false;
      });
      return;
    }

    try {
      // Add a timeout to prevent infinite waiting
      await supabase.auth.exchangeCodeForSession(code).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timed out'),
      );
      setState(() => _isExchanging = false);
    } on AuthException catch (e) {
      final msg = e.message;
      setState(() {
        _isLinkValid = false;
        _errorMessage = 'Reset link invalid or expired: $msg';
        _isExchanging = false;
      });
    } catch (e) {
      setState(() {
        _isLinkValid = false;
        _errorMessage = 'Unexpected error: $e';
        _isExchanging = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    if (!_isLinkValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This link is no longer valid. Please request a new one.')),
      );
      return;
    }

    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );
      // clear the pending reset flag after successful change
      DeepLinkService.isResetLinkPending = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successfully. Please log in.')),
      );
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // show loading indicator while exchanging code
    if (_isExchanging) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reset Password')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // show error if link invalid
    if (!_isLinkValid) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reset Password')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Invalid or expired password reset link',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Please request a new password reset from the login screen.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Navigate back to login
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  },
                  child: const Text('Back to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                validator: (v) => v == _passwordController.text ? null : 'Passwords do not match',
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _resetPassword,
                child: const Text('Set New Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}