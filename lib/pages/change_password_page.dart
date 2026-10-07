import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../features/auth/logic/session_controller.dart';
import '../features/network/data/api_exception.dart';
import '../features/network/data/result.dart';

/// Set a new password ('/change-password'). The guard parks anyone with
/// `must_change_password` here until the change succeeds; signed-in
/// users can also reach it voluntarily. Sign out is offered because a
/// user who forgot the old password must be able to leave.
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() =>
      _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final TextEditingController _old = TextEditingController();
  final TextEditingController _fresh = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _old.dispose();
    _fresh.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  String _failureText(Object error) {
    if (error is ApiException) {
      return error.message ?? 'Something went wrong. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_old.text.isEmpty) {
      _message('Enter your current password.');
      return;
    }
    if (_fresh.text.length < 8) {
      _message('New password must be at least 8 characters.');
      return;
    }
    if (_fresh.text != _confirm.text) {
      _message('Passwords don\'t match.');
      return;
    }
    setState(() => _busy = true);
    final result = await ref.read(sessionProvider.notifier).changePassword(
          oldPassword: _old.text,
          newPassword: _fresh.text,
          newPasswordConfirm: _confirm.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Data():
        _message('Password changed.');
        context.go('/home');
      case Error(:final error):
        _message(_failureText(error));
      case Offline():
        _message('You are offline. Check your connection and try again.');
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(sessionProvider.notifier).logout();
    if (!mounted) return;
    // The guard reroutes to '/login' as the state clears; if the
    // redirect has not landed yet, restore the button rather than
    // freezing a still-mounted page behind a permanently disabled one.
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RepairAI'),
        backgroundColor: RepairColors.bgCenter,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set a new password',
                textAlign: TextAlign.center,
                style: RepairText.wordmark(28),
              ),
              const SizedBox(height: 8),
              Text(
                'Your account requires a fresh password.',
                textAlign: TextAlign.center,
                style: RepairText.tagline(13),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _old,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Current password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _fresh,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'New password',
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              Text(
                'At least 8 characters.',
                style: RepairText.tagline(12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Confirm new password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save password'),
              ),
              TextButton(
                onPressed: _busy ? null : _signOut,
                child: const Text('Sign out instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
